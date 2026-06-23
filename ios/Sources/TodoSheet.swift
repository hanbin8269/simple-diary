import SwiftUI

/// Todo list sheet. Unfinished items carry over daily; same todos.json as the Mac app.
struct TodoSheet: View {
    @EnvironmentObject private var store: MobileStore
    @Environment(\.dismiss) private var dismiss
    @State private var newText = ""
    @FocusState private var addFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.todayTodos) { item in
                        TodoRow(item: item,
                                toggle: { store.toggleTodo(item) },
                                commit: { store.updateTodo(item, text: $0) })
                    }
                    .onDelete { offsets in
                        let items = store.todayTodos
                        offsets.map { items[$0] }.forEach(store.deleteTodo)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.accent)
                        TextField("할 일 추가", text: $newText)
                            .focused($addFocused)
                            .onSubmit {
                                store.addTodo(newText)
                                newText = ""
                                addFocused = true
                            }
                    }
                } header: {
                    Text(store.remainingTodoCount > 0 ? "남은 할 일 \(store.remainingTodoCount)개" : "할 일")
                }
            }
            .navigationTitle("할 일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let toggle: () -> Void
    let commit: (String) -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button(action: toggle) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(item.done ? Theme.accent : Color.secondary)
            }
            .buttonStyle(.plain)

            if item.done {
                Text(item.text)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
            } else {
                TextField("할 일", text: $draft, axis: .vertical)
                    .focused($focused)
                    .onSubmit { commit(draft) }
                    .onChange(of: focused) { isFocused in
                        if !isFocused { commit(draft) }
                    }
                Spacer(minLength: 4)
                if item.carried {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .onAppear { draft = item.text }
        .onChange(of: item.text) { newValue in
            if !focused { draft = newValue }
        }
    }
}
