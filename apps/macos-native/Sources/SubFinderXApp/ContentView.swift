import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSidebarVisible = true

    private let sidebarWidth: CGFloat = 220
    private let topBarHeight: CGFloat = 56
    private let titleBarControlY: CGFloat = 28
    private let expandedToggleTrailing: CGFloat = 24
    private let collapsedToggleX: CGFloat = 96
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

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                windowBackground
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    if isSidebarVisible {
                        sidebar
                            .frame(width: sidebarWidth)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            .zIndex(2)
                    }

                    selectedSectionView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, topBarHeight)
                        .padding(.leading, isSidebarVisible ? 0 : collapsedContentInset)
                        .animation(animation, value: isSidebarVisible)
                }
                .animation(animation, value: isSidebarVisible)

                titleBar(width: geometry.size.width)
            }
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
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 5, y: 0)
    }

    private func titleBar(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            titleBarBackground

            sidebarToggle
                .position(
                    x: toggleX,
                    y: titleBarControlY
                )
                .animation(animation, value: isSidebarVisible)

            Text(appState.selectedSection.title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .position(
                    x: titleX(totalWidth: width),
                    y: titleBarControlY
                )
                .animation(animation, value: isSidebarVisible)
        }
        .frame(height: topBarHeight)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var titleBarBackground: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebarBackground
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            windowBackground
        }
    }

    private var toggleX: CGFloat {
        isSidebarVisible ? sidebarWidth - expandedToggleTrailing : collapsedToggleX
    }

    private func titleX(totalWidth: CGFloat) -> CGFloat {
        let mainLeading = isSidebarVisible ? sidebarWidth : 0
        return mainLeading + max(0, totalWidth - mainLeading) / 2
    }

    private var sidebarToggle: some View {
        Button {
            withAnimation(animation) {
                isSidebarVisible.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
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
