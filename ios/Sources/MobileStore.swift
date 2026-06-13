import Foundation
import SwiftUI

struct DiaryEntry: Identifiable, Equatable {
    let dateKey: String // "2026-06-12", 하루에 한 개
    var text: String
    var modifiedAt: Date

    var id: String { dateKey }

    var firstLine: String {
        let line = text
            .split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        return line.isEmpty ? "(내용 없음)" : line
    }
}

/// Mac 일기장과 같은 iCloud Drive 폴더(Ilgi/entries)를 보안 북마크로 접근하는 저장소.
final class MobileStore: ObservableObject {
    static let shared = MobileStore()

    @Published private(set) var entries: [DiaryEntry] = [] // 최신순
    @Published var selectedDateKey: String
    @Published var pastRevealed = false
    @Published var unlockInProgress = false
    @Published private(set) var contentVersion = 0
    @Published var folderReady = false
    @Published var setupError: String?

    private var folderURL: URL?
    private var accessedBase: URL?
    private let bookmarkKey = "entriesFolderBookmark"
    private let subpathKey = "entriesFolderSubpath"

    private var pendingSave: (text: String, dateKey: String)?
    private var saveWorkItem: DispatchWorkItem?

    private init() {
        selectedDateKey = Formatters.dateKey.string(from: Date())
        // 시뮬레이터/테스트용: 앱 Documents 폴더를 저장소로 사용
        if ProcessInfo.processInfo.environment["ILGI_USE_LOCAL"] == "1" {
            folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            folderReady = true
            reload()
            return
        }
        restoreBookmark()
    }

    // MARK: - 조회

    var todayKey: String { Formatters.dateKey.string(from: Date()) }

    var todayEntry: DiaryEntry? { entries.first { $0.dateKey == todayKey } }

    var pastEntries: [DiaryEntry] { entries.filter { $0.dateKey != todayKey } }

    func text(for dateKey: String) -> String {
        entries.first { $0.dateKey == dateKey }?.text ?? ""
    }

    func selectToday() {
        selectedDateKey = todayKey
    }

    /// 지난 일기 잠금 해제(Face ID) 후 onSuccess 실행. 이미 해제됐으면 바로 실행.
    func revealPast(onSuccess: @escaping () -> Void = {}) {
        if pastRevealed {
            onSuccess()
            return
        }
        guard !unlockInProgress else { return }
        unlockInProgress = true
        BiometricGate.unlock(reason: "지난 일기를 보려면 인증이 필요합니다") { [weak self] success in
            guard let self else { return }
            self.unlockInProgress = false
            if success {
                self.pastRevealed = true
                onSuccess()
            }
        }
    }

    // MARK: - 폴더 연결 (보안 북마크)

    /// 문서 피커로 고른 폴더를 기억한다. entries 하위 폴더가 있으면 자동으로 그쪽을 쓴다.
    func adoptFolder(_ pickedURL: URL) {
        setupError = nil
        let accessing = pickedURL.startAccessingSecurityScopedResource()
        defer { if accessing { pickedURL.stopAccessingSecurityScopedResource() } }

        var isDirectory: ObjCBool = false
        let entriesSub = pickedURL.appendingPathComponent("entries", isDirectory: true)
        let hasEntriesSub = FileManager.default.fileExists(atPath: entriesSub.path, isDirectory: &isDirectory)
            && isDirectory.boolValue

        do {
            let bookmark = try pickedURL.bookmarkData()
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            UserDefaults.standard.set(hasEntriesSub ? "entries" : "", forKey: subpathKey)
        } catch {
            setupError = "폴더를 기억하지 못했어요: \(error.localizedDescription)"
            return
        }
        restoreBookmark()
    }

    private func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var stale = false
        guard let base = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else {
            setupError = "저장된 폴더 연결이 깨졌어요. 다시 연결해주세요."
            return
        }
        guard base.startAccessingSecurityScopedResource() else {
            setupError = "iCloud 폴더에 접근하지 못했어요. 다시 연결해주세요."
            return
        }
        accessedBase = base
        if stale, let fresh = try? base.bookmarkData() {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
        let subpath = UserDefaults.standard.string(forKey: subpathKey) ?? ""
        folderURL = subpath.isEmpty ? base : base.appendingPathComponent(subpath, isDirectory: true)
        folderReady = true
        reload()
    }

    /// 폴더 연결을 끊고 온보딩으로 돌아간다.
    func resetFolder() {
        flushPendingSave()
        accessedBase?.stopAccessingSecurityScopedResource()
        accessedBase = nil
        folderURL = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: subpathKey)
        entries = []
        pastRevealed = false
        folderReady = false
    }

    // MARK: - 읽기/쓰기 (NSFileCoordinator)

    private func fileURL(for dateKey: String) -> URL? {
        folderURL?.appendingPathComponent("\(dateKey).md")
    }

    func reload() {
        guard let directory = folderURL else { return }
        var loaded: [DiaryEntry] = []
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: directory, options: [], error: &coordinationError) { dirURL in
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )) ?? []
            for url in urls {
                // 아직 다운로드되지 않은 iCloud 파일(".파일명.icloud")은 내려받기를 요청하고 건너뛴다
                if url.lastPathComponent.hasSuffix(".icloud") {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                    continue
                }
                guard url.pathExtension == "md" else { continue }
                let key = url.deletingPathExtension().lastPathComponent
                guard Formatters.dateKey.date(from: key) != nil else { continue }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? Date()
                loaded.append(DiaryEntry(dateKey: key, text: text, modifiedAt: modified))
            }
        }
        entries = loaded.sorted { $0.dateKey > $1.dateKey }
        contentVersion += 1
    }

    func save(_ text: String, for dateKey: String) {
        guard let url = fileURL(for: dateKey) else { return }
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let exists = entries.contains { $0.dateKey == dateKey }
        if isEmpty && !exists { return } // 빈 일기는 파일을 만들지 않는다

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var writeFailed = false
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { destination in
            do {
                try text.write(to: destination, atomically: true, encoding: .utf8)
            } catch {
                writeFailed = true
                NSLog("일기 저장 실패(\(dateKey)): \(error)")
            }
        }
        if coordinationError != nil || writeFailed { return }

        if let index = entries.firstIndex(where: { $0.dateKey == dateKey }) {
            entries[index].text = text
            entries[index].modifiedAt = Date()
        } else {
            entries.append(DiaryEntry(dateKey: dateKey, text: text, modifiedAt: Date()))
            entries.sort { $0.dateKey > $1.dateKey }
        }
    }

    /// 타이핑 도중 호출되는 디바운스 자동 저장
    func scheduleSave(_ text: String, for dateKey: String) {
        pendingSave = (text, dateKey)
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.commitPendingSave() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    private func commitPendingSave() {
        guard let pending = pendingSave else { return }
        pendingSave = nil
        save(pending.text, for: pending.dateKey)
    }

    /// 백그라운드 진입 등, 예약된 저장을 즉시 반영
    func flushPendingSave() {
        saveWorkItem?.cancel()
        commitPendingSave()
    }

    /// 표시하던 글을 마무리 저장. 내용이 비었으면 그날 파일을 정리한다.
    func finalize(_ text: String, for dateKey: String) {
        saveWorkItem?.cancel()
        pendingSave = nil
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            delete(dateKey: dateKey)
        } else {
            save(text, for: dateKey)
        }
    }

    func delete(_ entry: DiaryEntry) {
        delete(dateKey: entry.dateKey)
    }

    func delete(dateKey: String) {
        if let url = fileURL(for: dateKey), entries.contains(where: { $0.dateKey == dateKey }) {
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { target in
                try? FileManager.default.removeItem(at: target)
            }
        }
        entries.removeAll { $0.dateKey == dateKey }
        if selectedDateKey == dateKey {
            selectedDateKey = todayKey
        }
    }
}
