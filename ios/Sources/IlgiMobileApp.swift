import SwiftUI

@main
struct IlgiMobileApp: App {
    @StateObject private var store = MobileStore.shared
    @Environment(\.scenePhase) private var scenePhase
    // 테마 변경 시 전체 뷰 트리를 다시 그리기 위한 의존성
    @AppStorage(Theme.storageKey) private var themeID = ColorTheme.claude.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint((ColorTheme(rawValue: themeID) ?? .claude).accent)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background, .inactive:
                        store.flushPendingSave()
                    case .active:
                        if store.folderReady { store.reload() }
                    @unknown default:
                        break
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: MobileStore

    var body: some View {
        if store.folderReady {
            EditorScreen()
        } else {
            OnboardingView()
        }
    }
}
