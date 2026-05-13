import SwiftUI

struct ContentView: View {
    private let windowBackground = Color(
        red: 0.955,
        green: 0.955,
        blue: 0.95
    )
    private let contentBackground = Color(nsColor: .textBackgroundColor)

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

                AppTopBar(backgroundColor: contentBackground)
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
    @State private var searchDraft = ""

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
            .overlay(alignment: .center) {
                HStack(spacing: 16) {
                    HStack(spacing: 10) {
                        TopbarModeButton(
                            mode: .library,
                            systemImage: "folder",
                            help: "Library"
                        )

                        TopbarModeButton(
                            mode: .shiori,
                            systemImage: "bookmark",
                            help: "Shiori"
                        )
                    }

                    TopbarSearchField(
                        text: $searchDraft,
                        isFocused: $appState.isSearchFocused,
                        onSubmit: {
                            appState.submitTopbarSearch(searchDraft)
                        }
                    )
                    .frame(width: AppShellLayout.topbarSearchFieldWidth)
                }
            }
            .onAppear {
                searchDraft = appState.searchQuery
            }
            .onChange(of: appState.searchQuery) { query in
                if !appState.isSearchFocused {
                    searchDraft = query
                }
            }
            .onChange(of: appState.isSearchFocused) { isFocused in
                if isFocused, layoutState.panelMode != .search {
                    appState.activateWorkbenchPanelMode(.search)
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    appState.dismissBottomPlaybackMenu()
                }
            )
    }
}

private struct TopbarModeButton: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var layoutState: WorkbenchLayoutState

    let mode: WorkbenchPanelMode
    let systemImage: String
    let help: String

    var body: some View {
        let isSelected = layoutState.panelMode == mode

        Button {
            appState.performUserInitiatedAppCommand {
                appState.activateWorkbenchPanelMode(mode)
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(TopbarModeButtonStyle(isSelected: isSelected))
        .foregroundStyle(isSelected ? AppShellLayout.topbarModeSelectedColor : AppShellLayout.topbarModeColor)
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct TopbarModeButtonStyle: ButtonStyle {
    let isSelected: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: AppShellLayout.topbarModeCornerRadius)
                    .fill(backgroundColor(configuration: configuration))
            )
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if configuration.isPressed {
            return AppShellLayout.topbarModeActiveHoverBackground
        }
        if isSelected {
            return isHovered
                ? AppShellLayout.topbarModeActiveHoverBackground
                : AppShellLayout.topbarModeActiveBackground
        }
        if isHovered {
            return AppShellLayout.topbarModeHoverBackground
        }
        return .clear
    }
}

private struct TopbarSearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppShellLayout.topbarSearchIconColor)

            SearchTextView(
                text: $text,
                placeholder: "Search subtitles",
                isFocused: $isFocused,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: AppShellLayout.topbarSearchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: AppShellLayout.topbarSearchFieldCornerRadius)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppShellLayout.topbarSearchFieldCornerRadius)
                .strokeBorder(
                    isFocused
                        ? AppShellLayout.topbarSearchFocusedBorderColor
                        : AppShellLayout.topbarSearchBorderColor,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }
}

enum AppShellLayout {
    static let contentTopPadding: CGFloat = 16
    static let minimumWindowWidth: CGFloat = 1_000
    static let minimumWindowHeight: CGFloat = 560
    static let topBarHeight: CGFloat = 45
    static let sidePanelAnimationDuration: Double = 0.18
    static let titleFontSize: CGFloat = 16
    static let titleFontWeight: Font.Weight = .semibold
    static let topbarSearchFieldWidth: CGFloat = 320
    static let topbarSearchFieldHeight: CGFloat = 44
    static let topbarSearchFieldCornerRadius: CGFloat = 14
    static let topbarModeCornerRadius: CGFloat = 9

    static let topbarModeColor = Color(
        red: 119.0 / 255.0,
        green: 121.0 / 255.0,
        blue: 129.0 / 255.0
    )
    static let topbarModeSelectedColor = Color(
        red: 45.0 / 255.0,
        green: 47.0 / 255.0,
        blue: 54.0 / 255.0
    )
    static let topbarModeHoverBackground = Color(
        red: 240.0 / 255.0,
        green: 240.0 / 255.0,
        blue: 242.0 / 255.0
    )
    static let topbarModeActiveBackground = Color(
        red: 217.0 / 255.0,
        green: 218.0 / 255.0,
        blue: 222.0 / 255.0
    )
    static let topbarModeActiveHoverBackground = Color(
        red: 210.0 / 255.0,
        green: 211.0 / 255.0,
        blue: 216.0 / 255.0
    )
    static let topbarSearchBorderColor = Color(
        red: 200.0 / 255.0,
        green: 200.0 / 255.0,
        blue: 204.0 / 255.0
    )
    static let topbarSearchFocusedBorderColor = Color(
        red: 170.0 / 255.0,
        green: 171.0 / 255.0,
        blue: 178.0 / 255.0
    )
    static let topbarSearchIconColor = Color(
        red: 154.0 / 255.0,
        green: 155.0 / 255.0,
        blue: 161.0 / 255.0
    )
}
