import Combine
import CoreGraphics
import Foundation

enum PlaybackMediaSelectionDirection: Equatable, Sendable {
    case left
    case right
    case up
    case down
}

struct PlaybackMediaSelectionScrollRequest: Equatable, Sendable {
    let sequence: UInt64
    let itemID: String
}

/// Session-local selection for the adaptive media-card grids used by Playback
/// Recent and Library. The model operates on the grid's visual row/column
/// positions, while the views remain responsible for rendering and scrolling.
@MainActor
final class PlaybackMediaSelectionStore: ObservableObject {
    /// The grid's one highlighted card. A playback grid always keeps one lit,
    /// so a pointer that leaves the cards leaves it where it was.
    let highlight = CardHighlightModel(keepsCurrentWhenPointerLeaves: true)
    @Published private(set) var scrollRequest: PlaybackMediaSelectionScrollRequest?

    var selectedItemID: String? {
        highlight.selectedID
    }

    private(set) var orderedItemIDs: [String] = []
    private(set) var availableItemIDs: Set<String> = []
    private(set) var scrollAnchorItemID: String?
    private(set) var scrollOffsetY: CGFloat = 0
    private(set) var columnCount = 1
    private(set) var itemFramesByID: [String: CGRect] = [:]

    private var scrollRequestSequence: UInt64 = 0
    private var handledScrollRequestSequence: UInt64 = 0
    private var isActive = true

    init() {}

    var restorationItemID: String? {
        scrollAnchorItemID ?? selectedItemID
    }

    var pendingScrollRequest: PlaybackMediaSelectionScrollRequest? {
        guard let scrollRequest,
              scrollRequest.sequence > handledScrollRequestSequence
        else {
            return nil
        }
        return scrollRequest
    }

    func replaceItems(
        orderedItemIDs: [String],
        availableItemIDs: Set<String>,
        resetsSelection: Bool,
        preferredSelectionID: String? = nil
    ) {
        guard isActive else {
            return
        }

        var seen = Set<String>()
        let normalizedOrder = orderedItemIDs.filter { seen.insert($0).inserted }
        let normalizedAvailability = availableItemIDs.intersection(normalizedOrder)
        self.orderedItemIDs = normalizedOrder
        self.availableItemIDs = normalizedAvailability

        itemFramesByID = itemFramesByID.filter { normalizedOrder.contains($0.key) }
        if resetsSelection {
            scrollAnchorItemID = nil
            select(
                preferredSelectionID.flatMap {
                    normalizedAvailability.contains($0) ? $0 : nil
                } ?? normalizedOrder.first(
                    where: normalizedAvailability.contains
                ),
                forcesScroll: true
            )
        } else if selectedItemID.map({ !normalizedAvailability.contains($0) }) == true {
            select(normalizedOrder.first(where: normalizedAvailability.contains))
        } else if selectedItemID == nil {
            select(normalizedOrder.first(where: normalizedAvailability.contains))
        }

        if let scrollAnchorItemID,
           !normalizedOrder.contains(scrollAnchorItemID) {
            self.scrollAnchorItemID = nil
        }
    }

    func updateAdaptiveGrid(
        containerWidth: CGFloat,
        minimumItemWidth: CGFloat,
        itemGap: CGFloat,
        maxColumns: Int = WorkbenchControlMetrics
            .redesignLibraryRecentGridMaxColumnsWithoutSidebar
    ) {
        guard isActive else {
            return
        }
        let resolvedColumnCount = WorkbenchControlMetrics.mediaCardGridColumnCount(
            containerWidth: containerWidth,
            minimumItemWidth: minimumItemWidth,
            itemGap: itemGap,
            maxColumns: maxColumns
        )
        guard columnCount != resolvedColumnCount else {
            return
        }
        columnCount = resolvedColumnCount
        requestScrollToSelected()
    }

    func updateColumnCount(_ columnCount: Int) {
        guard isActive else {
            return
        }
        let resolvedColumnCount = max(1, columnCount)
        guard self.columnCount != resolvedColumnCount else {
            return
        }
        self.columnCount = resolvedColumnCount
        requestScrollToSelected()
    }

    @discardableResult
    func move(_ direction: PlaybackMediaSelectionDirection) -> Bool {
        guard isActive else {
            return false
        }
        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        guard let selectedItemID,
              let selectedIndex = orderedItemIDs.firstIndex(of: selectedItemID),
              let targetIndex = Self.targetIndex(
                  from: selectedIndex,
                  direction: direction,
                  orderedItemIDs: orderedItemIDs,
                  availableItemIDs: availableItemIDs,
                  columnCount: columnCount
              )
        else {
            return false
        }

        select(orderedItemIDs[targetIndex])
        return true
    }

    @discardableResult
    func selectFromAccessibility(_ itemID: String) -> Bool {
        guard isActive, availableItemIDs.contains(itemID) else {
            return false
        }
        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        select(itemID)
        return true
    }

    func recordVisibleFrames(
        _ framesByItemID: [String: CGRect],
        viewportHeight: CGFloat
    ) {
        guard isActive, viewportHeight > 0 else {
            return
        }

        let orderByID = Dictionary(
            uniqueKeysWithValues: orderedItemIDs.enumerated().map { ($1, $0) }
        )
        let newFrames = framesByItemID.filter { orderByID[$0.key] != nil }
        if newFrames != itemFramesByID {
            objectWillChange.send()
            itemFramesByID = newFrames
        }
        let hasNegativeMinY = framesByItemID.values.contains { $0.minY < 0 }
        let visibleMinY = hasNegativeMinY ? 0 : scrollOffsetY
        let visibleMaxY = visibleMinY + viewportHeight
        scrollAnchorItemID = framesByItemID
            .filter { itemID, frame in
                orderByID[itemID] != nil
                    && frame.maxY > visibleMinY
                    && frame.minY < visibleMaxY
            }
            .min { lhs, rhs in
                if abs(lhs.value.minY - rhs.value.minY) > 0.5 {
                    return lhs.value.minY < rhs.value.minY
                }
                return (orderByID[lhs.key] ?? .max)
                    < (orderByID[rhs.key] ?? .max)
            }?
            .key
    }

    func recordScrollOffsetY(_ offset: CGFloat) {
        guard isActive, offset.isFinite else {
            return
        }
        scrollOffsetY = max(0, offset)
    }

    func markScrollRequestHandled(sequence: UInt64) {
        guard isActive,
              let scrollRequest,
              scrollRequest.sequence == sequence
        else {
            return
        }
        handledScrollRequestSequence = max(
            handledScrollRequestSequence,
            sequence
        )
    }

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        orderedItemIDs = []
        availableItemIDs = []
        highlight.reset()
        scrollAnchorItemID = nil
        scrollOffsetY = 0
        scrollRequest = nil
        handledScrollRequestSequence = 0
        columnCount = 1
        itemFramesByID = [:]
    }

    private func select(_ itemID: String?, forcesScroll: Bool = false) {
        guard selectedItemID != itemID || forcesScroll else {
            return
        }
        highlight.setCurrent(itemID)
        guard let itemID else {
            scrollRequest = nil
            return
        }
        scrollRequestSequence &+= 1
        scrollRequest = PlaybackMediaSelectionScrollRequest(
            sequence: scrollRequestSequence,
            itemID: itemID
        )
    }

    static func targetIndex(
        from selectedIndex: Int,
        direction: PlaybackMediaSelectionDirection,
        orderedItemIDs: [String],
        availableItemIDs: Set<String>,
        columnCount: Int,
        sectionItemCounts: [Int]? = nil
    ) -> Int? {
        guard orderedItemIDs.indices.contains(selectedIndex) else {
            return nil
        }
        let rows = makeRows(
            itemCount: orderedItemIDs.count,
            columnCount: columnCount,
            sectionItemCounts: sectionItemCounts
        )
        guard let selectedRow = rows.firstIndex(where: { $0.contains(selectedIndex) }),
              let selectedColumn = rows[selectedRow].firstIndex(of: selectedIndex)
        else {
            return nil
        }
        let row = rows[selectedRow]

        switch direction {
        case .left:
            for column in (0..<selectedColumn).reversed() {
                let candidate = row[column]
                if availableItemIDs.contains(orderedItemIDs[candidate]) {
                    return candidate
                }
            }
            return nil
        case .right:
            for column in (selectedColumn + 1)..<row.count {
                let candidate = row[column]
                if availableItemIDs.contains(orderedItemIDs[candidate]) {
                    return candidate
                }
            }
            return nil
        case .up:
            guard selectedRow > 0 else {
                return nil
            }
            for targetRowIndex in (0..<selectedRow).reversed() {
                if let candidate = availableIndex(
                    in: rows[targetRowIndex],
                    preferredColumn: selectedColumn,
                    orderedItemIDs: orderedItemIDs,
                    availableItemIDs: availableItemIDs
                ) {
                    return candidate
                }
            }
            return nil
        case .down:
            guard selectedRow + 1 < rows.count else {
                return nil
            }
            for targetRowIndex in (selectedRow + 1)..<rows.count {
                if let candidate = availableIndex(
                    in: rows[targetRowIndex],
                    preferredColumn: selectedColumn,
                    orderedItemIDs: orderedItemIDs,
                    availableItemIDs: availableItemIDs
                ) {
                    return candidate
                }
            }
            return nil
        }
    }

    static func isFirstRow(
        index: Int,
        itemCount: Int,
        columnCount: Int,
        sectionItemCounts: [Int]? = nil
    ) -> Bool {
        let rows = makeRows(
            itemCount: itemCount,
            columnCount: columnCount,
            sectionItemCounts: sectionItemCounts
        )
        return rows.first?.contains(index) == true
    }

    static func targetScrollOffsetY(
        for itemID: String,
        isFirstRow: Bool = false,
        itemFramesByID: [String: CGRect],
        currentOffsetY: CGFloat,
        viewportHeight: CGFloat,
        topPadding: CGFloat = 0,
        bottomPadding: CGFloat = 0
    ) -> CGFloat? {
        guard viewportHeight > 0,
              let frame = itemFramesByID[itemID]
        else {
            return nil
        }
        let visibleMinY = max(0, currentOffsetY)
        let visibleMaxY = visibleMinY + viewportHeight

        if frame.minY < visibleMinY {
            if isFirstRow {
                return 0
            }
            return max(0, frame.minY - topPadding)
        }
        if frame.maxY > visibleMaxY {
            return max(0, frame.maxY + bottomPadding - viewportHeight)
        }
        return nil
    }

    private static func makeRows(
        itemCount: Int,
        columnCount: Int,
        sectionItemCounts: [Int]?
    ) -> [[Int]] {
        guard itemCount > 0 else {
            return []
        }
        let resolvedColumnCount = max(1, columnCount)
        let counts: [Int]
        if let sectionItemCounts,
           !sectionItemCounts.isEmpty,
           sectionItemCounts.reduce(0, +) == itemCount {
            counts = sectionItemCounts
        } else {
            counts = [itemCount]
        }

        var rows: [[Int]] = []
        var nextIndex = 0
        for sectionCount in counts where sectionCount > 0 {
            let sectionEnd = min(itemCount, nextIndex + sectionCount)
            var rowStart = nextIndex
            while rowStart < sectionEnd {
                let rowEnd = min(sectionEnd, rowStart + resolvedColumnCount)
                rows.append(Array(rowStart..<rowEnd))
                rowStart = rowEnd
            }
            nextIndex = sectionEnd
        }
        return rows
    }

    private static func availableIndex(
        in row: [Int],
        preferredColumn: Int,
        orderedItemIDs: [String],
        availableItemIDs: Set<String>
    ) -> Int? {
        guard !row.isEmpty else {
            return nil
        }
        let clampedColumn = min(max(0, preferredColumn), row.count - 1)
        let preferredIndex = row[clampedColumn]
        if availableItemIDs.contains(orderedItemIDs[preferredIndex]) {
            return preferredIndex
        }
        for offset in 1..<row.count {
            let leftColumn = clampedColumn - offset
            if leftColumn >= 0 {
                let candidate = row[leftColumn]
                if availableItemIDs.contains(orderedItemIDs[candidate]) {
                    return candidate
                }
            }
            let rightColumn = clampedColumn + offset
            if rightColumn < row.count {
                let candidate = row[rightColumn]
                if availableItemIDs.contains(orderedItemIDs[candidate]) {
                    return candidate
                }
            }
        }
        return nil
    }

    private func requestScrollToSelected() {
        guard let selectedItemID else {
            return
        }
        scrollRequestSequence &+= 1
        scrollRequest = PlaybackMediaSelectionScrollRequest(
            sequence: scrollRequestSequence,
            itemID: selectedItemID
        )
    }
}
