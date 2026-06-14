import SwiftUI

/// Split layout: left (calendar + recent entries) / right (editor).
struct ContentView: View {
    @EnvironmentObject private var store: DiaryStore
    // Dependency to redraw the whole view tree when the theme changes
    @AppStorage(Theme.storageKey) private var themeID = ColorTheme.claude.rawValue

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 268)
                .background(Color.primary.opacity(0.03))

            Divider()

            EditorPane()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            TodoColumn()
                .frame(width: 210)
                .background(Color.primary.opacity(0.03))
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
