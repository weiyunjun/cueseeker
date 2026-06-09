import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case library
    case play
    case appearance
    case decode
    case maintenance
    case developer
    case experimentalFeatures

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library:
            "Library"
        case .play:
            "Play"
        case .appearance:
            "Appearance"
        case .decode:
            "Decode"
        case .maintenance:
            "Maintenance"
        case .developer:
            "Developer"
        case .experimentalFeatures:
            "Experimental Features"
        }
    }

    var systemImage: String {
        switch self {
        case .library:
            "folder"
        case .play:
            "play.fill"
        case .appearance:
            "circle.lefthalf.filled"
        case .decode:
            "play.rectangle"
        case .maintenance:
            "externaldrive"
        case .developer:
            "hammer"
        case .experimentalFeatures:
            "sparkles"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedCategory: SettingsCategory = .library
    private let categoryColumnWidth: CGFloat = 184
    private let sidebarBackground = Color(
        red: 0.942,
        green: 0.942,
        blue: 0.936
    )
    private let contentBackground = Color.white

    var body: some View {
        HStack(spacing: 0) {
            categoryList
                .frame(width: categoryColumnWidth)

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 1)

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 420)
        .background(contentBackground)
        .preferredColorScheme(settingsStore.appAppearanceMode.colorScheme)
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SettingsCategory.allCases) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.title, systemImage: category.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category
                                ? Color.accentColor
                                : Color.clear
                        )
                        .foregroundStyle(
                            selectedCategory == category ? .white : .primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
            }

            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 12)
        .background(sidebarBackground)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedCategory {
        case .library:
            SettingsLibraryCategory()
        case .play:
            SettingsPlayCategory()
        case .appearance:
            SettingsAppearanceCategory()
        case .decode:
            SettingsDecodeCategory()
        case .maintenance:
            SettingsMaintenanceCategory()
        case .developer:
            SettingsDeveloperCategory()
        case .experimentalFeatures:
            SettingsExperimentalCategory()
        }
    }

}
