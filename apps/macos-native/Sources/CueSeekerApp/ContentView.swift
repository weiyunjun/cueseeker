import SwiftUI

struct ContentView: View {
    private let windowBackground = Color(
        red: 0.955,
        green: 0.955,
        blue: 0.95
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

                AppTopBar(backgroundColor: windowBackground)
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
                HStack(spacing: 10) {
                    TopbarModeButton(
                        mode: .library,
                        systemImage: "folder",
                        selectedSystemImage: "folder.fill",
                        help: "Library"
                    )

                    TopbarModeButton(
                        mode: .shiori,
                        systemImage: "bookmark",
                        selectedSystemImage: "bookmark.fill",
                        help: "Shiori"
                    )

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
    let selectedSystemImage: String
    let help: String

    var body: some View {
        let isSelected = layoutState.panelMode == mode

        Button {
            appState.performUserInitiatedAppCommand {
                appState.activateWorkbenchPanelMode(mode)
            }
        } label: {
            Image(systemName: isSelected ? selectedSystemImage : systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(TopbarModeButtonStyle(isSelected: isSelected))
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
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
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundColor(configuration: configuration))
            )
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if configuration.isPressed {
            return Color.primary.opacity(0.14)
        }
        if isSelected {
            return Color.primary.opacity(0.12)
        }
        if isHovered {
            return Color.primary.opacity(0.07)
        }
        return .clear
    }
}

private struct TopbarSearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            SearchTextView(
                text: $text,
                placeholder: "Search subtitles",
                isFocused: $isFocused,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isFocused ? Color.accentColor : Color.primary.opacity(0.10),
                    lineWidth: isFocused ? 1.5 : 1
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
}
