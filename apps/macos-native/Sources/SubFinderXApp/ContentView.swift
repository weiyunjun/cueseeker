import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

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
                        .frame(width: AppShellLayout.sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(2)
                }

                selectedSectionView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, AppShellLayout.topBarHeight)
            }
            .animation(animation, value: appState.isSidebarVisible)

            appTopBar
                .frame(height: AppShellLayout.topBarHeight)
                .zIndex(3)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: AppShellLayout.minimumWindowWidth, minHeight: AppShellLayout.minimumWindowHeight)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(AppSection.allCases) { section in
                Button {
                    appState.selectSection(section)
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            appState.selectedSection == section
                                ? Color.accentColor
                                : Color.clear
                        )
                        .foregroundStyle(
                            appState.selectedSection == section ? .white : .primary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            Spacer()
        }
        .padding(.top, AppShellLayout.topBarHeight + AppShellLayout.contentTopPadding)
        .padding(.horizontal, 12)
        .background(sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private var appTopBar: some View {
        TitlebarBackgroundView(backgroundColor: topBarBackground)
            .overlay {
                Text(appState.selectedSection.title)
                    .font(.system(
                        size: AppShellLayout.titleFontSize,
                        weight: AppShellLayout.titleFontWeight
                    ))
                    .foregroundStyle(.primary)
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
        sidebarToggle
            .padding(
                .leading,
                AppShellLayout.windowControlsReservedWidth
                    + AppShellLayout.toggleLeadingAfterWindowControls
            )
            .frame(height: AppShellLayout.topBarHeight)
    }

    @ViewBuilder
    private var topBarTrailingControls: some View {
        if appState.selectedSection == .search {
            playbackInspectorToggle
                .padding(.trailing, AppShellLayout.toggleTrailing)
                .frame(height: AppShellLayout.topBarHeight)
        }
    }

    private var sidebarToggle: some View {
        Button {
            appState.toggleSidebar()
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: AppShellLayout.toggleIconSize, weight: .medium))
                .frame(
                    width: AppShellLayout.toggleSize,
                    height: AppShellLayout.toggleSize
                )
                .contentShape(Rectangle())
                .hoverBackground(cornerRadius: 6)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .foregroundStyle(.primary)
        .help(appState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
        .frame(
            width: AppShellLayout.toggleSize,
            height: AppShellLayout.toggleSize
        )
    }

    private var playbackInspectorToggle: some View {
        Button {
            appState.togglePlaybackInspector()
        } label: {
            Image(systemName: "sidebar.right")
                .font(.system(size: AppShellLayout.toggleIconSize, weight: .medium))
                .frame(
                    width: AppShellLayout.toggleSize,
                    height: AppShellLayout.toggleSize
                )
                .contentShape(Rectangle())
                .hoverBackground(cornerRadius: 6)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .foregroundStyle(.primary)
        .help(appState.isPlaybackInspectorVisible ? "Hide Playback Inspector" : "Show Playback Inspector")
        .frame(
            width: AppShellLayout.toggleSize,
            height: AppShellLayout.toggleSize
        )
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

enum AppShellLayout {
    static let contentTopPadding: CGFloat = 16
    static let minimumWindowWidth: CGFloat = 1_040
    static let minimumWindowHeight: CGFloat = 560
    static let topBarHeight: CGFloat = 45
    static let sidebarWidth: CGFloat = 154
    static let windowControlsReservedWidth: CGFloat = 80
    static let toggleLeadingAfterWindowControls: CGFloat = 18
    static let toggleTrailing: CGFloat = 16
    static let toggleSize: CGFloat = 28
    static let toggleIconSize: CGFloat = 15
    static let titleFontSize: CGFloat = 16
    static let titleFontWeight: Font.Weight = .semibold
    static let topBarSeparatorOpacity = 0.12
}
