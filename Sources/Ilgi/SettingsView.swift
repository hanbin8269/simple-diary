import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DiaryStore
    @AppStorage(Theme.storageKey) private var themeID = ColorTheme.claude.rawValue
    @AppStorage("autoOpenEnabled") private var autoOpenEnabled = false
    @AppStorage("autoOpenHour") private var autoOpenHour = 22
    @AppStorage("autoOpenMinute") private var autoOpenMinute = 0
    @State private var errorMessage: String?

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: autoOpenHour, minute: autoOpenMinute, second: 0, of: Date()
                ) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                autoOpenHour = components.hour ?? 22
                autoOpenMinute = components.minute ?? 0
                applyAgent()
            }
        )
    }

    var body: some View {
        Form {
            Section("색 테마") {
                ThemeSwatchPicker()
                    .padding(.vertical, 4)
            }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: store.isUsingCustomDirectory ? "folder" : "icloud")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.isUsingCustomDirectory ? "사용자 지정 폴더" : "iCloud Drive (기본)")
                            .font(.system(size: 13))
                        Text(prettyPath(store.directory))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 8)
                }

                Button("폴더 변경…") { chooseFolder() }
                if store.isUsingCustomDirectory {
                    Button("기본 위치(iCloud)로 되돌리기") { store.resetDirectoryToDefault() }
                }
            } header: {
                Text("저장 위치")
            } footer: {
                Text("일기는 선택한 폴더에 날짜별 .md 파일로 저장됩니다. 따로 지정하지 않으면 iCloud Drive의 Simple Diary 폴더에 저장되어 기기 간 자동 동기화됩니다. 폴더를 바꾸면 기존 일기도 함께 옮겨집니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("매일 자동으로 열기", isOn: $autoOpenEnabled)
                    .onChange(of: autoOpenEnabled) { _ in applyAgent() }

                DatePicker("열리는 시간", selection: timeBinding, displayedComponents: .hourAndMinute)
                    .disabled(!autoOpenEnabled)
            } footer: {
                Text("Mac이 켜져 있으면 매일 이 시간에 Simple Diary가 열립니다. 잠들어 있던 시간의 예약은 깨어날 때 처리돼요.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .tint((ColorTheme(rawValue: themeID) ?? .claude).accent)
    }

    private func prettyPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "이 폴더 사용"
        panel.message = "일기를 저장할 폴더를 선택하세요"
        panel.directoryURL = store.directory.deletingLastPathComponent()
        if panel.runModal() == .OK, let url = panel.url {
            store.changeDirectory(to: url)
        }
    }

    private func applyAgent() {
        errorMessage = nil
        if autoOpenEnabled {
            do {
                try AutoOpenAgent.install(hour: autoOpenHour, minute: autoOpenMinute)
            } catch {
                errorMessage = "예약 등록에 실패했어요: \(error.localizedDescription)"
            }
        } else {
            AutoOpenAgent.uninstall()
        }
    }
}
