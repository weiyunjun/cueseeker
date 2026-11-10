import AppKit
import SwiftUI

enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case general
    case play
    case shortcuts
    case subtitle

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
        }
    }

    /// Play is the one category whose glyph reads as a solid mark.
    var iconWeight: AppIconWeight? {
        self == .play ? .fill : nil
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var settingsStore: SettingsStore
    // Observed so the category titles are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var workbenchAccessibility: WorkbenchAccessibilityCoordinator
    @Environment(\.interfaceLayers) private var environmentInterfaceLayers
    @StateObject private var ownedInterfaceLayers = InterfaceLayerRegistry()

    private var selectedCategory: SettingsCategory {
        workbenchAccessibility.selectedSettingsCategory
    }

    private var activeInterfaceLayers: InterfaceLayerRegistry {
        environmentInterfaceLayers ?? ownedInterfaceLayers
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                categoryList
                    .frame(width: WorkbenchControlMetrics.redesignSettingsSidebarWidth)

                Rectangle()
                    .fill(WorkbenchRedesignColors.borderDivider)
                    .frame(width: WorkbenchControlMetrics.hairlineWidth)

                VStack(spacing: 0) {
                    settingsTopbar

                    SettingsPage {
                        selectedContent
                    }
                    // Each category opens scrolled to its top.
                    .id(selectedCategory)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            SettingsDialogLayerHost(confirmation: settingsStore.confirmation)
                .zIndex(AppShellLayout.dialogLayerZIndex)

            TooltipOverlayView(surface: .settings)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(400)
        }
        .environmentObject(settingsStore.playbackShortcuts)
        .environment(\.workbenchAccessibility, workbenchAccessibility)
        .modifier(InterfaceLayerCoverageBridge(layers: activeInterfaceLayers))
        .background(
            WindowKeyDownMonitor { event in
                appState.handleSettingsKeyDown(event)
            }
        )
        .ignoresSafeArea(.container, edges: .top)
        .frame(
            minWidth: WorkbenchControlMetrics.redesignSettingsWindowWidth,
            minHeight: WorkbenchControlMetrics.redesignSettingsWindowMinimumHeight
        )
        .background(WorkbenchRedesignColors.bgSurface)
        .opensWithoutFocus()
        .preferredColorScheme(settingsStore.appAppearanceMode.colorScheme)
    }

    private var settingsTopbar: some View {
        TitlebarBackgroundView(backgroundColor: WorkbenchRedesignColors.NS.bgSurface)
            .overlay(alignment: .leading) {
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                        backButton
                        forwardButton
                    }

                    Text(selectedCategory.title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeSectionTitle,
                            weight: .semibold
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .workbenchTruncatedTextTooltip(
                            scenarioID: "truncated.settings.topbar.title",
                            surface: .settings,
                            text: selectedCategory.title,
                            font: .system(
                                size: WorkbenchControlMetrics.redesignFontSizeSectionTitle,
                                weight: .semibold
                            )
                        )
                        .allowsHitTesting(false)

                    Spacer(minLength: 0)
                }
                .padding(.leading, WorkbenchControlMetrics.redesignSpacing6)
                .padding(
                    .trailing,
                    WorkbenchControlMetrics.redesignAppTopbarContentTrailingPadding
                )
            }
            .frame(height: WorkbenchControlMetrics.redesignSettingsTitlebarHeight)
    }

    private var backButton: some View {
        WorkbenchIconButton(
            icon: .caretLeft,
            isFocused: workbenchAccessibility.isSettingsFocused(.topbarBackButton),
            iconSize: WorkbenchControlMetrics.redesignDialogCloseIconSize,
            boxSize: WorkbenchControlMetrics.redesignDialogCloseButtonSize,
            action: {
                let startedAt = DebugInteractionLatencyProbe.now()
                let previousCategory = workbenchAccessibility.selectedSettingsCategory
                if workbenchAccessibility.goBackInSettings() {
                    DebugInteractionLatencyProbe.completeImmediateNavigation(
                        domain: "settings",
                        from: "settings_\(previousCategory.rawValue)",
                        to: "settings_\(workbenchAccessibility.selectedSettingsCategory.rawValue)",
                        trigger: "settings_topbar_back",
                        startedAt: startedAt
                    )
                }
            }
        )
        .disabled(!workbenchAccessibility.canGoBackInSettings)
        .workbenchTooltip(
            scenarioID: "topbar.navigation.back",
            surface: .settings,
            label: workbenchAccessibility.canGoBackInSettings
                ? L("topbar.back")
                : L("tooltip.topbar.back.disabled")
        )
        .accessibilityLabel(L("topbar.back"))
        .accessibilityIdentifier("settings-topbar-back")
    }

    private var forwardButton: some View {
        WorkbenchIconButton(
            icon: .caretRight,
            isFocused: workbenchAccessibility.isSettingsFocused(.topbarForwardButton),
            iconSize: WorkbenchControlMetrics.redesignDialogCloseIconSize,
            boxSize: WorkbenchControlMetrics.redesignDialogCloseButtonSize,
            action: {
                let startedAt = DebugInteractionLatencyProbe.now()
                let previousCategory = workbenchAccessibility.selectedSettingsCategory
                if workbenchAccessibility.goForwardInSettings() {
                    DebugInteractionLatencyProbe.completeImmediateNavigation(
                        domain: "settings",
                        from: "settings_\(previousCategory.rawValue)",
                        to: "settings_\(workbenchAccessibility.selectedSettingsCategory.rawValue)",
                        trigger: "settings_topbar_forward",
                        startedAt: startedAt
                    )
                }
            }
        )
        .disabled(!workbenchAccessibility.canGoForwardInSettings)
        .workbenchTooltip(
            scenarioID: "topbar.navigation.forward",
            surface: .settings,
            label: workbenchAccessibility.canGoForwardInSettings
                ? L("topbar.forward")
                : L("tooltip.topbar.forward.disabled")
        )
        .accessibilityLabel(L("topbar.forward"))
        .accessibilityIdentifier("settings-topbar-forward")
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(SettingsCategory.allCases) { category in
                let isSelected = selectedCategory == category
                let isAccessibilityFocused = workbenchAccessibility.isSettingsFocused(.sidebarCategory(category))

                Button {
                    let startedAt = DebugInteractionLatencyProbe.now()
                    let previousCategory = workbenchAccessibility.selectedSettingsCategory
                    if workbenchAccessibility.navigateSettingsCategory(to: category) {
                        DebugInteractionLatencyProbe.completeImmediateNavigation(
                            domain: "settings",
                            from: "settings_\(previousCategory.rawValue)",
                            to: "settings_\(category.rawValue)",
                            trigger: "settings_sidebar_click",
                            startedAt: startedAt
                        )
                    }
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
                .workbenchAccessibilityFocusRing(
                    isFocused: isAccessibilityFocused,
                    cornerRadius: WorkbenchControlMetrics.redesignAppSidebarItemRadius
                )
            }

            Spacer()
        }
        .padding(.top, WorkbenchControlMetrics.redesignSettingsTitlebarHeight)
        .padding(.horizontal, WorkbenchControlMetrics.redesignAppSidebarHorizontalPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignAppSidebarVerticalPadding)
        .background(WorkbenchRedesignColors.appSidebarBg)
        .overlay(alignment: .top) {
            TitlebarBackgroundView(backgroundColor: NSColor.clear)
                .frame(height: WorkbenchControlMetrics.redesignSettingsTitlebarHeight)
        }
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
                .zIndex(10)
            SettingsURLSchemeCategory()
        case .play:
            SettingsPlayCategory()
            SettingsDecodeCategory()
        case .shortcuts:
            SettingsShortcutsCategory()
        case .subtitle:
            SettingsSubtitleCategory()
        }
    }
}

private struct SettingsDialogLayerHost: View {
    @ObservedObject var confirmation: ConfirmationCenter

    var body: some View {
        WorkbenchDialogLayer(
            dialogIDs: confirmation.session.map { ["settings_confirmation:\($0.id)"] } ?? [],
            topBandHeight: WorkbenchControlMetrics.redesignSettingsTitlebarHeight
        ) {
            if let session = confirmation.session {
                WorkbenchConfirmationDialog(
                    session: session,
                    onClose: { confirmation.session = nil }
                )
                .environment(\.workbenchDialogID, .settingsConfirmation)
                .workbenchDialog(level: 2)
            }
        }
        .background(
            SettingsWindowCloseButtonSyncView(
                isCloseEnabled: confirmation.session == nil
            )
            .frame(width: 0, height: 0)
        )
    }
}

private struct SettingsWindowCloseButtonSyncView: NSViewRepresentable {
    let isCloseEnabled: Bool

    func makeNSView(context _: Context) -> SyncView {
        let view = SyncView()
        view.isCloseEnabled = isCloseEnabled
        return view
    }

    func updateNSView(_ nsView: SyncView, context _: Context) {
        nsView.isCloseEnabled = isCloseEnabled
        nsView.applyToWindow()
    }

    final class SyncView: NSView {
        var isCloseEnabled = true

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyToWindow()
        }

        func applyToWindow() {
            if !isCloseEnabled {
                window?.makeFirstResponder(nil)
            }
            window?.standardWindowButton(.closeButton)?.isEnabled = isCloseEnabled
        }
    }
}
