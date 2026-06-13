import SwiftUI

/// 우측 패널: 선택된 날짜의 글을 항상 표시하는 상시 에디터
struct EditorPane: View {
    @EnvironmentObject private var store: DiaryStore

    @State private var text = ""
    @State private var loadedKey = ""
    @FocusState private var editorFocused: Bool

    private var isToday: Bool { store.selectedDateKey == store.todayKey }

    var body: some View {
        VStack(spacing: 10) {
            header

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("오늘 하루는 어땠나요?")
                        .font(.system(size: 15))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
            }

            HStack {
                Text("자동 저장됨")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                Spacer()
                Text("\(text.count)자")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: 700)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .onAppear {
            load(store.selectedDateKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                editorFocused = true
            }
        }
        .onChange(of: store.selectedDateKey) { newKey in
            guard newKey != loadedKey else { return }
            finalizeLoadedEntry()
            load(newKey)
            editorFocused = true
        }
        .onChange(of: store.contentVersion) { _ in
            // 가져오기 등으로 디스크 내용이 바뀌면 표시 중인 글을 다시 읽는다
            text = store.text(for: loadedKey)
        }
        .onChange(of: text) { newValue in
            store.scheduleSave(newValue, for: loadedKey)
        }
        .onDisappear {
            finalizeLoadedEntry()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(koreanDate(forKey: store.selectedDateKey, alwaysYear: true))
                .font(.system(size: 17, weight: .semibold))

            if !isToday {
                Button("오늘로") { store.selectToday() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .help("오늘 일기로 돌아가기 (⌘N)")
            }

            Spacer()
        }
    }

    private func load(_ key: String) {
        loadedKey = key
        text = store.text(for: key)
    }

    /// 표시 중이던 글을 마무리 저장한다. 단, 방금 삭제된 글이면 다시 만들지 않는다.
    private func finalizeLoadedEntry() {
        guard !loadedKey.isEmpty else { return }
        let stillExists = loadedKey == store.todayKey
            || store.entries.contains { $0.dateKey == loadedKey }
        if stillExists {
            store.finalize(text, for: loadedKey)
        }
    }
}
