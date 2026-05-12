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
    @State private var searchDraft = ""
    @State private var isSearchFocused = false

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
                TopbarSearchField(
                    text: $searchDraft,
                    isFocused: $isSearchFocused,
                    onSubmit: {
                        appState.submitTopbarSearch(searchDraft)
                        isSearchFocused = false
                    }
                )
                .frame(width: AppShellLayout.topbarSearchFieldWidth)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(AppShellLayout.topBarSeparatorOpacity))
                    .frame(height: 1)
            }
            .onAppear {
                searchDraft = appState.searchQuery
            }
            .onChange(of: appState.searchQuery) { query in
                if !isSearchFocused {
                    searchDraft = query
                }
            }
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
    static let topBarSeparatorOpacity = 0.12
    static let topbarSearchFieldWidth: CGFloat = 320
    static let topbarSearchTrailingPadding: CGFloat = 20
}
