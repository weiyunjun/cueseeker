import AppKit

struct SubtitleTableRowHeightCacheLookup {
    let height: CGFloat
    let isCacheHit: Bool
}

struct SubtitleTableRowHeightCache {
    private var entries: [Int: CacheEntry] = [:]

    var count: Int {
        entries.count
    }

    mutating func lookup(
        rowIndex: Int,
        row: SubtitleTableRow,
        nameWidth: CGFloat,
        cuesWidth: CGFloat,
        compute: () -> CGFloat
    ) -> SubtitleTableRowHeightCacheLookup {
        guard rowIndex >= 0 else {
            let height = compute()
            return SubtitleTableRowHeightCacheLookup(height: height, isCacheHit: false)
        }

        let nameWidthKey = Self.widthKey(nameWidth)
        let cuesWidthKey = Self.widthKey(cuesWidth)

        if let entry = entries[rowIndex],
           entry.matches(row: row, nameWidth: nameWidthKey, cuesWidth: cuesWidthKey) {
            return SubtitleTableRowHeightCacheLookup(height: entry.height, isCacheHit: true)
        }

        let height = compute()
        entries[rowIndex] = CacheEntry(
            rowID: row.id,
            displayTitle: row.displayTitle,
            cues: row.cues,
            nameWidth: nameWidthKey,
            cuesWidth: cuesWidthKey,
            height: height
        )
        return SubtitleTableRowHeightCacheLookup(height: height, isCacheHit: false)
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
    let displayTitle: String
    let cues: String
    let nameWidth: Int
    let cuesWidth: Int
    let height: CGFloat

    func matches(row: SubtitleTableRow, nameWidth: Int, cuesWidth: Int) -> Bool {
        matches(row: row)
            && self.nameWidth == nameWidth
            && self.cuesWidth == cuesWidth
    }

    func matches(row: SubtitleTableRow) -> Bool {
        rowID == row.id
            && displayTitle == row.displayTitle
            && cues == row.cues
    }
}
