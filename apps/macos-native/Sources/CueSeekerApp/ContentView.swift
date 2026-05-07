import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    private let animation = Animation.easeInOut(duration: 0.22)

    private let windowBackground = Color(
        red: 0.955,
        green: 0.955,
        blue: 0.95
    )
    private let topBarBackground = Color(
        red: 0.92,
        green: 0.92,
        blue: 0.915
    )

    var body: some View {
        ZStack(alignment: .topLeading) {
            windowBackground
                .ignoresSafeArea()

            HStack(spacing: 0) {
                mainWorkspace
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, AppShellLayout.topBarHeight)
            }
            .animation(animation, value: appState.isLibraryPanelVisible)

            appTopBar
                .frame(height: AppShellLayout.topBarHeight)
                .zIndex(3)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: AppShellLayout.minimumWindowWidth, minHeight: AppShellLayout.minimumWindowHeight)
    }

    @ViewBuilder
    private var appTopBar: some View {
        TitlebarBackgroundView(
            backgroundColor: topBarBackground,
            onDoubleClickZoom: {
                appState.beginTitlebarZoomTransitionFromUser()
            }
        )
            .overlay {
                Text("CueSeeker")
                    .font(.system(
                        size: AppShellLayout.titleFontSize,
                        weight: AppShellLayout.titleFontWeight
                    ))
                    .foregroundStyle(.primary)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .leading) {
                topBarLeadingControls
            }
            .overlay(alignment: .trailing) {
                topBarTrailingControls
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(AppShellLayout.topBarSeparatorOpacity))
                    .frame(height: 1)
            }
    }

    private var topBarLeadingControls: some View {
        libraryPanelToggle
            .padding(
                .leading,
                AppShellLayout.windowControlsReservedWidth
                    + AppShellLayout.toggleLeadingAfterWindowControls
            )
            .frame(height: AppShellLayout.topBarHeight)
    }

    @ViewBuilder
    private var topBarTrailingControls: some View {
        searchPanelToggle
            .padding(.trailing, AppShellLayout.toggleTrailing)
            .frame(height: AppShellLayout.topBarHeight)
    }

    private var libraryPanelToggle: some View {
        Button {
            appState.performUserInitiatedAppCommand {
                appState.toggleLibraryPanel()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: AppShellLayout.toggleIconSize, weight: .medium))
                .frame(
                    width: AppShellLayout.toggleSize,
                    height: AppShellLayout.toggleSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarButtonStyle())
        .disabled(appState.isVideoSizeTransitionInProgress)
        .focusable(false)
        .foregroundStyle(.primary)
        .help(appState.isLibraryPanelVisible ? "Hide Library" : "Show Library")
        .frame(
            width: AppShellLayout.toggleSize,
            height: AppShellLayout.toggleSize
        )
    }

    private var searchPanelToggle: some View {
        Button {
            appState.performUserInitiatedAppCommand {
                appState.toggleSearchPanel()
            }
        } label: {
            Image(systemName: "sidebar.right")
                .font(.system(size: AppShellLayout.toggleIconSize, weight: .medium))
                .frame(
                    width: AppShellLayout.toggleSize,
                    height: AppShellLayout.toggleSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarButtonStyle())
        .disabled(appState.isVideoSizeTransitionInProgress)
        .focusable(false)
        .foregroundStyle(.primary)
        .help(appState.isSearchPanelVisible ? "Hide Search Panel" : "Show Search Panel")
        .frame(
            width: AppShellLayout.toggleSize,
            height: AppShellLayout.toggleSize
        )
    }

    @ViewBuilder
    private var mainWorkspace: some View {
        SearchView()
    }
}

enum AppShellLayout {
    static let contentTopPadding: CGFloat = 16
    static let minimumWindowWidth: CGFloat = 1_250
    static let minimumWindowHeight: CGFloat = 560
    static let topBarHeight: CGFloat = 45
    static let windowControlsReservedWidth: CGFloat = 80
    static let toggleLeadingAfterWindowControls: CGFloat = 18
    static let toggleTrailing: CGFloat = 16
    static let toggleSize: CGFloat = 28
    static let toggleIconSize: CGFloat = 15
    static let titleFontSize: CGFloat = 16
    static let titleFontWeight: Font.Weight = .semibold
    static let topBarSeparatorOpacity = 0.12
}
