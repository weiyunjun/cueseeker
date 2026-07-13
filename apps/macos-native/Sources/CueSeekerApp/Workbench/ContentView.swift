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
            fullscreenManager: appState.playbackFullscreenManager
        )
    }
}

private struct ContentRootView: View {
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
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

                    TitlebarCommandBridge()
                        .frame(width: 0, height: 0)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onAppear {
                    collapseSidebarForCompactWindowIfNeeded(width: geometry.size.width)
                }
                .onChange(of: geometry.size.width) { width in
                    collapseSidebarForCompactWindowIfNeeded(width: width)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .frame(minWidth: AppShellLayout.minimumWindowWidth, minHeight: AppShellLayout.minimumWindowHeight)
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
    @EnvironmentObject private var appState: AppCoordinator
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @EnvironmentObject private var routeState: WorkbenchRouteState

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
            titlebarContent
        } sidebarToggle: {
            sidebarToggle
        }
    }

    @ViewBuilder
    private var titlebarContent: some View {
        switch routeState.panelMode {
        case .testLibrary:
            if let selectedFolder = routeState.selectedTestLibraryFolder {
                LibraryFolderDetailHeader(
                    folderTitle: selectedFolder.folderTitle,
                    onBack: {
                        appState.performUserInitiatedAppCommand {
                            appState.workbenchLayout.clearTestLibraryFolder()
                        }
                    }
                )
            } else {
                LibrarySectionTitle("Library")
                    .allowsHitTesting(false)
            }
        default:
            LibrarySectionTitle(routeState.panelMode.title)
                .allowsHitTesting(false)
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
        .help(layoutState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
        .accessibilityLabel(layoutState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
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

    var body: some View {
        UIInvalidationProbe.count(
            "UI.AppSidebar.body",
            scope: appState.uiProbeScope,
            details: "selection=\(routeState.panelMode.rawValue)"
        )

        return VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                ForEach(WorkbenchPanelMode.sidebarCases, id: \.rawValue) { mode in
                    AppSidebarNavigationItem(
                        mode: mode,
                        isSelected: routeState.panelMode == mode,
                        isEnabled: !layoutState.isVideoSizeTransitionInProgress,
                        onSelect: {
                            guard routeState.panelMode != mode else {
                                return
                            }

                            appState.performUserInitiatedAppCommand {
                                appState.activateWorkbenchPanelMode(mode)
                            }
                        }
                    )
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
        .buttonStyle(AppSidebarItemButtonStyle(isSelected: isSelected))
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .help(mode.sidebarLabel)
        .accessibilityLabel(mode.sidebarLabel)
    }
}

private struct AppSidebarSettingsItem: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppSidebarItemLabel(
                systemImage: "gearshape",
                label: "Settings",
                isSelected: false,
                isEnabled: true
            )
        }
        .buttonStyle(AppSidebarItemButtonStyle(isSelected: false))
        .subtitleTableTextSelectionInteractiveRegion()
        .focusable(false)
        .help("Settings")
        .accessibilityLabel("Settings")
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
        guard isEnabled else {
            return WorkbenchRedesignColors.iconDisabled
        }
        return WorkbenchRedesignColors.iconDefault
    }

    private var textColor: Color {
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
            .onHover { isHovered = $0 }
    }
}

enum AppShellLayout {
    static let contentTopPadding: CGFloat = 16
    static let defaultWindowWidth: CGFloat = 1_000
    static let minimumWindowWidth: CGFloat = 480
    static let minimumWindowHeight: CGFloat = 560
    static let sidebarAutoCollapseWindowWidth: CGFloat = 760
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
