import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case play
    case shortcuts
    case subtitle
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
        case .play:
            L("settings.category.play")
        case .shortcuts:
            L("settings.category.shortcuts")
        case .subtitle:
            L("settings.category.subtitle")
        case .appearance:
            L("settings.category.appearance")
        case .search:
            L("settings.category.search")
        case .language:
            L("settings.category.language")
        case .urlScheme:
            "Deep Link"
        case .decode:
            L("settings.category.decode")
        case .maintenance:
            L("settings.category.maintenance")
        case .developer:
            L("settings.category.developer")
        }
    }

    var icon: AppIcon {
        switch self {
        case .play:
            .play
        case .shortcuts:
            .keyboard
        case .subtitle:
            .subtitles
        case .appearance:
            .circleHalf
        case .search:
            .magnifyingGlass
        case .language:
            .globe
        case .urlScheme:
            .linkSimple
        case .decode:
            .video
        case .maintenance:
            .hardDrives
        case .developer:
            .hammer
        }
    }

    /// Play is the one category whose glyph reads as a solid mark.
    var iconWeight: AppIconWeight? {
        self == .play ? .fill : nil
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    // Observed so the category titles are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @State private var selectedCategory: SettingsCategory = .play

    var body: some View {
        HStack(spacing: 0) {
            categoryList
                .frame(width: WorkbenchControlMetrics.redesignSettingsSidebarWidth)

            Rectangle()
                .fill(WorkbenchRedesignColors.borderDivider)
                .frame(width: WorkbenchControlMetrics.hairlineWidth)

            selectedContent
                .padding(.top, WorkbenchControlMetrics.redesignAppTopbarHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(
            minWidth: WorkbenchControlMetrics.redesignSettingsWindowMinimumWidth,
            minHeight: WorkbenchControlMetrics.redesignSettingsWindowMinimumHeight
        )
        .background(WorkbenchRedesignColors.bgSurface)
        .opensWithoutFocus()
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
                        AppIconImage(
                            category.icon,
                            size: WorkbenchControlMetrics.redesignAppSidebarItemIconSize,
                            weight: category.iconWeight
                        )
                            .foregroundStyle(
                                isSelected
                                    ? WorkbenchRedesignColors.appSidebarItemSelectedContent
                                    : WorkbenchRedesignColors.textSecondary
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
        case .play:
            SettingsPlayCategory()
        case .shortcuts:
            SettingsShortcutsCategory()
        case .subtitle:
            SettingsSubtitleCategory()
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
