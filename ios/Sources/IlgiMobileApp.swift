import SwiftUI

@main
struct IlgiMobileApp: App {
    @StateObject private var store = MobileStore.shared
    @Environment(\.scenePhase) private var scenePhase
    // Dependency to redraw the whole view tree when the theme changes
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
