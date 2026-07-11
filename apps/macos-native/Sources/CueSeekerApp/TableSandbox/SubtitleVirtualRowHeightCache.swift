import CoreGraphics

struct SubtitleVirtualRowHeightCache {
    private(set) var rowCount = 0
    private(set) var defaultHeight: CGFloat = SubtitleTableCueGeometry.minimumRowHeight
    private var measuredHeights: [Int: CGFloat] = [:]
    private var fenwickDeltas: [Int: CGFloat] = [:]

    var count: Int {
        measuredHeights.count
    }

    var totalHeight: CGFloat {
        CGFloat(rowCount) * defaultHeight + prefixDelta(rowCount)
    }

    mutating func configure(rowCount: Int, defaultHeight: CGFloat) {
        let nextRowCount = max(0, rowCount)
        let nextDefaultHeight = max(1, defaultHeight)
        guard nextRowCount != self.rowCount || nextDefaultHeight != self.defaultHeight else {
            return
        }

        let defaultHeightChanged = nextDefaultHeight != self.defaultHeight
        self.rowCount = nextRowCount
        self.defaultHeight = nextDefaultHeight
        if defaultHeightChanged {
            measuredHeights.removeAll(keepingCapacity: true)
        } else {
            measuredHeights = measuredHeights.filter { row, _ in
                row >= 0 && row < nextRowCount
            }
        }
        rebuildFenwickDeltas()
    }

    mutating func removeAll() {
        measuredHeights.removeAll(keepingCapacity: true)
        fenwickDeltas.removeAll(keepingCapacity: true)
    }

    mutating func removeHeight(for row: Int) {
        guard let oldHeight = measuredHeights.removeValue(forKey: row) else { return }
        addFenwickDelta(defaultHeight - oldHeight, at: row)
    }

    func height(for row: Int) -> CGFloat {
        guard row >= 0, row < rowCount else { return defaultHeight }
        return measuredHeights[row] ?? defaultHeight
    }

    @discardableResult
    mutating func setHeight(_ height: CGFloat, for row: Int) -> Bool {
        guard row >= 0, row < rowCount else { return false }
        let nextHeight = max(defaultHeight, height)
        let oldHeight = measuredHeights[row] ?? defaultHeight
        guard abs(nextHeight - oldHeight) > 0.001 else { return false }

        if abs(nextHeight - defaultHeight) <= 0.001 {
            measuredHeights.removeValue(forKey: row)
        } else {
            measuredHeights[row] = nextHeight
        }
        addFenwickDelta(nextHeight - oldHeight, at: row)
        return true
    }

    func yOffset(for row: Int) -> CGFloat {
        let clampedRow = min(max(0, row), rowCount)
        return CGFloat(clampedRow) * defaultHeight + prefixDelta(clampedRow)
    }

    func rowIndex(atY y: CGFloat) -> Int {
        guard rowCount > 0 else { return 0 }
        if y == .infinity { return rowCount - 1 }
        let targetY = y.isFinite ? max(0, y) : 0
        var index = 0
        var prefixDelta: CGFloat = 0
        var bit = highestPowerOfTwo(notExceeding: rowCount)
        while bit > 0 {
            let nextIndex = index + bit
            if nextIndex <= rowCount {
                let nextPrefixDelta = prefixDelta + (fenwickDeltas[nextIndex] ?? 0)
                let nextPrefixHeight = CGFloat(nextIndex) * defaultHeight + nextPrefixDelta
                if nextPrefixHeight <= targetY {
                    index = nextIndex
                    prefixDelta = nextPrefixDelta
                }
            }
            bit >>= 1
        }
        return min(index, rowCount - 1)
    }

    private mutating func rebuildFenwickDeltas() {
        fenwickDeltas.removeAll(keepingCapacity: true)
        for (row, height) in measuredHeights {
            addFenwickDelta(height - defaultHeight, at: row)
        }
    }

    private mutating func addFenwickDelta(_ delta: CGFloat, at row: Int) {
        guard abs(delta) > 0.001, row >= 0, row < rowCount else { return }
        var index = row + 1
        while index <= rowCount {
            let nextValue = (fenwickDeltas[index] ?? 0) + delta
            if abs(nextValue) <= 0.001 {
                fenwickDeltas.removeValue(forKey: index)
            } else {
                fenwickDeltas[index] = nextValue
            }
            let step = index & -index
            guard step > 0, index <= rowCount - step else { break }
            index += step
        }
    }

    private func prefixDelta(_ rowCount: Int) -> CGFloat {
        var index = min(max(0, rowCount), self.rowCount)
        var result: CGFloat = 0
        while index > 0 {
            result += fenwickDeltas[index] ?? 0
            index -= index & -index
        }
        return result
    }

    private func highestPowerOfTwo(notExceeding value: Int) -> Int {
        guard value > 0 else { return 0 }
        var result = 1
        while result <= value / 2 {
            result <<= 1
        }
        return result
    }
}
