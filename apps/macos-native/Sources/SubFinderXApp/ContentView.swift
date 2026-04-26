import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    private let sidebarWidth: CGFloat = 220
    private let topBarHeight: CGFloat = 56
    private let collapsedContentInset: CGFloat = 104
    private let animation = Animation.easeInOut(duration: 0.22)

    private let windowBackground = Color(
        red: 0.955,
        green: 0.955,
        blue: 0.95
    )
    private let sidebarBackground = Color(
        red: 0.942,
        green: 0.942,
        blue: 0.936
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
                if appState.isSidebarVisible {
                    sidebar
                        .frame(width: sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(2)
                }

                selectedSectionView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, topBarHeight)
                    .padding(.leading, appState.isSidebarVisible ? 0 : collapsedContentInset)
                    .animation(animation, value: appState.isSidebarVisible)
            }
            .animation(animation, value: appState.isSidebarVisible)

            titleBarBackground
                .frame(height: topBarHeight)
                .zIndex(3)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 860, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
                .frame(height: topBarHeight)

            ForEach(AppSection.allCases) { section in
                Button {
                    appState.selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            appState.selectedSection == section
                                ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.16)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private var titleBarBackground: some View {
        topBarBackground
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 1)
        }
    }

    @ViewBuilder
    private var selectedSectionView: some View {
        switch appState.selectedSection {
        case .search:
            SearchView()
        case .settings:
            SettingsView()
        }
    }
}
