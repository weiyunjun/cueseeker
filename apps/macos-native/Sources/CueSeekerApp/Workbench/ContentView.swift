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
    /// Observed because the window root presents the Task panel, so the dialog
    /// layer has to be re-read when the panel opens or closes.
    @ObservedObject var tasks: TaskQueueStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var libraryStore: LibraryStore
    @EnvironmentObject private var excerptStore: ExcerptStore
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
                            .environment(\.workbenchPageScrollOffset, layoutState.pageScroll)
                    }

                    if !hidesWorkbenchChrome {
                        AppTopBar(pageScroll: layoutState.pageScroll)
                            .zIndex(3)
                    }

                    ToastStackView(center: appState.toast)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(100)

                    dialogLayer(isPlaybackPageVisible: hidesWorkbenchChrome)
                        .zIndex(200)

                    TitlebarCommandBridge()
                        .frame(width: 0, height: 0)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .modifier(
                    InterfaceLayerCoverageBridge(layers: appState.interfaceLayers)
                )
                .environment(\.isAppFullscreen, layoutState.isAppFullscreen)
                .onAppear {
                    collapseSidebarForCompactWindowIfNeeded(
                        width: geometry.size.width,
                        isWorkbenchVisible: !hidesWorkbenchChrome
                    )
                }
                .onChange(of: geometry.size.width) { width in
                    collapseSidebarForCompactWindowIfNeeded(
                        width: width,
                        isWorkbenchVisible: !hidesWorkbenchChrome
                    )
                }
                // The playback page must not decide the Sidebar's state. While
                // it is up the width is not tested at all, and the return to
                // the Workbench tests the width that is in effect by then.
                .onChange(of: hidesWorkbenchChrome) { hidesChrome in
                    collapseSidebarForCompactWindowIfNeeded(
                        width: geometry.size.width,
                        isWorkbenchVisible: !hidesChrome
                    )
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .frame(minWidth: AppShellLayout.minimumWindowWidth, minHeight: AppShellLayout.minimumWindowHeight)
            .opensWithoutFocus()
            .preferredColorScheme(settingsStore.appAppearanceMode.colorScheme)
            .background(LayoutPerformanceProbe(name: "ContentView.layout"))
        }
    }

    /// The dialogs, bottom first. Only a Confirmation stacks on another one:
    /// the Task panel raises its confirmations here, as every page does.
    private func dialogLayer(isPlaybackPageVisible: Bool) -> some View {
        WorkbenchDialogLayer(
            dialogIDs: openDialogIDs,
            topBandHeight: isPlaybackPageVisible
                ? WorkbenchControlMetrics.redesignAppTopbarHeight
                : AppShellLayout.topBarHeight
        ) {
            if let session = libraryStore.coverEditingSession {
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
                .workbenchDialog()
            }

            if let session = excerptStore.listEditorSession {
                ExcerptListEditorDialog(
                    session: session,
                    onChooseImage: {
                        appState.beginChoosingExcerptListCover(session)
                    },
                    onValidate: {
                        appState.validateExcerptListEditor(session)
                    },
                    onSave: {
                        appState.saveExcerptListEditor(session)
                    },
                    onClose: appState.closeExcerptListEditor
                )
                .workbenchDialog()
            }

            if let session = libraryStore.renameSession {
                LibraryRenameDialog(
                    session: session,
                    onConfirm: {
                        appState.confirmRename(session)
                    },
                    onClose: appState.closeRenameDialog
                )
                .workbenchDialog()
            }

            if let session = tasks.ankiExportSession {
                AnkiExportDialog(
                    session: session,
                    onChooseFolder: {
                        appState.beginChoosingAnkiExportFolder(session)
                    },
                    onExport: {
                        appState.confirmAnkiExport(session)
                    },
                    onClose: appState.closeAnkiExportDialog
                )
                .workbenchDialog()
            }

            if tasks.isPanelOpen {
                TaskPanel(tasks: tasks, confirmation: confirmation)
                    .workbenchDialog(isCovered: confirmation.session != nil)
            }

            if let session = confirmation.session {
                WorkbenchConfirmationDialog(
                    session: session,
                    onClose: { confirmation.session = nil }
                )
                .workbenchDialog(level: 2)
            }
        }
    }

    private var openDialogIDs: [AnyHashable] {
        var ids: [AnyHashable] = []
        if let session = libraryStore.coverEditingSession {
            ids.append(session.id)
        }
        if let session = excerptStore.listEditorSession {
            ids.append(session.id)
        }
        if let session = libraryStore.renameSession {
            ids.append(session.id)
        }
        if let session = tasks.ankiExportSession {
            ids.append(session.id)
        }
        if tasks.isPanelOpen {
            ids.append("task-panel")
        }
        if let session = confirmation.session {
            ids.append(session.id)
        }
        return ids
    }

    @ViewBuilder
    private var mainWorkspace: some View {
        SearchView()
    }

    private func collapseSidebarForCompactWindowIfNeeded(
        width: CGFloat,
        isWorkbenchVisible: Bool
    ) {
        guard isWorkbenchVisible else {
            return
        }

        layoutState.collapseSidebarForCompactWindowIfNeeded(
            width: width,
            threshold: AppShellLayout.sidebarAutoCollapseWindowWidth
        )
    }
}

private struct AppTopBar: View {
    /// Observed so the function region follows the page's horizontal scroll;
    /// it is the only view that re-reads it.
    @ObservedObject var pageScroll: WorkbenchPageScrollOffset
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var routeState: WorkbenchRouteState
    // Observed so the title turns into the unknown page's when the Excerpt
    // list or Library folder a history entry points to disappears.
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var excerptStore: ExcerptStore
    @State private var isSidebarToggleHovered = false
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
            pageScrollOffset: pageScroll.horizontal,
            onDoubleClickZoom: { window in
                NotificationCenter.default.post(name: .topbarTitlebarZoomRequested, object: window)
                return true
            }
        ) {
            HStack(spacing: WorkbenchControlMetrics.redesignAppTopbarContentAfterToggleGap) {
                // Back and Forward are one pair, closer to each other than
                // to what stands on either side of them.
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                    backButton
                    forwardButton
                }

                if let pageTitle {
                    WorkbenchPageTitle(pageTitle)
                }
            }
        } trailingContent: {
            TopbarAppEntries()
        } sidebarToggle: {
            sidebarToggle
        }
    }

    private var backButton: some View {
        WorkbenchIconButton(
            icon: .caretLeft,
            isRedesign: true,
            isFrozen: layoutState.isVideoSizeTransitionInProgress
        ) {
            appState.performUserInitiatedAppCommand {
                appState.goBackInWorkbench()
            }
        }
        .disabled(!routeState.canGoBack)
        .help(L("topbar.back"))
        .accessibilityLabel(L("topbar.back"))
        .accessibilityIdentifier("topbar-back")
    }

    /// First-level pages carry their name; a second-level page carries none,
    /// its Cover Summary names it — unless the page it points to is gone.
    private var pageTitle: String? {
        switch routeState.currentRoute {
        case .search:
            L("sidebar.search")
        case .recent:
            L("sidebar.recent")
        case .library:
            L("sidebar.library")
        case .file:
            L("sidebar.file")
        case .excerpt:
            L("sidebar.excerpt")
        case .libraryFolder, .excerptList:
            appState.isWorkbenchRouteUnknown(routeState.currentRoute)
                ? L("page.unknown.title")
                : nil
        }
    }

    private var forwardButton: some View {
        WorkbenchIconButton(
            icon: .caretRight,
            isRedesign: true,
            isFrozen: layoutState.isVideoSizeTransitionInProgress
        ) {
            appState.performUserInitiatedAppCommand {
                appState.goForwardInWorkbench()
            }
        }
        .disabled(!routeState.canGoForward)
        .help(L("topbar.forward"))
        .accessibilityLabel(L("topbar.forward"))
        .accessibilityIdentifier("topbar-forward")
    }

    private var sidebarToggle: some View {
        Button {
            appState.performUserInitiatedAppCommand {
                appState.toggleWorkbenchSidebarVisibilityFromUser()
            }
        } label: {
            AppIconImage(.sidebarSimple, size: WorkbenchControlMetrics.redesignControlIconSize)
                .frame(
                    width: AppShellLayout.sidebarToggleSize,
                    height: AppShellLayout.sidebarToggleSize
                )
                .background(
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                        .fill(isSidebarToggleHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(AppSidebarToggleButtonStyle())
        .disabled(layoutState.isVideoSizeTransitionInProgress)
        .onPointerHover { isSidebarToggleHovered = $0 }
        .subtitleTableTextSelectionInteractiveRegion(
            isActive: !layoutState.isVideoSizeTransitionInProgress
        )
        .foregroundStyle(WorkbenchRedesignColors.textSecondary)
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
                isSelected: routeState.panelMode == .recentWatching,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.activateWorkbenchPanelMode(.recentWatching)
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
                mode: .file,
                isSelected: routeState.panelMode == .file,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.activateWorkbenchPanelMode(.file)
                }
            }

            AppSidebarNavigationItem(
                mode: .excerpt,
                isSelected: routeState.panelMode == .excerpt,
                isEnabled: !layoutState.isVideoSizeTransitionInProgress
            ) {
                appState.performUserInitiatedAppCommand {
                    appState.activateWorkbenchPanelMode(.excerpt)
                }
            }
        }
        // The Sidebar keeps clear of the window controls, not of the topbar,
        // so its items stay put when the topbar is taller than that band.
        .padding(.top, WorkbenchControlMetrics.redesignAppTopbarHeight + WorkbenchControlMetrics.redesignAppSidebarVerticalPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignAppSidebarHorizontalPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignAppSidebarVerticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.appSidebarBg)
        .background(LayoutPerformanceProbe(name: "AppSidebar.layout"))
        // The Sidebar no longer lists the Excerpt lists, but this is still the
        // earliest place the overview is loaded, and the Excerpt table's
        // move-to-list destinations read it without loading it themselves.
        .task {
            appState.loadExcerptListOverviewIfNeeded()
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
                icon: mode.icon,
                label: mode.sidebarLabel,
                isSelected: isSelected
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
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .help(mode.sidebarLabel)
        .accessibilityLabel(mode.sidebarLabel)
    }
}

private struct AppSidebarItemLabel: View {
    let icon: AppIcon
    let label: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            AppIconImage(icon, size: WorkbenchControlMetrics.redesignAppSidebarItemIconSize)
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
        isSelected
            ? WorkbenchRedesignColors.appSidebarItemSelectedContent
            : WorkbenchRedesignColors.textSecondary
    }

    private var textColor: Color {
        isSelected
            ? WorkbenchRedesignColors.appSidebarItemSelectedContent
            : WorkbenchRedesignColors.textPrimary
    }
}

/// The toggle's hover background is painted by the view, so the style itself
/// only has to keep AppKit from adding a pressed look of its own.
private struct AppSidebarToggleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

enum AppShellLayout {
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
    static let topBarHeight = WorkbenchControlMetrics.redesignWorkbenchTopbarHeight
    static let sidePanelAnimationDuration: Double = 0.18

    static let modeControlsOuterPadding: CGFloat = 12
    /// After the window controls: their inset, their measured width, then the
    /// gap to the toggle.
    @MainActor static var collapsedLeadingToggleX: CGFloat {
        WorkbenchControlMetrics.redesignSpacing6
            + AppWindowControls.clusterWidth
            + WorkbenchControlMetrics.redesignAppTopbarToggleGapAfterWindowControls
    }

    static let sidebarWidth = WorkbenchControlMetrics.redesignAppSidebarWidth
    static let sidebarToggleSize = WorkbenchControlMetrics.redesignIconButtonSize
}
