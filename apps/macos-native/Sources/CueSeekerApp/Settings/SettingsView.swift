import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case library
    case play
    case appearance
    case search
    case urlScheme
    case decode
    case maintenance
    case developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library:
            "Library"
        case .play:
            "Play"
        case .appearance:
            "Appearance"
        case .search:
            "Search"
        case .urlScheme:
            "Deep Link"
        case .decode:
            "Decode"
        case .maintenance:
            "Maintenance"
        case .developer:
            "Developer"
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
        case .search:
            "magnifyingglass"
        case .urlScheme:
            "link"
        case .decode:
            "play.rectangle"
        case .maintenance:
            "externaldrive"
        case .developer:
            "hammer"
        }
    }
}

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedCategory: SettingsCategory = .library
    private let categoryColumnWidth: CGFloat = 184

    private var sidebarBackground: Color {
        colorScheme == .dark
            ? WorkbenchRedesignColors.appSidebarBg
            : Color(red: 0.942, green: 0.942, blue: 0.936)
    }

    private var dividerColor: Color {
        colorScheme == .dark
            ? WorkbenchRedesignColors.borderDivider
            : Color.black.opacity(0.08)
    }

    var body: some View {
        HStack(spacing: 0) {
            categoryList
                .frame(width: categoryColumnWidth)

            Rectangle()
                .fill(dividerColor)
                .frame(width: 1)

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 420)
        .background(WorkbenchRedesignColors.bgSurface)
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
        case .search:
            SettingsSearchCategory()
        case .urlScheme:
            SettingsURLSchemeCategory()
        case .decode:
            SettingsDecodeCategory()
        case .maintenance:
            SettingsMaintenanceCategory()
        case .developer:
            SettingsDeveloperCategory()
        }
    }
}
