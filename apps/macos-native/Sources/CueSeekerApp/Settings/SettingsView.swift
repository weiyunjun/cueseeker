import SwiftUI

private enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case play
    case shortcuts
    case subtitle
    case maintenance
    case developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            L("settings.category.general")
        case .play:
            L("settings.category.play")
        case .shortcuts:
            L("settings.category.shortcuts")
        case .subtitle:
            L("settings.category.subtitle")
        case .maintenance:
            L("settings.category.maintenance")
        case .developer:
            L("settings.category.developer")
        }
    }

    var icon: AppIcon {
        switch self {
        case .general:
            .gearFine
        case .play:
            .play
        case .shortcuts:
            .keyboard
        case .subtitle:
            .subtitles
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
    @State private var selectedCategory: SettingsCategory = .general

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                categoryList
                    .frame(width: WorkbenchControlMetrics.redesignSettingsSidebarWidth)

                Rectangle()
                    .fill(WorkbenchRedesignColors.borderDivider)
                    .frame(width: WorkbenchControlMetrics.hairlineWidth)

                SettingsPage(title: selectedCategory.title) {
                    selectedContent
                }
                // Each category opens scrolled to its top.
                .id(selectedCategory)
                .padding(.top, WorkbenchControlMetrics.redesignSettingsTitlebarHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            TooltipOverlayView(surface: .settings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(400)
        }
        .environmentObject(settingsStore.playbackShortcuts)
        .ignoresSafeArea(.container, edges: .top)
        .frame(
            minWidth: WorkbenchControlMetrics.redesignSettingsWindowWidth,
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
                    TooltipCenter.shared.dismissFromUserInteraction()
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
        .padding(.top, WorkbenchControlMetrics.redesignSettingsTitlebarHeight)
        .padding(.horizontal, WorkbenchControlMetrics.redesignAppSidebarHorizontalPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignAppSidebarVerticalPadding)
        .background(WorkbenchRedesignColors.appSidebarBg)
    }

    /// The groups on the selected category's page. General and Play gather
    /// what used to be separate categories, one group each.
    @ViewBuilder
    private var selectedContent: some View {
        switch selectedCategory {
        case .general:
            SettingsAppearanceCategory()
            SettingsSearchCategory()
            SettingsLanguageCategory()
            SettingsURLSchemeCategory()
        case .play:
            SettingsPlayCategory()
            SettingsDecodeCategory()
        case .shortcuts:
            SettingsShortcutsCategory()
        case .subtitle:
            SettingsSubtitleCategory()
        case .maintenance:
            SettingsMaintenanceCategory()
        case .developer:
            SettingsDeveloperCategory()
        }
    }
}
