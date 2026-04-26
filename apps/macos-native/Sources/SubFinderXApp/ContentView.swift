import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSidebarVisible = true

    private let sidebarWidth: CGFloat = 220
    private let topBarHeight: CGFloat = 54
    private let titleBarControlY: CGFloat = 25
    private let collapsedToggleX: CGFloat = 118
    private let titleLeadingGap: CGFloat = 22

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                if isSidebarVisible {
                    sidebar
                        .frame(width: sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Divider()
                }

                selectedSectionView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, topBarHeight)
            }
            .animation(.easeInOut(duration: 0.22), value: isSidebarVisible)

            titleBar
        }
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
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var titleBar: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)

            sidebarToggle
                .position(
                    x: isSidebarVisible ? sidebarWidth - 25 : collapsedToggleX,
                    y: titleBarControlY
                )
                .animation(.easeInOut(duration: 0.22), value: isSidebarVisible)

            Text(appState.selectedSection.title)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
                .position(
                    x: titleX,
                    y: titleBarControlY
                )
                .animation(.easeInOut(duration: 0.22), value: isSidebarVisible)
        }
        .frame(height: topBarHeight)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var titleX: CGFloat {
        (isSidebarVisible ? sidebarWidth - 25 : collapsedToggleX) + titleLeadingGap + 36
    }

    private var sidebarToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
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
