import SwiftUI

/// 잔디 캘린더 + (Face ID 뒤의) 지난 일기 목록 시트
struct BrowserSheet: View {
    @EnvironmentObject private var store: MobileStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: DiaryEntry?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    MobileCalendarView { dismiss() }

                    pastSection

                    Divider()

                    themeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("일기 둘러보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            store.resetFolder()
                            dismiss()
                        } label: {
                            Label("iCloud 폴더 다시 연결…", systemImage: "folder.badge.gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
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
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("색 테마")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ThemeSwatchPicker()
        }
    }

    @ViewBuilder
    private var pastSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text(store.pastEntries.isEmpty
                     ? "지난 일기 없음"
                     : "지난 일기 \(store.pastEntries.count)개")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !store.pastEntries.isEmpty && store.pastRevealed {
                    Button {
                        withAnimation { store.pastRevealed = false }
                    } label: {
                        Label("숨기기", systemImage: "eye.slash")
                            .font(.system(size: 13))
                    }
                }
            }

            if store.pastEntries.isEmpty {
                Text("아직 지난 일기가 없어요")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else if store.pastRevealed {
                LazyVStack(spacing: 2) {
                    ForEach(store.pastEntries) { entry in
                        RecentRow(
                            entry: entry,
                            isSelected: store.selectedDateKey == entry.dateKey,
                            open: {
                                store.selectedDateKey = entry.dateKey
                                dismiss()
                            },
                            delete: { pendingDelete = entry }
                        )
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                    Text("지난 일기는 잠겨 있어요")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Button {
                        store.revealPast()
                    } label: {
                        Label("Face ID로 보기", systemImage: "faceid")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.unlockInProgress)
                }
                .padding(.vertical, 18)
            }
        }
    }
}

private struct RecentRow: View {
    let entry: DiaryEntry
    let isSelected: Bool
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(koreanDate(forKey: entry.dateKey))
                        .font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 8)
                    Text("\(entry.text.count)자")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                Text(entry.firstLine)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? Theme.accent.opacity(0.13) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label("삭제…", systemImage: "trash")
            }
        }
    }
}
