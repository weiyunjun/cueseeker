import AppKit
import SwiftUI

struct AppTopbarLayout<Content: View, SidebarToggle: View>: View {
    let isSidebarVisible: Bool
    let isAppFullscreen: Bool
    let onDoubleClickZoom: (NSWindow) -> Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let sidebarToggle: () -> SidebarToggle

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
        .overlay(alignment: .leading) {
            content()
                .padding(.leading, contentLeadingInset)
                .padding(.trailing, WorkbenchControlMetrics.redesignAppTopbarContentHorizontalPadding)
        }
        .overlay(alignment: .leading) {
            leadingControls
        }
        .frame(height: WorkbenchControlMetrics.redesignAppTopbarHeight)
        .simultaneousGesture(
            TapGesture().onEnded {
                NotificationCenter.default.post(name: .topbarDismissMenusRequested, object: nil)
            }
        )
        .background(LayoutPerformanceProbe(name: "AppTopbarLayout.layout"))
    }

    private var leadingControls: some View {
        GeometryReader { _ in
            sidebarToggle()
                .frame(
                    width: AppShellLayout.sidebarToggleSize,
                    height: AppShellLayout.sidebarToggleSize
                )
                .offset(
                    x: sidebarToggleHandleX,
                    y: (WorkbenchControlMetrics.redesignAppTopbarHeight - AppShellLayout.sidebarToggleSize) / 2
                )
        }
        .frame(height: WorkbenchControlMetrics.redesignAppTopbarHeight)
        .clipped()
    }

    private var contentLeadingInset: CGFloat {
        if isSidebarVisible {
            return AppShellLayout.sidebarWidth + WorkbenchControlMetrics.redesignAppTopbarContentHorizontalPadding
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
