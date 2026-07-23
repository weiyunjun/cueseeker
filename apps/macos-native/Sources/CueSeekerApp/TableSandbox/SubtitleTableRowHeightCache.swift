import AppKit

struct SubtitleTableRowMeasurementLayoutKey: Equatable {
    let columnWidths: [String: Int]

    init(columnWidths: [String: CGFloat]) {
        self.columnWidths = columnWidths.mapValues(Self.widthKey)
    }

    private static func widthKey(_ width: CGFloat) -> Int {
        Int((max(0, width) * 100).rounded())
    }
}

struct SubtitleTableRowHeightCacheLookup {
    let measurement: SubtitleTableRowMeasurement
    let isCacheHit: Bool

    var height: CGFloat {
        measurement.height
    }
}

struct SubtitleTableRowHeightCache {
    private var entries: [Int: CacheEntry] = [:]

    var count: Int {
        entries.count
    }

    mutating func lookup(
        rowIndex: Int,
        row: SubtitleTableRow,
        layoutKey: SubtitleTableRowMeasurementLayoutKey,
        showsCueGroup: Bool,
        styleRevision: Int,
        compute: () -> SubtitleTableRowMeasurement
    ) -> SubtitleTableRowHeightCacheLookup {
        guard rowIndex >= 0 else {
            return SubtitleTableRowHeightCacheLookup(measurement: compute(), isCacheHit: false)
        }

        if let entry = entries[rowIndex],
           entry.matches(
               row: row,
               layoutKey: layoutKey,
               showsCueGroup: showsCueGroup,
               styleRevision: styleRevision
           ) {
            return SubtitleTableRowHeightCacheLookup(measurement: entry.measurement, isCacheHit: true)
        }

        let measurement = compute()
        entries[rowIndex] = CacheEntry(
            row: row,
            layoutKey: layoutKey,
            showsCueGroup: showsCueGroup,
            styleRevision: styleRevision,
            measurement: measurement
        )
        return SubtitleTableRowHeightCacheLookup(measurement: measurement, isCacheHit: false)
    }

    func cachedMeasurement(
        rowIndex: Int,
        row: SubtitleTableRow,
        layoutKey: SubtitleTableRowMeasurementLayoutKey,
        showsCueGroup: Bool,
        styleRevision: Int
    ) -> SubtitleTableRowMeasurement? {
        guard let entry = entries[rowIndex],
              entry.matches(
                  row: row,
                  layoutKey: layoutKey,
                  showsCueGroup: showsCueGroup,
                  styleRevision: styleRevision
              )
        else {
            return nil
        }
        return entry.measurement
    }

    func cachedMeasurement(
        rowIndex: Int,
        primaryCueIdentity: SubtitleTablePrimaryCueIdentity
    ) -> SubtitleTableRowMeasurement? {
        guard let entry = entries[rowIndex] else { return nil }
        switch primaryCueIdentity {
        case .cue(let cueID):
            guard entry.row.primaryCueID == cueID else { return nil }
        case .rowFallback(let rowID):
            guard entry.row.id == rowID, entry.row.primaryCueID == nil else { return nil }
        }
        return entry.measurement
    }

    mutating func removeAll() {
        entries.removeAll(keepingCapacity: false)
    }

    mutating func remove(rowIndex: Int) {
        entries.removeValue(forKey: rowIndex)
    }

    mutating func retain(rowIndices: Range<Int>) {
        entries = entries.filter { rowIndices.contains($0.key) }
    }

    mutating func prune(to rows: [SubtitleTableRow]) {
        prune(rowCount: rows.count) { index in
            guard rows.indices.contains(index) else { return nil }
            return rows[index]
        }
    }

    mutating func prune(rowCount: Int, rowProvider: (Int) -> SubtitleTableRow?) {
        entries = entries.filter { index, entry in
            guard index >= 0, index < rowCount, let row = rowProvider(index) else {
                return false
            }
            return entry.matches(row: row)
        }
    }
}

private struct CacheEntry {
    let row: SubtitleTableRow
    let layoutKey: SubtitleTableRowMeasurementLayoutKey
    let showsCueGroup: Bool
    let styleRevision: Int
    let measurement: SubtitleTableRowMeasurement

    func matches(
        row: SubtitleTableRow,
        layoutKey: SubtitleTableRowMeasurementLayoutKey,
        showsCueGroup: Bool,
        styleRevision: Int
    ) -> Bool {
        matches(row: row)
            && self.layoutKey == layoutKey
            && self.showsCueGroup == showsCueGroup
            && self.styleRevision == styleRevision
    }

    func matches(row: SubtitleTableRow) -> Bool {
        self.row == row
    }
}
