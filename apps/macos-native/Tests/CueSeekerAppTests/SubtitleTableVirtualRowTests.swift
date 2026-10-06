import AppKit
import CoreGraphics
import SwiftUI
import Testing
@testable import CueSeekerApp

private let subtitleTableForbiddenRefreshScopeCounters = SubtitleTableProbeSurface.allCases.flatMap { surface in
    [
        surface.counterName("snapshot_rebuild"),
        surface.counterName("row_hydration_requested"),
        surface.counterName("row_hydration_applied"),
    ]
} + [
    "UI.SearchPresentation.rebuilt",
    "UI.ExcerptPresentation.rebuilt",
    "UI.Workbench.body",
    "UI.ContentView.body",
    "UI.AppTopBar.body",
    "UI.AppSidebar.body",
    "UI.PlaybackPage.body",
    "playback.subtitle_focus.cue_measurement",
    "playback.subtitle_focus.native_update",
    "playback.subtitle_focus.layout_update",
    "playback.subtitle_focus.cue_draw",
    "library.snapshot_rebuild",
    "playback.render_host_update",
    "playback.high_frequency_chrome_update",
]

@MainActor
@Test
func subtitleTableViewUsesVirtualRowCountWithoutMaterializingModels() {
    let loadedRow = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode 01",
        startTime: "01:15:32",
        endTime: "01:16:04",
        cues: "loaded cue",
        tags: [
            WorkbenchTag(key: "zh-hans"),
            WorkbenchTag(key: "jp"),
        ]
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 2_000_000,
        rowProvider: { index in
            index == 0 ? loadedRow : nil
        },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsTimeColumn: true,
        showsLanguageColumn: true,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )

    #expect(coordinator.numberOfRowsForTesting() == 2_000_000)
    #expect(coordinator.cellFullText(row: -1, column: 1) == "Display Title")
    #expect(coordinator.cellFullText(row: -1, column: 2) == "Cues")
    #expect(coordinator.cellFullText(row: -1, column: 4) == "Language")
    #expect(coordinator.cellFullText(row: 0, column: 1) == "Episode 01")
    #expect(coordinator.cellFullText(row: 0, column: 2) == "loaded cue")
    #expect(coordinator.cellFullText(row: 0, column: 3) == "01:15:32 - 01:16:04")
    #expect(coordinator.cellFullText(row: 0, column: 4) == "zh-hans, jp")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 0) == "1000001")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 2) == "")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 3) == "")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 4) == "")
}

@MainActor
@Test
func subtitleTableViewMapsTextColumnsWhenDisplayTitleIsHidden() {
    let loadedRow = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode 01",
        startTime: "15:18",
        endTime: "15:20",
        cues: "loaded cue",
        tags: [
            WorkbenchTag(key: "zh-hans"),
            WorkbenchTag(key: "jp"),
        ]
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 1,
        rowProvider: { _ in loadedRow },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsDisplayTitleColumn: false,
        showsTimeColumn: true,
        showsLanguageColumn: true,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.cellFullText(row: -1, column: 1) == "Cues")
    #expect(coordinator.cellFullText(row: -1, column: 2) == "Time Range")
    #expect(coordinator.cellFullText(row: -1, column: 3) == "Language")
    #expect(coordinator.cellFullText(row: -1, column: 4) == "")
    #expect(coordinator.cellFullText(row: 0, column: 1) == "loaded cue")
    #expect(coordinator.cellFullText(row: 0, column: 2) == "15:18 - 15:20")
    #expect(coordinator.cellFullText(row: 0, column: 3) == "zh-hans, jp")
    #expect(coordinator.cellFullText(row: 0, column: 4) == "")
}

@MainActor
@Test
func subtitleTableViewUsesExplicitColumnOrderForTextColumns() {
    let loadedRow = SubtitleTableRow(
        id: 1,
        dateAdded: "26-07-02 14:30",
        displayTitle: "Episode 01",
        startTime: "15:18",
        endTime: "15:20",
        cues: "loaded cue",
        tags: [
            WorkbenchTag(key: "en", label: "English", colorID: .gray),
            WorkbenchTag(key: "ja", label: "Japanese", colorID: .gray),
        ]
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "excerpt",
        rowCount: 1,
        rowProvider: { _ in loadedRow },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        columnOrder: ["cues", "display", "language", "time", "dateAdded"],
        showsDateAddedColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: true,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.cellFullText(row: -1, column: 1) == "Cues")
    #expect(coordinator.cellFullText(row: -1, column: 2) == "Display Title")
    #expect(coordinator.cellFullText(row: -1, column: 3) == "Language")
    #expect(coordinator.cellFullText(row: -1, column: 4) == "Time Range")
    #expect(coordinator.cellFullText(row: -1, column: 5) == "Date Added")
    #expect(coordinator.cellFullText(row: 0, column: 1) == "loaded cue")
    #expect(coordinator.cellFullText(row: 0, column: 2) == "Episode 01")
    #expect(coordinator.cellFullText(row: 0, column: 3) == "English, Japanese")
    #expect(coordinator.cellFullText(row: 0, column: 4) == "15:18 - 15:20")
    #expect(coordinator.cellFullText(row: 0, column: 5) == "26-07-02 14:30")
}

@MainActor
@Test
func subtitleTableColumnLayoutUsesDocumentedMinimumWidths() {
    let searchMinimumWidth = SubtitleTableColumnLayout.minimumContentWidth(
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth
    )
    let excerptMinimumWidth = SubtitleTableColumnLayout.minimumContentWidth(
        showsDateAddedColumn: true,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth
    )
    let allOptionalColumnsMinimumWidth = SubtitleTableColumnLayout.minimumContentWidth(
        showsDateAddedColumn: true,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: true,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth
    )

    #expect(searchMinimumWidth == 610)
    #expect(excerptMinimumWidth == 730)
    #expect(allOptionalColumnsMinimumWidth == 850)
}

@MainActor
@Test
func subtitleTableColumnLayoutRedistributesWidthAfterMinimumConstraints() {
    let layout = SubtitleTableColumnLayout.resolve(
        contentWidth: 736,
        height: 64,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
        columnOrder: ["cues", "display", "time"]
    )

    #expect(layout.indexRect.width == 50)
    #expect(layout.nameRect.width == 182)
    #expect(layout.cuesRect.width == 364)
    #expect(layout.timeRect?.width == 140)
    #expect(layout.cuesRect.minX == layout.indexRect.maxX)
    #expect(layout.nameRect.minX == layout.cuesRect.maxX)
    #expect(layout.timeRect?.minX == layout.nameRect.maxX)
    #expect(layout.contentWidth == 736)
}

@MainActor
@Test
func subtitleTableColumnLayoutExpandsNarrowDocumentsToAllVisibleMinimums() {
    let layout = SubtitleTableColumnLayout.resolve(
        contentWidth: 320,
        height: 64,
        showsDateAddedColumn: true,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
        columnOrder: ["display", "cues", "time", "dateAdded"]
    )

    #expect(layout.indexRect.width == 50)
    #expect(layout.nameRect.width == 180)
    #expect(layout.cuesRect.width == 240)
    #expect(layout.timeRect?.width == 140)
    #expect(layout.dateAddedRect?.width == 120)
    #expect(layout.contentWidth == 730)
}

@MainActor
@Test
func subtitleTableColumnLayoutExcludesHiddenColumnsFromWeightedAllocation() {
    let layout = SubtitleTableColumnLayout.resolve(
        contentWidth: 500,
        height: 64,
        showsDisplayTitleColumn: true,
        showsTimeColumn: false,
        showsLanguageColumn: false,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
        columnOrder: ["display", "cues", "time"]
    )

    #expect(layout.nameRect.width == 180)
    #expect(layout.cuesRect.width == 270)
    #expect(layout.timeRect == nil)
    #expect(layout.contentWidth == 500)
}

@MainActor
@Test
func subtitleTableColumnLayoutUsesUnconstrainedWeightsInWideDocuments() {
    let layout = SubtitleTableColumnLayout.resolve(
        contentWidth: 1_350,
        height: 64,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
        columnOrder: ["display", "cues", "time"]
    )
    let timeWidth = layout.timeRect?.width ?? 0

    #expect(abs(layout.cuesRect.width / layout.nameRect.width - 2) < 0.001)
    #expect(abs(timeWidth / layout.nameRect.width - CGFloat(2) / 3) < 0.001)
    #expect(abs(layout.indexRect.width + layout.nameRect.width + layout.cuesRect.width + timeWidth - 1_350) < 0.001)
}

@MainActor
@Test
func subtitleTableColumnLayoutMeasurementKeyIncludesEveryVisibleColumnWidth() {
    let oldLayout = SubtitleTableColumnLayout.resolve(
        contentWidth: 1_160,
        height: 64,
        showsDateAddedColumn: true,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: true,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
        columnOrder: ["display", "cues", "language", "time", "dateAdded"]
    )
    let newLayout = SubtitleTableColumnLayout.resolve(
        contentWidth: 1_360,
        height: 64,
        showsDateAddedColumn: true,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: true,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
        columnOrder: ["display", "cues", "language", "time", "dateAdded"]
    )

    #expect(oldLayout.rowMeasurementLayoutKey.columnWidths == [
        "selection": 5_000,
        "dateAdded": 14_800,
        "display": 22_200,
        "time": 14_800,
        "cues": 44_400,
        "language": 14_800,
    ])
    #expect(newLayout.rowMeasurementLayoutKey != oldLayout.rowMeasurementLayoutKey)
    #expect(newLayout.nameRect.width > oldLayout.nameRect.width)
    #expect((newLayout.timeRect?.width ?? 0) > (oldLayout.timeRect?.width ?? 0))
    #expect((newLayout.dateAddedRect?.width ?? 0) > (oldLayout.dateAddedRect?.width ?? 0))
    #expect((newLayout.languageRect?.width ?? 0) > (oldLayout.languageRect?.width ?? 0))
    #expect(newLayout.languageRect?.minX == newLayout.cuesRect.maxX)
    #expect(newLayout.timeRect?.minX == newLayout.languageRect?.maxX)
    #expect(newLayout.cuesRect.width > oldLayout.cuesRect.width)
}

@MainActor
@Test
func subtitleTableViewUsesDynamicMinimumRowHeightAndLazySelectionState() {
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 100_000,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        onVisibleRowsChange: { _ in },
        isRowSelected: { $0 == 99_999 },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.numberOfRowsForTesting() == 100_000)
    #expect(coordinator.currentRowHeight == SubtitleTableCueGeometry.minimumRowHeight)
    #expect(coordinator.rowSelectionStateForTesting(row: 0) == false)
    #expect(coordinator.rowSelectionStateForTesting(row: 99_999) == true)
}

@MainActor
@Test
func subtitleTableViewTracksFocusedRedesignCheckboxRowSparsely() {
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 100_000,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        onVisibleRowsChange: { _ in },
        isSelectionMode: true,
        isRowSelected: { _ in false },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    coordinator.setFocusedCheckboxRowForTesting(99_999)
    #expect(coordinator.focusedCheckboxRowForTesting() == 99_999)

    coordinator.update(
        tableName: "test-search",
        rowCount: 10,
        rowProvider: { _ in nil },
        rowsVersion: 2,
        rowsUpdate: .reload,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        scrollResetToken: 0,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    #expect(coordinator.focusedCheckboxRowForTesting() == nil)
}

@MainActor
@Test
func subtitleTableViewChoosesFirstVisibleRowForKeyboardCheckboxEntry() {
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 100_000,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.firstFocusableCheckboxRowForTesting(visibleRows: 42..<60) == 42)
    #expect(coordinator.firstFocusableCheckboxRowForTesting(visibleRows: nil) == 0)
}

@MainActor
@Test
func subtitleTableViewRejectsKeyboardCheckboxEntryWhenNoRowsExist() {
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 0,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.firstFocusableCheckboxRowForTesting(visibleRows: 0..<10) == nil)
}

@MainActor
@Test
func subtitleTableViewTabsBetweenFocusedVirtualCheckboxRows() {
    let coordinator = makeKeyboardFocusTableCoordinator()

    coordinator.setFocusedCheckboxRowForTesting(0)
    #expect(coordinator.handleKeyDown(makeTabKeyEvent()) == true)
    #expect(coordinator.focusedCheckboxRowForTesting() == 1)

    #expect(coordinator.handleKeyDown(makeTabKeyEvent(shift: true)) == true)
    #expect(coordinator.focusedCheckboxRowForTesting() == 0)
}

@MainActor
@Test
func subtitleTableViewExitsVirtualCheckboxFocusAtTabBoundaries() {
    let coordinator = makeKeyboardFocusTableCoordinator(rowCount: 100_000)

    coordinator.setFocusedCheckboxRowForTesting(0)
    #expect(coordinator.handleKeyDown(makeTabKeyEvent(shift: true)) == true)
    #expect(coordinator.focusedCheckboxRowForTesting() == nil)

    coordinator.setFocusedCheckboxRowForTesting(99_999)
    #expect(coordinator.handleKeyDown(makeTabKeyEvent()) == true)
    #expect(coordinator.focusedCheckboxRowForTesting() == nil)
}

@MainActor
@Test
func subtitleTableViewIgnoresMouseCheckboxToggleWhenDisabled() {
    var toggledRows: [Int] = []
    let coordinator = makeKeyboardFocusTableCoordinator { row in
        toggledRows.append(row)
    }

    coordinator.setFocusedCheckboxRowForTesting(3)
    coordinator.isEnabled = false

    #expect(coordinator.toggleRowCheckboxFromMouseForTesting(row: 1) == false)
    #expect(toggledRows.isEmpty)
    #expect(coordinator.focusedCheckboxRowForTesting() == nil)
}

@MainActor
@Test
func subtitleTableViewMouseCheckboxToggleDoesNotKeepKeyboardFocus() {
    var toggledRows: [Int] = []
    let coordinator = makeKeyboardFocusTableCoordinator { row in
        toggledRows.append(row)
    }

    coordinator.setFocusedCheckboxRowForTesting(3)

    #expect(coordinator.toggleRowCheckboxFromMouseForTesting(row: 1) == true)
    #expect(toggledRows == [1])
    #expect(coordinator.focusedCheckboxRowForTesting() == nil)
}

@MainActor
@Test
func subtitleTableViewSkipsDuplicateVisibleRowNotifications() {
    var notifiedRanges = [Range<Int>]()
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 100_000,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        onVisibleRowsChange: { notifiedRanges.append($0) },
        isRowSelected: { _ in false },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    let container = SubtitleTableContainerView(frame: CGRect(x: 0, y: 0, width: 500, height: 260))
    let header = SubtitleVirtualTableHeaderView(frame: CGRect(x: 0, y: 0, width: 500, height: 44))
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 44, width: 500, height: 200))
    let overlay = SubtitleTableScrollbarOverlayView(frame: scrollView.frame)
    let documentView = SubtitleVirtualTableDocumentView(frame: CGRect(x: 0, y: 0, width: 500, height: 1))

    documentView.coordinator = coordinator
    scrollView.documentView = documentView
    let pageScrollbar = WorkbenchPageScrollbar()
    pageScrollbar.attach(overlayView: overlay, axis: .vertical)
    coordinator.attach(
        container: container,
        headerView: header,
        scrollView: scrollView,
        pageScrollbar: pageScrollbar,
        documentView: documentView
    )
    coordinator.resizeDocument()

    coordinator.notifyVisibleRowsChanged()
    coordinator.notifyVisibleRowsChanged()
    #expect(notifiedRanges.count == 1)

    scrollView.contentView.scroll(to: CGPoint(x: 0, y: 10))
    coordinator.scrollContentDidChange()
    #expect(notifiedRanges.count == 2)

    scrollView.contentView.scroll(to: CGPoint(x: 0, y: 1_000))
    coordinator.scrollContentDidChange()
    #expect(notifiedRanges.count == 3)
}

@MainActor
@Test
func subtitleTablePageChromePinsAgainstTheFullViewportScrollbar() throws {
    let loadedRow = SubtitleTableRow(
        id: 1,
        primaryCueID: 1,
        displayTitle: "Episode 01",
        primaryCueText: "cue text",
        cueGroupTexts: ["cue text"],
        primaryGroupIndex: 0
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "excerpt",
        probeSurface: .excerpt,
        rowCount: 100,
        rowProvider: { _ in loadedRow },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: false,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    let container = SubtitleTableContainerView(
        frame: CGRect(x: 0, y: 0, width: 1_000, height: 700)
    )
    let viewport = SubtitleTablePageChromeViewportView(frame: container.bounds)
    let header = SubtitleVirtualTableHeaderView()
    let scrollView = NSScrollView(
        frame: CGRect(x: 32, y: 0, width: 936, height: 700)
    )
    let overlay = SubtitleTableScrollbarOverlayView(frame: container.bounds)
    let documentView = SubtitleVirtualTableDocumentView(
        frame: CGRect(x: 0, y: 0, width: 936, height: 1)
    )
    container.addSubview(scrollView)
    container.addSubview(viewport)
    viewport.addSubview(header)
    container.addSubview(overlay)
    scrollView.documentView = documentView
    let pageScrollbar = WorkbenchPageScrollbar()
    pageScrollbar.attach(overlayView: overlay, axis: .vertical)
    coordinator.attach(
        container: container,
        headerView: header,
        scrollView: scrollView,
        pageScrollbar: pageScrollbar,
        documentView: documentView,
        pageChromeViewport: viewport
    )
    coordinator.updatePageChrome(SubtitleTablePageChrome(
        scrollableHeader: AnyView(Color.clear),
        pinnedHeader: AnyView(Color.clear),
        scrollableHeaderHeight: { _ in 294 },
        pinnedHeaderHeight: 52,
        leadingInset: 32,
        trailingInset: 48,
        bottomInset: 14
    ))
    coordinator.resizeDocument()
    var frames = coordinator.pageChromeFramesForTesting()
    #expect(frames?.scrollable.minY == 0)
    #expect(frames?.pinned.minY == 294)
    #expect(frames?.tableHeader.minY == 346)

    scrollView.contentView.scroll(to: CGPoint(x: 0, y: 400))
    coordinator.scrollContentDidChange()
    frames = coordinator.pageChromeFramesForTesting()
    #expect(frames?.scrollable.minY == -400)
    #expect(frames?.pinned.minY == 0)
    #expect(frames?.tableHeader.minY == 52)
    #expect(coordinator.usesOverlayScrollbarsForTesting())

    let coveredCueRect = try #require(
        coordinator.cellContentHoverDocumentRectForTesting(
            row: 0,
            columnID: "cues"
        )
    )
    let coveredPoint = CGPoint(
        x: coveredCueRect.midX,
        y: coveredCueRect.midY
    )
    let coveredWindowPoint = documentView.convert(coveredPoint, to: nil)
    #expect(documentView.visibleRect.contains(coveredPoint))
    #expect(coordinator.pointerShape(atWindowPoint: coveredWindowPoint) == .arrow)
    #expect(!coordinator.handleMouseDown(windowPoint: coveredWindowPoint))
    #expect(!coordinator.handleRightMouseDown(windowPoint: coveredWindowPoint))
    coordinator.handleMouseHover(windowPoint: coveredWindowPoint)
    #expect(!coordinator.isCellHoveredForTesting(row: 0, columnID: "cues"))
}

@MainActor
@Test
func subtitleTablePageChromeClipsPartialRowsBelowPinnedHeader() throws {
    let row = SubtitleTableRow(
        id: 1,
        primaryCueID: 1,
        displayTitle: "Episode 01",
        primaryCueText: "cue text",
        cueGroupTexts: ["cue text"],
        primaryGroupIndex: 0
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "excerpt",
        probeSurface: .excerpt,
        rowCount: 100,
        rowProvider: { _ in row },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: false,
        onVisibleRowsChange: { _ in },
        isSelectionMode: true,
        isRowSelected: { _ in true },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    let container = SubtitleTableContainerView(
        frame: CGRect(x: 0, y: 0, width: 1_000, height: 700)
    )
    let viewport = SubtitleTablePageChromeViewportView(frame: container.bounds)
    let header = SubtitleVirtualTableHeaderView()
    let scrollView = NSScrollView(
        frame: CGRect(x: 32, y: 0, width: 936, height: 700)
    )
    let overlay = SubtitleTableScrollbarOverlayView(frame: container.bounds)
    let documentView = SubtitleVirtualTableDocumentView(
        frame: CGRect(x: 0, y: 0, width: 936, height: 1)
    )
    container.addSubview(scrollView)
    container.addSubview(viewport)
    viewport.addSubview(header)
    container.addSubview(overlay)
    header.coordinator = coordinator
    header.isRedesign = true
    documentView.coordinator = coordinator
    documentView.isRedesign = true
    scrollView.documentView = documentView
    let pageScrollbar = WorkbenchPageScrollbar()
    pageScrollbar.attach(overlayView: overlay, axis: .vertical)
    coordinator.attach(
        container: container,
        headerView: header,
        scrollView: scrollView,
        pageScrollbar: pageScrollbar,
        documentView: documentView,
        pageChromeViewport: viewport
    )
    coordinator.updatePageChrome(SubtitleTablePageChrome(
        scrollableHeader: AnyView(Color.clear),
        pinnedHeader: AnyView(Color.clear),
        scrollableHeaderHeight: { _ in 294 },
        pinnedHeaderHeight: 52,
        leadingInset: 32,
        trailingInset: 48,
        bottomInset: 14
    ))
    coordinator.resizeDocument()

    scrollView.contentView.scroll(to: CGPoint(x: 0, y: 330))
    coordinator.scrollContentDidChange()
    let visibleRect = documentView.visibleRect
    let pageFrames = try #require(coordinator.pageChromeFramesForTesting())
    let bodyBoundaryY = visibleRect.minY + pageFrames.tableHeader.maxY
    let bitmap = try #require(
        documentView.bitmapImageRepForCachingDisplay(in: visibleRect)
    )
    documentView.cacheDisplay(in: visibleRect, to: bitmap)
    let expected = try #require(
        coordinator.rowBackgroundColorForTesting(row: 0)?.usingColorSpace(.deviceRGB)
    )
    let scaleX = CGFloat(bitmap.pixelsWide) / visibleRect.width
    let scaleY = CGFloat(bitmap.pixelsHigh) / visibleRect.height
    let sampleX = Int((visibleRect.width - 10) * scaleX)
    let coveredLocalY = bodyBoundaryY - 12 - visibleRect.minY
    let visibleLocalY = bodyBoundaryY + 13 - visibleRect.minY

    func matchesExpected(x: Int, y: Int) -> Bool {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
            return false
        }
        return abs(color.redComponent - expected.redComponent) < 0.02
            && abs(color.greenComponent - expected.greenComponent) < 0.02
            && abs(color.blueComponent - expected.blueComponent) < 0.02
            && abs(color.alphaComponent - expected.alphaComponent) < 0.02
    }

    let orientations = [
        (
            covered: Int(coveredLocalY * scaleY),
            visible: Int(visibleLocalY * scaleY)
        ),
        (
            covered: bitmap.pixelsHigh - 1 - Int(coveredLocalY * scaleY),
            visible: bitmap.pixelsHigh - 1 - Int(visibleLocalY * scaleY)
        ),
    ]
    #expect(
        orientations.contains { orientation in
            !matchesExpected(x: sampleX, y: orientation.covered)
                && matchesExpected(x: sampleX, y: orientation.visible)
        }
    )
}

@MainActor
@Test
func subtitleTableViewKeepsRowMenuOpenAcrossContainerLayout() {
    let fixture = makeAttachedVirtualTableCoordinator()
    let buttonFrame = CGRect(x: 320, y: 10 * fixture.coordinator.currentRowHeight + 14, width: 36, height: 36)

    fixture.coordinator.showMenu(for: 10, buttonFrame: buttonFrame)
    #expect(fixture.coordinator.isMenuOpenForTesting() == true)

    fixture.container.layout()
    #expect(fixture.coordinator.isMenuOpenForTesting() == true)
}

@MainActor
@Test
func subtitleTableViewKeepsRowMenuOpenAcrossScrollNotifications() {
    let fixture = makeAttachedVirtualTableCoordinator()
    let buttonFrame = CGRect(x: 320, y: 10 * fixture.coordinator.currentRowHeight + 14, width: 36, height: 36)

    fixture.coordinator.showMenu(for: 10, buttonFrame: buttonFrame)
    #expect(fixture.coordinator.isMenuOpenForTesting() == true)

    fixture.coordinator.scrollContentDidChange()
    #expect(fixture.coordinator.isMenuOpenForTesting() == true)
}

@MainActor
@Test
func subtitleTableViewCueTextHitTestingUsesTextFragmentsOnly() {
    let fixture = makeAttachedVirtualTableCoordinator()
    let row = 0
    let textPoint = CGPoint(
        x: SubtitleTableMetrics.indexColumnWidth + SubtitleTableMetrics.nameColumnWidth + SubtitleTableMetrics.cellLeading + 4,
        y: fixture.coordinator.currentRowHeight / 2
    )
    let trailingPoint = CGPoint(
        x: 898,
        y: fixture.coordinator.currentRowHeight / 2
    )
    let rowActionFrame = fixture.coordinator.rowActionButtonDocumentFrameForTesting(row: row)
    let rowActionPoint = CGPoint(
        x: rowActionFrame?.midX ?? trailingPoint.x,
        y: rowActionFrame?.midY ?? trailingPoint.y
    )

    #expect(fixture.coordinator.cueTextHitTestForTesting(row: row, point: textPoint) == true)
    #expect(fixture.coordinator.cueTextHitTestForTesting(row: row, point: trailingPoint) == false)
    #expect(rowActionFrame == nil)
    #expect(fixture.coordinator.cueTextHitTestForTesting(row: row, point: rowActionPoint) == false)
    #expect(fixture.coordinator.rowActionButtonHitTestForTesting(row: row, point: rowActionPoint) == false)
}

@MainActor
@Test
func subtitleTableViewExpandsRedesignDocumentWidthForHorizontalScrolling() {
    let fixture = makeAttachedVirtualTableCoordinator(width: 500)
    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: fixture.scrollView.contentView.bounds.size,
        contentSize: fixture.documentView.frame.size,
        contentOffset: fixture.scrollView.contentView.bounds.origin
    )

    #expect(fixture.documentView.frame.width == fixture.coordinator.tableContentWidthForTesting(viewportWidth: 500))
    #expect(fixture.documentView.frame.width > fixture.scrollView.contentView.bounds.width)
    #expect(metrics.isVisible(.horizontal) == true)
}

@MainActor
@Test
func subtitleTableViewRemovesRowActionButtonFromCuesColumn() {
    let fixture = makeAttachedVirtualTableCoordinator(width: 900)
    let beforeScrollFrame = fixture.coordinator.rowActionButtonFrameForTesting(row: 0)

    fixture.scrollView.contentView.scroll(to: CGPoint(x: 120, y: 0))
    fixture.scrollView.reflectScrolledClipView(fixture.scrollView.contentView)
    fixture.coordinator.scrollContentDidChange()

    let afterScrollFrame = fixture.coordinator.rowActionButtonFrameForTesting(row: 0)

    #expect(beforeScrollFrame == nil)
    #expect(afterScrollFrame == nil)
}

@MainActor
@Test
func subtitleTableViewCueContentLeftClickPlaysInsteadOfOpeningMenu() throws {
    var playCount = 0
    let fixture = makeAttachedVirtualTableCoordinator(onPlay: { _ in
        playCount += 1
    })
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesPoint = CGPoint(x: cuesRect.midX, y: cuesRect.midY)
    let windowPoint = fixture.documentView.convert(cuesPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
    #expect(playCount == 0)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: windowPoint) == true)
    #expect(playCount == 1)
}

@MainActor
@Test
func subtitleTableViewRedesignHoverUsesFullRowBackground() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let displayRect = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "display")
    )
    let cuesRect = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues")
    )

    fixture.coordinator.handleMouseHover(windowPoint: fixture.documentView.convert(
        CGPoint(x: displayRect.midX, y: displayRect.midY),
        to: nil
    ))
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )

    fixture.coordinator.handleMouseHover(windowPoint: fixture.documentView.convert(
        CGPoint(x: cuesRect.midX, y: cuesRect.midY),
        to: nil
    ))
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )

    fixture.coordinator.clearHover()
    #expect(fixture.coordinator.rowBackgroundColorForTesting(row: 0) == nil)
}

@MainActor
@Test
func subtitleTableViewDisplayTitleContentLeftClickHasNoAction() throws {
    var openedPath: String?
    let fixture = makeAttachedVirtualTableCoordinator(onOpenSubtitleFile: { path in
        openedPath = path
    })
    let displayRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "display"))
    let displayPoint = CGPoint(x: displayRect.midX, y: displayRect.midY)
    let windowPoint = fixture.documentView.convert(displayPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
    #expect(openedPath == nil)
}

@MainActor
@Test
func subtitleTableViewCueContentRightClickOpensMenuBelowClickPosition() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    // A table body tall enough to have room below the click, which is where
    // the shared placement rule puts the menu.
    fixture.container.frame.size.height = 800
    fixture.scrollView.frame.size.height = 756
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesPoint = CGPoint(x: cuesRect.midX, y: cuesRect.midY)
    let windowPoint = fixture.documentView.convert(cuesPoint, to: nil)
    let clickPointInContainer = fixture.container.convert(cuesPoint, from: fixture.documentView)

    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint) == true)

    let menuFrame = try #require(fixture.coordinator.menuFrameForTesting())
    expectMenuFrame(menuFrame, opensBelow: clickPointInContainer)
}

@MainActor
@Test
func subtitleTableViewDisplayTitleContentRightClickOpensMenuBelowClickPosition() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    fixture.container.frame.size.height = 800
    fixture.scrollView.frame.size.height = 756
    let displayRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "display"))
    let displayPoint = CGPoint(x: displayRect.midX, y: displayRect.midY)
    let windowPoint = fixture.documentView.convert(displayPoint, to: nil)
    let clickPointInContainer = fixture.container.convert(displayPoint, from: fixture.documentView)

    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint) == true)

    let menuFrame = try #require(fixture.coordinator.menuFrameForTesting())
    expectMenuFrame(menuFrame, opensBelow: clickPointInContainer)
}

@MainActor
@Test
func subtitleTableCoveredByADialogKeepsItsHighlight() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    fixture.container.frame.size.height = 800
    fixture.scrollView.frame.size.height = 756
    let firstRowRect = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues")
    )
    fixture.coordinator.handleMouseHover(
        windowPoint: fixture.documentView.convert(
            CGPoint(x: firstRowRect.midX, y: firstRowRect.midY),
            to: nil
        )
    )
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )

    // A dialog above the table takes its input and leaves its picture alone.
    fixture.coordinator.isCoveredByHigherLayer = true
    fixture.coordinator.clearHover()
    let secondRowRect = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 1, columnID: "cues")
    )
    fixture.coordinator.handleMouseHover(
        windowPoint: fixture.documentView.convert(
            CGPoint(x: secondRowRect.midX, y: secondRowRect.midY),
            to: nil
        )
    )
    #expect(fixture.coordinator.rowBackgroundColorForTesting(row: 1) == nil)
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )
}

@MainActor
@Test
func subtitleTableForeignMenuOnItsLayerFreezesHover() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    fixture.container.frame.size.height = 800
    fixture.scrollView.frame.size.height = 756
    let firstRowRect = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues")
    )
    fixture.coordinator.handleMouseHover(
        windowPoint: fixture.documentView.convert(
            CGPoint(x: firstRowRect.midX, y: firstRowRect.midY),
            to: nil
        )
    )
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )

    // A menu opened elsewhere on the table's layer — the filter menu — is
    // reported through the layer context and freezes the table exactly like
    // its own row menu: the lit row keeps its highlight, no other row takes
    // one, and leaving the table does not drop it.
    fixture.coordinator.interfaceLayerContext = InterfaceLayerContext(
        layer: .workbenchPage,
        frozenLayers: [.workbenchPage]
    )
    let secondRowRect = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 1, columnID: "cues")
    )
    fixture.coordinator.handleMouseHover(
        windowPoint: fixture.documentView.convert(
            CGPoint(x: secondRowRect.midX, y: secondRowRect.midY),
            to: nil
        )
    )
    fixture.coordinator.clearHover()
    #expect(fixture.coordinator.rowBackgroundColorForTesting(row: 1) == nil)
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )

    // The freeze lifting hands hover back to wherever the pointer really is.
    fixture.coordinator.interfaceLayerContext = InterfaceLayerContext(
        layer: .workbenchPage
    )
    fixture.coordinator.handleMouseHover(
        windowPoint: fixture.documentView.convert(
            CGPoint(x: secondRowRect.midX, y: secondRowRect.midY),
            to: nil
        )
    )
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 1)
            === WorkbenchRedesignColors.NS.rowHover
    )
}

@MainActor
@Test
func subtitleTableViewOpenMenuFreezesTheTableUnderneathIt() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    fixture.container.frame.size.height = 800
    fixture.scrollView.frame.size.height = 756
    let firstRowRect = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues")
    )
    #expect(
        fixture.coordinator.handleRightMouseDown(
            windowPoint: fixture.documentView.convert(
                CGPoint(x: firstRowRect.midX, y: firstRowRect.midY),
                to: nil
            )
        )
    )
    #expect(fixture.coordinator.isMenuOpenForTesting())
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )

    // The row below the menu cannot take the highlight away from the row the
    // menu hangs off.
    let secondRowRect = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 1, columnID: "cues")
    )
    fixture.coordinator.handleMouseHover(
        windowPoint: fixture.documentView.convert(
            CGPoint(x: secondRowRect.minX + 2, y: secondRowRect.midY),
            to: nil
        )
    )
    #expect(fixture.coordinator.rowBackgroundColorForTesting(row: 1) == nil)
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )

    // Nor does the pointer moving onto the menu, or leaving the table.
    let menuFrame = try #require(fixture.coordinator.menuFrameForTesting())
    fixture.coordinator.handleMouseHover(
        windowPoint: fixture.container.convert(
            CGPoint(x: menuFrame.midX, y: menuFrame.midY),
            to: nil
        )
    )
    fixture.coordinator.clearHover()
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            === WorkbenchRedesignColors.NS.rowHover
    )
    #expect(fixture.coordinator.isMenuOpenForTesting())
}

@MainActor
@Test
func subtitleTableViewRightClickMenuIsBoundedByTheTableBody() throws {
    // This fixture's body is shorter than the menu, so the menu fits on neither
    // side of the click. It takes the roomier side, gives up the height it
    // cannot have, and scrolls the rest — nothing is left hanging over the body
    // for the clip to cut off.
    let fixture = makeAttachedVirtualTableCoordinator()
    // The body is cut down until it is shorter than the menu again: the menu's
    // own height follows the menu item metrics, so the fixture states the
    // relationship it is testing instead of relying on a particular density.
    fixture.container.frame.size.height = 204
    fixture.scrollView.frame.size.height = 144
    let cuesRect = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues")
    )
    let windowPoint = fixture.documentView.convert(
        CGPoint(x: cuesRect.midX, y: cuesRect.midY),
        to: nil
    )

    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint) == true)

    let menuFrame = try #require(fixture.coordinator.menuFrameForTesting())
    let bodyFrame = fixture.coordinator.menuBodyFrameForTesting()
    #expect(bodyFrame.height > 0)
    #expect(menuFrame.height > 0)
    #expect(menuFrame.height <= bodyFrame.height + 0.5)
    #expect(menuFrame.minY >= bodyFrame.minY - 0.5)
    #expect(menuFrame.maxY <= bodyFrame.maxY + 0.5)
    #expect(menuFrame.minX >= bodyFrame.minX - 0.5)
    // The clip stays: it is what keeps a menu that follows its row up under the
    // frozen header from drawing over it.
    #expect(fixture.coordinator.menuIsClippedToTableBodyForTesting())
}

private func expectMenuFrame(_ menuFrame: CGRect, opensBelow clickPoint: CGPoint) {
    let gap = WorkbenchControlMetrics.redesignSpacing1
    #expect(abs(menuFrame.minX - clickPoint.x) < 0.5)
    #expect(abs(menuFrame.minY - (clickPoint.y + gap)) < 0.5)
}

@MainActor
@Test
func subtitleTableViewTimeContentLeftClickHasNoAction() throws {
    let fixture = makeAttachedVirtualTableCoordinator(showsTimeColumn: true)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString("unchanged", forType: .string)
    let timeRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "time"))
    let timePoint = CGPoint(x: timeRect.midX, y: timeRect.midY)
    let windowPoint = fixture.documentView.convert(timePoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
    #expect(pasteboard.string(forType: .string) == "unchanged")
}

@MainActor
@Test
func subtitleTableViewDateAddedContentLeftClickHasNoAction() throws {
    let fixture = makeAttachedVirtualTableCoordinator(showsDateAddedColumn: true)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString("unchanged", forType: .string)
    let dateAddedRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "dateAdded"))
    let dateAddedPoint = CGPoint(x: dateAddedRect.midX, y: dateAddedRect.midY)
    let windowPoint = fixture.documentView.convert(dateAddedPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
    #expect(pasteboard.string(forType: .string) == "unchanged")
}

@MainActor
@Test
func subtitleTableViewRightClickOutsideContentHoverRegionOpensRowMenu() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    // A tall container: this case only needs the menu to open, not to land
    // anywhere in particular.
    fixture.container.frame.size.height = 800
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let outsideContentPoint = CGPoint(
        x: cuesRect.maxX + SubtitleTableMetrics.tableCellHoverPaddingX + 12,
        y: cuesRect.midY
    )
    let windowPoint = fixture.documentView.convert(outsideContentPoint, to: nil)

    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting())
}

@MainActor
@Test
func subtitleTableViewLeftClickOutsideInteractiveRegionsHasNoAction() throws {
    var toggledRows: [Int] = []
    let fixture = makeAttachedVirtualTableCoordinator(onToggleRowSelection: { row in
        toggledRows.append(row)
    })
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let outsideContentPoint = CGPoint(
        x: cuesRect.maxX + SubtitleTableMetrics.tableCellHoverPaddingX + 12,
        y: cuesRect.midY
    )
    let windowPoint = fixture.documentView.convert(outsideContentPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting() == false)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "cues") == nil)
    #expect(toggledRows.isEmpty)
}

@MainActor
@Test
func subtitleTableViewSelectModeReservesColumnAndMakesWholeRowSelectable() throws {
    var toggledRows: [Int] = []
    var playedRow: SubtitleTableRow?
    let normalFixture = makeAttachedVirtualTableCoordinator()
    let fixture = makeAttachedVirtualTableCoordinator(
        isSelectionMode: true,
        onPlay: { playedRow = $0 },
        onToggleRowSelection: { row in
            toggledRows.append(row)
        }
    )
    normalFixture.header.refreshHeaderHosts()
    fixture.header.refreshHeaderHosts()

    let normalLayout = normalFixture.coordinator.headerColumnLayoutForRendering(
        viewportWidth: normalFixture.header.bounds.width,
        height: normalFixture.header.bounds.height
    )
    let selectionLayout = fixture.coordinator.headerColumnLayoutForRendering(
        viewportWidth: fixture.header.bounds.width,
        height: fixture.header.bounds.height
    )
    #expect(normalLayout.indexRect == selectionLayout.indexRect)
    #expect(normalFixture.header.sequenceHeaderIsVisibleForTesting())
    #expect(normalFixture.header.selectionHeaderIsVisibleForTesting() == false)
    #expect(fixture.header.sequenceHeaderIsVisibleForTesting() == false)
    #expect(fixture.header.selectionHeaderIsVisibleForTesting())

    let checkboxRect = try #require(fixture.coordinator.checkboxRectForTesting(row: 0))
    let displayRect = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "display")
    )
    let displayPoint = CGPoint(x: displayRect.midX, y: checkboxRect.midY)
    let displayWindowPoint = fixture.documentView.convert(displayPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: displayWindowPoint))
    #expect(toggledRows == [0])
    #expect(playedRow == nil)
    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: displayWindowPoint))
    #expect(!fixture.coordinator.isMenuOpenForTesting())
    #expect(!fixture.coordinator.canBeginExternalTextSelection)
    #expect(fixture.coordinator.pointerShape(atWindowPoint: displayWindowPoint) == .arrow)
    fixture.coordinator.handleMouseHover(windowPoint: displayWindowPoint)
    #expect(!fixture.coordinator.isCellHoveredForTesting(row: 0, columnID: "cues"))
}

@MainActor
@Test
func subtitleTableViewUnselectedRowClickInCheckboxSelectsRowAndClickOutsidePlaysRow() throws {
    var toggledRows: [Int] = []
    var playedRow: SubtitleTableRow?
    let fixture = makeAttachedVirtualTableCoordinator(
        isSelectionMode: false,
        onPlay: { playedRow = $0 },
        onToggleRowSelection: { row in
            toggledRows.append(row)
        }
    )
    let checkboxRect = try #require(fixture.coordinator.checkboxRectForTesting(row: 0))
    let checkboxPoint = CGPoint(x: checkboxRect.midX, y: checkboxRect.midY)
    let checkboxWindowPoint = fixture.documentView.convert(checkboxPoint, to: nil)

    // Clicking precisely on checkbox rect triggers selection toggle even when not in selection mode
    #expect(fixture.coordinator.handleMouseDown(windowPoint: checkboxWindowPoint))
    #expect(toggledRows == [0])
    #expect(playedRow == nil)

    // Clicking in cues text area triggers play, not selection toggle
    toggledRows.removeAll()
    let cueFragment = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "cues").first
    )
    let cuePoint = CGPoint(x: cueFragment.textBounds.midX, y: cueFragment.textBounds.midY)
    let cuesWindowPoint = fixture.documentView.convert(cuePoint, to: nil)
    #expect(fixture.coordinator.handleMouseDown(windowPoint: cuesWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: cuesWindowPoint))
    #expect(toggledRows.isEmpty)
    #expect(playedRow != nil)
}

@MainActor
@Test
func subtitleTableViewUnselectedHeaderHoverShowsCheckbox() {
    let fixture = makeAttachedVirtualTableCoordinator(isSelectionMode: false)
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 900, height: 260),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = fixture.container
    fixture.header.refreshHeaderHosts()
    #expect(fixture.header.sequenceHeaderIsVisibleForTesting())
    #expect(fixture.header.selectionHeaderIsVisibleForTesting() == false)

    let layout = fixture.coordinator.headerColumnLayoutForRendering(
        viewportWidth: fixture.header.bounds.width,
        height: fixture.header.bounds.height
    )
    let indexPoint = CGPoint(x: layout.indexRect.midX, y: layout.indexRect.midY)
    let windowPoint = fixture.header.convert(indexPoint, to: nil)
    fixture.header.handleHeaderHoverForTesting(windowPoint: windowPoint)
    #expect(fixture.header.selectionHeaderIsVisibleForTesting())
}

@MainActor
@Test
func subtitleTableViewToggleAllWorksWhenNotInSelectionMode() {
    var toggledAll = false
    let fixture = makeAttachedVirtualTableCoordinator(
        isSelectionMode: false,
        onToggleAllSelection: { toggledAll = true }
    )
    fixture.coordinator.toggleAllRowSelection()
    #expect(toggledAll)
}

@MainActor
@Test
func subtitleTableViewUnavailableRowDoesNotTriggerCheckboxOrSelection() throws {
    var toggledRows: [Int] = []
    let unavailableRow = SubtitleTableRow(
        id: 1,
        primaryCueID: 1,
        subtitlePath: "/tmp/CueSeeker/Episode 01.srt",
        dateAdded: "26-07-04 19:00",
        displayTitle: "Episode 01",
        startTime: "00:01",
        endTime: "00:02",
        primaryCueText: "cue text",
        cueGroupTexts: ["cue text"],
        primaryGroupIndex: 0,
        tags: [],
        cueState: .unavailable(.videoMissing)
    )
    let fixture = makeAttachedVirtualTableCoordinator(
        row: unavailableRow,
        isSelectionMode: false,
        onToggleRowSelection: { toggledRows.append($0) }
    )
    let checkboxRect = try #require(fixture.coordinator.checkboxRectForTesting(row: 0))
    let checkboxWindowPoint = fixture.documentView.convert(
        CGPoint(x: checkboxRect.midX, y: checkboxRect.midY),
        to: nil as NSView?
    )

    _ = fixture.coordinator.handleMouseDown(windowPoint: checkboxWindowPoint)
    #expect(toggledRows.isEmpty)

    let selectionFixture = makeAttachedVirtualTableCoordinator(
        row: unavailableRow,
        isSelectionMode: true,
        onToggleRowSelection: { toggledRows.append($0) }
    )
    _ = selectionFixture.coordinator.handleMouseDown(windowPoint: checkboxWindowPoint)
    #expect(toggledRows.isEmpty)
}

@MainActor
@Test
func subtitleTableViewSelectedRowUsesSelectedColorWithoutHoverStacking() throws {
    let fixture = makeAttachedVirtualTableCoordinator(
        isSelectionMode: true,
        isRowSelected: { $0 == 0 }
    )
    let rowRect = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "display")
    )
    let windowPoint = fixture.documentView.convert(
        CGPoint(x: rowRect.midX, y: rowRect.midY),
        to: nil
    )

    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            == WorkbenchRedesignColors.NS.rowSelected
    )
    fixture.coordinator.handleMouseHover(windowPoint: windowPoint)
    #expect(
        fixture.coordinator.rowBackgroundColorForTesting(row: 0)
            == WorkbenchRedesignColors.NS.rowSelected
    )
}

@MainActor
@Test
func subtitleTableViewRightClickUsesEveryNonSelectionCellFullArea() throws {
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_800,
        showsDateAddedColumn: true,
        showsTimeColumn: true
    )

    for columnID in ["display", "cues", "language", "time", "dateAdded"] {
        let cellRect = try #require(fixture.coordinator.dataCellRectForTesting(row: 0, columnID: columnID))
        let blankSidePoint = CGPoint(x: cellRect.maxX - 4, y: cellRect.midY)
        let windowPoint = fixture.documentView.convert(blankSidePoint, to: nil)

        #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint) == true)
        #expect(fixture.coordinator.isMenuOpenForTesting())
        fixture.coordinator.dismissMenu()
    }
}

@MainActor
@Test
func subtitleTableViewCopiesCellActionText() {
    let fixture = makeAttachedVirtualTableCoordinator(showsDateAddedColumn: true, showsTimeColumn: true)
    let pasteboard = NSPasteboard.general

    fixture.coordinator.copyCellTextForTesting(row: 0, columnID: "display")
    #expect(pasteboard.string(forType: .string) == "Episode 01")

    fixture.coordinator.copyCellTextForTesting(row: 0, columnID: "time")
    #expect(pasteboard.string(forType: .string) == "00:01 - 00:02")

    fixture.coordinator.copyCellTextForTesting(row: 0, columnID: "dateAdded")
    #expect(pasteboard.string(forType: .string) == "26-07-04 19:00")
}

@MainActor
@Test
func subtitleTableViewOpenFolderActionUsesSubtitlePath() {
    var openedPath: String?
    let fixture = makeAttachedVirtualTableCoordinator(onOpenSubtitleFile: { path in
        openedPath = path
    })

    fixture.coordinator.openSubtitleFileForTesting(row: 0)

    #expect(openedPath == "/tmp/CueSeeker/Episode 01.srt")
}

@MainActor
@Test
func subtitleTableViewUnifiedRowMenuDispatchesActionsToTheTargetRow() {
    var playedRowID: Int?
    var openedPath: String?
    var removedRowID: Int?
    let fixture = makeAttachedVirtualTableCoordinator(
        showsTimeColumn: true,
        showsCueGroup: true,
        rowActionMenuStyle: .excerpt,
        onPlay: { playedRowID = $0.id },
        onOpenSubtitleFile: { openedPath = $0 },
        onRemoveExcerpt: { removedRowID = $0.id }
    )
    let pasteboard = NSPasteboard.general

    fixture.coordinator.performRowActionForTesting(.play, row: 0)
    fixture.coordinator.performRowActionForTesting(.openSubtitleFolder, row: 0)
    fixture.coordinator.performRowActionForTesting(.removeExcerpt, row: 0)

    #expect(playedRowID == 1)
    #expect(openedPath == "/tmp/CueSeeker/Episode 01.srt")
    #expect(removedRowID == 1)

    fixture.coordinator.performRowActionForTesting(.copyCueText, row: 0)
    #expect(pasteboard.string(forType: .string) == "cue text")

    fixture.coordinator.performRowActionForTesting(.copyDeepLink, row: 0)
    #expect(
        pasteboard.string(forType: .string)
            == "[cue text](cueseeker://cue?id=1)"
    )

    fixture.coordinator.performRowActionForTesting(.copyCueGroupText, row: 0)
    #expect(pasteboard.string(forType: .string) == "cue text")

    fixture.coordinator.performRowActionForTesting(.copyTimeRange, row: 0)
    #expect(pasteboard.string(forType: .string) == "00:01 - 00:02")
}

@MainActor
@Test
func subtitleTableViewRowMenuActionsKeepTheOriginalTargetAfterItsIndexChanges() throws {
    let original = SubtitleTableRow(
        id: 11,
        primaryCueID: 101,
        subtitlePath: "/tmp/CueSeeker/Original.srt",
        displayTitle: "Original",
        startTime: "00:11",
        endTime: "00:12",
        timeRange: "00:11 - 00:12",
        primaryCueText: "original cue",
        cueGroupTexts: ["original extra", "original cue"],
        primaryGroupIndex: 1
    )
    let replacement = SubtitleTableRow(
        id: 22,
        primaryCueID: 202,
        subtitlePath: "/tmp/CueSeeker/Replacement.srt",
        displayTitle: "Replacement",
        startTime: "00:21",
        endTime: "00:22",
        timeRange: "00:21 - 00:22",
        primaryCueText: "replacement cue",
        cueGroupTexts: ["replacement extra", "replacement cue"],
        primaryGroupIndex: 1
    )
    var currentRow = original
    var playedRowIDs: [Int] = []
    var openedPaths: [String] = []
    var movedRows: [(rowID: Int, destinationID: Int64)] = []
    var duplicatedRows: [(rowID: Int, destinationID: Int64)] = []
    var removedRowIDs: [Int] = []
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: 1,
        rowProvider: { _ in currentRow },
        showsCueGroup: true,
        rowActionMenuStyle: .excerpt,
        onPlay: { playedRowIDs.append($0.id) },
        onOpenSubtitleFile: { openedPaths.append($0) },
        rowActionDestinations: [
            SubtitleTableRowActionDestination(id: 90, title: "Destination"),
        ],
        onMoveExcerpt: { movedRows.append(($0.id, $1)) },
        onDuplicateExcerpt: { duplicatedRows.append(($0.id, $1)) },
        onRemoveExcerpt: { removedRowIDs.append($0.id) }
    )
    let anchorFrame = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "cues")
    )
    let pasteboard = NSPasteboard.general

    func performAfterReplacingRow(_ action: SubtitleTableRowAction) {
        currentRow = original
        fixture.coordinator.showMenu(
            for: 0,
            buttonFrame: anchorFrame
        )
        #expect(fixture.coordinator.activeRowMenuTargetForTesting() == original)
        currentRow = replacement
        fixture.coordinator.performActiveRowMenuActionForTesting(action)
        #expect(fixture.coordinator.activeRowMenuTargetForTesting() == nil)
    }

    performAfterReplacingRow(.play)
    #expect(playedRowIDs == [original.id])

    performAfterReplacingRow(.openSubtitleFolder)
    #expect(openedPaths == [original.subtitlePath])

    performAfterReplacingRow(.copyCueText)
    #expect(pasteboard.string(forType: .string) == original.primaryCueText)

    performAfterReplacingRow(.copyDeepLink)
    #expect(
        pasteboard.string(forType: .string)
            == "[original cue](cueseeker://cue?id=101)"
    )

    performAfterReplacingRow(.copyCueGroupText)
    #expect(pasteboard.string(forType: .string) == original.cueGroupCopyText)

    performAfterReplacingRow(.copyTimeRange)
    #expect(pasteboard.string(forType: .string) == original.timeRange)

    performAfterReplacingRow(.removeExcerpt)
    #expect(removedRowIDs == [original.id])

    currentRow = original
    fixture.coordinator.showMenu(for: 0, buttonFrame: anchorFrame)
    currentRow = replacement
    fixture.coordinator.performActiveRowMenuDestinationActionForTesting(
        .moveToList,
        destinationID: 90
    )
    #expect(movedRows.count == 1)
    #expect(movedRows.first?.rowID == original.id)
    #expect(movedRows.first?.destinationID == 90)

    currentRow = original
    fixture.coordinator.showMenu(for: 0, buttonFrame: anchorFrame)
    currentRow = replacement
    fixture.coordinator.performActiveRowMenuDestinationActionForTesting(
        .duplicateToList,
        destinationID: 90
    )
    #expect(duplicatedRows.count == 1)
    #expect(duplicatedRows.first?.rowID == original.id)
    #expect(duplicatedRows.first?.destinationID == 90)

    currentRow = original
    fixture.coordinator.showMenu(for: 0, buttonFrame: anchorFrame)
    #expect(fixture.coordinator.activeRowMenuTargetForTesting() == original)
    fixture.coordinator.dismissMenu()
    #expect(fixture.coordinator.activeRowMenuTargetForTesting() == nil)
    fixture.coordinator.performActiveRowMenuActionForTesting(.play)
    #expect(playedRowIDs == [original.id])
}

@MainActor
@Test
func subtitleTableViewDoesNotCreateRowActionHostsDuringContainerLayout() {
    let fixture = makeAttachedVirtualTableCoordinator(width: 500)
    let initialSubviewCount = fixture.container.subviews.count

    fixture.container.layout()

    #expect(fixture.container.subviews.count == initialSubviewCount)
}

@MainActor
@Test
func subtitleTableViewHidesHorizontalScrollbarWhenContentFitsViewport() {
    let fixture = makeAttachedVirtualTableCoordinator(width: 1_400)
    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: fixture.scrollView.contentView.bounds.size,
        contentSize: fixture.documentView.frame.size,
        contentOffset: fixture.scrollView.contentView.bounds.origin
    )

    #expect(fixture.documentView.frame.width == fixture.scrollView.contentView.bounds.width)
    #expect(metrics.isVisible(.horizontal) == false)
}

@MainActor
@Test
func subtitleTableViewClampsHorizontalScrollWhenColumnsAreHidden() {
    let fixture = makeAttachedVirtualTableCoordinator(width: 900)

    fixture.scrollView.contentView.scroll(to: CGPoint(x: 120, y: 0))
    fixture.scrollView.reflectScrolledClipView(fixture.scrollView.contentView)
    #expect(fixture.scrollView.contentView.bounds.origin.x > 0)

    fixture.coordinator.update(
        tableName: "test-search",
        rowCount: 100,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        rowsUpdate: .none,
        displayTitleHeader: "Display Title",
        showsDisplayTitleColumn: false,
        showsLanguageColumn: false,
        scrollResetToken: 0,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    let metrics = SubtitleTableScrollbarMetrics(
        viewportSize: fixture.scrollView.contentView.bounds.size,
        contentSize: fixture.documentView.frame.size,
        contentOffset: fixture.scrollView.contentView.bounds.origin
    )

    #expect(fixture.documentView.frame.width == fixture.scrollView.contentView.bounds.width)
    #expect(fixture.scrollView.contentView.bounds.origin.x == 0)
    #expect(metrics.isVisible(.horizontal) == false)
}

@MainActor
@Test
func subtitleTableViewScrollsToTargetRowOnReset() {
    let fixture = makeAttachedVirtualTableCoordinator(width: 900)

    fixture.coordinator.update(
        tableName: "test-search",
        rowCount: 100,
        rowProvider: { _ in nil },
        rowsVersion: 2,
        rowsUpdate: .reload,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        scrollResetToken: 1,
        scrollTargetRow: 42,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    let expectedY = CGFloat(42) * fixture.coordinator.currentRowHeight
    #expect(abs(fixture.scrollView.contentView.bounds.origin.y - expectedY) < 0.5)
}

@MainActor
@Test
func subtitleTableViewDoesNotRedrawForCallbackOnlyUpdates() {
    let fixture = makeAttachedVirtualTableCoordinator(width: 900)
    fixture.header.needsDisplay = false
    fixture.documentView.needsDisplay = false

    fixture.coordinator.update(
        tableName: "test-search",
        rowCount: 100,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        rowsUpdate: .none,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        scrollResetToken: 0,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    #expect(fixture.header.needsDisplay == false)
    #expect(fixture.documentView.needsDisplay == false)
}

@MainActor
@Test
func subtitleTableViewSuppressesVisibleRowNotificationsWhenExternalLayerIsOpen() {
    var visibleRowNotifications = 0
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 900,
        onVisibleRowsChange: { _ in
            visibleRowNotifications += 1
        }
    )

    visibleRowNotifications = 0
    fixture.coordinator.isCoveredByHigherLayer = true
    fixture.coordinator.notifyVisibleRowsChanged(force: true)

    #expect(visibleRowNotifications == 0)

    fixture.coordinator.isCoveredByHigherLayer = false
    fixture.coordinator.notifyVisibleRowsChanged(force: true)

    #expect(visibleRowNotifications == 1)
}

@MainActor
@Test
func subtitleTableViewLimitsPointingHandToCueContent() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let checkboxRect = try #require(fixture.coordinator.checkboxRectForTesting(row: 0))
    let checkboxPoint = CGPoint(x: checkboxRect.midX, y: checkboxRect.midY)
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesPoint = CGPoint(x: cuesRect.midX, y: cuesRect.midY)
    let displayRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "display"))
    let displayPoint = CGPoint(x: displayRect.midX, y: displayRect.midY)
    let outsideContentPoint = CGPoint(
        x: cuesRect.maxX + SubtitleTableMetrics.tableCellHoverPaddingX + 12,
        y: cuesRect.midY
    )

    let shape = { (point: CGPoint) in
        fixture.coordinator.pointerShape(atWindowPoint: fixture.documentView.convert(point, to: nil))
    }
    #expect(shape(checkboxPoint) == .arrow)
    #expect(shape(cuesPoint) == .grab)
    #expect(shape(displayPoint) == .iBeam)
    #expect(shape(outsideContentPoint) == .arrow)
}

@MainActor
@Test
func subtitleTableViewKeepsHoverWhenAppKitReportsAnExitUnderAStillPointer() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesWindowPoint = fixture.documentView.convert(CGPoint(x: cuesRect.midX, y: cuesRect.midY), to: nil)
    fixture.coordinator.handleMouseHover(windowPoint: cuesWindowPoint)
    #expect(fixture.coordinator.isCellHoveredForTesting(row: 0, columnID: "cues"))

    // A scroll makes AppKit report an exit for a pointer that never moved.
    fixture.coordinator.clearHoverUnlessPointerInside(windowPoint: cuesWindowPoint)
    #expect(fixture.coordinator.isCellHoveredForTesting(row: 0, columnID: "cues"))

    let outsideWindowPoint = fixture.documentView.convert(CGPoint(x: -40, y: -40), to: nil)
    fixture.coordinator.clearHoverUnlessPointerInside(windowPoint: outsideWindowPoint)
    #expect(!fixture.coordinator.isCellHoveredForTesting(row: 0, columnID: "cues"))
}

@MainActor
@Test
func subtitleTableViewDropsPointingHandInSelectionMode() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesPoint = CGPoint(x: cuesRect.midX, y: cuesRect.midY)
    let checkboxRect = try #require(fixture.coordinator.checkboxRectForTesting(row: 0))
    let checkboxPoint = CGPoint(x: checkboxRect.midX, y: checkboxRect.midY)
    let displayRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "display"))
    let displayPoint = CGPoint(x: displayRect.midX, y: displayRect.midY)

    let shape = { (point: CGPoint) in
        fixture.coordinator.pointerShape(atWindowPoint: fixture.documentView.convert(point, to: nil))
    }

    fixture.coordinator.setSelectionModeForTesting(true)

    #expect(shape(cuesPoint) == .arrow)
    #expect(shape(checkboxPoint) == .arrow)
    #expect(shape(displayPoint) == .arrow)

    fixture.coordinator.setSelectionModeForTesting(false)

    #expect(shape(cuesPoint) == .grab)
}

@MainActor
@Test
func subtitleTableViewMapsCueAndLanguageTagFragmentsIntoSingleLogicalCells() throws {
    let row = SubtitleTableRow(
        id: 1,
        primaryCueID: 41,
        displayTitle: "Episode",
        primaryCueText: "primary",
        cueGroupTexts: ["extra", "primary"],
        primaryGroupIndex: 1,
        tags: [
            WorkbenchTag(key: "1", label: "First", colorID: .gray),
            WorkbenchTag(key: "2", label: "Second", colorID: .gray),
        ]
    )
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: 1,
        row: row,
        showsCueGroup: true
    )

    #expect(fixture.coordinator.selectableTextForTesting(row: 0, columnID: "cues") == "primary\nextra")
    let cueFragments = fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "cues")
    #expect(cueFragments.map(\.logicalRange) == [
        NSRange(location: 0, length: 7),
        NSRange(location: 8, length: 5),
    ])

    #expect(fixture.coordinator.selectableTextForTesting(row: 0, columnID: "language") == "First, Second")
    let tagFragments = fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "language")
    #expect(tagFragments.map(\.logicalRange) == [
        NSRange(location: 0, length: 5),
        NSRange(location: 7, length: 6),
    ])
    let secondTagPoint = CGPoint(x: tagFragments[1].textBounds.midX, y: tagFragments[1].textBounds.midY)
    let secondTagPosition = try #require(
        fixture.coordinator.textPositionForTesting(
            row: 0,
            columnID: "language",
            point: secondTagPoint
        )
    )
    #expect(secondTagPosition.utf16Offset >= 7)

    let tagPaddingPoint = CGPoint(
        x: tagFragments[0].clipRect.minX - 3,
        y: tagFragments[0].clipRect.midY
    )
    #expect(
        fixture.coordinator.textPositionForTesting(
            row: 0,
            columnID: "language",
            point: tagPaddingPoint
        ) == nil
    )
}

@MainActor
@Test
func subtitleTableViewDoesNotReplayReloadForTheSameRowsVersion() {
    let row = dynamicTableRow(
        id: 1,
        primary: "primary",
        group: ["context one", "context two", "primary"],
        primaryIndex: 2
    )
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: 1,
        row: row,
        showsCueGroup: true
    )
    let rowHeightBeforeUpdate = fixture.coordinator.rowHeightForTesting(0)

    #expect(
        fixture.coordinator.textFragmentInfoForTesting(
            row: 0,
            columnID: "cues"
        ).count == 3
    )

    fixture.coordinator.update(
        tableName: "test-search",
        rowCount: 1,
        rowProvider: { _ in row },
        rowsVersion: 1,
        rowsUpdate: .reload,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        showsCueGroup: true,
        scrollResetToken: 0,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in true },
        selectionHeaderState: .indeterminate,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    #expect(fixture.coordinator.rowHeightForTesting(0) == rowHeightBeforeUpdate)
    #expect(
        fixture.coordinator.textFragmentInfoForTesting(
            row: 0,
            columnID: "cues"
        ).count == 3
    )
}

@MainActor
@Test
func subtitleTableViewCueFallbackAlwaysKeepsPrimaryFragment() {
    let row = SubtitleTableRow(
        id: 1,
        primaryCueID: 41,
        displayTitle: "Episode",
        primaryCueText: "primary",
        cueGroupTexts: ["extra", "primary"],
        primaryGroupIndex: 1
    )
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: 1,
        row: row,
        showsCueGroup: true
    )

    let fragments = fixture.coordinator.cueTextFragmentInfoForTesting(
        row: 0,
        measurement: SubtitleTableRowMeasurement(
            height: fixture.coordinator.currentRowHeight,
            primaryLineCount: 1,
            extraCueLineCounts: []
        )
    )

    #expect(fragments.map(\.logicalRange) == [NSRange(location: 0, length: 7)])
}

@MainActor
@Test
func subtitleTableViewLanguageTagDragFocusIgnoresClippedOverflow() throws {
    let longLabel = String(repeating: "Long tag ", count: 30)
    let row = SubtitleTableRow(
        id: 1,
        primaryCueID: 41,
        displayTitle: "Episode",
        primaryCueText: "primary",
        cueGroupTexts: ["primary"],
        primaryGroupIndex: 0,
        tags: [
            WorkbenchTag(key: "1", label: longLabel, colorID: .gray),
            WorkbenchTag(key: "2", label: "Second", colorID: .gray),
        ]
    )
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: 1,
        row: row
    )
    let fragments = fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "language")
    let first = try #require(fragments.first)
    let second = try #require(fragments.last)
    #expect(fragments.count == 2)
    #expect(first.textBounds.maxY <= first.clipRect.maxY)

    let secondPoint = CGPoint(x: second.textBounds.midX, y: second.textBounds.midY)
    let position = try #require(
        fixture.coordinator.textPositionForTesting(
            row: 0,
            columnID: "language",
            point: secondPoint,
            requiresTextHit: false
        )
    )
    #expect(position.utf16Offset >= (longLabel as NSString).length + 2)
}

@MainActor
@Test
func subtitleTableViewOnlyInvalidatesWhenTextSelectionActuallyChanges() throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "First Episode", cues: "first cue"),
        SubtitleTableRow(id: 2, displayTitle: "Second Episode", cues: "second cue"),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let start = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "display").first
    )
    let end = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 1, columnID: "cues").first
    )
    let startWindowPoint = fixture.documentView.convert(
        CGPoint(x: start.textBounds.midX, y: start.textBounds.midY),
        to: nil
    )
    let endWindowPoint = fixture.documentView.convert(
        CGPoint(x: end.textBounds.midX, y: end.textBounds.midY),
        to: nil
    )

    fixture.documentView.needsDisplay = false
    fixture.coordinator.resetTextSelectionInvalidationCountForTesting()
    #expect(fixture.coordinator.handleMouseDown(windowPoint: startWindowPoint))
    #expect(fixture.documentView.needsDisplay == false)
    #expect(fixture.coordinator.textSelectionInvalidationCountForTesting() == 0)

    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.textSelectionInvalidationCountForTesting() > 0)

    fixture.coordinator.resetTextSelectionInvalidationCountForTesting()
    fixture.documentView.needsDisplay = false
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.documentView.needsDisplay == false)
    #expect(fixture.coordinator.textSelectionInvalidationCountForTesting() == 0)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: endWindowPoint))
    #expect(fixture.documentView.needsDisplay == false)
    #expect(fixture.coordinator.textSelectionInvalidationCountForTesting() == 0)
}

@MainActor
@Test
func subtitleTableViewArmsNoninteractiveCellPaddingUntilDragThreshold() throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "First Episode", cues: "first cue"),
        SubtitleTableRow(id: 2, displayTitle: "Second Episode", cues: "second cue"),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let displayCell = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "display")
    )
    let endFragment = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 1, columnID: "cues").first
    )
    let blankPoint = CGPoint(x: displayCell.maxX - 4, y: displayCell.midY)
    let blankWindowPoint = fixture.documentView.convert(blankPoint, to: nil)
    let jitterWindowPoint = CGPoint(x: blankWindowPoint.x + 2.5, y: blankWindowPoint.y)
    let endWindowPoint = fixture.documentView.convert(
        CGPoint(x: endFragment.textBounds.maxX, y: endFragment.textBounds.midY),
        to: nil
    )

    #expect(
        fixture.coordinator.documentTextPositionForTesting(
            point: blankPoint,
            requiresTextHit: true
        ) == nil
    )
    #expect(fixture.coordinator.handleMouseDown(windowPoint: blankWindowPoint))
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting() == false)
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: jitterWindowPoint))
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting() == false)
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting())
    #expect(fixture.coordinator.handleMouseUp(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "cues") != nil)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 1, columnID: "cues") != nil)
}

@MainActor
@Test
func subtitleTableViewDoesNotAutoScrollWhileBlankInteractionIsOnlyArmed() throws {
    let rows = (0..<100).map {
        SubtitleTableRow(id: $0 + 1, displayTitle: "Episode \($0)", cues: "cue \($0)")
    }
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let displayCell = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "display")
    )
    let blankPoint = CGPoint(x: displayCell.maxX - 4, y: displayCell.midY)
    let blankWindowPoint = fixture.documentView.convert(blankPoint, to: nil)
    let beforeOrigin = fixture.scrollView.contentView.bounds.origin

    #expect(fixture.coordinator.handleMouseDown(windowPoint: blankWindowPoint))
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting() == false)
    fixture.coordinator.textDragAutoScrollTickForTesting()
    #expect(fixture.scrollView.contentView.bounds.origin == beforeOrigin)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: blankWindowPoint))
}

@MainActor
@Test
func subtitleTableViewSelectionColumnBlankCanStartTextDrag() throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "First Episode", cues: "first cue"),
        SubtitleTableRow(id: 2, displayTitle: "Second Episode", cues: "second cue"),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let checkbox = try #require(fixture.coordinator.checkboxRectForTesting(row: 0))
    let endFragment = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 1, columnID: "cues").first
    )
    let blankPoint = CGPoint(x: 4, y: checkbox.midY)
    let blankWindowPoint = fixture.documentView.convert(blankPoint, to: nil)
    let endWindowPoint = fixture.documentView.convert(
        CGPoint(x: endFragment.textBounds.maxX, y: endFragment.textBounds.midY),
        to: nil
    )

    #expect(fixture.coordinator.handleMouseDown(windowPoint: blankWindowPoint))
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting() == false)
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting())
    #expect(fixture.coordinator.handleMouseUp(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "display") != nil)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 1, columnID: "cues") != nil)
}

@MainActor
@Test
func subtitleTableViewShortBodyBlankProjectsToLastActualRow() throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "First Episode", cues: "first cue"),
        SubtitleTableRow(id: 2, displayTitle: "Second Episode", cues: "second cue"),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let displayCell = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 1, columnID: "display")
    )
    let firstFragment = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "display").first
    )
    let blankY = fixture.coordinator.totalRowsHeightForTesting() + 24
    #expect(blankY < fixture.documentView.visibleRect.maxY)
    let blankPoint = CGPoint(x: displayCell.midX, y: blankY)
    let projected = try #require(
        fixture.coordinator.documentTextPositionForTesting(
            point: blankPoint,
            requiresTextHit: false
        )
    )
    #expect(projected.row == .body(1))

    let blankWindowPoint = fixture.documentView.convert(blankPoint, to: nil)
    let endWindowPoint = fixture.documentView.convert(
        CGPoint(x: firstFragment.textBounds.minX, y: firstFragment.textBounds.midY),
        to: nil
    )
    #expect(fixture.coordinator.handleMouseDown(windowPoint: blankWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 1, columnID: "display") != nil)
}

@MainActor
@Test
func subtitleTableViewInteractiveCuePaddingSuppressesClickWithoutStartingSelection() throws {
    var playCount = 0
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: 2,
        onPlay: { _ in playCount += 1 }
    )
    let cueHover = try #require(
        fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues")
    )
    let endFragment = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 1, columnID: "cues").first
    )
    let paddingPoint = CGPoint(x: cueHover.maxX - 1, y: cueHover.midY)
    let startWindowPoint = fixture.documentView.convert(paddingPoint, to: nil)
    let endWindowPoint = fixture.documentView.convert(
        CGPoint(x: endFragment.textBounds.midX, y: endFragment.textBounds.midY),
        to: nil
    )

    #expect(fixture.coordinator.cueTextHitTestForTesting(row: 0, point: paddingPoint))
    #expect(
        fixture.coordinator.documentTextPositionForTesting(
            point: paddingPoint,
            requiresTextHit: true
        ) == nil
    )
    #expect(fixture.coordinator.handleMouseDown(windowPoint: startWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting() == false)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: endWindowPoint))
    #expect(playCount == 0)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 1, columnID: "cues") == nil)
}

@MainActor
@Test
func subtitleTableViewEmptyBodyBlankFallsBackToHeaderText() throws {
    let fixture = makeAttachedVirtualTableCoordinator(width: 1_400, rowCount: 0)
    let headerFragments = fixture.coordinator.headerTextFragmentInfoForTesting()
    let display = try #require(headerFragments.first(where: { $0.columnID == "display" }))
    let cues = try #require(headerFragments.first(where: { $0.columnID == "cues" }))
    let startPoint = CGPoint(x: display.textBounds.minX, y: fixture.documentView.visibleRect.midY)
    let endPoint = CGPoint(x: cues.textBounds.maxX, y: fixture.documentView.visibleRect.midY)
    let projected = try #require(
        fixture.coordinator.documentTextPositionForTesting(
            point: startPoint,
            requiresTextHit: false
        )
    )
    #expect(projected.row == .header)

    let startWindowPoint = fixture.documentView.convert(startPoint, to: nil)
    let endWindowPoint = fixture.documentView.convert(endPoint, to: nil)
    #expect(fixture.coordinator.handleMouseDown(windowPoint: startWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: endWindowPoint))
    #expect(!fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "display").isEmpty)
    #expect(!fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "cues").isEmpty)
}

@MainActor
@Test
func subtitleTableViewExternalSelectionTargetBeginsUpdatesEndsAndCancels() throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "First Episode", cues: "first cue"),
        SubtitleTableRow(id: 2, displayTitle: "Second Episode", cues: "second cue"),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 1_400, height: 260),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = fixture.container
    #expect(fixture.coordinator.focusFirstVisibleCheckboxFromKeyboard())
    #expect(fixture.coordinator.focusedCheckboxRowForTesting() != nil)
    let display = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "display").first
    )
    let cues = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 1, columnID: "cues").first
    )
    let tableWindowRect = try #require(fixture.coordinator.externalTextSelectionWindowRect)
    let currentWindowPoint = fixture.documentView.convert(
        CGPoint(x: display.textBounds.midX, y: display.textBounds.midY),
        to: nil
    )
    let endWindowPoint = fixture.documentView.convert(
        CGPoint(x: cues.textBounds.maxX, y: cues.textBounds.midY),
        to: nil
    )
    let startWindowPoint = CGPoint(
        x: tableWindowRect.minX - 24,
        y: currentWindowPoint.y
    )

    #expect(fixture.coordinator.canBeginExternalTextSelection)
    #expect(
        fixture.coordinator.beginExternalTextSelection(
            startWindowPoint: startWindowPoint,
            currentWindowPoint: currentWindowPoint
        )
    )
    #expect(fixture.coordinator.pendingTextSelectionHasBegunForTesting())
    #expect(fixture.coordinator.focusedCheckboxRowForTesting() == nil)
    #expect(window.firstResponder === fixture.documentView)
    #expect(fixture.coordinator.updateExternalTextSelection(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.endExternalTextSelection(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 1, columnID: "cues") != nil)

    fixture.coordinator.clearTextSelectionForTesting()
    #expect(
        fixture.coordinator.beginExternalTextSelection(
            startWindowPoint: startWindowPoint,
            currentWindowPoint: currentWindowPoint
        )
    )
    fixture.coordinator.cancelExternalTextSelection()
    #expect(fixture.coordinator.updateExternalTextSelection(windowPoint: endWindowPoint) == false)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 1, columnID: "cues") == nil)

    window.contentView = NSView()
    #expect(fixture.coordinator.externalTextSelectionWindowRect == nil)
    #expect(fixture.coordinator.canBeginExternalTextSelection == false)
}

@MainActor
@Test
func subtitleTableViewHeaderTextDragSelectsAndClickOpensNoMenu() throws {
    let fixture = makeAttachedVirtualTableCoordinator(width: 1_400, rowCount: 2)
    let fragments = fixture.coordinator.headerTextFragmentInfoForTesting()
    let display = try #require(fragments.first(where: { $0.columnID == "display" }))
    let cues = try #require(fragments.first(where: { $0.columnID == "cues" }))
    let startPoint = CGPoint(x: display.textBounds.midX, y: display.textBounds.midY)
    let endPoint = CGPoint(x: cues.textBounds.midX, y: cues.textBounds.midY)
    let startWindowPoint = fixture.header.convert(startPoint, to: nil)
    let endWindowPoint = fixture.header.convert(endPoint, to: nil)

    #expect(fixture.coordinator.handleHeaderMouseDown(windowPoint: startWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: endWindowPoint))
    #expect(!fixture.coordinator.isMenuOpenForTesting())
    #expect(!fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "display").isEmpty)
    #expect(!fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "cues").isEmpty)

    fixture.coordinator.clearTextSelectionForTesting()
    let jitterPoint = CGPoint(x: startWindowPoint.x + 2.5, y: startWindowPoint.y)
    #expect(fixture.coordinator.handleHeaderMouseDown(windowPoint: startWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: jitterPoint))
    #expect(!fixture.coordinator.isMenuOpenForTesting())
    #expect(fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "display").isEmpty)
}

@MainActor
@Test
func subtitleTableViewHeaderNonInteractiveBlankStartsDragButClickDoesNothing() throws {
    let fixture = makeAttachedVirtualTableCoordinator(width: 1_400, rowCount: 2)
    let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 1_400, height: 260),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = fixture.container
    fixture.container.layoutSubtreeIfNeeded()
    fixture.header.layoutSubtreeIfNeeded()
    let layout = fixture.coordinator.headerColumnLayoutForRendering(
        viewportWidth: fixture.header.bounds.width,
        height: fixture.header.bounds.height
    )
    let displayCell = try #require(layout.rect(for: "display"))
    let display = try #require(
        fixture.coordinator.headerTextFragmentInfoForTesting().first(where: {
            $0.columnID == "display"
        })
    )
    let cues = try #require(
        fixture.coordinator.headerTextFragmentInfoForTesting().first(where: {
            $0.columnID == "cues"
        })
    )
    let blankPoint = CGPoint(
        x: max(display.textBounds.maxX + 20, displayCell.maxX - 24),
        y: displayCell.midY
    )
    #expect(displayCell.contains(blankPoint))
    #expect(fixture.header.shouldRouteTextSelectionMouseDownForTesting(at: blankPoint))
    #expect(fixture.header.shouldRouteTextSelectionMouseDownForTesting(at: CGPoint(
        x: displayCell.minX + 4,
        y: displayCell.midY
    )))
    #expect(fixture.header.shouldRouteTextSelectionMouseDownForTesting(at: CGPoint(
        x: layout.indexRect.midX,
        y: layout.indexRect.midY
    )))
    #expect(fixture.header.shouldRouteTextSelectionMouseDownForTesting(at: CGPoint(
        x: layout.indexRect.midX,
        y: layout.indexRect.minY + 2
    )))
    #expect(fixture.header.shouldRouteTextSelectionMouseDownForTesting(at: CGPoint(
        x: layout.indexRect.midX,
        y: layout.indexRect.maxY - 2
    )))

    let blankWindowPoint = fixture.header.convert(blankPoint, to: nil)
    #expect(fixture.coordinator.handleHeaderMouseDown(windowPoint: blankWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: blankWindowPoint))
    #expect(!fixture.coordinator.isMenuOpenForTesting())
    #expect(fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "display").isEmpty)

    let cuesWindowPoint = fixture.header.convert(
        CGPoint(x: cues.textBounds.midX, y: cues.textBounds.midY),
        to: nil
    )
    #expect(fixture.coordinator.handleHeaderMouseDown(windowPoint: blankWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: cuesWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: cuesWindowPoint))
    #expect(!fixture.coordinator.isMenuOpenForTesting())
    #expect(
        !fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "display").isEmpty ||
            !fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "cues").isEmpty
    )
}

@MainActor
@Test
func subtitleTableViewHeaderTextDragKeepsHeaderFocusOutsideItsSidesAndTop() throws {
    let fixture = makeAttachedVirtualTableCoordinator(width: 1_400, rowCount: 2)
    let fragments = fixture.coordinator.headerTextFragmentInfoForTesting()
    let display = try #require(fragments.first(where: { $0.columnID == "display" }))
    let cues = try #require(fragments.first(where: { $0.columnID == "cues" }))
    let headerWindowRect = fixture.header.convert(fixture.header.bounds, to: nil)
    let bodyWindowRect = fixture.scrollView.convert(fixture.scrollView.bounds, to: nil)
    let startWindowPoint = fixture.header.convert(
        CGPoint(x: display.textBounds.midX, y: display.textBounds.midY),
        to: nil
    )

    let outsideRight = CGPoint(
        x: headerWindowRect.maxX + 80,
        y: headerWindowRect.midY
    )
    #expect(fixture.coordinator.handleHeaderMouseDown(windowPoint: startWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: outsideRight))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: outsideRight))
    #expect(!fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "cues").isEmpty)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "display") == nil)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "cues") == nil)

    fixture.coordinator.clearTextSelectionForTesting()
    let cuesWindowPoint = fixture.header.convert(
        CGPoint(x: cues.textBounds.midX, y: cues.textBounds.midY),
        to: nil
    )
    let outsideTopY = bodyWindowRect.midY < headerWindowRect.midY
        ? headerWindowRect.maxY + 80
        : headerWindowRect.minY - 80
    let outsideTop = CGPoint(x: startWindowPoint.x, y: outsideTopY)
    #expect(fixture.coordinator.handleHeaderMouseDown(windowPoint: cuesWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: outsideTop))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: outsideTop))
    #expect(!fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "cues").isEmpty)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "display") == nil)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "cues") == nil)
}

@MainActor
@Test
func subtitleTableViewSelectionCrossesBetweenFixedHeaderAndBody() throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "Episode", cues: "first cue"),
        SubtitleTableRow(id: 2, displayTitle: "Episode 2", cues: "second cue"),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let headerDisplay = try #require(
        fixture.coordinator.headerTextFragmentInfoForTesting().first(where: {
            $0.columnID == "display"
        })
    )
    let bodyCue = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 1, columnID: "cues").first
    )
    let headerWindowPoint = fixture.header.convert(
        CGPoint(x: headerDisplay.textBounds.midX, y: headerDisplay.textBounds.midY),
        to: nil
    )
    let bodyWindowPoint = fixture.documentView.convert(
        CGPoint(x: bodyCue.textBounds.midX, y: bodyCue.textBounds.midY),
        to: nil
    )

    #expect(fixture.coordinator.handleHeaderMouseDown(windowPoint: headerWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: bodyWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: bodyWindowPoint))
    #expect(!fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "display").isEmpty)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "display") != nil)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 1, columnID: "cues") != nil)

    fixture.coordinator.clearTextSelectionForTesting()
    #expect(fixture.coordinator.handleMouseDown(windowPoint: bodyWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: headerWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: headerWindowPoint))
    #expect(!fixture.coordinator.headerTextSelectionRectsForTesting(columnID: "display").isEmpty)
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 1, columnID: "cues") != nil)
}

@MainActor
@Test
func subtitleTableViewResponderSelectAllCopiesVisibleColumnsWithoutCheckboxes() async throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "Episode 1", cues: "first"),
        SubtitleTableRow(id: 2, displayTitle: "Episode 2", cues: "second"),
    ]
    var rowProviderCalls = 0
    var checkboxToggleCount = 0
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: {
            rowProviderCalls += 1
            return rows[$0]
        },
        onToggleRowSelection: { _ in checkboxToggleCount += 1 }
    )
    rowProviderCalls = 0

    fixture.documentView.selectAll(nil)
    #expect(fixture.coordinator.textSelectionSelectsAllForTesting())
    #expect(rowProviderCalls == 0)
    #expect(checkboxToggleCount == 0)

    let pasteboard = NSPasteboard(name: .init("SubtitleTableTextCopy-\(UUID().uuidString)"))
    defer { pasteboard.clearContents() }
    fixture.coordinator.copyTableTextSelection(to: pasteboard)
    await fixture.coordinator.waitForTextCopyForTesting()
    let copied = try #require(pasteboard.string(forType: .tabularText))
    #expect(copied.hasPrefix("Display Title\tCues"))
    #expect(copied.contains("Episode 1\tfirst"))
    #expect(copied.contains("Episode 2\tsecond"))
    #expect(!copied.contains("Selection"))
    #expect(checkboxToggleCount == 0)
}

@MainActor
@Test
func subtitleTableViewTextCopyLoadsExactBatches() async throws {
    let rowCount = 513
    var requestedRanges: [Range<Int>] = []
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: 1,
        rowProvider: { _ in nil },
        allResultsTextCopyRowCount: rowCount,
        loadRowsForTextCopy: { range in
            requestedRanges.append(range)
            return range.map {
                SubtitleTableRow(id: $0 + 1, displayTitle: "Episode \($0)", cues: "cue \($0)")
            }
        }
    )
    let pasteboard = NSPasteboard(name: .init("SubtitleTableTextCopyBatch-\(UUID().uuidString)"))
    defer { pasteboard.clearContents() }

    fixture.documentView.selectAll(nil)
    fixture.coordinator.copyTableTextSelection(to: pasteboard)
    await fixture.coordinator.waitForTextCopyForTesting()

    #expect(requestedRanges == [0..<512, 512..<513])
    let copied = try #require(pasteboard.string(forType: .tabularText))
    #expect(copied.contains("Episode 0\tcue 0"))
    #expect(copied.contains("Episode 512\tcue 512"))
}

@MainActor
@Test
func subtitleTableViewPartialTextCopyUsesDisplayedRowsInsteadOfFullResultLoader() async throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "Visible 1", cues: "first cue"),
        SubtitleTableRow(id: 2, displayTitle: "Visible 2", cues: "second cue"),
    ]
    var loaderCallCount = 0
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] },
        allResultsTextCopyRowCount: 1_000,
        loadRowsForTextCopy: { range in
            loaderCallCount += 1
            return range.map {
                SubtitleTableRow(id: $0 + 100, displayTitle: "Wrong \($0)", cues: "wrong")
            }
        }
    )
    let start = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "display").first
    )
    let end = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 1, columnID: "cues").first
    )
    let startWindowPoint = fixture.documentView.convert(
        CGPoint(x: start.textBounds.minX, y: start.textBounds.midY),
        to: nil
    )
    let endWindowPoint = fixture.documentView.convert(
        CGPoint(x: end.textBounds.maxX, y: end.textBounds.midY),
        to: nil
    )
    #expect(fixture.coordinator.handleMouseDown(windowPoint: startWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: endWindowPoint))

    let pasteboard = NSPasteboard(name: .init("SubtitleTablePartialTextCopy-\(UUID().uuidString)"))
    defer { pasteboard.clearContents() }
    fixture.coordinator.copyTableTextSelection(to: pasteboard)
    await fixture.coordinator.waitForTextCopyForTesting()

    #expect(loaderCallCount == 0)
    let copied = try #require(pasteboard.string(forType: .tabularText))
    #expect(copied.contains("Visible 1"))
    #expect(copied.contains("Visible 2"))
    #expect(!copied.contains("Wrong"))
}

@MainActor
@Test
func subtitleTableViewAsyncTextCopyDoesNotOverwriteNewerPasteboardContent() async {
    let pasteboard = NSPasteboard(name: .init("SubtitleTableTextCopyRace-\(UUID().uuidString)"))
    defer { pasteboard.clearContents() }
    pasteboard.clearContents()
    pasteboard.setString("older", forType: .string)
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: 1,
        rowProvider: { _ in nil },
        loadRowsForTextCopy: { range in
            pasteboard.clearContents()
            pasteboard.setString("newer", forType: .string)
            return range.map {
                SubtitleTableRow(id: $0 + 1, displayTitle: "Episode", cues: "cue")
            }
        }
    )

    fixture.documentView.selectAll(nil)
    fixture.coordinator.copyTableTextSelection(to: pasteboard)
    await fixture.coordinator.waitForTextCopyForTesting()

    #expect(pasteboard.string(forType: .string) == "newer")
    #expect(pasteboard.string(forType: .tabularText) == nil)
}

@Test
func subtitleTableTextDragAutoScrollGeometryHandlesEdgesAndBounds() {
    let viewport = CGRect(x: 100, y: 100, width: 400, height: 200)
    let contentSize = CGSize(width: 1_000, height: 2_000)
    let viewportSize = viewport.size
    let origin = CGPoint(x: 200, y: 500)

    #expect(
        SubtitleTableTextDragAutoScrollGeometry.nextOrigin(
            pointer: CGPoint(x: viewport.midX, y: viewport.midY),
            viewport: viewport,
            currentOrigin: origin,
            contentSize: contentSize,
            viewportSize: viewportSize
        ) == origin
    )
    let bottomRight = SubtitleTableTextDragAutoScrollGeometry.nextOrigin(
        pointer: CGPoint(x: viewport.maxX, y: viewport.minY),
        viewport: viewport,
        currentOrigin: origin,
        contentSize: contentSize,
        viewportSize: viewportSize
    )
    #expect(bottomRight.x > origin.x)
    #expect(bottomRight.y > origin.y)

    let topLeft = SubtitleTableTextDragAutoScrollGeometry.nextOrigin(
        pointer: CGPoint(x: viewport.minX, y: viewport.maxY),
        viewport: viewport,
        currentOrigin: .zero,
        contentSize: contentSize,
        viewportSize: viewportSize
    )
    #expect(topLeft == .zero)

    let horizontalOnly = SubtitleTableTextDragAutoScrollGeometry.nextOrigin(
        pointer: CGPoint(x: viewport.maxX, y: viewport.maxY),
        viewport: viewport,
        currentOrigin: origin,
        contentSize: contentSize,
        viewportSize: viewportSize,
        allowsVerticalScrolling: false
    )
    #expect(horizontalOnly.x > origin.x)
    #expect(horizontalOnly.y == origin.y)
}

@MainActor
@Test
func subtitleTableViewAutoScrollTickMovesViewportAndKeepsDragSelection() throws {
    let rows = (0..<100).map {
        SubtitleTableRow(id: $0 + 1, displayTitle: "Episode \($0)", cues: "cue \($0)")
    }
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let start = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "display").first
    )
    let startWindowPoint = fixture.documentView.convert(
        CGPoint(x: start.textBounds.midX, y: start.textBounds.midY),
        to: nil
    )
    let viewport = fixture.scrollView.contentView.convert(
        fixture.scrollView.contentView.bounds,
        to: nil
    )
    let edgeWindowPoint = CGPoint(x: startWindowPoint.x, y: viewport.minY + 1)
    let beforeY = fixture.scrollView.contentView.bounds.minY

    #expect(fixture.coordinator.handleMouseDown(windowPoint: startWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: edgeWindowPoint))
    fixture.coordinator.textDragAutoScrollTickForTesting()
    let afterY = fixture.scrollView.contentView.bounds.minY
    #expect(afterY > beforeY)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: edgeWindowPoint))
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "display") != nil)
}

@MainActor
@Test
func subtitleTableViewSelectModeDisablesInternalTextSelection() throws {
    var toggledRows: [Int] = []
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: 1,
        isSelectionMode: true,
        onToggleRowSelection: { toggledRows.append($0) }
    )
    let displayRect = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "display")
    )
    let rowWindowPoint = fixture.documentView.convert(
        CGPoint(x: displayRect.midX, y: displayRect.midY),
        to: nil
    )

    fixture.coordinator.selectAllTableText()
    #expect(!fixture.coordinator.textSelectionSelectsAllForTesting())
    #expect(fixture.coordinator.handleMouseDown(windowPoint: rowWindowPoint))
    #expect(toggledRows == [0])
    #expect(!fixture.coordinator.handleMouseDragged(windowPoint: rowWindowPoint))
    #expect(fixture.coordinator.textSelectionRangeForTesting(row: 0, columnID: "cues") == nil)
}

@MainActor
@Test
func subtitleTableViewAppLeftMouseDownClearsEveryAttachedTableSelection() throws {
    let first = makeAttachedVirtualTableCoordinator()
    let second = makeAttachedVirtualTableCoordinator()
    defer {
        first.coordinator.quiesceForTesting()
        second.coordinator.quiesceForTesting()
    }
    first.coordinator.selectAllTableText()
    second.coordinator.selectAllTableText()
    #expect(first.coordinator.textSelectionSelectsAllForTesting())
    #expect(second.coordinator.textSelectionSelectsAllForTesting())

    let event = subtitleTableLeftMouseDownEvent()
    let routedEvent = CueSeekerPointerEventRouter.routeLeftMouseDown(event)

    #expect(routedEvent === event)
    #expect(first.coordinator.textSelectionSelectsAllForTesting() == false)
    #expect(second.coordinator.textSelectionSelectsAllForTesting() == false)

    let start = try #require(first.coordinator.textFragmentInfoForTesting(
        row: 0,
        columnID: "display"
    ).first)
    let end = try #require(first.coordinator.textFragmentInfoForTesting(
        row: 1,
        columnID: "cues"
    ).first)
    let startWindowPoint = first.documentView.convert(
        CGPoint(x: start.textBounds.midX, y: start.textBounds.midY),
        to: nil
    )
    let endWindowPoint = first.documentView.convert(
        CGPoint(x: end.textBounds.midX, y: end.textBounds.midY),
        to: nil
    )
    #expect(first.coordinator.handleMouseDown(windowPoint: startWindowPoint))
    #expect(first.coordinator.handleMouseDragged(windowPoint: endWindowPoint))
    #expect(first.coordinator.handleMouseUp(windowPoint: endWindowPoint))
    #expect(first.coordinator.textSelectionRangeForTesting(row: 1, columnID: "cues") != nil)
}

@MainActor
@Test
func subtitleTableViewCueDragSuppressesPlayAfterThresholdAndClickStillPlays() throws {
    var playCount = 0
    let fixture = makeAttachedVirtualTableCoordinator(onPlay: { _ in playCount += 1 })
    let cueFragment = try #require(
        fixture.coordinator.textFragmentInfoForTesting(row: 0, columnID: "cues").first
    )
    let cuePoint = CGPoint(x: cueFragment.textBounds.midX, y: cueFragment.textBounds.midY)
    let cueWindowPoint = fixture.documentView.convert(cuePoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: cueWindowPoint))
    #expect(playCount == 0)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: cueWindowPoint))
    #expect(playCount == 1)

    let dragWindowPoint = CGPoint(x: cueWindowPoint.x + 8, y: cueWindowPoint.y)
    #expect(fixture.coordinator.handleMouseDown(windowPoint: cueWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: dragWindowPoint))
    #expect(fixture.coordinator.handleMouseDragged(windowPoint: cueWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: cueWindowPoint))
    #expect(playCount == 1)

    let jitterWindowPoint = CGPoint(x: cueWindowPoint.x + 2.5, y: cueWindowPoint.y)
    #expect(fixture.coordinator.handleMouseDown(windowPoint: cueWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: jitterWindowPoint))
    #expect(playCount == 2)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: cueWindowPoint))
    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: cueWindowPoint))
    fixture.coordinator.dismissMenu()
    #expect(fixture.coordinator.handleMouseUp(windowPoint: cueWindowPoint) == false)
    #expect(playCount == 2)
}

@MainActor
@Test
func subtitleTableUnavailableExcerptBlocksInteractiveActionsButKeepsAllowedMenuActions() throws {
    let row = SubtitleTableRow(
        id: 7,
        primaryCueID: 42,
        subtitlePath: "/tmp/CueSeeker/Series/episode.ass",
        displayTitle: "Episode",
        startTime: "00:01",
        endTime: "00:02",
        primaryCueText: "Unavailable Cue",
        cueGroupTexts: ["Unavailable Cue"],
        primaryGroupIndex: 0,
        cueState: .unavailable(.videoMissing)
    )
    var playCount = 0
    var openFolderCount = 0
    var removeCount = 0
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: 1,
        row: row,
        rowActionMenuStyle: .excerpt,
        onPlay: { _ in playCount += 1 },
        onOpenSubtitleFile: { _ in openFolderCount += 1 },
        onRemoveExcerpt: { _ in removeCount += 1 }
    )

    let cueFragment = try #require(
        fixture.coordinator.textFragmentInfoForTesting(
            row: 0,
            columnID: "cues"
        ).first
    )
    let cuePoint = CGPoint(
        x: cueFragment.textBounds.midX,
        y: cueFragment.textBounds.midY
    )
    let cueWindowPoint = fixture.documentView.convert(cuePoint, to: nil)
    #expect(fixture.coordinator.pointerShape(atWindowPoint: cueWindowPoint) == .arrow)
    #expect(fixture.coordinator.handleMouseDown(windowPoint: cueWindowPoint))
    #expect(fixture.coordinator.handleMouseUp(windowPoint: cueWindowPoint))
    #expect(playCount == 0)

    fixture.coordinator.performRowActionForTesting(.play, row: 0)
    fixture.coordinator.performRowActionForTesting(.openSubtitleFolder, row: 0)
    fixture.coordinator.performRowActionForTesting(.removeExcerpt, row: 0)
    #expect(playCount == 0)
    #expect(openFolderCount == 1)
    #expect(removeCount == 1)
}

@MainActor
@Test
func subtitleTableViewAnswersTheArrowWhenExternalLayerIsOpen() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    // A tall container: this case only needs the menu to open, not to land
    // anywhere in particular.
    fixture.container.frame.size.height = 800
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesWindowPoint = fixture.documentView.convert(CGPoint(x: cuesRect.midX, y: cuesRect.midY), to: nil)

    #expect(fixture.coordinator.pointerShape(atWindowPoint: cuesWindowPoint) == .grab)

    fixture.coordinator.isCoveredByHigherLayer = true

    #expect(fixture.coordinator.pointerShape(atWindowPoint: cuesWindowPoint) == .arrow)
}

@MainActor
@Test
func subtitleTableViewDismissMenuKeepsTheHandAvailable() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let anchorFrame = CGRect(
        x: SubtitleTableMetrics.indexColumnWidth + SubtitleTableMetrics.nameColumnWidth,
        y: 14,
        width: 520,
        height: fixture.coordinator.currentRowHeight
    )
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesPoint = CGPoint(x: cuesRect.midX, y: cuesRect.midY)

    let cuesWindowPoint = fixture.documentView.convert(cuesPoint, to: nil)

    fixture.coordinator.showMenu(for: 0, buttonFrame: anchorFrame)
    #expect(fixture.coordinator.pointerShape(atWindowPoint: cuesWindowPoint) == .arrow)
    fixture.coordinator.dismissMenu()

    #expect(fixture.coordinator.pointerShape(atWindowPoint: cuesWindowPoint) == .grab)
}

@MainActor
@Test
func subtitleTableViewResolvesDocumentedDynamicRowHeightsAndPrimarySlotAlignment() throws {
    let rows = [
        dynamicTableRow(id: 1, primary: "one"),
        dynamicTableRow(id: 2, primary: "one\ntwo"),
        dynamicTableRow(id: 3, primary: "one\ntwo\nthree"),
        dynamicTableRow(id: 4, primary: "main", group: ["extra", "main"], primaryIndex: 1),
        dynamicTableRow(id: 5, primary: "main", group: ["extra one", "extra two", "main"], primaryIndex: 2),
        dynamicTableRow(id: 6, primary: "main one\nmain two", group: ["extra", "main one\nmain two"], primaryIndex: 1),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: rows.count,
        rowProvider: { rows[$0] },
        showsCueGroup: true
    )

    #expect(fixture.coordinator.rowHeightForTesting(0) == 40)
    #expect(fixture.coordinator.rowHeightForTesting(1) == 64)
    #expect(fixture.coordinator.rowHeightForTesting(2) == 88)
    #expect(fixture.coordinator.rowHeightForTesting(3) == 68)
    #expect(fixture.coordinator.rowHeightForTesting(4) == 96)
    #expect(fixture.coordinator.rowHeightForTesting(5) == 92)

    let checkbox = try #require(fixture.coordinator.checkboxRectForTesting(row: 3))
    let expectedRowCenterY = fixture.coordinator.rowYOffsetForTesting(3)
        + fixture.coordinator.rowHeightForTesting(3) / 2
    #expect(abs(checkbox.midY - expectedRowCenterY) < 0.5)
}

@MainActor
@Test
func subtitleTableViewUsesTallestVisibleColumnAndCentersCheckbox() throws {
    let rows = [
        SubtitleTableRow(id: 1, displayTitle: "Short", cues: "cue"),
        SubtitleTableRow(
            id: 2,
            displayTitle: "Line one\nLine two\nLine three\nLine four",
            cues: "cue"
        ),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )

    #expect(fixture.coordinator.rowHeightForTesting(0) == 40)
    #expect(fixture.coordinator.rowHeightForTesting(1) > 40)

    let checkbox = try #require(fixture.coordinator.checkboxRectForTesting(row: 1))
    let expectedCenter = fixture.coordinator.rowYOffsetForTesting(1)
        + fixture.coordinator.rowHeightForTesting(1) / 2
    #expect(abs(checkbox.midY - expectedCenter) < 0.5)
}

@MainActor
@Test
func subtitleTableViewUnifiedRowMenuAndClipboardKeepPrimaryAndGroupSemantics() {
    let row = dynamicTableRow(
        id: 77,
        primary: "main\nline",
        group: ["extra one", "main\nline", "extra two"],
        primaryIndex: 1
    )
    let offFixture = makeAttachedVirtualTableCoordinator(rowCount: 1, row: row)
    let onFixture = makeAttachedVirtualTableCoordinator(
        rowCount: 1,
        row: row,
        showsCueGroup: true,
        rowActionMenuStyle: .excerpt
    )

    #expect(offFixture.coordinator.rowMenuItemsForTesting().map(\.title) == [
        "Play", "Open Subtitle Folder", "Save to Excerpt List", "Copy Cue Text",
        "Copy Deep Link", "Copy Time Range",
    ])
    let onItems = onFixture.coordinator.rowMenuItemsForTesting()
    #expect(onItems.map(\.title) == [
        "Play", "Open Subtitle Folder", "Copy Cue Text", "Copy Deep Link",
        "Copy Cue Group Text", "Copy Time Range", "Move to ...",
        "Duplicate to ...", "Remove Excerpt",
    ])
    #expect(onItems[2].icon == .copy)
    #expect(onItems[3].icon == .linkSimple)
    #expect(onItems[4].icon == .copy)
    #expect(onItems[5].icon == .copy)

    offFixture.coordinator.copyCueTextForTesting(row: 0)
    #expect(NSPasteboard.general.string(forType: .string) == "main\nline")
    offFixture.coordinator.copyDeepLinkForTesting(row: 0)
    #expect(
        NSPasteboard.general.string(forType: .string)
            == "[main line](cueseeker://cue?id=77)"
    )
    onFixture.coordinator.copyCueGroupTextForTesting(row: 0)
    #expect(NSPasteboard.general.string(forType: .string) == "extra one\nmain\nline\nextra two")
}

@MainActor
@Test
func subtitleTableExcerptSubmenuStopsAtTheMenuHeightCap() async throws {
    let destinations = (2...31).map {
        SubtitleTableRowActionDestination(id: Int64($0), title: "List \($0)")
    }
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_200,
        showsCueGroup: true,
        rowActionMenuStyle: .excerpt,
        rowActionDestinations: destinations
    )
    fixture.container.frame.size.height = 900
    fixture.scrollView.frame.size.height = 856
    fixture.coordinator.showMenu(
        for: 0,
        buttonFrame: .zero,
        clickPointInDocument: CGPoint(x: 100, y: 700)
    )

    // The menu itself is well under the cap and is not stretched to it.
    let menuFrame = try #require(fixture.coordinator.menuFrameForTesting())
    #expect(menuFrame.height > 0)
    #expect(menuFrame.height < MenuMetrics.maximumHeight)

    for _ in 0..<10
    where fixture.coordinator.rowActionParentItemFrameForTesting(
        .moveToList
    ) == nil {
        await Task.yield()
    }
    fixture.coordinator.openRowActionSubmenuForTesting(.moveToList)

    // Thirty destinations are far taller than the cap, so the submenu stops
    // there and scrolls instead of growing.
    let submenuFrame = try #require(fixture.coordinator.submenuFrameForTesting())
    #expect(abs(submenuFrame.height - MenuMetrics.maximumHeight) < 0.5)
    #expect(submenuFrame.width > 0)
}

@MainActor
@Test
func subtitleTableExcerptSubmenuReachesNewListWithoutOtherLists() async throws {
    var createRequests: [(rowID: Int, action: SubtitleTableRowAction)] = []
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_200,
        showsCueGroup: true,
        rowActionMenuStyle: .excerpt,
        rowActionDestinations: [],
        onCreateExcerptList: { createRequests.append(($0.id, $1)) }
    )
    let anchorFrame = try #require(
        fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "cues")
    )
    fixture.coordinator.showMenu(for: 0, buttonFrame: anchorFrame)

    // The current list is the only list, and Move to still opens a submenu
    // because New List always sits at its end.
    fixture.coordinator.openRowActionSubmenuForTesting(.moveToList)
    #expect(fixture.coordinator.submenuFrameForTesting() != nil)

    // The submenu opens highlighting New List, so Return reaches it by
    // keyboard alone.
    #expect(fixture.coordinator.handleMenuKeyForTesting(36))
    #expect(createRequests.count == 1)
    #expect(createRequests.first?.action == .moveToList)
    #expect(!fixture.coordinator.isMenuOpenForTesting())
}

@MainActor
@Test
func subtitleTableExcerptSubmenuTouchesAndAlignsWithItsParentItem() async throws {
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_200,
        showsCueGroup: true,
        rowActionMenuStyle: .excerpt,
        rowActionDestinations: [
            SubtitleTableRowActionDestination(id: 2, title: "Second List"),
            SubtitleTableRowActionDestination(id: 3, title: "Third List"),
        ]
    )
    fixture.container.frame.size.height = 800
    fixture.scrollView.frame.size.height = 756
    fixture.coordinator.showMenu(
        for: 0,
        buttonFrame: .zero,
        clickPointInDocument: CGPoint(x: 100, y: 700)
    )
    let parentFrameBefore = try #require(
        fixture.coordinator.menuFrameForTesting()
    )
    for _ in 0..<10
    where fixture.coordinator.rowActionParentItemFrameForTesting(
        .moveToList
    ) == nil {
        await Task.yield()
    }
    let moveItemFrame = try #require(
        fixture.coordinator.rowActionParentItemFrameForTesting(.moveToList)
    )
    // Six items and the two dividers between them sit above Move to, so the
    // submenu's alignment below is measured against a real offset rather than
    // against the top of the menu.
    let itemHeight = WorkbenchControlMetrics.redesignMenuItemHeight
    let moveItemOffset = MenuMetrics.padding + 6 * itemHeight
    #expect(moveItemFrame.minY >= moveItemOffset)
    #expect(moveItemFrame.height == itemHeight)

    fixture.coordinator.openRowActionSubmenuForTesting(.moveToList)

    let parentFrameAfter = try #require(
        fixture.coordinator.menuFrameForTesting()
    )
    let submenuFrame = try #require(
        fixture.coordinator.submenuFrameForTesting()
    )

    #expect(parentFrameAfter == parentFrameBefore)
    #expect(abs(submenuFrame.minX - parentFrameAfter.maxX) < 0.5)
    #expect(submenuFrame.minY >= parentFrameAfter.minY + moveItemOffset)
    #expect(
        abs(
            submenuFrame.minY
                - (parentFrameAfter.minY + moveItemFrame.minY)
        ) < 0.5
    )

    let submenuCenterInWindow = fixture.container.convert(
        CGPoint(x: submenuFrame.midX, y: submenuFrame.midY),
        to: nil
    )
    #expect(
        fixture.coordinator.menuContainsWindowPointForTesting(
            submenuCenterInWindow
        )
    )
    #expect(
        fixture.coordinator.submenuReceivesHitForTesting(
            containerPoint: CGPoint(
                x: submenuFrame.minX + 1,
                y: submenuFrame.midY
            )
        )
    )

    // Right of the parent menu and above the submenu, so it sits in neither.
    let outsideBothMenusInWindow = fixture.container.convert(
        CGPoint(
            x: submenuFrame.midX,
            y: submenuFrame.minY - 10
        ),
        to: nil
    )
    #expect(
        fixture.coordinator.menuOutsideClickDismissesForTesting(
            windowPoint: outsideBothMenusInWindow
        )
    )
}

@MainActor
@Test
func subtitleTableViewExtraCueLeftAndRightHitRegionsStillTargetPrimaryRow() throws {
    let row = dynamicTableRow(
        id: 41,
        primary: "primary target",
        group: ["extra target", "primary target"],
        primaryIndex: 1
    )
    var playedIdentity: SubtitleTablePrimaryCueIdentity?
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: 1,
        row: row,
        showsCueGroup: true,
        onPlay: { playedIdentity = $0.primaryCueIdentity }
    )
    let cuesCell = try #require(fixture.coordinator.dataCellRectForTesting(row: 0, columnID: "cues"))
    let extraPoint = CGPoint(
        x: cuesCell.minX + SubtitleTableCueGeometry.cellLeadingPadding + 8,
        y: fixture.coordinator.rowYOffsetForTesting(0)
            + SubtitleTableCueGeometry.rowPaddingY
            + SubtitleTableCueGeometry.primaryLineHeight
            + SubtitleTableCueGeometry.rowPaddingY
            + 10
    )
    let windowPoint = fixture.documentView.convert(extraPoint, to: nil)

    #expect(fixture.coordinator.cueTextHitTestForTesting(row: 0, point: extraPoint))
    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint))
    #expect(playedIdentity == nil)
    #expect(fixture.coordinator.handleMouseUp(windowPoint: windowPoint))
    #expect(playedIdentity == row.primaryCueIdentity)
    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint))
    #expect(fixture.coordinator.isMenuOpenForTesting())
}

@MainActor
@Test
func subtitleTableViewShowCueGroupReflowPreservesPrimaryFirstLineAndPresentationState() throws {
    let rows = (0..<200).map { index in
        dynamicTableRow(
            id: index + 1,
            primary: "primary \(index)",
            group: ["extra first", "extra second", "primary \(index)"],
            primaryIndex: 2
        )
    }
    var visibleNotifications = 0
    let selectedRow = 50
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: rows.count,
        rowProvider: { rows[$0] },
        onVisibleRowsChange: { _ in visibleNotifications += 1 },
        isRowSelected: { $0 == selectedRow }
    )
    fixture.coordinator.scrollToRow(selectedRow)
    let beforeY = try #require(fixture.coordinator.primaryFirstLineScreenYForTesting(row: selectedRow))
    let measurementLimit = (fixture.coordinator.measurementRowRangeForTesting()?.count ?? 0) + 1
    visibleNotifications = 0
    fixture.coordinator.resetMeasurementComputeCountForTesting()

    let recording = UIInvalidationProbe.recordForTesting {
        fixture.coordinator.update(
            tableName: "test-search",
            rowCount: rows.count,
            rowProvider: { rows[$0] },
            rowsVersion: 1,
            rowsUpdate: .none,
            displayTitleHeader: "Display Title",
            showsLanguageColumn: true,
            showsCueGroup: true,
            scrollResetToken: 0,
            onVisibleRowsChange: { _ in visibleNotifications += 1 },
            isRowSelected: { $0 == selectedRow },
            selectionHeaderState: .unchecked,
            onToggleRowSelection: { _ in },
            onToggleAllSelection: {},
            onPlay: { _ in }
        )
    }.recording

    let afterY = try #require(fixture.coordinator.primaryFirstLineScreenYForTesting(row: selectedRow))
    #expect(abs(afterY - beforeY) < 0.5)
    #expect(fixture.coordinator.numberOfRowsForTesting() == rows.count)
    #expect(fixture.coordinator.rowSelectionStateForTesting(row: selectedRow))
    #expect(visibleNotifications == 0)
    #expect(fixture.coordinator.measurementComputeCountForTesting() <= measurementLimit)
    #expect(recording.count("table.search.show_cue_group_owner_update") == 1)
    #expect(recording.count("table.search.dynamic_row_measurement") > 0)
    #expect(recording.count("table.search.dynamic_row_measurement") <= UInt64(measurementLimit))
    #expect(recording.count("table.search.dynamic_scroll_anchor_correction") > 0)
    for counter in subtitleTableForbiddenRefreshScopeCounters {
        #expect(recording.count(counter) == 0)
    }
}

@MainActor
@Test
func subtitleTableViewWidthReflowPreservesPrimaryFirstLineAnchor() throws {
    let longText = Array(repeating: "automatic wrapping content", count: 30).joined(separator: " ")
    let rows = (0..<200).map { index in
        dynamicTableRow(id: index + 1, primary: "\(index) \(longText)")
    }
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    let anchorRow = 40
    fixture.coordinator.scrollToRow(anchorRow)
    let beforeY = try #require(fixture.coordinator.primaryFirstLineScreenYForTesting(row: anchorRow))
    let measurementLimit = (fixture.coordinator.measurementRowRangeForTesting()?.count ?? 0) + 1
    fixture.coordinator.resetMeasurementComputeCountForTesting()

    let recording = UIInvalidationProbe.recordForTesting {
        fixture.container.setFrameSize(CGSize(width: 1_600, height: fixture.container.frame.height))
        fixture.header.setFrameSize(CGSize(width: 1_600, height: fixture.header.frame.height))
        fixture.scrollView.setFrameSize(CGSize(width: 1_600, height: fixture.scrollView.frame.height))
        fixture.overlay.setFrameSize(CGSize(width: 1_600, height: fixture.overlay.frame.height))
        fixture.coordinator.resizeDocument()
    }.recording

    let afterY = try #require(fixture.coordinator.primaryFirstLineScreenYForTesting(row: anchorRow))
    #expect(abs(afterY - beforeY) < 0.5)
    #expect(fixture.coordinator.measurementComputeCountForTesting() <= measurementLimit)
    #expect(recording.marks.contains("ACTION UI.SubtitleTable.search.width_reflow"))
    #expect(recording.count("table.search.width_reflow_owner_update") > 0)
    #expect(recording.count("table.search.dynamic_row_measurement") > 0)
    #expect(recording.count("table.search.dynamic_row_measurement") <= UInt64(measurementLimit))
    #expect(recording.count("table.search.dynamic_scroll_anchor_correction") > 0)
    for counter in subtitleTableForbiddenRefreshScopeCounters {
        #expect(recording.count(counter) == 0)
    }
}

@MainActor
@Test
func subtitleTableViewCueCellPatchPreservesSamePrimaryIdentityAnchor() throws {
    var rows = (0..<100).map { index in
        dynamicTableRow(id: index + 1, primary: "primary \(index)")
    }
    let anchorRow = 30
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    fixture.coordinator.scrollToRow(anchorRow)
    let beforeY = try #require(fixture.coordinator.primaryFirstLineScreenYForTesting(row: anchorRow))
    rows[anchorRow] = dynamicTableRow(
        id: anchorRow + 1,
        primary: "primary changed\nsecond line\nthird line"
    )

    fixture.coordinator.update(
        tableName: "test-search",
        rowCount: rows.count,
        rowProvider: { rows[$0] },
        rowsVersion: 2,
        rowsUpdate: .cells([TableSandboxCellInvalidation(row: anchorRow, columnID: "cues")]),
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        scrollResetToken: 0,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    let afterY = try #require(fixture.coordinator.primaryFirstLineScreenYForTesting(row: anchorRow))
    #expect(fixture.coordinator.rowHeightForTesting(anchorRow) == 88)
    #expect(abs(afterY - beforeY) < 0.5)
}

@MainActor
@Test
func subtitleTableViewReloadPreservesSamePrimaryIdentityAnchor() throws {
    var rows = (0..<100).map { index in
        dynamicTableRow(id: index + 1, primary: "primary \(index)")
    }
    let anchorRow = 30
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    fixture.coordinator.scrollToRow(anchorRow)
    let beforeY = try #require(fixture.coordinator.primaryFirstLineScreenYForTesting(row: anchorRow))
    rows[anchorRow] = dynamicTableRow(
        id: anchorRow + 1,
        primary: "primary changed\nsecond line\nthird line"
    )

    fixture.coordinator.update(
        tableName: "test-search",
        rowCount: rows.count,
        rowProvider: { rows[$0] },
        rowsVersion: 2,
        rowsUpdate: .reload,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        scrollResetToken: 0,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    let afterY = try #require(fixture.coordinator.primaryFirstLineScreenYForTesting(row: anchorRow))
    #expect(fixture.coordinator.rowHeightForTesting(anchorRow) == 88)
    #expect(abs(afterY - beforeY) < 0.5)
}

@MainActor
@Test
func subtitleTableViewAppendKeepsMeasurementsWhileReloadInvalidatesIdentityContent() {
    var rows = [
        dynamicTableRow(id: 1, primary: "one"),
        dynamicTableRow(id: 2, primary: "two"),
    ]
    let fixture = makeAttachedVirtualTableCoordinator(
        rowCount: rows.count,
        rowProvider: { rows[$0] }
    )
    fixture.coordinator.resetMeasurementComputeCountForTesting()
    rows.append(dynamicTableRow(id: 3, primary: "three"))

    fixture.coordinator.update(
        tableName: "test-search",
        rowCount: rows.count,
        rowProvider: { rows[$0] },
        rowsVersion: 2,
        rowsUpdate: .append(2..<3),
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        scrollResetToken: 0,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    #expect(fixture.coordinator.measurementComputeCountForTesting() == 1)
    #expect(fixture.coordinator.rowHeightForTesting(0) == 40)

    fixture.coordinator.resetMeasurementComputeCountForTesting()
    rows[0] = dynamicTableRow(id: 1, primary: "one\nchanged\ncontent")
    fixture.coordinator.update(
        tableName: "test-search",
        rowCount: rows.count,
        rowProvider: { rows[$0] },
        rowsVersion: 3,
        rowsUpdate: .reload,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        scrollResetToken: 0,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        selectionHeaderState: .unchecked,
        onToggleRowSelection: { _ in },
        onToggleAllSelection: {},
        onPlay: { _ in }
    )

    #expect(fixture.coordinator.rowHeightForTesting(0) == 88)
    #expect(fixture.coordinator.measurementComputeCountForTesting() == rows.count)
}

@MainActor
@Test
func subtitleTableViewMeasurementAndDrawingWorkStayViewportBoundedAtLargeCounts() {
    let row = dynamicTableRow(id: 1, primary: "one")
    let small = makeAttachedVirtualTableCoordinator(width: 900, rowCount: 500, row: row)
    let large = makeAttachedVirtualTableCoordinator(width: 900, rowCount: 50_000, row: row)

    let smallMeasurementRange = small.coordinator.measurementRowRangeForTesting()
    let largeMeasurementRange = large.coordinator.measurementRowRangeForTesting()
    #expect(smallMeasurementRange?.count == largeMeasurementRange?.count)
    #expect(small.coordinator.measurementComputeCountForTesting() == smallMeasurementRange?.count)
    #expect(large.coordinator.measurementComputeCountForTesting() == largeMeasurementRange?.count)
    #expect((largeMeasurementRange?.count ?? 0) <= 9)

    let smallDrawRange = small.coordinator.drawingRowRangeForTesting(dirtyRect: small.documentView.bounds)
    let largeDrawRange = large.coordinator.drawingRowRangeForTesting(dirtyRect: large.documentView.bounds)
    #expect(smallDrawRange?.count == largeDrawRange?.count)
    #expect((largeDrawRange?.count ?? 0) <= 5)

    let image = NSImage(size: large.scrollView.contentView.bounds.size)
    image.lockFocus()
    large.coordinator.resetDrawnRowCountForTesting()
    large.coordinator.drawRows(in: large.documentView.bounds)
    image.unlockFocus()
    #expect(large.coordinator.drawnRowCountForTesting() > 0)
    #expect(large.coordinator.drawnRowCountForTesting() <= (largeDrawRange?.count ?? 0))

    for targetRow in stride(from: 1_000, through: 49_000, by: 1_000) {
        large.coordinator.scrollToRow(targetRow)
        let retainedLimit = large.coordinator.measurementRowRangeForTesting()?.count ?? 0
        #expect(large.coordinator.retainedRowMeasurementCountForTesting() <= retainedLimit)
    }
}

@Test
func subtitleVirtualRowHeightCacheUsesMeasuredHeightForFastScrollMapping() {
    var cache = SubtitleVirtualRowHeightCache()
    cache.configure(rowCount: 2_000_000, defaultHeight: 40)

    let changed = cache.setHeight(120, for: 1_999_999)
    #expect(changed)
    #expect(cache.count == 1)
    #expect(cache.height(for: 1_999_999) == 120)
    #expect(cache.height(for: 1_999_998) == 40)
    #expect(cache.rowIndex(atY: 80) == 2)
    #expect(cache.totalHeight == 80_000_080)
}

@MainActor
@Test
func systemColorsDidChangeInvalidatesVisibleDocumentOnlyInSelectionMode() {
    let selectionFixture = makeAttachedVirtualTableCoordinator(isSelectionMode: true)
    #expect(selectionFixture.coordinator.didInvalidateForSystemColorsChangeForTesting == false)

    NotificationCenter.default.post(
        name: NSColor.systemColorsDidChangeNotification,
        object: nil
    )
    #expect(selectionFixture.coordinator.didInvalidateForSystemColorsChangeForTesting == true)
    selectionFixture.coordinator.quiesceForTesting()

    let normalFixture = makeAttachedVirtualTableCoordinator(isSelectionMode: false)
    #expect(normalFixture.coordinator.didInvalidateForSystemColorsChangeForTesting == false)

    NotificationCenter.default.post(
        name: NSColor.systemColorsDidChangeNotification,
        object: nil
    )
    #expect(normalFixture.coordinator.didInvalidateForSystemColorsChangeForTesting == false)
    normalFixture.coordinator.quiesceForTesting()
}

@MainActor
private func makeKeyboardFocusTableCoordinator(
    rowCount: Int = 100_000,
    onToggleRowSelection: @escaping (Int) -> Void = { _ in }
) -> SubtitleTableView.Coordinator {
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: rowCount,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        onVisibleRowsChange: { _ in },
        isSelectionMode: true,
        isRowSelected: { _ in false },
        onToggleRowSelection: onToggleRowSelection,
        onPlay: { _ in }
    )
    coordinator.isRedesign = true
    return coordinator
}

@MainActor
private func makeAttachedVirtualTableCoordinator() -> (
    coordinator: SubtitleTableView.Coordinator,
    container: SubtitleTableContainerView,
    header: SubtitleVirtualTableHeaderView,
    scrollView: NSScrollView,
    overlay: SubtitleTableScrollbarOverlayView,
    documentView: SubtitleVirtualTableDocumentView
) {
    makeAttachedVirtualTableCoordinator(width: 900)
}

@MainActor
private func makeAttachedVirtualTableCoordinator(
    onPlay: @escaping (SubtitleTableRow) -> Void
) -> (
    coordinator: SubtitleTableView.Coordinator,
    container: SubtitleTableContainerView,
    header: SubtitleVirtualTableHeaderView,
    scrollView: NSScrollView,
    overlay: SubtitleTableScrollbarOverlayView,
    documentView: SubtitleVirtualTableDocumentView
) {
    makeAttachedVirtualTableCoordinator(width: 900, onPlay: onPlay)
}

@MainActor
private func makeAttachedVirtualTableCoordinator(
    width: CGFloat = 900,
    rowCount: Int = 100,
    row: SubtitleTableRow? = nil,
    rowProvider customRowProvider: ((Int) -> SubtitleTableRow?)? = nil,
    showsDateAddedColumn: Bool = false,
    showsTimeColumn: Bool = false,
    showsCueGroup: Bool = false,
    isSelectionMode: Bool = false,
    rowActionMenuStyle: SubtitleTableRowActionMenuStyle = .search,
    onVisibleRowsChange: @escaping (Range<Int>) -> Void = { _ in },
    isRowSelected: @escaping (Int) -> Bool = { _ in false },
    allResultsTextCopyRowCount: Int? = nil,
    loadRowsForTextCopy: SubtitleTableTextCopyRowLoader? = nil,
    onPlay: @escaping (SubtitleTableRow) -> Void = { _ in },
    onToggleRowSelection: @escaping (Int) -> Void = { _ in },
    onToggleAllSelection: @escaping () -> Void = {},
    onOpenSubtitleFile: @escaping (String) -> Void = { _ in },
    rowActionDestinations: [SubtitleTableRowActionDestination] = [],
    onMoveExcerpt: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
    onDuplicateExcerpt: @escaping (SubtitleTableRow, Int64) -> Void = { _, _ in },
    onCreateExcerptList: @escaping (
        SubtitleTableRow, SubtitleTableRowAction
    ) -> Void = { _, _ in },
    onRemoveExcerpt: @escaping (SubtitleTableRow) -> Void = { _ in }
) -> (
    coordinator: SubtitleTableView.Coordinator,
    container: SubtitleTableContainerView,
    header: SubtitleVirtualTableHeaderView,
    scrollView: NSScrollView,
    overlay: SubtitleTableScrollbarOverlayView,
    documentView: SubtitleVirtualTableDocumentView
) {
    let loadedRow = row ?? SubtitleTableRow(
        id: 1,
        primaryCueID: 1,
        subtitlePath: "/tmp/CueSeeker/Episode 01.srt",
        dateAdded: "26-07-04 19:00",
        displayTitle: "Episode 01",
        startTime: "00:01",
        endTime: "00:02",
        primaryCueText: "cue text",
        cueGroupTexts: ["cue text"],
        primaryGroupIndex: 0,
        tags: []
    )
    let rowProvider = customRowProvider ?? { _ in loadedRow }
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: rowCount,
        rowProvider: rowProvider,
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsDateAddedColumn: showsDateAddedColumn,
        showsTimeColumn: showsTimeColumn,
        showsLanguageColumn: true,
        showsCueGroup: showsCueGroup,
        onVisibleRowsChange: onVisibleRowsChange,
        isSelectionMode: isSelectionMode,
        isRowSelected: isRowSelected,
        onToggleRowSelection: onToggleRowSelection,
        onToggleAllSelection: onToggleAllSelection,
        allResultsTextCopyRowCount: allResultsTextCopyRowCount,
        loadRowsForTextCopy: loadRowsForTextCopy,
        onPlay: onPlay,
        onOpenSubtitleFile: onOpenSubtitleFile,
        rowActionMenuStyle: rowActionMenuStyle,
        rowActionDestinations: rowActionDestinations,
        onMoveExcerpt: onMoveExcerpt,
        onDuplicateExcerpt: onDuplicateExcerpt,
        onCreateExcerptList: onCreateExcerptList,
        onRemoveExcerpt: onRemoveExcerpt
    )
    coordinator.isRedesign = true

    let container = SubtitleTableContainerView(frame: CGRect(x: 0, y: 0, width: width, height: 260))
    let header = SubtitleVirtualTableHeaderView(frame: CGRect(x: 0, y: 0, width: width, height: 44))
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 44, width: width, height: 200))
    let overlay = SubtitleTableScrollbarOverlayView(frame: scrollView.frame)
    let documentView = SubtitleVirtualTableDocumentView(frame: CGRect(x: 0, y: 0, width: width, height: 1))

    container.addSubview(header)
    container.addSubview(scrollView)
    container.addSubview(overlay)
    documentView.coordinator = coordinator
    scrollView.documentView = documentView
    let pageScrollbar = WorkbenchPageScrollbar()
    pageScrollbar.attach(overlayView: overlay, axis: .vertical)
    coordinator.attach(
        container: container,
        headerView: header,
        scrollView: scrollView,
        pageScrollbar: pageScrollbar,
        documentView: documentView
    )
    coordinator.resizeDocument()

    return (coordinator, container, header, scrollView, overlay, documentView)
}

private func makeTabKeyEvent(shift: Bool = false) -> NSEvent {
    NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: shift ? [.shift] : [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "\t",
        charactersIgnoringModifiers: "\t",
        isARepeat: false,
        keyCode: 48
    )!
}

@MainActor
private func subtitleTableLeftMouseDownEvent() -> NSEvent {
    NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
    )!
}

private func dynamicTableRow(
    id: Int,
    primary: String,
    group: [String]? = nil,
    primaryIndex: Int? = nil
) -> SubtitleTableRow {
    SubtitleTableRow(
        id: id,
        primaryCueID: Int64(id),
        displayTitle: "Episode \(id)",
        primaryCueText: primary,
        cueGroupTexts: group ?? [primary],
        primaryGroupIndex: primaryIndex ?? 0
    )
}
