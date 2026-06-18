import Testing
@testable import CueSeekerApp

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
func tableSandboxRowSelectionClampsWhenRowCountShrinks() {
    var selection = TableSandboxRowSelectionState()
    selection.toggle(row: 2, rowCount: 10)
    selection.toggle(row: 9, rowCount: 10)

    selection.clamp(rowCount: 5)

    #expect(selection.isSelected(2, rowCount: 5))
    #expect(!selection.isSelected(9, rowCount: 5))
    #expect(selection.selectedCount(rowCount: 5) == 1)
}
