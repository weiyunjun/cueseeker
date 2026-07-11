import AppKit

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
        effectiveCuesWidth: CGFloat,
        showsCueGroup: Bool,
        styleRevision: Int,
        compute: () -> SubtitleTableRowMeasurement
    ) -> SubtitleTableRowHeightCacheLookup {
        guard rowIndex >= 0 else {
            return SubtitleTableRowHeightCacheLookup(measurement: compute(), isCacheHit: false)
        }

        let cuesWidthKey = Self.widthKey(effectiveCuesWidth)

        if let entry = entries[rowIndex],
           entry.matches(
               row: row,
               cuesWidth: cuesWidthKey,
               showsCueGroup: showsCueGroup,
               styleRevision: styleRevision
           ) {
            return SubtitleTableRowHeightCacheLookup(measurement: entry.measurement, isCacheHit: true)
        }

        let measurement = compute()
        entries[rowIndex] = CacheEntry(
            rowID: row.id,
            primaryCueID: row.primaryCueID,
            primaryCueText: row.primaryCueText,
            cueGroupTexts: row.cueGroupTexts,
            primaryGroupIndex: row.primaryGroupIndex,
            cuesWidth: cuesWidthKey,
            showsCueGroup: showsCueGroup,
            styleRevision: styleRevision,
            measurement: measurement
        )
        return SubtitleTableRowHeightCacheLookup(measurement: measurement, isCacheHit: false)
    }

    func cachedMeasurement(
        rowIndex: Int,
        row: SubtitleTableRow,
        effectiveCuesWidth: CGFloat,
        showsCueGroup: Bool,
        styleRevision: Int
    ) -> SubtitleTableRowMeasurement? {
        let cuesWidthKey = Self.widthKey(effectiveCuesWidth)
        guard let entry = entries[rowIndex],
              entry.matches(
                  row: row,
                  cuesWidth: cuesWidthKey,
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
            guard entry.primaryCueID == cueID else { return nil }
        case .rowFallback(let rowID):
            guard entry.rowID == rowID, entry.primaryCueID == nil else { return nil }
        }
        return entry.measurement
    }

    mutating func removeAll() {
        entries.removeAll(keepingCapacity: true)
    }

    mutating func remove(rowIndex: Int) {
        entries.removeValue(forKey: rowIndex)
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

    static func widthKey(_ width: CGFloat) -> Int {
        Int((max(0, width) * 100).rounded())
    }
}

private struct CacheEntry {
    let rowID: Int
    let primaryCueID: Int64?
    let primaryCueText: String
    let cueGroupTexts: [String]
    let primaryGroupIndex: Int?
    let cuesWidth: Int
    let showsCueGroup: Bool
    let styleRevision: Int
    let measurement: SubtitleTableRowMeasurement

    func matches(
        row: SubtitleTableRow,
        cuesWidth: Int,
        showsCueGroup: Bool,
        styleRevision: Int
    ) -> Bool {
        matches(row: row)
            && self.cuesWidth == cuesWidth
            && self.showsCueGroup == showsCueGroup
            && self.styleRevision == styleRevision
    }

    func matches(row: SubtitleTableRow) -> Bool {
        rowID == row.id
            && primaryCueID == row.primaryCueID
            && primaryCueText == row.primaryCueText
            && cueGroupTexts == row.cueGroupTexts
            && primaryGroupIndex == row.primaryGroupIndex
    }
}
