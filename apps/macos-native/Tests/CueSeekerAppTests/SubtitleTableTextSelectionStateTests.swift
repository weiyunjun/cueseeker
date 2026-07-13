import Foundation
import Testing
@testable import CueSeekerApp

@Test
func subtitleTableTextPositionUsesStrictHeaderRowColumnAndUTF16Order() {
    let positions = [
        SubtitleTableTextPosition(row: .body(0), columnIndex: 1, utf16Offset: 0),
        SubtitleTableTextPosition(row: .header, columnIndex: 1, utf16Offset: 3),
        SubtitleTableTextPosition(row: .body(-1), columnIndex: 0, utf16Offset: 0),
        SubtitleTableTextPosition(row: .body(0), columnIndex: 0, utf16Offset: 2),
        SubtitleTableTextPosition(row: .body(0), columnIndex: 0, utf16Offset: 1),
    ].sorted()

    #expect(positions[0].row == .header)
    #expect(positions[1].row == .body(-1))
    #expect(positions[2].utf16Offset == 1)
    #expect(positions[3].utf16Offset == 2)
    #expect(positions[4].columnIndex == 1)
}

@Test
func subtitleTableTextSelectionNormalizesForwardAndReverseRanges() throws {
    let start = SubtitleTableTextPosition(row: .header, columnIndex: 1, utf16Offset: 2)
    let end = SubtitleTableTextPosition(row: .body(4), columnIndex: 2, utf16Offset: 5)
    var forward = SubtitleTableTextSelectionState()
    forward.begin(at: start)
    forward.updateFocus(to: end)
    var reverse = SubtitleTableTextSelectionState()
    reverse.begin(at: end)
    reverse.updateFocus(to: start)

    let forwardRange = try #require(forward.orderedRange)
    let reverseRange = try #require(reverse.orderedRange)

    #expect(forwardRange.start == start)
    #expect(forwardRange.end == end)
    #expect(reverseRange.start == start)
    #expect(reverseRange.end == end)
}

@Test
func subtitleTableTextSelectionProjectsPartialAndCompleteCellRanges() {
    var selection = SubtitleTableTextSelectionState()
    selection.begin(at: .init(row: .body(1), columnIndex: 1, utf16Offset: 2))
    selection.updateFocus(to: .init(row: .body(2), columnIndex: 1, utf16Offset: 3))

    #expect(
        selection.selectedUTF16Range(row: .body(1), columnIndex: 0, utf16Length: 8) == nil
    )
    #expect(
        selection.selectedUTF16Range(row: .body(1), columnIndex: 1, utf16Length: 7)
            == NSRange(location: 2, length: 5)
    )
    #expect(
        selection.selectedUTF16Range(row: .body(1), columnIndex: 2, utf16Length: 6)
            == NSRange(location: 0, length: 6)
    )
    #expect(
        selection.selectedUTF16Range(row: .body(2), columnIndex: 0, utf16Length: 4)
            == NSRange(location: 0, length: 4)
    )
    #expect(
        selection.selectedUTF16Range(row: .body(2), columnIndex: 1, utf16Length: 8)
            == NSRange(location: 0, length: 3)
    )
    #expect(
        selection.selectedUTF16Range(row: .body(2), columnIndex: 2, utf16Length: 8) == nil
    )
}

@Test
func subtitleTableTextSelectionClampsOffsetsAndUsesUTF16Lengths() {
    let text = "A😀B" as NSString
    #expect(text.length == 4)

    var emojiSelection = SubtitleTableTextSelectionState()
    emojiSelection.begin(at: .init(row: .body(0), columnIndex: 0, utf16Offset: 1))
    emojiSelection.updateFocus(to: .init(row: .body(0), columnIndex: 0, utf16Offset: 3))
    #expect(
        emojiSelection.selectedUTF16Range(row: .body(0), columnIndex: 0, utf16Length: text.length)
            == NSRange(location: 1, length: 2)
    )

    var clampedSelection = SubtitleTableTextSelectionState()
    clampedSelection.begin(at: .init(row: .body(0), columnIndex: 0, utf16Offset: -20))
    clampedSelection.updateFocus(to: .init(row: .body(0), columnIndex: 0, utf16Offset: 200))
    #expect(
        clampedSelection.selectedUTF16Range(row: .body(0), columnIndex: 0, utf16Length: text.length)
            == NSRange(location: 0, length: 4)
    )
}

@Test
func subtitleTableTextSelectionCollapsedAndBoundaryRangesAreEmpty() {
    let boundary = SubtitleTableTextPosition(row: .body(0), columnIndex: 1, utf16Offset: 4)
    var collapsed = SubtitleTableTextSelectionState()
    collapsed.begin(at: boundary)

    #expect(!collapsed.hasSelection)
    #expect(collapsed.orderedRange == nil)
    #expect(collapsed.selectedUTF16Range(row: .body(0), columnIndex: 1, utf16Length: 4) == nil)

    collapsed.updateFocus(to: .init(row: .body(0), columnIndex: 2, utf16Offset: 0))
    #expect(collapsed.selectedUTF16Range(row: .body(0), columnIndex: 1, utf16Length: 4) == nil)
    #expect(collapsed.selectedUTF16Range(row: .body(0), columnIndex: 2, utf16Length: 6) == nil)
}

@Test
func subtitleTableTextSelectionPreservesSelectedEmptyCellsAsStructure() {
    var selection = SubtitleTableTextSelectionState()
    selection.begin(at: .init(row: .body(0), columnIndex: 0, utf16Offset: 1))
    selection.updateFocus(to: .init(row: .body(0), columnIndex: 2, utf16Offset: 1))

    #expect(
        selection.cellSelection(row: .body(0), columnIndex: 1, utf16Length: 0) == .full
    )
    #expect(
        selection.cellSelection(row: .body(1), columnIndex: 1, utf16Length: 0) == .none
    )
    #expect(
        selection.selectedUTF16Range(row: .body(0), columnIndex: 1, utf16Length: 0) == nil
    )

    selection.selectAll()
    #expect(
        selection.cellSelection(row: .body(1_999_999), columnIndex: 6, utf16Length: 0) == .full
    )
}

@Test
func subtitleTableTextSelectionSelectAllIsAConstantSizeLogicalSentinel() {
    var selection = SubtitleTableTextSelectionState()
    selection.selectAll()

    #expect(selection.hasSelection)
    #expect(selection.selectsAllResults)
    #expect(selection.orderedRange == nil)
    #expect(
        selection.selectedUTF16Range(
            row: .body(1_999_999),
            columnIndex: 6,
            utf16Length: 12
        ) == NSRange(location: 0, length: 12)
    )

    selection.clear()
    #expect(!selection.hasSelection)
    #expect(!selection.selectsAllResults)
}
