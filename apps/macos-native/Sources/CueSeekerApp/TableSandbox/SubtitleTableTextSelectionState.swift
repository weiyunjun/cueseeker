import Foundation

enum SubtitleTableTextRow: Comparable, Equatable, Hashable, Sendable {
    case header
    case body(Int)

    static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.header, .header):
            return false
        case (.header, .body):
            return true
        case (.body, .header):
            return false
        case (.body(let lhsRow), .body(let rhsRow)):
            return lhsRow < rhsRow
        }
    }
}

struct SubtitleTableTextPosition: Comparable, Equatable, Hashable, Sendable {
    let row: SubtitleTableTextRow
    let columnIndex: Int
    let utf16Offset: Int

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.row != rhs.row {
            return lhs.row < rhs.row
        }
        if lhs.columnIndex != rhs.columnIndex {
            return lhs.columnIndex < rhs.columnIndex
        }
        return lhs.utf16Offset < rhs.utf16Offset
    }
}

enum SubtitleTableTextCellSelection: Equatable, Sendable {
    case none
    case full
    case range(NSRange)
}

struct SubtitleTableTextSelectionState: Equatable, Sendable {
    private enum Storage: Equatable, Sendable {
        case none
        case range(anchor: SubtitleTableTextPosition, focus: SubtitleTableTextPosition)
        case all
    }

    private var storage: Storage = .none

    var hasSelection: Bool {
        switch storage {
        case .none:
            return false
        case .range(let anchor, let focus):
            return anchor != focus
        case .all:
            return true
        }
    }

    var selectsAllResults: Bool {
        if case .all = storage {
            return true
        }
        return false
    }

    var orderedRange: (start: SubtitleTableTextPosition, end: SubtitleTableTextPosition)? {
        guard case .range(let anchor, let focus) = storage,
              anchor != focus
        else {
            return nil
        }
        return anchor < focus ? (anchor, focus) : (focus, anchor)
    }

    mutating func begin(at position: SubtitleTableTextPosition) {
        storage = .range(anchor: position, focus: position)
    }

    mutating func updateFocus(to position: SubtitleTableTextPosition) {
        guard case .range(let anchor, _) = storage else { return }
        storage = .range(anchor: anchor, focus: position)
    }

    mutating func selectAll() {
        storage = .all
    }

    mutating func clear() {
        storage = .none
    }

    func selectedUTF16Range(
        row: SubtitleTableTextRow,
        columnIndex: Int,
        utf16Length: Int
    ) -> NSRange? {
        switch cellSelection(row: row, columnIndex: columnIndex, utf16Length: utf16Length) {
        case .none:
            return nil
        case .full:
            let safeLength = max(0, utf16Length)
            return safeLength > 0 ? NSRange(location: 0, length: safeLength) : nil
        case .range(let range):
            return range
        }
    }

    func cellSelection(
        row: SubtitleTableTextRow,
        columnIndex: Int,
        utf16Length: Int
    ) -> SubtitleTableTextCellSelection {
        let safeLength = max(0, utf16Length)
        switch storage {
        case .none:
            return .none
        case .all:
            return .full
        case .range:
            guard let selection = orderedRange else { return .none }
            let cellStart = SubtitleTableTextPosition(
                row: row,
                columnIndex: columnIndex,
                utf16Offset: 0
            )
            if safeLength == 0 {
                return selection.start <= cellStart && cellStart <= selection.end ? .full : .none
            }
            let cellEnd = SubtitleTableTextPosition(
                row: row,
                columnIndex: columnIndex,
                utf16Offset: safeLength
            )
            guard selection.start < cellEnd, cellStart < selection.end else {
                return .none
            }

            let lower = selection.start.row == row && selection.start.columnIndex == columnIndex
                ? selection.start.utf16Offset
                : 0
            let upper = selection.end.row == row && selection.end.columnIndex == columnIndex
                ? selection.end.utf16Offset
                : safeLength
            let clampedLower = min(max(0, lower), safeLength)
            let clampedUpper = min(max(clampedLower, upper), safeLength)
            guard clampedUpper > clampedLower else { return .none }
            if clampedLower == 0, clampedUpper == safeLength {
                return .full
            }
            return .range(NSRange(location: clampedLower, length: clampedUpper - clampedLower))
        }
    }
}
