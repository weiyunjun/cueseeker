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
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(AppShellLayout.topBarSeparatorOpacity))
                    .frame(height: 1)
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
}
