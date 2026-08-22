import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case library
    case play
    case appearance
    case search
    case language
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
        case .language:
            L("settings.category.language")
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
        case .language:
            "globe"
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
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedCategory: SettingsCategory = .library

    var body: some View {
        HStack(spacing: 0) {
            categoryList
                .frame(width: WorkbenchControlMetrics.redesignSettingsSidebarWidth)

            Rectangle()
                .fill(WorkbenchRedesignColors.borderDivider)
                .frame(width: WorkbenchControlMetrics.hairlineWidth)

            selectedContent
                .id(settingsStore.appLanguage)
                .padding(.top, WorkbenchControlMetrics.redesignAppTopbarHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(
            minWidth: WorkbenchControlMetrics.redesignSettingsWindowMinimumWidth,
            minHeight: WorkbenchControlMetrics.redesignSettingsWindowMinimumHeight
        )
        .background(WorkbenchRedesignColors.bgSurface)
        .preferredColorScheme(settingsStore.appAppearanceMode.colorScheme)
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
            ForEach(SettingsCategory.allCases) { category in
                let isSelected = selectedCategory == category

                Button {
                    selectedCategory = category
                } label: {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                        Image(systemName: category.systemImage)
                            .font(.system(
                                size: WorkbenchControlMetrics.redesignAppSidebarItemIconSize,
                                weight: .medium
                            ))
                            .frame(
                                width: WorkbenchControlMetrics.redesignAppSidebarItemIconSize,
                                height: WorkbenchControlMetrics.redesignAppSidebarItemIconSize
                            )
                            .foregroundStyle(
                                isSelected
                                    ? WorkbenchRedesignColors.appSidebarItemSelectedContent
                                    : WorkbenchRedesignColors.iconDefault
                            )

                        Text(category.title)
                            .font(.system(
                                size: WorkbenchControlMetrics.redesignFontSizeAppSidebarItem,
                                weight: .regular
                            ))
                            .foregroundStyle(
                                isSelected
                                    ? WorkbenchRedesignColors.appSidebarItemSelectedContent
                                    : WorkbenchRedesignColors.textPrimary
                            )

                        Spacer(minLength: 0)
                    }
                    .padding(
                        .horizontal,
                        WorkbenchControlMetrics.redesignAppSidebarItemHorizontalPadding
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: WorkbenchControlMetrics.redesignAppSidebarItemHeight,
                        maxHeight: WorkbenchControlMetrics.redesignAppSidebarItemHeight,
                        alignment: .leading
                    )
                    .background(
                        RoundedRectangle(
                            cornerRadius: WorkbenchControlMetrics.redesignAppSidebarItemRadius,
                            style: .continuous
                        )
                        .fill(
                            isSelected
                                ? WorkbenchRedesignColors.appSidebarItemSelectedBg
                                : Color.clear
                        )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
            }

            Spacer()
        }
        .padding(
            .top,
            WorkbenchControlMetrics.redesignAppTopbarHeight
                + WorkbenchControlMetrics.redesignAppSidebarVerticalPadding
        )
        .padding(.horizontal, WorkbenchControlMetrics.redesignAppSidebarHorizontalPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignAppSidebarVerticalPadding)
        .background(WorkbenchRedesignColors.appSidebarBg)
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
        case .language:
            SettingsLanguageCategory()
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
