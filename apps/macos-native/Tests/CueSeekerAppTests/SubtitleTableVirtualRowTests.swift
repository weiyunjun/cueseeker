import AppKit
import CoreGraphics
import SwiftUI
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
        cues: "loaded cue",
        shioriTags: [
            WorkbenchTag(key: "7", label: "Review", colorID: .gray),
            WorkbenchTag(key: "8", label: "Grammar", colorID: .gray),
        ]
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "shiori",
        rowCount: 1,
        rowProvider: { _ in loadedRow },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        columnOrder: ["display", "cues", "time", "dateAdded", "tags"],
        showsDateAddedColumn: true,
        showsTimeColumn: true,
        showsLanguageColumn: false,
        showsSpeakerColumn: false,
        showsTagsColumn: true,
        onVisibleRowsChange: { _ in },
        onPlay: { _ in }
    )
    coordinator.isRedesign = true

    #expect(coordinator.cellFullText(row: -1, column: 1) == "Display Title")
    #expect(coordinator.cellFullText(row: -1, column: 2) == "Cues")
    #expect(coordinator.cellFullText(row: -1, column: 3) == "Time")
    #expect(coordinator.cellFullText(row: -1, column: 4) == "Date Added")
    #expect(coordinator.cellFullText(row: -1, column: 5) == "Tags")
    #expect(coordinator.cellFullText(row: 0, column: 1) == "Episode 01")
    #expect(coordinator.cellFullText(row: 0, column: 2) == "loaded cue")
    #expect(coordinator.cellFullText(row: 0, column: 3) == "15:18 - 15:20")
    #expect(coordinator.cellFullText(row: 0, column: 4) == "26-07-02 14:30")
    #expect(coordinator.cellFullText(row: 0, column: 5) == "Review, Grammar")
}

@MainActor
@Test
func subtitleTableColumnLayoutClassifiesViewportGrowthAsCuesWidthChange() {
    let oldLayout = SubtitleTableColumnLayout.resolve(
        contentWidth: 1_160,
        height: 64,
        showsDateAddedColumn: true,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsSpeakerColumn: false,
        showsLanguageColumn: false,
        showsTagsColumn: true,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
        columnOrder: ["display", "cues", "time", "dateAdded", "tags"]
    )
    let newLayout = SubtitleTableColumnLayout.resolve(
        contentWidth: 1_360,
        height: 64,
        showsDateAddedColumn: true,
        showsDisplayTitleColumn: true,
        showsTimeColumn: true,
        showsSpeakerColumn: false,
        showsLanguageColumn: false,
        showsTagsColumn: true,
        cuesMinimumWidth: SubtitleTableMetrics.cuesColumnMinimumWidth,
        columnOrder: ["display", "cues", "time", "dateAdded", "tags"]
    )

    #expect(newLayout.isCuesOnlyWidthChange(from: oldLayout))
    #expect(newLayout.nameRect.width == oldLayout.nameRect.width)
    #expect(newLayout.timeRect?.width == oldLayout.timeRect?.width)
    #expect(newLayout.dateAddedRect?.width == oldLayout.dateAddedRect?.width)
    #expect(newLayout.tagsRect?.width == 180)
    #expect(newLayout.tagsRect?.width == oldLayout.tagsRect?.width)
    #expect(newLayout.cuesRect.width > oldLayout.cuesRect.width)
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
    #expect(playCount == 1)
}

@MainActor
@Test
func subtitleTableViewDisplayTitleContentLeftClickOpensFolder() throws {
    var openedPath: String?
    let fixture = makeAttachedVirtualTableCoordinator(onOpenSubtitleFile: { path in
        openedPath = path
    })
    let displayRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "display"))
    let displayPoint = CGPoint(x: displayRect.midX, y: displayRect.midY)
    let windowPoint = fixture.documentView.convert(displayPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
    #expect(openedPath == "/tmp/CueSeeker/Episode 01.srt")
}

@MainActor
@Test
func subtitleTableViewCueContentRightClickOpensMenuBelowClickPosition() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
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
    let displayRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "display"))
    let displayPoint = CGPoint(x: displayRect.midX, y: displayRect.midY)
    let windowPoint = fixture.documentView.convert(displayPoint, to: nil)
    let clickPointInContainer = fixture.container.convert(displayPoint, from: fixture.documentView)

    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint) == true)

    let menuFrame = try #require(fixture.coordinator.menuFrameForTesting())
    expectMenuFrame(menuFrame, opensBelow: clickPointInContainer)
}

private func expectMenuFrame(_ menuFrame: CGRect, opensBelow clickPoint: CGPoint) {
    let gap = WorkbenchControlMetrics.redesignSpacing1
    #expect(abs(menuFrame.minX - clickPoint.x) < 0.5)
    #expect(abs(menuFrame.maxY - (clickPoint.y - gap)) < 0.5)
}

@MainActor
@Test
func subtitleTableViewTimeContentLeftClickCopiesText() throws {
    let fixture = makeAttachedVirtualTableCoordinator(showsTimeColumn: true)
    let pasteboard = NSPasteboard.general
    let timeRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "time"))
    let timePoint = CGPoint(x: timeRect.midX, y: timeRect.midY)
    let windowPoint = fixture.documentView.convert(timePoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
    #expect(pasteboard.string(forType: .string) == "00:01 - 00:02")
}

@MainActor
@Test
func subtitleTableViewDateAddedContentLeftClickCopiesText() throws {
    let fixture = makeAttachedVirtualTableCoordinator(showsDateAddedColumn: true)
    let pasteboard = NSPasteboard.general
    let dateAddedRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "dateAdded"))
    let dateAddedPoint = CGPoint(x: dateAddedRect.midX, y: dateAddedRect.midY)
    let windowPoint = fixture.documentView.convert(dateAddedPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
    #expect(pasteboard.string(forType: .string) == "26-07-04 19:00")
}

@MainActor
@Test
func subtitleTableViewRightClickOutsideContentHoverRegionDoesNotOpenMenu() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let outsideContentPoint = CGPoint(
        x: cuesRect.maxX + SubtitleTableMetrics.tableCellHoverPaddingX + 12,
        y: cuesRect.midY
    )
    let windowPoint = fixture.documentView.convert(outsideContentPoint, to: nil)

    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint) == false)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
}

@MainActor
@Test
func subtitleTableViewTagsContentRightClickDoesNotOpenMenu() throws {
    let fixture = makeAttachedVirtualTableCoordinator(width: 1_400, showsTagsColumn: true)
    let tagsRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "tags"))
    let tagsPoint = CGPoint(x: tagsRect.midX, y: tagsRect.midY)
    let windowPoint = fixture.documentView.convert(tagsPoint, to: nil)

    #expect(fixture.coordinator.interactiveCellCursorRectsForTesting().contains { $0.contains(tagsPoint) })
    #expect(fixture.coordinator.isInteractiveCellCursorActiveForTesting(documentPoint: tagsPoint) == true)
    #expect(fixture.coordinator.handleRightMouseDown(windowPoint: windowPoint) == false)
    #expect(fixture.coordinator.isMenuOpenForTesting() == false)
}

@MainActor
@Test
func subtitleTableViewTagsContentLeftClickOpensPopover() throws {
    var requestedRowID: Int?
    let fixture = makeAttachedVirtualTableCoordinator(
        width: 1_400,
        showsTagsColumn: true,
        makeTagsPopover: { row, _ in
            requestedRowID = row.id
            return AnyView(Text("Tags"))
        }
    )
    let tagsRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "tags"))
    let tagsPoint = CGPoint(x: tagsRect.midX, y: tagsRect.midY)
    let windowPoint = fixture.documentView.convert(tagsPoint, to: nil)

    #expect(fixture.coordinator.handleMouseDown(windowPoint: windowPoint) == true)
    #expect(requestedRowID == 1)
    #expect(fixture.coordinator.isMenuOpenForTesting())
}

@MainActor
@Test
func subtitleTableViewLeftClickOutsideContentHoverRegionTogglesSelection() throws {
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
    #expect(toggledRows == [0])
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
        showsSpeakerColumn: true,
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
    fixture.coordinator.isExternalPopupLayerOpen = true
    fixture.coordinator.notifyVisibleRowsChanged(force: true)

    #expect(visibleRowNotifications == 0)

    fixture.coordinator.isExternalPopupLayerOpen = false
    fixture.coordinator.notifyVisibleRowsChanged(force: true)

    #expect(visibleRowNotifications == 1)
}

@MainActor
@Test
func subtitleTableViewProvidesInteractiveCellCursorRectsForContentHoverRegions() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesPoint = CGPoint(x: cuesRect.midX, y: cuesRect.midY)
    let outsideContentPoint = CGPoint(
        x: cuesRect.maxX + SubtitleTableMetrics.tableCellHoverPaddingX + 12,
        y: cuesRect.midY
    )

    #expect(fixture.coordinator.interactiveCellCursorRectsForTesting().contains { $0.contains(cuesPoint) })
    #expect(fixture.coordinator.isInteractiveCellCursorActiveForTesting(documentPoint: cuesPoint) == true)
    #expect(fixture.coordinator.interactiveCellCursorRectsForTesting().contains { $0.contains(outsideContentPoint) } == false)
    #expect(fixture.coordinator.isInteractiveCellCursorActiveForTesting(documentPoint: outsideContentPoint) == false)
}

@MainActor
@Test
func subtitleTableViewSuppressesInteractiveCursorRectsWhenExternalLayerIsOpen() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesPoint = CGPoint(x: cuesRect.midX, y: cuesRect.midY)

    fixture.coordinator.isExternalPopupLayerOpen = true

    #expect(fixture.coordinator.interactiveCellCursorRectsForTesting().isEmpty)
    #expect(fixture.coordinator.isInteractiveCellCursorActiveForTesting(documentPoint: cuesPoint) == false)
}

@MainActor
@Test
func subtitleTableViewDismissMenuKeepsInteractiveCellCursorRectAvailable() throws {
    let fixture = makeAttachedVirtualTableCoordinator()
    let anchorFrame = CGRect(
        x: SubtitleTableMetrics.indexColumnWidth + SubtitleTableMetrics.nameColumnWidth,
        y: 14,
        width: 520,
        height: fixture.coordinator.currentRowHeight
    )
    let cuesRect = try #require(fixture.coordinator.cellContentHoverDocumentRectForTesting(row: 0, columnID: "cues"))
    let cuesPoint = CGPoint(x: cuesRect.midX, y: cuesRect.midY)

    fixture.coordinator.showMenu(for: 0, buttonFrame: anchorFrame)
    fixture.coordinator.dismissMenu(recalculateHover: false)

    #expect(fixture.coordinator.isInteractiveCellCursorActiveForTesting(documentPoint: cuesPoint) == true)
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
    width: CGFloat = 900,
    showsDateAddedColumn: Bool = false,
    showsTimeColumn: Bool = false,
    showsTagsColumn: Bool = false,
    makeTagsPopover: @escaping (SubtitleTableRow, @escaping () -> Void) -> AnyView? = { _, _ in nil },
    onVisibleRowsChange: @escaping (Range<Int>) -> Void = { _ in },
    onPlay: @escaping (SubtitleTableRow) -> Void = { _ in },
    onToggleRowSelection: @escaping (Int) -> Void = { _ in },
    onOpenSubtitleFile: @escaping (String) -> Void = { _ in }
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
        subtitlePath: "/tmp/CueSeeker/Episode 01.srt",
        dateAdded: "26-07-04 19:00",
        displayTitle: "Episode 01",
        startTime: "00:01",
        endTime: "00:02",
        cues: "cue text",
        tags: [],
        speakerTags: [],
        shioriTags: showsTagsColumn ? [WorkbenchTag(key: "7", label: "Review", colorID: .gray)] : []
    )
    let coordinator = SubtitleTableView.Coordinator(
        tableName: "test-search",
        rowCount: 100,
        rowProvider: { _ in loadedRow },
        rowsVersion: 1,
        displayTitleHeader: "Display Title",
        showsDateAddedColumn: showsDateAddedColumn,
        showsTimeColumn: showsTimeColumn,
        showsLanguageColumn: true,
        showsSpeakerColumn: true,
        showsTagsColumn: showsTagsColumn,
        onVisibleRowsChange: onVisibleRowsChange,
        isRowSelected: { _ in false },
        onToggleRowSelection: onToggleRowSelection,
        onPlay: onPlay,
        onOpenSubtitleFile: onOpenSubtitleFile,
        makeTagsPopover: makeTagsPopover
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
