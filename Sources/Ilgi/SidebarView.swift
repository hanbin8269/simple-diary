import SwiftUI

/// 좌측 패널: 위에는 잔디 캘린더, 아래에는 잠금 처리된 최근 글 목록
struct SidebarView: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var pendingDelete: DiaryEntry?

    var body: some View {
        VStack(spacing: 0) {
            MonthCalendarView()
                .padding(.top, 16)
                .padding(.bottom, 16)

            Divider()
                .padding(.horizontal, 14)

            recentHeader

            recentContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .confirmationDialog(
            "이 일기를 삭제할까요?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { entry in
            Button("삭제", role: .destructive) { store.delete(entry) }
            Button("취소", role: .cancel) {}
        } message: { entry in
            Text("\(koreanDate(forKey: entry.dateKey, alwaysYear: true)) 일기가 완전히 삭제됩니다.")
        }
    }

    private var recentHeader: some View {
        HStack {
            Text(store.pastEntries.isEmpty
                 ? "지난 일기 없음"
                 : "지난 일기 \(store.pastEntries.count)개")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if !store.pastEntries.isEmpty {
                Button {
                    if store.pastRevealed {
                        withAnimation(.easeInOut(duration: 0.2)) { store.pastRevealed = false }
                    } else {
                        store.revealPast()
                    }
                } label: {
                    Label(store.pastRevealed ? "숨기기" : "보기",
                          systemImage: store.pastRevealed ? "eye.slash" : "touchid")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .disabled(store.unlockInProgress)
                .help(store.pastRevealed ? "지난 일기 숨기기" : "Touch ID로 지난 일기 보기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var recentContent: some View {
        if store.pastEntries.isEmpty {
            VStack {
                Spacer()
                Text("아직 지난 일기가 없어요")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        } else if store.pastRevealed {
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(store.pastEntries) { entry in
                        RecentEntryRow(
                            entry: entry,
                            isSelected: store.selectedDateKey == entry.dateKey,
                            open: { store.selectedDateKey = entry.dateKey },
                            delete: { pendingDelete = entry }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        } else {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                Text("지난 일기는 잠겨 있어요")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }
}

private struct RecentEntryRow: View {
    let entry: DiaryEntry
    let isSelected: Bool
    let open: () -> Void
    let delete: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(koreanDate(forKey: entry.dateKey))
                        .font(.system(size: 11, weight: .semibold))
                    Spacer(minLength: 6)
                    Text("\(entry.text.count)자")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                Text(entry.firstLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Theme.accent.opacity(0.13)
                          : hovering ? Color.primary.opacity(0.06)
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label("삭제…", systemImage: "trash")
            }
        }
    }
}
