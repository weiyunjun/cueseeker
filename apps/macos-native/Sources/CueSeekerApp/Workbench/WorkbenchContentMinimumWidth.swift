import CoreGraphics

/// Minimum width of the Workbench content region.
///
/// A page that renders a table must still show every column at its minimum
/// width; a page without a table falls back to the App minimum window width
/// with the sidebar collapsed. Opening the sidebar adds its width to the
/// window minimum instead of shrinking the content region.
enum WorkbenchContentMinimumWidth {
    static func contentWidth(
        panelMode: WorkbenchPanelMode,
        isShioriListDetail: Bool
    ) -> CGFloat {
        switch panelMode {
        case .search, .library:
            return tableContentWidth(showsDateAddedColumn: false)
        case .shiori:
            return isShioriListDetail
                ? tableContentWidth(showsDateAddedColumn: true)
                : AppShellLayout.minimumWindowWidth
        case .recentWatching, .testLibrary, .data:
            return AppShellLayout.minimumWindowWidth
        }
    }

    static func windowWidth(
        panelMode: WorkbenchPanelMode,
        isShioriListDetail: Bool,
        isSidebarVisible: Bool
    ) -> CGFloat {
        contentWidth(
            panelMode: panelMode,
            isShioriListDetail: isShioriListDetail
        ) + (isSidebarVisible ? AppShellLayout.sidebarWidth : 0)
    }

    private static func tableContentWidth(showsDateAddedColumn: Bool) -> CGFloat {
        SubtitleTableColumnLayout.minimumContentWidth(
            showsDateAddedColumn: showsDateAddedColumn,
            showsDisplayTitleColumn: true,
            showsTimeColumn: true,
            showsLanguageColumn: false,
            cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth
        ) + 2 * WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
    }
}
