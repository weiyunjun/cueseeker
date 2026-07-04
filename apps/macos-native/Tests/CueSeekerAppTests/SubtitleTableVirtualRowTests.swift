import AppKit
import CoreGraphics
import Testing
@testable import CueSeekerApp

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
        ],
        speakerTags: [
            WorkbenchTag(key: "高松灯"),
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
        showsSpeakerColumn: true,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )

    #expect(coordinator.numberOfRowsForTesting() == 2_000_000)
    #expect(coordinator.cellFullText(row: -1, column: 1) == "Display Title")
    #expect(coordinator.cellFullText(row: -1, column: 2) == "Time")
    #expect(coordinator.cellFullText(row: -1, column: 4) == "Speaker")
    #expect(coordinator.cellFullText(row: -1, column: 5) == "Language")
    #expect(coordinator.cellFullText(row: 0, column: 1) == "Episode 01")
    #expect(coordinator.cellFullText(row: 0, column: 2) == "01:15:32 - 01:16:04")
    #expect(coordinator.cellFullText(row: 0, column: 3) == "loaded cue")
    #expect(coordinator.cellFullText(row: 0, column: 4) == "高松灯")
    #expect(coordinator.cellFullText(row: 0, column: 5) == "zh-hans, jp")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 0) == "1000001")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 2) == "")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 3) == "")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 4) == "")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 5) == "")
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
        ],
        speakerTags: [
            WorkbenchTag(key: "高松灯"),
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
        showsSpeakerColumn: false,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.cellFullText(row: -1, column: 1) == "Time")
    #expect(coordinator.cellFullText(row: -1, column: 2) == "Cues")
    #expect(coordinator.cellFullText(row: -1, column: 3) == "Language")
    #expect(coordinator.cellFullText(row: -1, column: 4) == "")
    #expect(coordinator.cellFullText(row: 0, column: 1) == "15:18 - 15:20")
    #expect(coordinator.cellFullText(row: 0, column: 2) == "loaded cue")
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
        cues: "loaded cue"
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "shiori",
        rowCount: 1,
        rowProvider: { _ in loadedRow },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        columnOrder: ["display", "cues", "time", "dateAdded"],
        showsDateAddedColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        showsSpeakerColumn: false,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.cellFullText(row: -1, column: 1) == "Display Title")
    #expect(coordinator.cellFullText(row: -1, column: 2) == "Cues")
    #expect(coordinator.cellFullText(row: -1, column: 3) == "Time")
    #expect(coordinator.cellFullText(row: -1, column: 4) == "Date Added")
    #expect(coordinator.cellFullText(row: 0, column: 1) == "Episode 01")
    #expect(coordinator.cellFullText(row: 0, column: 2) == "loaded cue")
    #expect(coordinator.cellFullText(row: 0, column: 3) == "15:18 - 15:20")
    #expect(coordinator.cellFullText(row: 0, column: 4) == "26-07-02 14:30")
}

@MainActor
@Test
func subtitleTableViewUsesRedesignFixedRowHeightAndLazySelectionState() {
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 100_000,
        rowProvider: { _ in nil },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        showsSpeakerColumn: true,
        onVisibleRowsChange: { _ in },
        isRowSelected: { $0 == 99_999 },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.numberOfRowsForTesting() == 100_000)
    #expect(coordinator.currentRowHeight == CGFloat(64))
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
        showsSpeakerColumn: true,
        onVisibleRowsChange: { _ in },
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
        showsSpeakerColumn: true,
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
        showsSpeakerColumn: true,
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
        showsSpeakerColumn: true,
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
        showsSpeakerColumn: true,
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
    overlay.scrollView = scrollView
    coordinator.attach(
        container: container,
        headerView: header,
        scrollView: scrollView,
        scrollbarOverlayView: overlay,
        documentView: documentView
    )
    coordinator.resizeDocument()

    coordinator.notifyVisibleRowsChanged()
    coordinator.notifyVisibleRowsChanged()
    #expect(notifiedRanges.count == 1)

    scrollView.contentView.scroll(to: CGPoint(x: 0, y: 10))
    coordinator.scrollContentDidChange()
    #expect(notifiedRanges.count == 1)

    scrollView.contentView.scroll(to: CGPoint(x: 0, y: 1_000))
    coordinator.scrollContentDidChange()
    #expect(notifiedRanges.count == 2)
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
func subtitleTableViewCueCellClickOpensMenuInsteadOfPlaying() {
    var playCount = 0
    let fixture = makeAttachedVirtualTableCoordinator(onPlay: { _ in
        playCount += 1
    })
    let cuesPoint = CGPoint(
        x: SubtitleTableMetrics.indexColumnWidth + SubtitleTableMetrics.nameColumnWidth + SubtitleTableMetrics.cellLeading + 4,
        y: fixture.coordinator.currentRowHeight / 2
    )
    let windowPoint = fixture.documentView.convert(cuesPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting() == true)
    #expect(playCount == 0)
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
        showsSpeakerColumn: false,
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
        showsSpeakerColumn: true,
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
func subtitleTableViewClearsCueTextCursorState() {
    let fixture = makeAttachedVirtualTableCoordinator()

    fixture.coordinator.setCueTextCursorActiveForTesting(true)
    #expect(fixture.coordinator.hasPushedCueTextCursorForTesting() == true)

    fixture.coordinator.clearCueTextCursorForTesting()
    #expect(fixture.coordinator.hasPushedCueTextCursorForTesting() == false)
}

@Test
func subtitleVirtualRowHeightCacheKeepsFixedRowHeightForFastScrollMapping() {
    var cache = SubtitleVirtualRowHeightCache()

    let changed = cache.setHeight(CGFloat(120), for: 2_000_000, defaultHeight: CGFloat(56))
    #expect(!changed)
    #expect(cache.count == 0)
    #expect(cache.height(for: 2_000_000, defaultHeight: CGFloat(56)) == CGFloat(56))
    #expect(cache.height(for: 1_999_999, defaultHeight: CGFloat(56)) == CGFloat(56))
    #expect(cache.rowIndex(atY: CGFloat(112), rowCount: 2_000_000, defaultHeight: CGFloat(56)) == 2)
    #expect(cache.totalHeight(rowCount: 2_000_000, defaultHeight: CGFloat(56)) == CGFloat(112_000_000))
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
        showsSpeakerColumn: true,
        onVisibleRowsChange: { _ in },
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
    width: CGFloat,
    onPlay: @escaping (SubtitleTableRow) -> Void = { _ in }
) -> (
    coordinator: SubtitleTableView.Coordinator,
    container: SubtitleTableContainerView,
    header: SubtitleVirtualTableHeaderView,
    scrollView: NSScrollView,
    overlay: SubtitleTableScrollbarOverlayView,
    documentView: SubtitleVirtualTableDocumentView
) {
    let loadedRow = SubtitleTableRow(
        id: 1,
        displayTitle: "Episode 01",
        cues: "cue text",
        tags: [],
        speakerTags: []
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 100,
        rowProvider: { _ in loadedRow },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        showsSpeakerColumn: true,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        onPlay: onPlay
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
    overlay.scrollView = scrollView
    coordinator.attach(
        container: container,
        headerView: header,
        scrollView: scrollView,
        scrollbarOverlayView: overlay,
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
