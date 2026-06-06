import AppKit

struct SubtitleTableRowHeightCacheLookup {
    let height: CGFloat
    let isCacheHit: Bool
}

struct SubtitleTableRowHeightCache {
    private var entries: [CacheEntry?] = []

    var count: Int {
        entries.reduce(0) { $0 + ($1 == nil ? 0 : 1) }
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

        if rowIndex >= entries.count {
            entries.append(contentsOf: repeatElement(nil, count: rowIndex - entries.count + 1))
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
            name: row.name,
            cues: row.cues,
            nameWidth: nameWidthKey,
            cuesWidth: cuesWidthKey,
            height: height
        )
        return SubtitleTableRowHeightCacheLookup(height: height, isCacheHit: false)
    }

    mutating func prune(to rows: [SubtitleTableRow]) {
        if entries.count > rows.count {
            entries.removeSubrange(rows.count..<entries.count)
        }

        for index in rows.indices {
            guard index < entries.count, let entry = entries[index] else { continue }
            if !entry.matches(row: rows[index]) {
                entries[index] = nil
            }
        }
    }

    static func widthKey(_ width: CGFloat) -> Int {
        Int((max(0, width) * 100).rounded())
    }
}

private struct CacheEntry {
    let rowID: Int
    let name: String
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
            && name == row.name
            && cues == row.cues
    }
}
