import AppKit
import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var text: String
    var done = false
    var day: String       // dateKey the item currently belongs to
    var carried = false   // carried over from a previous day (shown with a badge)
}

/// A small rolling todo list. Unfinished items carry over to today when the day
/// changes; items completed on a past day are cleared. Stored locally (not in the
/// diary folder), so changing the diary's storage location doesn't affect it.
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    @Published private(set) var items: [TodoItem] = []

    private let fileURL: URL
    private var saveWorkItem: DispatchWorkItem?

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Simple Diary", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("todos.json")
        load()
        rollOver()
        // Re-check carry-over whenever the app comes to the front (e.g. left open past midnight)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rollOver() }
    }

    private var todayKey: String { Formatters.dateKey.string(from: Date()) }

    /// Items belonging to today (today's own + carried-over unfinished ones),
    /// unfinished first.
    var todayItems: [TodoItem] {
        items.filter { $0.day == todayKey }
            .enumerated()
            .sorted { ($0.element.done ? 1 : 0, $0.offset) < ($1.element.done ? 1 : 0, $1.offset) }
            .map(\.element)
    }

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

    // MARK: - Carry-over

    /// Roll unfinished past items to today; drop items completed on a past day.
    func rollOver() {
        let today = todayKey
        var changed = false
        items = items.compactMap { item in
            guard item.day < today else { return item }
            if item.done {
                changed = true
                return nil // completed on a past day → cleared
            }
            var rolled = item
            rolled.day = today
            rolled.carried = true
            changed = true
            return rolled
        }
        if changed { save() }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        saveWorkItem?.cancel()
        let snapshot = items
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: self.fileURL, options: .atomic)
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
}
