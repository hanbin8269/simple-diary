import Foundation

// Shared between the macOS and iOS apps (pure Foundation, no AppKit/UIKit).

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var text: String
    var done = false
    var day: String       // dateKey the item currently belongs to
    var carried = false   // carried over from a previous day (shown with a badge)
}

/// Pure carry-over: unfinished items from a past day roll to `today` (carried = true);
/// items completed on a past day are dropped. Returns the new list and whether it changed.
func rollOverTodos(_ items: [TodoItem], today: String) -> (items: [TodoItem], changed: Bool) {
    var changed = false
    let result: [TodoItem] = items.compactMap { item in
        guard item.day < today else { return item }
        if item.done {
            changed = true
            return nil
        }
        var rolled = item
        rolled.day = today
        rolled.carried = true
        changed = true
        return rolled
    }
    return (result, changed)
}

/// Today's items (today's own + carried-over), unfinished first, preserving insertion order.
func todaysTodos(_ items: [TodoItem], today: String) -> [TodoItem] {
    items.filter { $0.day == today }
        .enumerated()
        .sorted { ($0.element.done ? 1 : 0, $0.offset) < ($1.element.done ? 1 : 0, $1.offset) }
        .map(\.element)
}
