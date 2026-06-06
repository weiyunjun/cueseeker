import Foundation
import Testing
@testable import CueSeekerApp

@Test
func subtitleTableHeightInvalidationWindowExpandsVisibleRowsWithOverscan() {
    let window = SubtitleTableHeightInvalidationWindow.make(
        visibleRows: NSRange(location: 10, length: 20),
        rowCount: 100,
        overscan: 5
    )

    #expect(window?.range == 5..<35)
    #expect(window?.visibleCount == 20)
    #expect(window?.invalidatedCount == 30)
}

@Test
func subtitleTableHeightInvalidationWindowClampsToTableBounds() {
    let window = SubtitleTableHeightInvalidationWindow.make(
        visibleRows: NSRange(location: 2, length: 8),
        rowCount: 12,
        overscan: 10
    )

    #expect(window?.range == 0..<12)
    #expect(window?.visibleCount == 8)
}

@Test
func subtitleTableHeightInvalidationWindowRejectsEmptyVisibleRows() {
    let empty = SubtitleTableHeightInvalidationWindow.make(
        visibleRows: NSRange(location: 0, length: 0),
        rowCount: 100,
        overscan: 5
    )
    let outside = SubtitleTableHeightInvalidationWindow.make(
        visibleRows: NSRange(location: 120, length: 10),
        rowCount: 100,
        overscan: 5
    )

    #expect(empty == nil)
    #expect(outside == nil)
}
