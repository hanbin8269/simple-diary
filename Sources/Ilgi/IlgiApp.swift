import AppKit
import SwiftUI

@main
struct IlgiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DiaryStore.shared

    var body: some Scene {
        Window("Simple Diary", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 920, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("오늘 일기 쓰기") { store.selectToday() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .importExport) {
                Menu("내보내기") {
                    Button("Markdown (.md)…") { store.export(.markdown) }
                        .keyboardShortcut("e", modifiers: .command)
                    Button("일반 텍스트 (.txt)…") { store.export(.plainText) }
                    Button("JSON (.json)…") { store.export(.json) }
                }
                .disabled(store.entries.isEmpty)

                Button("Day One에서 가져오기…") { store.importFromDayOne() }
            }
        }

        // App menu → Settings… (⌘,): theme, storage location, auto-open
        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        DiaryStore.shared.flushPendingSave()
    }
}
