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
        showsLanguageColumn: true,
        showsSpeakerColumn: true,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )

    #expect(coordinator.numberOfRowsForTesting() == 2_000_000)
    #expect(coordinator.cellFullText(row: -1, column: 1) == "Display Title")
    #expect(coordinator.cellFullText(row: -1, column: 3) == "Speaker")
    #expect(coordinator.cellFullText(row: -1, column: 4) == "Language")
    #expect(coordinator.cellFullText(row: 0, column: 1) == "Episode 01")
    #expect(coordinator.cellFullText(row: 0, column: 2) == "loaded cue")
    #expect(coordinator.cellFullText(row: 0, column: 3) == "高松灯")
    #expect(coordinator.cellFullText(row: 0, column: 4) == "zh-hans, jp")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 0) == "1000001")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 2) == "")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 3) == "")
    #expect(coordinator.cellFullText(row: 1_000_000, column: 4) == "")
}

@MainActor
@Test
func subtitleTableViewUsesRedesignFixedRowHeightAndLazySelectionState() {
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search-2",
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
        tableName: "test-search-2",
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
        tableName: "test-search-2",
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
        tableName: "test-search-2",
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
        tableName: "test-search-2",
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
        tableName: "test-search-2",
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

    #expect(fixture.coordinator.cueTextHitTestForTesting(row: row, point: textPoint) == true)
    #expect(fixture.coordinator.cueTextHitTestForTesting(row: row, point: trailingPoint) == false)
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
        tableName: "test-search-2",
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
private func makeAttachedVirtualTableCoordinator(width: CGFloat) -> (
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
        tableName: "test-search-2",
        rowCount: 100,
        rowProvider: { _ in loadedRow },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsLanguageColumn: true,
        showsSpeakerColumn: true,
        onVisibleRowsChange: { _ in },
        isRowSelected: { _ in false },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    let container = SubtitleTableContainerView(frame: CGRect(x: 0, y: 0, width: width, height: 260))
    let header = SubtitleVirtualTableHeaderView(frame: CGRect(x: 0, y: 0, width: width, height: 44))
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 44, width: width, height: 200))
    let overlay = SubtitleTableScrollbarOverlayView(frame: scrollView.frame)
    let documentView = SubtitleVirtualTableDocumentView(frame: CGRect(x: 0, y: 0, width: width, height: 1))

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
