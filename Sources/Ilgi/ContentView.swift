import SwiftUI

/// 좌측(캘린더 + 최근 글) / 우측(글 작성) 분할 레이아웃
struct ContentView: View {
    @EnvironmentObject private var store: DiaryStore
    // 테마 변경 시 전체 뷰 트리를 다시 그리기 위한 의존성
    @AppStorage(Theme.storageKey) private var themeID = ColorTheme.claude.rawValue

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 268)
                .background(Color.primary.opacity(0.03))

            Divider()

            EditorPane()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint((ColorTheme(rawValue: themeID) ?? .claude).accent)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Markdown (.md)…") { store.export(.markdown) }
                    Button("일반 텍스트 (.txt)…") { store.export(.plainText) }
                    Button("JSON (.json)…") { store.export(.json) }
                } label: {
                    Label("내보내기", systemImage: "square.and.arrow.up")
                }
                .disabled(store.entries.isEmpty)
                .help("모든 일기를 한 파일로 내보내기")
            }
        }
    }
}
