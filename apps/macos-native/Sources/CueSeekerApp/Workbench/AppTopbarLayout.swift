import AppKit
import SwiftUI

struct AppTopbarLayout<
    Content: View,
    TrailingContent: View,
    SidebarToggle: View,
    CenterContent: View
>: View {
    let isSidebarVisible: Bool
    let isAppFullscreen: Bool
    /// How far the page below is scrolled sideways. The function region is the
    /// page's own row, so it travels with the page.
    let pageScrollOffset: CGFloat
    let onDoubleClickZoom: (NSWindow) -> Bool
    @ViewBuilder let content: () -> Content
    /// The trailing function region. It holds what belongs to the App rather
    /// than to the page below, so it is the same in every workbench page.
    @ViewBuilder let trailingContent: () -> TrailingContent
    @ViewBuilder let centerContent: () -> CenterContent
    @ViewBuilder let sidebarToggle: () -> SidebarToggle

    init(
        isSidebarVisible: Bool,
        isAppFullscreen: Bool,
        pageScrollOffset: CGFloat,
        onDoubleClickZoom: @escaping (NSWindow) -> Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent,
        @ViewBuilder centerContent: @escaping () -> CenterContent,
        @ViewBuilder sidebarToggle: @escaping () -> SidebarToggle
    ) {
        self.isSidebarVisible = isSidebarVisible
        self.isAppFullscreen = isAppFullscreen
        self.pageScrollOffset = pageScrollOffset
        self.onDoubleClickZoom = onDoubleClickZoom
        self.content = content
        self.trailingContent = trailingContent
        self.centerContent = centerContent
        self.sidebarToggle = sidebarToggle
    }

    var body: some View {
        TitlebarBackgroundView(
            backgroundColor: WorkbenchRedesignColors.NS.appTopbarBg,
            onDoubleClickZoom: onDoubleClickZoom
        )
        .overlay(alignment: .leading) {
            if isSidebarVisible {
                WorkbenchRedesignColors.appSidebarBg
                    .frame(width: AppShellLayout.sidebarWidth)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            functionRegion
        }
        .overlay(alignment: .leading) {
            leadingControls
        }
        .frame(height: WorkbenchControlMetrics.redesignWorkbenchTopbarHeight)
        .simultaneousGesture(
            TapGesture().onEnded {
                NotificationCenter.default.post(name: .topbarDismissMenusRequested, object: nil)
            }
        )
        .background(LayoutPerformanceProbe(name: "AppTopbarLayout.layout"))
    }

    /// One row for the function region and the trailing function region: they
    /// share the page's content minimum width, so the title yields to the
    /// buttons instead of running under them, and below that width the whole
    /// row travels with the page rather than staying pinned to the window.
    private var functionRegion: some View {
        GeometryReader { proxy in
            let regionWidth = max(0, proxy.size.width - regionLeadingEdge)
            let rowWidth = max(regionWidth, AppShellLayout.pageContentMinimumWidth)
            let offset = min(max(0, pageScrollOffset), rowWidth - regionWidth)

            ZStack {
                HStack(spacing: 0) {
                    content()

                    Spacer(minLength: WorkbenchControlMetrics.redesignAppTopbarContentAfterToggleGap)

                    trailingContent()
                }
                .padding(.leading, rowLeadingInset)
                .padding(.trailing, WorkbenchControlMetrics.redesignAppTopbarContentTrailingPadding)

                centerContent()
            }
            .frame(width: rowWidth, height: proxy.size.height)
            .offset(x: -offset)
            .frame(width: regionWidth, height: proxy.size.height, alignment: .leading)
            .clipped()
            .offset(x: regionLeadingEdge)
        }
    }

    private var leadingControls: some View {
        GeometryReader { _ in
            sidebarToggle()
                .frame(
                    width: AppShellLayout.sidebarToggleSize,
                    height: AppShellLayout.sidebarToggleSize
                )
                // On the window controls' centre line, not the taller bar's.
                .offset(
                    x: sidebarToggleHandleX,
                    y: (WorkbenchControlMetrics.redesignWindowControlsBandHeight - AppShellLayout.sidebarToggleSize) / 2
                )
        }
        .frame(height: WorkbenchControlMetrics.redesignWorkbenchTopbarHeight)
        .clipped()
    }

    /// Where the scrolling row starts: after the sidebar segment, which stays
    /// put, or at the window's leading edge when the sidebar is collapsed.
    private var regionLeadingEdge: CGFloat {
        isSidebarVisible ? AppShellLayout.sidebarWidth : 0
    }

    private var rowLeadingInset: CGFloat {
        if isSidebarVisible {
            return WorkbenchControlMetrics.redesignAppTopbarContentHorizontalPadding
        }

        return max(
            WorkbenchControlMetrics.redesignAppTopbarContentHorizontalPadding,
            sidebarToggleHandleX
                + AppShellLayout.sidebarToggleSize
                + WorkbenchControlMetrics.redesignAppTopbarContentAfterToggleGap
        )
    }

    private var sidebarToggleHandleX: CGFloat {
        let collapsedX = isAppFullscreen
            ? AppShellLayout.modeControlsOuterPadding
            : AppShellLayout.collapsedLeadingToggleX

        guard isSidebarVisible else {
            return collapsedX
        }

        return max(
            collapsedX,
            AppShellLayout.sidebarWidth
                - AppShellLayout.modeControlsOuterPadding
                - AppShellLayout.sidebarToggleSize
        )
    }
}
