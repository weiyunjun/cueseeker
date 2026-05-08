import SwiftUI

struct ContentView: View {
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
        AppPerformanceProbe.measure("ContentView.body", thresholdMilliseconds: 4) {
            UIInvalidationProbe.count("UI.ContentView.body")

            return ZStack(alignment: .topLeading) {
                windowBackground
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    mainWorkspace
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, AppShellLayout.topBarHeight)
                }

                AppTopBar(backgroundColor: topBarBackground)
                    .frame(height: AppShellLayout.topBarHeight)
                    .zIndex(3)
            }
            .ignoresSafeArea(.container, edges: .top)
            .frame(minWidth: AppShellLayout.minimumWindowWidth, minHeight: AppShellLayout.minimumWindowHeight)
            .background(LayoutPerformanceProbe(name: "ContentView.layout"))
        }
    }

    @ViewBuilder
    private var mainWorkspace: some View {
        SearchView()
    }
}

private struct AppTopBar: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var layoutState: WorkbenchLayoutState

    let backgroundColor: Color

    var body: some View {
        UIInvalidationProbe.count("UI.AppTopBar.body")

        return appTopBar
    }

    @ViewBuilder
    private var appTopBar: some View {
        TitlebarBackgroundView(
            backgroundColor: backgroundColor,
            onDoubleClickZoom: { window in
                appState.beginTitlebarZoomTransitionFromUser(window: window)
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
        GeometryReader { geometry in
            let regionWidth = leadingControlRegionWidth(availableWidth: geometry.size.width)

            HStack(spacing: AppShellLayout.modeButtonSpacing) {
                if layoutState.isLibraryPanelVisible {
                    titlebarModeButton(
                        systemImage: "folder",
                        isSelected: true,
                        action: {},
                        help: "Library"
                    )
                    .zIndex(1)
                }

                Spacer(minLength: 0)

                libraryPanelToggle
                    .zIndex(2)
            }
            .padding(.leading, AppShellLayout.windowControlsReservedWidth + AppShellLayout.modeControlsOuterPadding)
            .padding(.trailing, AppShellLayout.modeControlsOuterPadding)
            .frame(width: regionWidth, height: AppShellLayout.topBarHeight)
            .animation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration), value: layoutState.isLibraryPanelVisible)
            .animation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration), value: layoutState.libraryPanelWidth)
        }
        .frame(height: AppShellLayout.topBarHeight)
    }

    @ViewBuilder
    private var topBarTrailingControls: some View {
        GeometryReader { geometry in
            let regionWidth = trailingControlRegionWidth(availableWidth: geometry.size.width)

            HStack(spacing: AppShellLayout.modeButtonSpacing) {
                searchPanelToggle
                    .zIndex(2)

                if layoutState.isSearchPanelVisible {
                    titlebarModeButton(
                        systemImage: "magnifyingglass",
                        isSelected: layoutState.rightPanelMode == .search,
                        action: {
                            layoutState.selectRightPanelMode(.search)
                        },
                        help: "Search"
                    )
                    .zIndex(1)

                    titlebarModeButton(
                        systemImage: "star",
                        isSelected: layoutState.rightPanelMode == .favorites,
                        action: {
                            layoutState.selectRightPanelMode(.favorites)
                        },
                        help: "Favorites"
                    )
                    .zIndex(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, AppShellLayout.modeControlsOuterPadding)
            .padding(.trailing, AppShellLayout.modeControlsOuterPadding)
            .frame(width: regionWidth, height: AppShellLayout.topBarHeight, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: AppShellLayout.topBarHeight, alignment: .trailing)
            .animation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration), value: layoutState.isSearchPanelVisible)
            .animation(.easeInOut(duration: AppShellLayout.sidePanelAnimationDuration), value: layoutState.searchPanelWidth)
        }
        .frame(height: AppShellLayout.topBarHeight)
    }

    private func leadingControlRegionWidth(availableWidth: CGFloat) -> CGFloat {
        if layoutState.isLibraryPanelVisible {
            return max(
                CGFloat(layoutState.libraryPanelWidth),
                AppShellLayout.collapsedLeadingControlRegionWidth
            )
        }

        return AppShellLayout.collapsedLeadingControlRegionWidth
    }

    private func trailingControlRegionWidth(availableWidth: CGFloat) -> CGFloat {
        if layoutState.isSearchPanelVisible {
            return min(
                max(
                    CGFloat(layoutState.searchPanelWidth),
                    AppShellLayout.collapsedTrailingControlRegionWidth
                ),
                max(AppShellLayout.collapsedTrailingControlRegionWidth, availableWidth)
            )
        }

        return AppShellLayout.collapsedTrailingControlRegionWidth
    }

    private func titlebarModeButton(
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        help: String
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: AppShellLayout.toggleIconSize, weight: .medium))
                .frame(
                    width: AppShellLayout.toggleSize,
                    height: AppShellLayout.toggleSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(TitlebarModeButtonStyle(isSelected: isSelected))
        .focusable(false)
        .foregroundStyle(.primary)
        .help(help)
        .frame(
            width: AppShellLayout.toggleSize,
            height: AppShellLayout.toggleSize
        )
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
        .disabled(layoutState.isVideoSizeTransitionInProgress)
        .focusable(false)
        .foregroundStyle(.primary)
        .help(layoutState.isLibraryPanelVisible ? "Hide Library" : "Show Library")
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
        .disabled(layoutState.isVideoSizeTransitionInProgress)
        .focusable(false)
        .foregroundStyle(.primary)
        .help(layoutState.isSearchPanelVisible ? "Hide Right Panel" : "Show Right Panel")
        .frame(
            width: AppShellLayout.toggleSize,
            height: AppShellLayout.toggleSize
        )
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
    static let modeButtonSpacing: CGFloat = 6
    static let modeControlsOuterPadding: CGFloat = 12
    static let collapsedLeadingControlRegionWidth: CGFloat = windowControlsReservedWidth
        + modeControlsOuterPadding
        + toggleSize
        + modeControlsOuterPadding
    static let collapsedTrailingControlRegionWidth: CGFloat = toggleSize
        + modeControlsOuterPadding * 2
    static let sidePanelAnimationDuration: Double = 0.18
    static let titleFontSize: CGFloat = 16
    static let titleFontWeight: Font.Weight = .semibold
    static let topBarSeparatorOpacity = 0.12
}

struct TitlebarModeButtonStyle: ButtonStyle {
    let isSelected: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                isSelected ? Color.black.opacity(0.15) :
                (isHovered ? Color.black.opacity(0.08) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
