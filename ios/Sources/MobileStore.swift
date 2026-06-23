import Foundation
import SwiftUI

struct DiaryEntry: Identifiable, Equatable {
    let dateKey: String // "2026-06-12", one per day
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

/// Store that accesses the same iCloud Drive folder as the Mac app (Simple Diary/entries) via a security bookmark.
final class MobileStore: ObservableObject {
    static let shared = MobileStore()

    @Published private(set) var entries: [DiaryEntry] = [] // newest first
    @Published var selectedDateKey: String
    @Published var pastRevealed = false
    @Published var unlockInProgress = false
    @Published private(set) var contentVersion = 0
    @Published var folderReady = false
    @Published var setupError: String?
    @Published private(set) var todos: [TodoItem] = []

    private var folderURL: URL?
    private var accessedBase: URL?
    private let bookmarkKey = "entriesFolderBookmark"
    private let subpathKey = "entriesFolderSubpath"

    private var pendingSave: (text: String, dateKey: String)?
    private var saveWorkItem: DispatchWorkItem?

    private init() {
        selectedDateKey = Formatters.dateKey.string(from: Date())
        // Simulator/testing: use the app's Documents folder as the store
        if ProcessInfo.processInfo.environment["ILGI_USE_LOCAL"] == "1" {
            folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            folderReady = true
            reload()
            reloadTodos()
            applyTodoRollOver()
            return
        }
        restoreBookmark()
    }

    // MARK: - Queries

    var todayKey: String { Formatters.dateKey.string(from: Date()) }

    var todayEntry: DiaryEntry? { entries.first { $0.dateKey == todayKey } }

    var pastEntries: [DiaryEntry] { entries.filter { $0.dateKey != todayKey } }

    func text(for dateKey: String) -> String {
        entries.first { $0.dateKey == dateKey }?.text ?? ""
    }

    func selectToday() {
        selectedDateKey = todayKey
    }

    /// Runs onSuccess after unlocking past entries (Face ID). Runs immediately if already unlocked.
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

    // MARK: - Folder connection (security bookmark)

    /// Remembers the folder picked in the document picker. If an "entries" subfolder exists, uses that automatically.
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
        reloadTodos()
        applyTodoRollOver()
    }

    /// Disconnects the folder and returns to onboarding.
    func resetFolder() {
        flushPendingSave()
        accessedBase?.stopAccessingSecurityScopedResource()
        accessedBase = nil
        folderURL = nil
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: subpathKey)
        entries = []
        todos = []
        pastRevealed = false
        folderReady = false
    }

    // MARK: - Read / write (NSFileCoordinator)

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
                // Request download for not-yet-downloaded iCloud files (".name.icloud") and skip them
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

    // MARK: - Todos (todos.json in the same iCloud folder)

    private var todosURL: URL? { folderURL?.appendingPathComponent("todos.json") }

    var todayTodos: [TodoItem] { todaysTodos(todos, today: todayKey) }
    var remainingTodoCount: Int { todos.filter { $0.day == todayKey && !$0.done }.count }

    func reloadTodos() {
        guard let url = todosURL else { return }
        var data: Data?
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            data = try? Data(contentsOf: readURL)
        }
        if let data, let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todos = decoded
        } else if data == nil {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }

    func applyTodoRollOver() {
        let (rolled, changed) = rollOverTodos(todos, today: todayKey)
        if changed {
            todos = rolled
            saveTodos()
        }
    }

    func addTodo(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.append(TodoItem(text: trimmed, day: todayKey))
        saveTodos()
    }

    func toggleTodo(_ item: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[index].done.toggle()
        saveTodos()
    }

    func updateTodo(_ item: TodoItem, text: String) {
        guard let index = todos.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            todos.remove(at: index)
        } else {
            todos[index].text = trimmed
        }
        saveTodos()
    }

    func deleteTodo(_ item: TodoItem) {
        todos.removeAll { $0.id == item.id }
        saveTodos()
    }

    private func saveTodos() {
        guard let url = todosURL, let data = try? JSONEncoder().encode(todos) else { return }
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
            try? data.write(to: writeURL, options: .atomic)
        }
    }

    func save(_ text: String, for dateKey: String) {
        guard let url = fileURL(for: dateKey) else { return }
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let exists = entries.contains { $0.dateKey == dateKey }
        if isEmpty && !exists { return } // don't create a file for an empty entry

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var writeFailed = false
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { destination in
            do {
                try text.write(to: destination, atomically: true, encoding: .utf8)
            } catch {
                writeFailed = true
                NSLog("entry save failed (\(dateKey)): \(error)")
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

    /// Debounced autosave called while typing
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

    /// Flush a pending save immediately (e.g. when entering the background)
    func flushPendingSave() {
        saveWorkItem?.cancel()
        commitPendingSave()
    }

    /// Finalizes the shown entry. Cleans up the day's file if it's empty.
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
