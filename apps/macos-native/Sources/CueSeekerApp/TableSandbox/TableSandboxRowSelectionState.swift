import Foundation

enum WorkbenchCheckboxState: Equatable {
    case unchecked
    case checked
    case indeterminate
}

struct TableSandboxRowSelectionState: Equatable {
    private enum Storage: Equatable {
        case explicit(Set<Int>)
        case allExcept(Set<Int>)
    }

    private var storage: Storage = .explicit([])

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

    func headerState(rowCount: Int) -> WorkbenchCheckboxState {
        let safeRowCount = max(0, rowCount)
        guard safeRowCount > 0 else { return .unchecked }
        let count = selectedCount(rowCount: safeRowCount)
        if count == 0 {
            return .unchecked
        }
        if count == safeRowCount {
            return .checked
        }
        return .indeterminate
    }

    mutating func toggle(row: Int, rowCount: Int) {
        guard row >= 0, row < rowCount else { return }
        switch storage {
        case .explicit(var selectedRows):
            if selectedRows.contains(row) {
                selectedRows.remove(row)
            } else {
                selectedRows.insert(row)
            }
            storage = .explicit(selectedRows)
        case .allExcept(var deselectedRows):
            if deselectedRows.contains(row) {
                deselectedRows.remove(row)
            } else {
                deselectedRows.insert(row)
            }
            storage = .allExcept(deselectedRows)
        }
    }

    mutating func toggleAll(rowCount: Int) {
        switch headerState(rowCount: rowCount) {
        case .checked:
            reset()
        case .unchecked, .indeterminate:
            guard rowCount > 0 else {
                reset()
                return
            }
            storage = .allExcept([])
        }
    }

    mutating func reset() {
        storage = .explicit([])
    }

    mutating func shiftRows(by offset: Int) {
        guard offset != 0 else { return }
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
    }

    var trackedIndexCountForTesting: Int {
        switch storage {
        case .explicit(let selectedRows), .allExcept(let selectedRows):
            return selectedRows.count
        }
    }
}
