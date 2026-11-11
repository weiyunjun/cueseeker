import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func workbenchEmptyHintPassesMouseHitTestingToUnderlyingTableSurface() {
    let probe = WorkbenchEmptyHintHitProbeView()
    let hostingView = NSHostingView(
        rootView: ZStack {
            WorkbenchEmptyHintHitProbe(probe: probe)
            WorkbenchEmptyHint(icon: .searchHint, message: "No rows")
        }
        .frame(width: 320, height: 200)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 320, height: 200)

    let window = NSWindow(
        contentRect: hostingView.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    hostingView.layoutSubtreeIfNeeded()

    #expect(hostingView.hitTest(CGPoint(x: 160, y: 100)) === probe)
}

@MainActor
@Test
func workbenchEmptyHintAndDuotoneIconsMatchDesignMetrics() {
    #expect(AppEmptyStateIcon.allCases.count == 13)
    #expect(AppEmptyStateIcon.allCases.contains(.folderHint))
    #expect(WorkbenchControlMetrics.redesignEmptyStateIconSize == 68)
    #expect(WorkbenchControlMetrics.redesignEmptyStateIconToTextGap == 14)

    #expect(WorkbenchControlMetrics.redesignEmptyIconSearchCardOpacity == 0.30)
    #expect(WorkbenchControlMetrics.redesignEmptyIconCollageBackOpacity == 0.52)
    #expect(WorkbenchControlMetrics.redesignEmptyIconSearchLineOpacity == 0.58)
    #expect(WorkbenchControlMetrics.redesignEmptyIconMagnifierFillOpacity == 0.22)
    #expect(WorkbenchControlMetrics.redesignEmptyIconBadgeFillOpacity == 0.24)
    #expect(WorkbenchControlMetrics.redesignEmptyIconBaseOpacity == 0.32)
    #expect(WorkbenchControlMetrics.redesignEmptyIconMidOpacity == 0.52)
    #expect(WorkbenchControlMetrics.redesignEmptyIconForegroundOpacity == 1.0)
    #expect(AppEmptyStateIconMetrics.searchCardOpacity == 0.30)
    #expect(AppEmptyStateIconMetrics.collageBackOpacity == 0.52)
    #expect(AppEmptyStateIconMetrics.searchLineOpacity == 0.58)
    #expect(AppEmptyStateIconMetrics.magnifierFillOpacity == 0.22)
    #expect(AppEmptyStateIconMetrics.badgeFillOpacity == 0.24)
    #expect(AppEmptyStateIconMetrics.baseOpacity == 0.32)
    #expect(AppEmptyStateIconMetrics.midOpacity == 0.52)
    #expect(AppEmptyStateIconMetrics.foregroundOpacity == 1.0)

    if let lightAppearance = NSAppearance(named: .aqua) {
        lightAppearance.performAsCurrentDrawingAppearance {
            let fg = WorkbenchRedesignColors.NS.emptyIconForeground.usingColorSpace(.sRGB)
            let base = WorkbenchRedesignColors.NS.emptyIconBase.usingColorSpace(.sRGB)
            #expect(fg != nil)
            #expect(base != nil)
            if let fg, let base {
                #expect(abs(fg.redComponent - 113.0 / 255.0) < 0.01)
                #expect(abs(fg.greenComponent - 113.0 / 255.0) < 0.01)
                #expect(abs(fg.blueComponent - 113.0 / 255.0) < 0.01)
                #expect(abs(fg.alphaComponent - 1.0) < 0.01)
                #expect(abs(base.alphaComponent - 0.32) < 0.01)
            }
        }
    }

    if let darkAppearance = NSAppearance(named: .darkAqua) {
        darkAppearance.performAsCurrentDrawingAppearance {
            let fg = WorkbenchRedesignColors.NS.emptyIconForeground.usingColorSpace(.sRGB)
            let mid = WorkbenchRedesignColors.NS.emptyIconMid.usingColorSpace(.sRGB)
            #expect(fg != nil)
            #expect(mid != nil)
            if let fg, let mid {
                #expect(abs(fg.redComponent - 151.0 / 255.0) < 0.01)
                #expect(abs(fg.greenComponent - 151.0 / 255.0) < 0.01)
                #expect(abs(fg.blueComponent - 151.0 / 255.0) < 0.01)
                #expect(abs(fg.alphaComponent - 1.0) < 0.01)
                #expect(abs(mid.alphaComponent - 0.52) < 0.01)
            }
        }
    }

    for icon in AppEmptyStateIcon.allCases {
        let iconHostingView = NSHostingView(
            rootView: AppEmptyStateIconView(icon: icon)
        )
        iconHostingView.layoutSubtreeIfNeeded()
        #expect(iconHostingView.fittingSize.width == 68)
        #expect(iconHostingView.fittingSize.height == 68)

        let hintHostingView = NSHostingView(
            rootView: WorkbenchEmptyHint(
                icon: icon,
                message: "Empty state message for \(icon.rawValue)"
            )
            .frame(width: 480, height: 320)
        )
        hintHostingView.layoutSubtreeIfNeeded()
        #expect(hintHostingView.fittingSize == CGSize(width: 480, height: 320))
    }

    // Long single-sentence empty-state hints expand to container width instead of wrapping at 380px.
    let longMessage = "Save cues from search results or playback to collect excerpts."
    let wideHost = NSHostingView(
        rootView: WorkbenchEmptyHint(icon: .excerpt, message: longMessage)
            .fixedSize()
    )
    wideHost.layoutSubtreeIfNeeded()
    #expect(wideHost.fittingSize.width > 380)
    #expect(wideHost.fittingSize.height <= 68 + 14 + 24)
}

@MainActor
private final class WorkbenchEmptyHintHitProbeView: NSView {}

private struct WorkbenchEmptyHintHitProbe: NSViewRepresentable {
    let probe: WorkbenchEmptyHintHitProbeView

    func makeNSView(context _: Context) -> WorkbenchEmptyHintHitProbeView {
        probe
    }

    func updateNSView(_ nsView: WorkbenchEmptyHintHitProbeView, context _: Context) {}
}

@MainActor
@Test
func subtitleTableViewHidesHeaderWhenShowsHeaderIsFalse() throws {
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test",
        probeSurface: .search,
        rowCount: 0,
        rowProvider: { _ in nil },
        rowsVersion: 0,
        dateAddedHeader: "Date",
        displayTitleHeader: "Title",
        timeHeader: "Time",
        cuesHeader: "Cues",
        languageHeader: "Lang",
        columnOrder: ["rowNumber", "cues", "display", "time"],
        showsDateAddedColumn: false,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        showsCueGroup: false,
        scrollResetToken: 0,
        scrollTargetRow: nil,
        onVisibleRowsChange: { _ in },
        isSelectionMode: false,
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onShiftRowSelection: { _ in },
        onToggleAllSelection: {},
        selectionOverlayAnchor: nil,
        allResultsTextCopyRowCount: 0,
        loadRowsForTextCopy: nil,
        onPlay: { _ in },
        onOpenSubtitleFile: { _ in },
        rowActionMenuStyle: .search,
        rowActionDestinations: [],
        onSaveExcerpt: { _, _ in },
        onMoveExcerpt: { _, _ in },
        onDuplicateExcerpt: { _, _ in },
        onCreateExcerptList: { _, _ in },
        onRemoveExcerpt: { _ in },
        isCueInLibrary: nil,
        onToast: nil
    )

    let container = SubtitleTableContainerView()
    container.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
    let header = SubtitleVirtualTableHeaderView()
    header.frame = CGRect(x: 0, y: 0, width: 800, height: 40)
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    let documentView = SubtitleVirtualTableDocumentView()
    let viewport = SubtitleTablePageChromeViewportView()

    coordinator.attach(
        container: container,
        headerView: header,
        scrollView: scrollView,
        pageScrollbar: nil,
        documentView: documentView,
        pageChromeViewport: viewport
    )
    coordinator.updatePageChrome(SubtitleTablePageChrome(
        scrollableHeader: AnyView(Color.clear),
        pinnedHeader: AnyView(Color.clear),
        scrollableHeaderHeight: { _ in 200 },
        pinnedHeaderHeight: 80,
        leadingInset: 32,
        trailingInset: 32,
        bottomInset: 0
    ))

    // Default: showsHeader is true
    #expect(coordinator.showsHeader == true)
    #expect(coordinator.currentHeaderHeight == WorkbenchControlMetrics.redesignTableHeaderHeight)
    #expect(header.isHidden == false)
    var frames = try #require(coordinator.pageChromeFramesForTesting())
    #expect(frames.tableHeader.height == WorkbenchControlMetrics.redesignTableHeaderHeight)

    // Set showsHeader to false
    coordinator.showsHeader = false
    #expect(coordinator.showsHeader == false)
    #expect(coordinator.currentHeaderHeight == 0)
    #expect(header.isHidden == true)
    frames = try #require(coordinator.pageChromeFramesForTesting())
    #expect(frames.tableHeader.height == 0)

    // Restore showsHeader to true
    coordinator.showsHeader = true
    #expect(coordinator.showsHeader == true)
    #expect(coordinator.currentHeaderHeight == WorkbenchControlMetrics.redesignTableHeaderHeight)
    #expect(header.isHidden == false)
    frames = try #require(coordinator.pageChromeFramesForTesting())
    #expect(frames.tableHeader.height == WorkbenchControlMetrics.redesignTableHeaderHeight)
}

@Test
func emptyStateLocalizationMatchesRequirements() {
    let languages: [(AppLanguage, [String: String])] = [
        (.english, [
            "table.search_empty_hint": "Enter a search term to show cues.",
            "table.search_no_results": "No matching cues found.",
            "excerpt.table.empty_hint": "Save cues from search results or playback to collect excerpts.",
            "excerpt.table.no_results": "No matching excerpts found.",
            "excerpt.overview.empty_hint": "Create an excerpt list to collect excerpts.",
            "playback.hud.no_available_excerpts": "No Available Excerpts",
            "file.empty.message": "Add a folder containing video and subtitle files.",
            "onboarding.no_folder.message": "Add a folder to get started.",
            "onboarding.no_folder.go_to_file": "Go to File"
        ]),
        (.simplifiedChinese, [
            "table.search_empty_hint": "输入搜索词以显示台词。",
            "table.search_no_results": "未找到匹配的台词。",
            "excerpt.table.empty_hint": "从搜索结果中或在播放时保存台词，即可收集摘录。",
            "excerpt.table.no_results": "未找到匹配的摘录。",
            "excerpt.overview.empty_hint": "创建摘录集以收集摘录。",
            "playback.hud.no_available_excerpts": "没有可用的摘录",
            "file.empty.message": "添加包含视频与字幕文件的文件夹。",
            "onboarding.no_folder.message": "添加文件夹以开始使用。",
            "onboarding.no_folder.go_to_file": "前往文件"
        ]),
        (.traditionalChinese, [
            "table.search_empty_hint": "輸入搜尋字詞以顯示台詞。",
            "table.search_no_results": "未找到相符的台詞。",
            "excerpt.table.empty_hint": "從搜尋結果中或在播放時儲存台詞，即可收集摘錄。",
            "excerpt.table.no_results": "未找到相符的摘錄。",
            "excerpt.overview.empty_hint": "建立摘錄集以收集摘錄。",
            "playback.hud.no_available_excerpts": "沒有可用的摘錄",
            "file.empty.message": "加入包含影片與字幕檔案的資料夾。",
            "onboarding.no_folder.message": "加入資料夾以開始使用。",
            "onboarding.no_folder.go_to_file": "前往檔案"
        ])
    ]

    for (language, expected) in languages {
        let bundle = AppLocalization._bundleForTesting(language)
        guard let path = bundle.path(forResource: "Localizable", ofType: "strings"),
              let entries = NSDictionary(contentsOfFile: path) as? [String: String]
        else {
            Issue.record("Missing localization bundle for \(language)")
            continue
        }
        #expect(entries["settings.library.empty_title"] == nil)
        #expect(entries["settings.library.empty_message"] == nil)
        #expect(entries["file.onboarding.back"] == nil)
        #expect(entries["file.onboarding.next"] == nil)
        #expect(entries["file.onboarding.done"] == nil)
        #expect(entries["file.empty.view_tutorial"] == nil)
        for (key, expectedValue) in expected {
            #expect(entries[key] == expectedValue, "Key \(key) does not match in \(language)")
        }
    }
}

@Test
func workbenchSearchShowsTableHeaderRequiresNonEmptyRowsAndNonEmptyQuery() {
    // When query is empty (showsSearchEmptyHint is true), header is hidden regardless of rowCount
    #expect(workbenchSearchShowsTableHeader(showsSearchEmptyHint: true, rowCount: 0) == false)
    #expect(workbenchSearchShowsTableHeader(showsSearchEmptyHint: true, rowCount: 10) == false)

    // When query is entered but rowCount is 0 (searching / debounce / 0 results), header must NOT show
    // This prevents the table header from flashing during debounce/search
    #expect(workbenchSearchShowsTableHeader(showsSearchEmptyHint: false, rowCount: 0) == false)

    // Only when query is non-empty and actual rows exist (> 0), header is shown
    #expect(workbenchSearchShowsTableHeader(showsSearchEmptyHint: false, rowCount: 1) == true)
    #expect(workbenchSearchShowsTableHeader(showsSearchEmptyHint: false, rowCount: 50) == true)
}
