import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

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

                TopbarCommandBridge()
                    .frame(width: 0, height: 0)
            }
            .ignoresSafeArea(.container, edges: .top)
            .frame(minWidth: AppShellLayout.minimumWindowWidth, minHeight: AppShellLayout.minimumWindowHeight)
            .preferredColorScheme(appState.appAppearanceMode.colorScheme)
            .background(LayoutPerformanceProbe(name: "ContentView.layout"))
        }
    }

    @ViewBuilder
    private var mainWorkspace: some View {
        SearchView()
    }
}

private struct AppTopBar: View {
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
                NotificationCenter.default.post(name: .topbarTitlebarZoomRequested, object: window)
                return true
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

                    TopbarSearchInputHost()
                    .frame(width: AppShellLayout.topbarSearchFieldWidth)
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    NotificationCenter.default.post(name: .topbarDismissMenusRequested, object: nil)
                }
            )
    }
}

private struct TopbarCommandBridge: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var layoutState: WorkbenchLayoutState

    var body: some View {
        Color.clear
            .onReceive(NotificationCenter.default.publisher(for: .topbarSearchSubmitted)) { notification in
                guard let query = notification.object as? String else {
                    return
                }

                appState.submitTopbarSearch(query)
            }
            .onReceive(NotificationCenter.default.publisher(for: .topbarSearchFocusChanged)) { notification in
                guard let isFocused = notification.object as? Bool else {
                    return
                }

                appState.isSearchFocused = isFocused
                if isFocused, layoutState.panelMode != .search {
                    appState.activateWorkbenchPanelMode(.search)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .topbarDismissMenusRequested)) { _ in
                appState.dismissBottomPlaybackMenu()
            }
            .onReceive(NotificationCenter.default.publisher(for: .topbarTitlebarZoomRequested)) { notification in
                guard let window = notification.object as? NSWindow else {
                    return
                }

                _ = appState.beginTitlebarZoomTransitionFromUser(window: window)
            }
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

private struct TopbarSearchInputHost: View {
    @StateObject private var inputState = TopbarSearchInputState()

    var body: some View {
        UIInvalidationProbe.count("UI.TopbarSearchInput.body")

        return TopbarSearchField(inputState: inputState)
            .onChange(of: inputState.isFocused) { isFocused in
                NotificationCenter.default.post(name: .topbarSearchFocusChanged, object: isFocused)
            }
            .onReceive(NotificationCenter.default.publisher(for: .topbarSearchFocusClearRequested)) { _ in
                inputState.requestFocus(false)
            }
    }
}

private struct TopbarSearchField: View {
    @ObservedObject var inputState: TopbarSearchInputState
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppShellLayout.topbarSearchIconColor)

            SearchTextView(
                text: $inputState.draft,
                placeholder: "Search subtitles",
                isFocused: $inputState.isFocused,
                forcedTextUpdateID: inputState.forcedTextUpdateID,
                onSubmit: {
                    inputState.submit()
                }
            )
            .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)

            if !inputState.draft.isEmpty {
                Button {
                    inputState.clearDraft()
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
                    topbarSearchBorderColor,
                    lineWidth: inputState.isFocused ? 3 : 1.5
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            inputState.requestFocus(true)
        }
    }

    private var topbarSearchBorderColor: Color {
        if inputState.isFocused {
            return AppShellLayout.topbarSearchBorderColor
        }
        if isHovered {
            return AppShellLayout.topbarSearchHoverBorderColor
        }
        return AppShellLayout.topbarSearchBorderColor
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
    static let topbarSearchFieldHeight: CGFloat = 36
    static let topbarSearchFieldCornerRadius: CGFloat = 12
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
        red: 184.0 / 255.0,
        green: 185.0 / 255.0,
        blue: 191.0 / 255.0
    )
    static let topbarSearchHoverBorderColor = Color(
        red: 158.0 / 255.0,
        green: 159.0 / 255.0,
        blue: 166.0 / 255.0
    )
    static let topbarSearchIconColor = Color(
        red: 154.0 / 255.0,
        green: 155.0 / 255.0,
        blue: 161.0 / 255.0
    )
}
