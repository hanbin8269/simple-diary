import SwiftUI

/// Narrow right-hand column for jotting todos. Unfinished items carry over daily.
struct TodoColumn: View {
    @ObservedObject private var store = TodoStore.shared
    @State private var newText = ""
    @FocusState private var addFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("할 일")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if store.remainingCount > 0 {
                    Text("\(store.remainingCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 10)

            if store.todayItems.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "checklist")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                    Text("오늘 할 일을 적어보세요")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(store.todayItems) { item in
                            TodoRow(item: item,
                                    toggle: { store.toggle(item) },
                                    delete: { store.delete(item) },
                                    update: { store.update(item, text: $0) })
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }

            Divider().padding(.horizontal, 10)

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("할 일 추가", text: $newText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($addFocused)
                    .onSubmit {
                        store.add(newText)
                        newText = ""
                        addFocused = true
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let toggle: () -> Void
    let delete: () -> Void
    let update: (String) -> Void
    @State private var hovering = false
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: toggle) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(item.done ? Theme.accent : Color.secondary)
            }
            .buttonStyle(.plain)

            if editing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($fieldFocused)
                    .onSubmit(commit)
                    .onExitCommand { editing = false } // Esc cancels
                    .onChange(of: fieldFocused) { focused in
                        if !focused { commit() } // commit on click-away
                    }
                Spacer(minLength: 4)
            } else {
                Text(item.text)
                    .font(.system(size: 12))
                    .foregroundStyle(item.done ? .tertiary : .primary)
                    .strikethrough(item.done)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .help("더블클릭해서 수정")
                    .onTapGesture(count: 2, perform: beginEdit)

                Spacer(minLength: 4)

                if item.carried && !item.done {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .help("어제까지의 할 일이 이월됐어요")
                }
                if hovering {
                    Button(action: delete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovering || editing ? Color.primary.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button("수정", systemImage: "pencil", action: beginEdit)
            Button(role: .destructive, action: delete) {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    private func beginEdit() {
        draft = item.text
        editing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { fieldFocused = true }
    }

    private func commit() {
        guard editing else { return }
        editing = false
        update(draft)
    }
}
