import SwiftUI

/// 선택 가능한 색 테마. 이름은 영어로 표기한다. 기본값은 Claude(테라코타).
enum ColorTheme: String, CaseIterable, Identifiable {
    case claude
    case leaf
    case tangerine
    case ocean
    case lavender
    case sakura
    case graphite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .leaf: return "Leaf"
        case .tangerine: return "Tangerine"
        case .ocean: return "Ocean"
        case .lavender: return "Lavender"
        case .sakura: return "Sakura"
        case .graphite: return "Graphite"
        }
    }

    var accent: Color {
        switch self {
        case .claude: return Color(red: 0.851, green: 0.467, blue: 0.341) // #D97757
        case .leaf: return Color(red: 0.20, green: 0.55, blue: 0.30)
        case .tangerine: return Color(red: 0.86, green: 0.39, blue: 0.22)
        case .ocean: return Color(red: 0.16, green: 0.45, blue: 0.74)
        case .lavender: return Color(red: 0.47, green: 0.40, blue: 0.78)
        case .sakura: return Color(red: 0.83, green: 0.42, blue: 0.58)
        case .graphite: return Color(red: 0.36, green: 0.39, blue: 0.42)
        }
    }

    var accentLight: Color {
        switch self {
        case .claude: return Color(red: 0.92, green: 0.63, blue: 0.51) // #EBA182
        case .leaf: return Color(red: 0.45, green: 0.75, blue: 0.45)
        case .tangerine: return Color(red: 0.96, green: 0.55, blue: 0.33)
        case .ocean: return Color(red: 0.45, green: 0.67, blue: 0.90)
        case .lavender: return Color(red: 0.68, green: 0.62, blue: 0.92)
        case .sakura: return Color(red: 0.95, green: 0.64, blue: 0.76)
        case .graphite: return Color(red: 0.58, green: 0.61, blue: 0.64)
        }
    }
}

/// 현재 선택된 테마의 색. 뷰들은 이걸 읽고, 루트 뷰가 테마 변경 시 트리를 다시 그린다.
enum Theme {
    static let storageKey = "colorTheme"

    static var current: ColorTheme {
        ColorTheme(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .claude
    }

    static var accent: Color { current.accent }
    static var accentLight: Color { current.accentLight }
}

/// 테마 선택 스와치 그리드 (macOS 설정 창과 iOS 시트에서 공용)
struct ThemeSwatchPicker: View {
    @AppStorage(Theme.storageKey) private var themeID = ColorTheme.claude.rawValue

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 14) {
            ForEach(ColorTheme.allCases) { theme in
                Button {
                    themeID = theme.rawValue
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            if themeID == theme.rawValue {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.55), lineWidth: 2)
                                    .frame(width: 42, height: 42)
                            }
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [theme.accentLight, theme.accent],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 32, height: 32)
                        }
                        .frame(width: 44, height: 44)

                        Text(theme.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(themeID == theme.rawValue ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
