import SwiftUI

/// 메인 화면: 선택된 날짜(기본 오늘)의 글을 바로 쓰는 에디터
struct EditorScreen: View {
    @EnvironmentObject private var store: MobileStore

    @State private var text = ""
    @State private var loadedKey = ""
    @State private var showBrowser = false
    @FocusState private var editorFocused: Bool

    private var isToday: Bool { store.selectedDateKey == store.todayKey }

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("오늘 하루는 어땠나요?")
                            .font(.system(size: 17))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 17))
                        .lineSpacing(5)
                        .scrollContentBackground(.hidden)
                        .focused($editorFocused)
                }

                HStack {
                    Text("자동 저장됨")
                        .font(.system(size: 12))
                        .foregroundStyle(.quaternary)
                    Spacer()
                    Text("\(text.count)자")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .navigationTitle(koreanDate(forKey: store.selectedDateKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isToday {
                        Button("오늘로") { store.selectToday() }
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.flushPendingSave()
                        showBrowser = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { editorFocused = false }
                }
            }
            .sheet(isPresented: $showBrowser) {
                BrowserSheet()
            }
            .onAppear {
                load(store.selectedDateKey)
                if isToday {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        editorFocused = true
                    }
                }
            }
            .onChange(of: store.selectedDateKey) { _, newKey in
                guard newKey != loadedKey else { return }
                finalizeLoadedEntry()
                load(newKey)
            }
            .onChange(of: text) { _, newValue in
                store.scheduleSave(newValue, for: loadedKey)
            }
            .onChange(of: store.contentVersion) { _, _ in
                text = store.text(for: loadedKey)
            }
        }
    }

    private func load(_ key: String) {
        loadedKey = key
        text = store.text(for: key)
    }

    /// 표시 중이던 글을 마무리 저장. 방금 삭제된 글이면 다시 만들지 않는다.
    private func finalizeLoadedEntry() {
        guard !loadedKey.isEmpty else { return }
        let stillExists = loadedKey == store.todayKey
            || store.entries.contains { $0.dateKey == loadedKey }
        if stillExists {
            store.finalize(text, for: loadedKey)
        }
    }
}
