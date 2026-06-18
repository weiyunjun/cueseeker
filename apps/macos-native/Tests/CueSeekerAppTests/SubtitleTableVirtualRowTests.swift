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
