import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DiaryEntry: Identifiable, Equatable {
    let dateKey: String // "2026-06-11", 하루에 한 개
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

enum ExportFormat {
    case markdown
    case plainText
    case json

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .json: return "json"
        }
    }

    var contentType: UTType? {
        UTType(filenameExtension: fileExtension)
    }
}

final class DiaryStore: ObservableObject {
    static let shared = DiaryStore()

    @Published private(set) var entries: [DiaryEntry] = [] // 최신순
    /// 우측 에디터에 표시 중인 날짜
    @Published var selectedDateKey: String
    /// 지난 일기 잠금 해제 상태. 저장하지 않으므로 앱을 켤 때마다 다시 잠긴다.
    @Published var pastRevealed = false
    /// Touch ID 인증 진행 중 여부 (버튼 비활성화용)
    @Published var unlockInProgress = false
    /// 디스크에서 다시 읽을 때마다 증가 — 에디터가 표시 중인 텍스트를 갱신하는 신호
    @Published private(set) var contentVersion = 0

    /// 현재 저장 폴더(.md 파일들이 놓이는 곳). 사용자가 바꾸면 갱신된다.
    @Published private(set) var directory: URL

    /// 사용자가 직접 지정한 폴더 경로 키 (없으면 기본 위치)
    static let customDirKey = "customDataDir"
    static let appFolderName = "Simple Diary"

    private var pendingSave: (text: String, dateKey: String)?
    private var saveWorkItem: DispatchWorkItem?

    private init() {
        selectedDateKey = Formatters.dateKey.string(from: Date())
        let env = ProcessInfo.processInfo.environment["ILGI_DATA_DIR"]
        directory = Self.resolveDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // 기본 위치를 쓸 때만 예전 Ilgi 폴더에서 새 Simple Diary 폴더로 이전한다
        if (env == nil || env!.isEmpty), Self.customDirectory() == nil {
            Self.migrateLegacyEntries(to: directory)
        }
        reload()
    }

    /// 우선순위: 환경변수(테스트) → 사용자 지정 폴더 → 기본 위치
    private static func resolveDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["ILGI_DATA_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        if let custom = customDirectory() { return custom }
        return defaultDirectory()
    }

    /// 사용자가 지정한 저장 폴더 (없으면 nil)
    static func customDirectory() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: customDirKey), !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    var isUsingCustomDirectory: Bool { Self.customDirectory() != nil }

    /// 기본 저장 위치: iCloud Drive(켜져 있으면) → 아니면 로컬 Application Support
    static func defaultDirectory() -> URL {
        let cloudDocs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        let base = FileManager.default.fileExists(atPath: cloudDocs.path)
            ? cloudDocs
            : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("\(appFolderName)/entries", isDirectory: true)
    }

    /// 예전 "Ilgi" 폴더(iCloud·로컬)에 있던 일기를 새 기본 폴더로 옮긴다.
    private static func migrateLegacyEntries(to directory: URL) {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let legacyDirs = [
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Ilgi/entries", isDirectory: true),
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Ilgi/entries", isDirectory: true),
        ]
        var moved = 0
        for legacy in legacyDirs {
            guard legacy.path != directory.path else { continue }
            guard let files = try? fm.contentsOfDirectory(at: legacy, includingPropertiesForKeys: nil) else { continue }
            for file in files where file.pathExtension == "md" {
                let destination = directory.appendingPathComponent(file.lastPathComponent)
                guard !fm.fileExists(atPath: destination.path) else { continue }
                do {
                    try fm.moveItem(at: file, to: destination)
                    moved += 1
                } catch {
                    NSLog("일기 마이그레이션 실패(\(file.lastPathComponent)): \(error)")
                }
            }
        }
        if moved > 0 {
            NSLog("일기 \(moved)개를 새 폴더로 옮겼습니다: \(directory.path)")
        }
    }

    // MARK: - 저장 폴더 변경

    /// 사용자가 고른 폴더로 저장 위치를 바꾼다. 기존 일기도 함께 옮긴다.
    func changeDirectory(to newDir: URL) {
        flushPendingSave()
        try? FileManager.default.createDirectory(at: newDir, withIntermediateDirectories: true)
        Self.moveEntries(from: directory, to: newDir)
        UserDefaults.standard.set(newDir.path, forKey: Self.customDirKey)
        directory = newDir
        selectedDateKey = todayKey
        reload()
    }

    /// 기본(iCloud) 위치로 되돌린다. 기존 일기도 함께 옮긴다.
    func resetDirectoryToDefault() {
        flushPendingSave()
        let def = Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: def, withIntermediateDirectories: true)
        Self.moveEntries(from: directory, to: def)
        UserDefaults.standard.removeObject(forKey: Self.customDirKey)
        directory = def
        selectedDateKey = todayKey
        reload()
    }

    /// .md 파일을 src에서 dst로 옮긴다(같은 이름이 있으면 건드리지 않음).
    private static func moveEntries(from src: URL, to dst: URL) {
        let fm = FileManager.default
        guard src.path != dst.path else { return }
        guard let files = try? fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "md" {
            let destination = dst.appendingPathComponent(file.lastPathComponent)
            guard !fm.fileExists(atPath: destination.path) else { continue }
            try? fm.moveItem(at: file, to: destination)
        }
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

    /// 지난 일기 잠금을 해제한 뒤 onSuccess를 실행한다. 이미 해제됐으면 바로 실행.
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

    // MARK: - 저장/삭제

    private func fileURL(for dateKey: String) -> URL {
        directory.appendingPathComponent("\(dateKey).md")
    }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        entries = urls
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> DiaryEntry? in
                let key = url.deletingPathExtension().lastPathComponent
                guard Formatters.dateKey.date(from: key) != nil else { return nil }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? Date()
                return DiaryEntry(dateKey: key, text: text, modifiedAt: modified)
            }
            .sorted { $0.dateKey > $1.dateKey }
        contentVersion += 1
    }

    func save(_ text: String, for dateKey: String) {
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let exists = entries.contains { $0.dateKey == dateKey }
        if isEmpty && !exists { return } // 빈 일기는 파일을 만들지 않는다

        do {
            try text.write(to: fileURL(for: dateKey), atomically: true, encoding: .utf8)
        } catch {
            NSLog("일기 저장 실패(\(dateKey)): \(error)")
            return
        }

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

    /// 앱 종료 직전 등, 예약된 저장을 즉시 반영
    func flushPendingSave() {
        saveWorkItem?.cancel()
        commitPendingSave()
    }

    /// 에디터를 닫을 때 호출. 내용이 비었으면 일기 자체를 정리한다.
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
        try? FileManager.default.removeItem(at: fileURL(for: dateKey))
        entries.removeAll { $0.dateKey == dateKey }
        if selectedDateKey == dateKey {
            selectedDateKey = todayKey
        }
    }

    // MARK: - 내보내기

    func export(_ format: ExportFormat) {
        guard !entries.isEmpty else { return }
        let content = exportContent(format)

        let panel = NSSavePanel()
        panel.title = "일기 내보내기"
        panel.nameFieldStringValue = "일기-\(todayKey).\(format.fileExtension)"
        if let type = format.contentType {
            panel.allowedContentTypes = [type]
        }
        panel.canCreateDirectories = true

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert()
                alert.messageText = "내보내기 실패"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    func exportContent(_ format: ExportFormat) -> String {
        let chronological = entries.sorted { $0.dateKey < $1.dateKey }
        switch format {
        case .markdown:
            var lines: [String] = ["# 일기", ""]
            for entry in chronological {
                lines.append("## \(koreanDate(forKey: entry.dateKey, alwaysYear: true))")
                lines.append("")
                lines.append(entry.text)
                lines.append("")
            }
            return lines.joined(separator: "\n")

        case .plainText:
            let blocks = chronological.map { entry in
                "\(koreanDate(forKey: entry.dateKey, alwaysYear: true))\n"
                    + String(repeating: "-", count: 28) + "\n"
                    + entry.text
            }
            return blocks.joined(separator: "\n\n\n")

        case .json:
            struct ExportEntry: Encodable {
                let date: String
                let text: String
                let modifiedAt: String
            }
            let iso = ISO8601DateFormatter()
            let items = chronological.map {
                ExportEntry(date: $0.dateKey, text: $0.text, modifiedAt: iso.string(from: $0.modifiedAt))
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(items),
                  let json = String(data: data, encoding: .utf8) else { return "[]" }
            return json
        }
    }

    // MARK: - Day One 가져오기

    func importFromDayOne() {
        let panel = NSOpenPanel()
        panel.title = "Day One 가져오기"
        panel.message = "Day One에서 내보낸 JSON 파일(또는 JSON이 든 ZIP)을 선택하세요"
        panel.prompt = "가져오기"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json, .zip]

        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self, response == .OK, let url = panel.url else { return }
            self.flushPendingSave()
            let backupURL = try? self.backupEntries()
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var summary = try DayOneImporter.run(source: url, entriesDir: self.directory)
                    summary.backupURL = backupURL
                    DispatchQueue.main.async {
                        self.reload()
                        self.presentImportSummary(summary)
                    }
                } catch {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "가져오기 실패"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
        }

        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    /// 가져오기 전에 기존 일기 전체를 백업한다. 일기가 없으면 nil.
    private func backupEntries() throws -> URL? {
        let fm = FileManager.default
        let files = ((try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "md" }
        guard !files.isEmpty else { return nil }

        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        let destination = directory.deletingLastPathComponent()
            .appendingPathComponent("backup/entries-\(stamp.string(from: Date()))", isDirectory: true)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for file in files {
            try fm.copyItem(at: file, to: destination.appendingPathComponent(file.lastPathComponent))
        }
        return destination
    }

    private func presentImportSummary(_ summary: DayOneImportSummary) {
        let alert = NSAlert()
        if summary.sourceEntries == 0 {
            alert.messageText = "가져올 일기가 없었어요"
            alert.informativeText = "선택한 파일에서 Day One 일기 항목을 찾지 못했습니다."
            alert.alertStyle = .warning
        } else {
            alert.messageText = "Day One 가져오기 완료"
            var lines = ["Day One 항목 \(summary.sourceEntries)개 → 새 일기 \(summary.createdDays)일"]
            if summary.skippedDays > 0 {
                lines.append("이미 일기가 있어 건너뛴 날: \(summary.skippedDays)일")
            }
            if let backup = summary.backupURL {
                lines.append("가져오기 전 일기 백업: \(backup.path)")
            }
            alert.informativeText = lines.joined(separator: "\n")
        }
        alert.runModal()
    }
}
