import Testing
@testable import CueSeekerApp

@Test
func tableViewportAnchorPrefersTheSameEntryAfterRowsMove() {
    let anchor = TableViewportAnchor(entryID: 100, rowIndex: 100)

    #expect(
        resolvedTableViewportRow(
            anchor: anchor,
            rowCount: 200,
            identityRow: 42
        ) == 42
    )
}

@Test
func tableViewportAnchorFallsBackToTheNearestPreviousPosition() {
    let anchor = TableViewportAnchor(entryID: 100, rowIndex: 100)

    #expect(
        resolvedTableViewportRow(
            anchor: anchor,
            rowCount: 200,
            identityRow: nil
        ) == 99
    )
    #expect(
        resolvedTableViewportRow(
            anchor: anchor,
            rowCount: 50,
            identityRow: nil
        ) == 49
    )
    #expect(
        resolvedTableViewportRow(
            anchor: anchor,
            rowCount: 0,
            identityRow: nil
        ) == nil
    )
}

@Test
func tableSandboxRowSelectionTogglesIndividualRows() {
    var selection = TableSandboxRowSelectionState()

    #expect(selection.headerState(rowCount: 10) == .unchecked)
    selection.toggle(row: 3, rowCount: 10)

    #expect(selection.isSelected(3, rowCount: 10))
    #expect(selection.selectedCount(rowCount: 10) == 1)
    #expect(selection.headerState(rowCount: 10) == .indeterminate)

    selection.toggle(row: 3, rowCount: 10)

    #expect(!selection.isSelected(3, rowCount: 10))
    #expect(selection.selectedCount(rowCount: 10) == 0)
    #expect(selection.headerState(rowCount: 10) == .unchecked)
}

@Test
func tableSandboxRowSelectionSelectsAllWithoutMaterializingEveryRow() {
    var selection = TableSandboxRowSelectionState()

    selection.toggleAll(rowCount: 100_000)

    #expect(selection.headerState(rowCount: 100_000) == .checked)
    #expect(selection.selectedCount(rowCount: 100_000) == 100_000)
    #expect(selection.trackedIndexCountForTesting == 0)
    #expect(selection.isSelected(99_999, rowCount: 100_000))

    selection.toggle(row: 42, rowCount: 100_000)

    #expect(selection.headerState(rowCount: 100_000) == .indeterminate)
    #expect(selection.selectedCount(rowCount: 100_000) == 99_999)
    #expect(selection.trackedIndexCountForTesting == 1)
    #expect(!selection.isSelected(42, rowCount: 100_000))

    selection.toggleAll(rowCount: 100_000)

    #expect(selection.headerState(rowCount: 100_000) == .checked)
    #expect(selection.selectedCount(rowCount: 100_000) == 100_000)
    #expect(selection.trackedIndexCountForTesting == 0)

    selection.toggleAll(rowCount: 100_000)

    #expect(selection.headerState(rowCount: 100_000) == .unchecked)
    #expect(selection.selectedCount(rowCount: 100_000) == 0)
}

@Test
func tableSandboxRowSelectionReturnsExplicitRowsInsideRange() {
    var selection = TableSandboxRowSelectionState()
    selection.toggle(row: 2, rowCount: 12)
    selection.toggle(row: 7, rowCount: 12)
    selection.toggle(row: 11, rowCount: 12)

    #expect(selection.selectedRows(in: 0..<5, rowCount: 12) == [2])
    #expect(selection.selectedRows(in: 5..<10, rowCount: 12) == [7])
    #expect(selection.selectedRows(in: 10..<20, rowCount: 12) == [11])
}

@Test
func tableSandboxRowSelectionReturnsAllExceptRowsInsideRange() {
    var selection = TableSandboxRowSelectionState()
    selection.toggleAll(rowCount: 12)
    selection.toggle(row: 6, rowCount: 12)

    #expect(selection.selectedRows(in: 5..<10, rowCount: 12) == [5, 7, 8, 9])
    #expect(selection.trackedIndexCountForTesting == 1)
}

@Test
func tableSandboxRowSelectionClampsWhenRowCountShrinks() {
    var selection = TableSandboxRowSelectionState()
    selection.toggle(row: 2, rowCount: 10)
    selection.toggle(row: 9, rowCount: 10)

    selection.clamp(rowCount: 5)

    #expect(selection.isSelected(2, rowCount: 5))
    #expect(!selection.isSelected(9, rowCount: 5))
    #expect(selection.selectedCount(rowCount: 5) == 1)
}

@Test
func tableSandboxRowSelectionShiftsExplicitRowsWhenRowsArePrepended() {
    var selection = TableSandboxRowSelectionState()
    selection.toggle(row: 0, rowCount: 3)
    selection.toggle(row: 2, rowCount: 3)

    selection.shiftRows(by: 4)

    #expect(!selection.isSelected(0, rowCount: 7))
    #expect(selection.isSelected(4, rowCount: 7))
    #expect(selection.isSelected(6, rowCount: 7))
    #expect(selection.selectedRows(rowCount: 7) == [4, 6])
}

@Test
func tableSandboxRowSelectionShiftsAllExceptRowsWhenRowsArePrepended() {
    var selection = TableSandboxRowSelectionState()
    selection.toggleAll(rowCount: 5)
    selection.toggle(row: 1, rowCount: 5)

    selection.shiftRows(by: 3)

    #expect(selection.isSelected(0, rowCount: 8))
    #expect(selection.isSelected(3, rowCount: 8))
    #expect(!selection.isSelected(4, rowCount: 8))
    #expect(selection.selectedCount(rowCount: 8) == 7)
}
