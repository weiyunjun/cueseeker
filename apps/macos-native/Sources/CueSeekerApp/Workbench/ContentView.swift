import AppKit
import SwiftUI

extension Notification.Name {
    static let topbarDismissMenusRequested = Notification.Name("CueSeekerTopbarDismissMenusRequested")
    static let topbarTitlebarZoomRequested = Notification.Name("CueSeekerTopbarTitlebarZoomRequested")
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppCoordinator

    var body: some View {
        ContentRootView(
            appState: appState,
            fullscreenManager: appState.playbackFullscreenManager,
            confirmation: appState.confirmation
        )
    }
}

private struct ContentRootView: View {
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    @ObservedObject var confirmation: ConfirmationCenter
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var shioriStore: ShioriStore
    @EnvironmentObject private var playback: PlaybackStore
    /// Shared between the top bar's entry button and the panel, so the panel
    /// can collapse back into the button across their hosting boundary.
    @State private var taskEntryAnchor = MenuAnchorHandle()

    private let windowBackground = Color(
        red: 0.955,
        green: 0.955,
        blue: 0.95
    )

    var body: some View {
        AppPerformanceProbe.measure("ContentView.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count(
                "UI.ContentView.body",
                scope: appState.uiProbeScope
            )

            let isPlaybackFullscreen = fullscreenManager.isFullscreen
            let hidesWorkbenchChrome = isPlaybackFullscreen || appState.isPlaybackPageVisible

            return GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    windowBackground
                        .ignoresSafeArea()

                    HStack(spacing: 0) {
                        if !hidesWorkbenchChrome && layoutState.isSidebarVisible {
                            AppSidebar()
                                .frame(width: AppShellLayout.sidebarWidth)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        mainWorkspace
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, hidesWorkbenchChrome ? 0 : AppShellLayout.topBarHeight)
                    }

                    if !hidesWorkbenchChrome {
                        AppTopBar(taskEntryAnchor: taskEntryAnchor)
                            .zIndex(3)
                    }

                    // Above the top bar it opens from, below the toasts, which
                    // are visual only and take no input.
                    TaskPanelHost(
                        tasks: appState.tasks,
                        confirmation: confirmation,
                        entryAnchor: taskEntryAnchor
                    )
                    .zIndex(4)

                    ToastStackView(center: appState.toast)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(100)

                    TitlebarCommandBridge()
                        .frame(width: 0, height: 0)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .modifier(
                    InterfaceLayerCoverageBridge(layers: appState.interfaceLayers)
                )
                .onAppear {
                    collapseSidebarForCompactWindowIfNeeded(width: geometry.size.width)
                }
                .onChange(of: geometry.size.width) { width in
                    collapseSidebarForCompactWindowIfNeeded(width: width)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .frame(minWidth: AppShellLayout.minimumWindowWidth, minHeight: AppShellLayout.minimumWindowHeight)
            .sheet(item: $libraryStore.coverEditingSession) { session in
                LibraryEditCoverDialog(
                    session: session,
                    onChooseImage: {
                        appState.beginChoosingLibraryCover(session)
                    },
                    onCancel: appState.cancelLibraryCoverEditing,
                    onSave: {
                        appState.saveLibraryCoverEditing(session)
                    }
                )
                // A dialog is the top layer; its own controls must not read the
                // freeze the dialog itself put on the page below.
                .interfaceLayer(.dialog)
                .interactiveDismissDisabled(session.isSaving)
            }
            .sheet(item: $shioriStore.listEditorSession) { session in
                ShioriListEditorDialog(
                    session: session,
                    onChooseImage: {
                        appState.beginChoosingShioriListCover(session)
                    },
                    onValidate: {
                        appState.validateShioriListEditor(session)
                    },
                    onSave: {
                        appState.saveShioriListEditor(session)
                    },
                    onClose: appState.closeShioriListEditor
                )
                .interfaceLayer(.dialog)
                .interactiveDismissDisabled(true)
            }
            .sheet(item: $confirmation.session) { session in
                WorkbenchConfirmationDialog(
                    session: session,
                    onClose: { confirmation.session = nil }
                )
                    .interfaceLayer(.dialog)
            }
            .preferredColorScheme(settingsStore.appAppearanceMode.colorScheme)
            .background(LayoutPerformanceProbe(name: "ContentView.layout"))
        }
    }

    @ViewBuilder
    private var mainWorkspace: some View {
        SearchView()
    }

    private func collapseSidebarForCompactWindowIfNeeded(width: CGFloat) {
        layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: width,
            threshold: AppShellLayout.sidebarAutoCollapseWindowWidth
        )
    }
}

private struct AppTopBar: View {
    let taskEntryAnchor: MenuAnchorHandle

    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var routeState: WorkbenchRouteState
    // Observed so the labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    var body: some View {
        UIInvalidationProbe.count(
            "UI.AppTopBar.body",
            scope: appState.uiProbeScope
        )

        return AppTopbarLayout(
            isSidebarVisible: layoutState.isSidebarVisible,
            isAppFullscreen: layoutState.isAppFullscreen,
            onDoubleClickZoom: { window in
                NotificationCenter.default.post(name: .topbarTitlebarZoomRequested, object: window)
                return true
            }
        ) {
            backButton
        } trailingContent: {
            TaskEntryButton(
                tasks: appState.tasks,
                anchor: taskEntryAnchor,
                onOpen: {
                    appState.performUserInitiatedAppCommand {
                        appState.tasks.openPanel()
                    }
                }
            )
        } sidebarToggle: {
            sidebarToggle
        }
    }

    private var backButton: some View {
        WorkbenchIconButton(
            systemImage: "chevron.left",
            isRedesign: true,
            action: navigateBack
        )
        .disabled(
            !routeState.canNavigateBack
                || layoutState.isVideoSizeTransitionInProgress
        )
        .help(L("topbar.back"))
        .accessibilityLabel(L("topbar.back"))
    }

    private func navigateBack() {
        appState.performUserInitiatedAppCommand {
            switch routeState.panelMode {
            case .recentWatching:
                layoutState.clearRecentSection()
            case .testLibrary:
                layoutState.clearTestLibraryFolder()
            case .shiori:
                appState.showShioriListOverview()
            case .library, .data, .search:
                break
            }
        }
    }

    private var sidebarToggle: some View {
        Button {
            appState.performUserInitiatedAppCommand {
                appState.toggleWorkbenchSidebarVisibilityFromUser()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: WorkbenchControlMetrics.redesignControlIconSize, weight: .medium))
                .frame(
                    width: AppShellLayout.sidebarToggleSize,
                    height: AppShellLayout.sidebarToggleSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(AppSidebarToggleButtonStyle())
        .disabled(layoutState.isVideoSizeTransitionInProgress)
        .subtitleTableTextSelectionInteractiveRegion(
            isActive: !layoutState.isVideoSizeTransitionInProgress
        )
        .foregroundStyle(WorkbenchRedesignColors.iconDefault)
        .focusable(false)
        .help(sidebarToggleLabel)
        .accessibilityLabel(sidebarToggleLabel)
    }

    private var sidebarToggleLabel: String {
        layoutState.isSidebarVisible
            ? L("topbar.hide_sidebar")
            : L("topbar.show_sidebar")
    }
}

private struct TitlebarCommandBridge: View {
    @EnvironmentObject private var appState: AppCoordinator

    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .topbarTitlebarZoomRequested)) { notification in
                guard let window = notification.object as? NSWindow else {
                    return
                }

                _ = appState.beginTitlebarZoomTransitionFromUser(window: window)
            }
    }
}

private struct AppSidebar: View {
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var routeState: WorkbenchRouteState
    @EnvironmentObject private var shioriStore: ShioriStore
    // Observed so the labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @State private var isRecentExpanded = true
    @State private var isShioriExpanded = true

    var body: some View {
        UIInvalidationProbe.count(
            "UI.AppSidebar.body",
            scope: appState.uiProbeScope,
            details: "selection=\(routeState.panelMode.rawValue)"
        )

        return VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
            AppSidebarNavigationItem(
                mode: .search,
                isSelected: routeState.panelMode == .search,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.activateWorkbenchPanelMode(.search)
                }
            }

            AppSidebarNavigationItem(
                mode: .recentWatching,
                isSelected: routeState.panelMode == .recentWatching
                    && routeState.selectedRecentSection == nil,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress,
                isExpanded: isRecentExpanded,
                onToggleExpansion: {
                    isRecentExpanded.toggle()
                }
            ) {
                appState.performUserInitiatedAppCommand {
                    layoutState.clearRecentSection()
                    appState.activateWorkbenchPanelMode(.recentWatching)
                }
            }

            if isRecentExpanded {
                AppSidebarChildItem(
                    label: L("sidebar.recent_videos"),
                    isSelected: routeState.panelMode == .recentWatching
                        && routeState.selectedRecentSection == .videos,
                    isEnabled: !layoutState.isVideoSizeTransitionInProgress
                ) {
                    appState.performUserInitiatedAppCommand {
                        appState.activateWorkbenchPanelMode(.recentWatching)
                        layoutState.selectRecentSection(.videos)
                    }
                }
                AppSidebarChildItem(
                    label: L("sidebar.recent_shioris"),
                    isSelected: routeState.panelMode == .recentWatching
                        && routeState.selectedRecentSection == .shioris,
                    isEnabled: !layoutState.isVideoSizeTransitionInProgress
                ) {
                    appState.performUserInitiatedAppCommand {
                        appState.activateWorkbenchPanelMode(.recentWatching)
                        layoutState.selectRecentSection(.shioris)
                    }
                }
            }

            AppSidebarNavigationItem(
                mode: .testLibrary,
                isSelected: routeState.panelMode == .testLibrary,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.activateWorkbenchPanelMode(.testLibrary)
                }
            }

            AppSidebarNavigationItem(
                mode: .data,
                isSelected: routeState.panelMode == .data,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.activateWorkbenchPanelMode(.data)
                }
            }

            AppSidebarNavigationItem(
                mode: .shiori,
                isSelected: routeState.panelMode == .shiori
                    && routeState.selectedShioriListID == nil,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress,
                isExpanded: isShioriExpanded,
                onToggleExpansion: {
                    isShioriExpanded.toggle()
                }
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.activateWorkbenchPanelMode(.shiori)
                    appState.showShioriListOverview()
                }
            }

            if isShioriExpanded {
                WorkbenchScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: WorkbenchControlMetrics.redesignSpacing1
                    ) {
                        ForEach(shioriStore.listOverview.lists) { summary in
                            AppSidebarChildItem(
                                label: summary.list.name,
                                isSelected: routeState.panelMode == .shiori
                                    && routeState.selectedShioriListID == summary.id,
                                isEnabled: !layoutState.isVideoSizeTransitionInProgress
                            ) {
                                appState.performUserInitiatedAppCommand {
                                    appState.activateWorkbenchPanelMode(.shiori)
                                    appState.openShioriList(id: summary.id)
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            AppSidebarSettingsItem {
                appState.performUserInitiatedAppCommand {
                    NotificationCenter.default.post(name: .cueSeekerShowSettings, object: nil)
                }
            }
        }
        .padding(.top, AppShellLayout.topBarHeight + WorkbenchControlMetrics.redesignAppSidebarVerticalPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignAppSidebarHorizontalPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignAppSidebarVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.appSidebarBg)
        .background(LayoutPerformanceProbe(name: "AppSidebar.layout"))
        .task {
            appState.loadShioriListOverviewIfNeeded()
        }
    }
}

private struct AppSidebarNavigationItem: View {
    let mode: WorkbenchPanelMode
    let isSelected: Bool
    let isEnabled: Bool
    var isExpanded: Bool? = nil
    var onToggleExpansion: (() -> Void)? = nil
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                AppSidebarItemLabel(
                    systemImage: mode.systemImage,
                    label: mode.sidebarLabel,
                    isSelected: isSelected,
                    isEnabled: isEnabled
                )
            }
            .buttonStyle(StaticButtonStyle())

            if let isExpanded, let onToggleExpansion {
                Button(action: onToggleExpansion) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                                ? WorkbenchRedesignColors.appSidebarItemSelectedContent
                                : WorkbenchRedesignColors.iconMuted
                        )
                        .frame(
                            width: WorkbenchControlMetrics.redesignAppSidebarItemHeight,
                            height: WorkbenchControlMetrics.redesignAppSidebarItemHeight
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
                .accessibilityLabel(isExpanded ? L("sidebar.collapse") : L("sidebar.expand"))
            }
        }
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
        .opacity(isEnabled ? 1 : 0.62)
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .help(mode.sidebarLabel)
        .accessibilityLabel(mode.sidebarLabel)
    }
}

private struct AppSidebarChildItem: View {
    let label: String
    let isSelected: Bool
    let isEnabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(label)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeAppSidebarItem,
                    weight: .regular
                ))
                .foregroundStyle(
                    isSelected
                        ? WorkbenchRedesignColors.appSidebarItemSelectedContent
                        : (isEnabled
                            ? WorkbenchRedesignColors.textPrimary
                            : WorkbenchRedesignColors.textDisabled)
                )
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, childLeadingPadding)
                .padding(
                    .trailing,
                    WorkbenchControlMetrics.redesignAppSidebarItemHorizontalPadding
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: WorkbenchControlMetrics.redesignAppSidebarItemHeight,
                    maxHeight: WorkbenchControlMetrics.redesignAppSidebarItemHeight,
                    alignment: .leading
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(AppSidebarItemButtonStyle(isSelected: isSelected))
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .help(label)
        .accessibilityLabel(label)
    }

    private var childLeadingPadding: CGFloat {
        WorkbenchControlMetrics.redesignAppSidebarItemHorizontalPadding
            + WorkbenchControlMetrics.redesignAppSidebarItemIconSize
            + WorkbenchControlMetrics.redesignSpacing3
    }
}

private struct AppSidebarSettingsItem: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppSidebarItemLabel(
                systemImage: "gearshape",
                label: L("sidebar.settings"),
                isSelected: false,
                isEnabled: true
            )
        }
        .buttonStyle(AppSidebarItemButtonStyle(isSelected: false))
        .subtitleTableTextSelectionInteractiveRegion()
        .focusable(false)
        .help(L("sidebar.settings"))
        .accessibilityLabel(L("sidebar.settings"))
    }
}

private struct AppSidebarItemLabel: View {
    let systemImage: String
    let label: String
    let isSelected: Bool
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            Image(systemName: systemImage)
                .font(.system(size: WorkbenchControlMetrics.redesignAppSidebarItemIconSize, weight: .medium))
                .frame(
                    width: WorkbenchControlMetrics.redesignAppSidebarItemIconSize,
                    height: WorkbenchControlMetrics.redesignAppSidebarItemIconSize
                )
                .foregroundStyle(iconColor)

            Text(label)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeAppSidebarItem, weight: .regular))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignAppSidebarItemHorizontalPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignAppSidebarItemHeight,
            maxHeight: WorkbenchControlMetrics.redesignAppSidebarItemHeight
        )
        .contentShape(Rectangle())
    }

    private var iconColor: Color {
        if isSelected {
            return WorkbenchRedesignColors.appSidebarItemSelectedContent
        }
        guard isEnabled else {
            return WorkbenchRedesignColors.iconDisabled
        }
        return WorkbenchRedesignColors.iconDefault
    }

    private var textColor: Color {
        if isSelected {
            return WorkbenchRedesignColors.appSidebarItemSelectedContent
        }
        guard isEnabled else {
            return WorkbenchRedesignColors.textDisabled
        }
        return WorkbenchRedesignColors.textPrimary
    }
}

private struct AppSidebarItemButtonStyle: ButtonStyle {
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignAppSidebarItemRadius,
                    style: .continuous
                )
                .fill(isSelected ? WorkbenchRedesignColors.appSidebarItemSelectedBg : Color.clear)
            )
            .opacity(isEnabled ? 1 : 0.62)
    }
}

private struct AppSidebarToggleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .fill(isHovered && isEnabled ? WorkbenchRedesignColors.bgHover : Color.clear)
            )
            .opacity(isEnabled ? 1 : 0.62)
            .onPointerHover { isHovered = $0 }
    }
}

enum AppShellLayout {
    static let contentTopPadding: CGFloat = 16
    static let defaultWindowWidth: CGFloat = 1_000
    static let minimumWindowWidth: CGFloat = 480
    /// Lower bound for Workbench page content: the right region width when the
    /// window is at its minimum with the sidebar collapsed. Pages stop shrinking
    /// here and scroll horizontally instead.
    static let pageContentMinimumWidth = minimumWindowWidth
    static let minimumWindowHeight: CGFloat = 560
    /// The sidebar collapses exactly when keeping it would push the page below
    /// its content minimum width and force page-level horizontal scrolling.
    static let sidebarAutoCollapseWindowWidth = pageContentMinimumWidth + sidebarWidth
    static let topBarHeight = WorkbenchControlMetrics.redesignAppTopbarHeight
    static let sidePanelAnimationDuration: Double = 0.18

    static let windowControlsReservedWidth: CGFloat = 80
    static let toggleLeadingAfterWindowControls: CGFloat = 18
    static let modeControlsOuterPadding: CGFloat = 12
    static let collapsedLeadingToggleX: CGFloat = windowControlsReservedWidth
        + toggleLeadingAfterWindowControls

    static let sidebarWidth = WorkbenchControlMetrics.redesignAppSidebarWidth
    static let sidebarToggleSize = WorkbenchControlMetrics.redesignIconButtonSize
}
