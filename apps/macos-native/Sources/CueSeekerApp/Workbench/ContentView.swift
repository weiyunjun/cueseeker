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
            confirmation: appState.confirmation,
            tasks: appState.tasks
        )
    }
}

private struct ContentRootView: View {
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    @ObservedObject var confirmation: ConfirmationCenter
    /// Observed because the window root presents the Task panel: the sheet's
    /// binding has to be re-read when the panel opens or closes.
    @ObservedObject var tasks: TaskQueueStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var shioriStore: ShioriStore
    @EnvironmentObject private var playback: PlaybackStore

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
                        AppTopBar()
                            .zIndex(3)
                    }

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
            .sheet(isPresented: taskPanelPresentation) {
                TaskPanel(tasks: tasks)
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

    /// The sheet only ever closes the panel. Opening goes through the store, so
    /// every open resets the tab the way the requirement asks.
    private var taskPanelPresentation: Binding<Bool> {
        Binding(
            get: { tasks.isPanelOpen },
            set: { isPresented in
                guard !isPresented else {
                    return
                }
                tasks.closePanel()
            }
        )
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
            case .library, .search:
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
                .font(.system(size: WorkbenchControlMetrics.redesignControlIconSize, weight: WorkbenchControlMetrics.redesignControlIconWeight))
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
        .foregroundStyle(
            layoutState.isVideoSizeTransitionInProgress
                ? WorkbenchRedesignColors.textDisabled
                : WorkbenchRedesignColors.textSecondary
        )
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
    // Observed so the labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

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
                isEnabled: !layoutState.isVideoSizeTransitionInProgress
            ) {
                appState.performUserInitiatedAppCommand {
                    layoutState.clearRecentSection()
                    appState.activateWorkbenchPanelMode(.recentWatching)
                }
            }

            AppSidebarChildItem(
                systemImage: "film",
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
                systemImage: "bookmark",
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
                mode: .shiori,
                isSelected: routeState.panelMode == .shiori,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.activateWorkbenchPanelMode(.shiori)
                    appState.showShioriListOverview()
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
        // The Sidebar no longer lists the Shiori lists, but this is still the
        // earliest place the overview is loaded, and the Shiori table's
        // move-to-list destinations read it without loading it themselves.
        .task {
            appState.loadShioriListOverviewIfNeeded()
        }
    }
}

private struct AppSidebarNavigationItem: View {
    let mode: WorkbenchPanelMode
    let isSelected: Bool
    let isEnabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            AppSidebarItemLabel(
                systemImage: mode.systemImage,
                label: mode.sidebarLabel,
                isSelected: isSelected,
                isEnabled: isEnabled
            )
        }
        .buttonStyle(StaticButtonStyle())
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
    let systemImage: String
    let label: String
    let isSelected: Bool
    let isEnabled: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                Image(systemName: systemImage)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignAppSidebarItemIconSize,
                        weight: .medium
                    ))
                    .frame(
                        width: WorkbenchControlMetrics.redesignAppSidebarItemIconSize,
                        height: WorkbenchControlMetrics.redesignAppSidebarItemIconSize
                    )
                    .foregroundStyle(iconColor)

                Text(label)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeAppSidebarItem,
                        weight: .regular
                    ))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
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
        return isEnabled
            ? WorkbenchRedesignColors.textPrimary
            : WorkbenchRedesignColors.textDisabled
    }

    /// The child's icon starts where the primary item's label starts, so the
    /// two levels read as one step of indentation.
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

/// The toggle has no hover response and no background of its own; the disabled
/// look comes from its icon color, the way the other icon buttons work.
private struct AppSidebarToggleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
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
