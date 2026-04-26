import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSidebarVisible = true

    private let sidebarWidth: CGFloat = 220
    private let topBarHeight: CGFloat = 64
    private let collapsedToggleX: CGFloat = 84

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

            topBar

            sidebarToggle
                .position(
                    x: isSidebarVisible ? sidebarWidth : collapsedToggleX,
                    y: topBarHeight / 2
                )
                .animation(.easeInOut(duration: 0.22), value: isSidebarVisible)
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
                                ? Color.accentColor.opacity(0.16)
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
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var topBar: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            Text(appState.selectedSection.title)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(height: topBarHeight)
        .frame(maxWidth: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var sidebarToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isSidebarVisible.toggle()
            }
        } label: {
            Image(systemName: isSidebarVisible ? "sidebar.left" : "sidebar.right")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
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
