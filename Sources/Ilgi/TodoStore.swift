import AppKit
import Foundation

/// A small rolling todo list, stored as `todos.json` in the diary folder so it syncs
/// across devices via iCloud (next to the entries). Unfinished items carry over to today
/// when the day changes; items completed on a past day are cleared.
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    @Published private(set) var items: [TodoItem] = []

    private var saveWorkItem: DispatchWorkItem?

    /// todos.json lives alongside the diary entries, following the diary's storage folder.
    private var fileURL: URL { DiaryStore.shared.directory.appendingPathComponent("todos.json") }

    private init() {
        migrateFromAppSupport()
        load()
        rollOver()
        // Re-check when the app comes to the front (picks up other-device edits + day change)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.load(); self?.rollOver() }
        // Reload when the diary's storage folder changes
        NotificationCenter.default.addObserver(
            forName: DiaryStore.directoryDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.load(); self?.rollOver() }
    }

    private var todayKey: String { Formatters.dateKey.string(from: Date()) }

    var todayItems: [TodoItem] { todaysTodos(items, today: todayKey) }
    var remainingCount: Int { items.filter { $0.day == todayKey && !$0.done }.count }

    // MARK: - Mutations

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(text: trimmed, day: todayKey))
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].done.toggle()
        save()
    }

    /// Rename an item. Empty text deletes it.
    func update(_ item: TodoItem, text: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            items.remove(at: index)
        } else {
            items[index].text = trimmed
        }
        save()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func rollOver() {
        let (rolled, changed) = rollOverTodos(items, today: todayKey)
        if changed {
            items = rolled
            save()
        }
    }

    // MARK: - Persistence (coordinated, since the file is shared via iCloud)

    private func load() {
        let url = fileURL
        var data: Data?
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            data = try? Data(contentsOf: readURL)
        }
        // Only replace the in-memory list when we actually decoded something — never clobber
        // local items because the file is missing or not yet downloaded.
        if let data, let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = decoded
        }
    }

    private func save() {
        saveWorkItem?.cancel()
        let snapshot = items
        let url = fileURL
        let item = DispatchWorkItem {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
                try? data.write(to: writeURL, options: .atomic)
            }
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    /// One-time move from the previous local location (~/Library/Application Support).
    private func migrateFromAppSupport() {
        let fm = FileManager.default
        let old = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Simple Diary/todos.json")
        let new = fileURL
        guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) else { return }
        try? fm.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.moveItem(at: old, to: new)
    }
}
