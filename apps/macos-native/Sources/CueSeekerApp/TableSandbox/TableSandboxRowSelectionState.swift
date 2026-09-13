import Foundation

struct TableViewportAnchor: Equatable {
    let entryID: Int
    let rowIndex: Int
}

func resolvedTableViewportRow(
    anchor: TableViewportAnchor,
    rowCount: Int,
    identityRow: Int?
) -> Int? {
    guard rowCount > 0 else { return nil }
    if let identityRow, identityRow >= 0, identityRow < rowCount {
        return identityRow
    }
    return min(max(0, anchor.rowIndex - 1), rowCount - 1)
}

struct TableSandboxRowSelectionState: Equatable {
    private enum Storage: Equatable {
        case explicit(Set<Int>)
        case allExcept(Set<Int>)
    }

    private var storage: Storage = .explicit([])

    /// The row a Shift range extends from: the highest row the most recent
    /// selecting operation selected. Deselecting never moves it.
    private(set) var anchorRow: Int?

    func isSelected(_ row: Int, rowCount: Int) -> Bool {
        guard row >= 0, row < rowCount else { return false }
        switch storage {
        case .explicit(let selectedRows):
            return selectedRows.contains(row)
        case .allExcept(let deselectedRows):
            return !deselectedRows.contains(row)
        }
    }

    func selectedCount(rowCount: Int) -> Int {
        let safeRowCount = max(0, rowCount)
        switch storage {
        case .explicit(let selectedRows):
            return selectedRows.reduce(0) { count, row in
                row >= 0 && row < safeRowCount ? count + 1 : count
            }
        case .allExcept(let deselectedRows):
            let deselectedCount = deselectedRows.reduce(0) { count, row in
                row >= 0 && row < safeRowCount ? count + 1 : count
            }
            return max(0, safeRowCount - deselectedCount)
        }
    }

    func selectedRows(rowCount: Int) -> [Int] {
        let safeRowCount = max(0, rowCount)
        guard safeRowCount > 0 else { return [] }
        switch storage {
        case .explicit(let selectedRows):
            return selectedRows
                .filter { $0 >= 0 && $0 < safeRowCount }
                .sorted()
        case .allExcept(let deselectedRows):
            let excluded = Set(deselectedRows.filter { $0 >= 0 && $0 < safeRowCount })
            return (0..<safeRowCount).filter { !excluded.contains($0) }
        }
    }

    func selectedRows(in range: Range<Int>, rowCount: Int) -> [Int] {
        let safeRowCount = max(0, rowCount)
        let lowerBound = min(max(0, range.lowerBound), safeRowCount)
        let upperBound = min(max(lowerBound, range.upperBound), safeRowCount)
        guard lowerBound < upperBound else { return [] }

        switch storage {
        case .explicit(let selectedRows):
            return selectedRows
                .filter { $0 >= lowerBound && $0 < upperBound }
                .sorted()
        case .allExcept(let deselectedRows):
            let excluded = Set(deselectedRows.filter { $0 >= lowerBound && $0 < upperBound })
            return (lowerBound..<upperBound).filter { !excluded.contains($0) }
        }
    }

    /// The highest selected row, used to restore the anchor after the rows
    /// underneath it move or disappear.
    func lastSelectedRow(rowCount: Int) -> Int? {
        let safeRowCount = max(0, rowCount)
        guard safeRowCount > 0 else { return nil }
        switch storage {
        case .explicit(let selectedRows):
            return selectedRows.filter { $0 >= 0 && $0 < safeRowCount }.max()
        case .allExcept(let deselectedRows):
            var row = safeRowCount - 1
            while row >= 0, deselectedRows.contains(row) {
                row -= 1
            }
            return row >= 0 ? row : nil
        }
    }

    /// Rows that can be selected: every row but the unselectable ones.
    static func selectableCount(rowCount: Int, unselectableRows: Set<Int>) -> Int {
        let safeRowCount = max(0, rowCount)
        return safeRowCount - unselectableRows.reduce(0) { count, row in
            row >= 0 && row < safeRowCount ? count + 1 : count
        }
    }

    /// Unselectable rows are never selected, so the header is checked once
    /// every selectable row is.
    func headerState(
        rowCount: Int,
        unselectableRows: Set<Int> = []
    ) -> WorkbenchCheckboxState {
        let selectableCount = Self.selectableCount(
            rowCount: rowCount,
            unselectableRows: unselectableRows
        )
        guard selectableCount > 0 else { return .unchecked }
        let count = selectedCount(rowCount: rowCount)
        if count == 0 {
            return .unchecked
        }
        if count == selectableCount {
            return .checked
        }
        return .indeterminate
    }

    mutating func toggle(
        row: Int,
        rowCount: Int,
        unselectableRows: Set<Int> = []
    ) {
        guard row >= 0, row < rowCount, !unselectableRows.contains(row) else { return }
        let willSelect = !isSelected(row, rowCount: rowCount)
        setSelected(willSelect, row: row)
        if willSelect {
            anchorRow = row
        } else if selectedCount(rowCount: rowCount) == 0 {
            anchorRow = nil
        }
    }

    /// Shift plus a click on `row`, per the Shift range selection rules. A
    /// range passes over unselectable rows without selecting them.
    mutating func shiftClick(
        row: Int,
        rowCount: Int,
        unselectableRows: Set<Int> = []
    ) {
        guard row >= 0, row < rowCount, !unselectableRows.contains(row) else { return }
        guard selectedCount(rowCount: rowCount) > 0 else {
            selectRange(
                through: row,
                from: 0,
                rowCount: rowCount,
                unselectableRows: unselectableRows
            )
            return
        }
        if isSelected(row, rowCount: rowCount) {
            setSelected(false, row: row)
            if selectedCount(rowCount: rowCount) == 0 {
                anchorRow = nil
            }
            return
        }
        let anchor = anchorRow ?? lastSelectedRow(rowCount: rowCount) ?? row
        selectRange(
            through: row,
            from: anchor,
            rowCount: rowCount,
            unselectableRows: unselectableRows
        )
    }

    mutating func toggleAll(rowCount: Int, unselectableRows: Set<Int> = []) {
        switch headerState(rowCount: rowCount, unselectableRows: unselectableRows) {
        case .checked:
            reset()
        case .unchecked, .indeterminate:
            var lastSelectableRow = rowCount - 1
            while lastSelectableRow >= 0, unselectableRows.contains(lastSelectableRow) {
                lastSelectableRow -= 1
            }
            guard lastSelectableRow >= 0 else {
                reset()
                return
            }
            storage = .allExcept(unselectableRows.filter { $0 >= 0 && $0 < rowCount })
            anchorRow = lastSelectableRow
        }
    }

    mutating func reset() {
        storage = .explicit([])
        anchorRow = nil
    }

    private mutating func setSelected(_ isSelected: Bool, row: Int) {
        switch storage {
        case .explicit(var selectedRows):
            if isSelected {
                selectedRows.insert(row)
            } else {
                selectedRows.remove(row)
            }
            storage = .explicit(selectedRows)
        case .allExcept(var deselectedRows):
            if isSelected {
                deselectedRows.remove(row)
            } else {
                deselectedRows.insert(row)
            }
            storage = .allExcept(deselectedRows)
        }
    }

    private mutating func selectRange(
        through row: Int,
        from other: Int,
        rowCount: Int,
        unselectableRows: Set<Int>
    ) {
        let lower = max(0, min(row, other))
        let upper = min(rowCount - 1, max(row, other))
        guard lower <= upper else { return }
        let rows = (lower...upper).filter { !unselectableRows.contains($0) }
        guard let highestRow = rows.last else { return }
        switch storage {
        case .explicit(var selectedRows):
            selectedRows.formUnion(rows)
            storage = .explicit(selectedRows)
        case .allExcept(var deselectedRows):
            deselectedRows.subtract(rows)
            storage = .allExcept(deselectedRows)
        }
        anchorRow = highestRow
    }

    mutating func shiftRows(by offset: Int) {
        guard offset != 0 else { return }
        anchorRow = anchorRow.map { $0 + offset }
        switch storage {
        case .explicit(let selectedRows):
            storage = .explicit(Set(selectedRows.map { $0 + offset }))
        case .allExcept(let deselectedRows):
            storage = .allExcept(Set(deselectedRows.map { $0 + offset }))
        }
    }

    mutating func clamp(rowCount: Int) {
        let safeRowCount = max(0, rowCount)
        switch storage {
        case .explicit(let selectedRows):
            storage = .explicit(Set(selectedRows.filter { $0 >= 0 && $0 < safeRowCount }))
        case .allExcept(let deselectedRows):
            storage = .allExcept(Set(deselectedRows.filter { $0 >= 0 && $0 < safeRowCount }))
        }
        if let anchorRow, anchorRow >= 0, anchorRow < safeRowCount {
            return
        }
        anchorRow = lastSelectedRow(rowCount: safeRowCount)
    }

    var trackedIndexCountForTesting: Int {
        switch storage {
        case .explicit(let selectedRows), .allExcept(let selectedRows):
            return selectedRows.count
        }
    }
}
