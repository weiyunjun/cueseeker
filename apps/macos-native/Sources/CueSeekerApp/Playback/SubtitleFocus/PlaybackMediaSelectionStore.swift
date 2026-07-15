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
    @Published private(set) var selectedItemID: String?
    @Published private(set) var scrollRequest: PlaybackMediaSelectionScrollRequest?

    private(set) var orderedItemIDs: [String] = []
    private(set) var availableItemIDs: Set<String> = []
    private(set) var scrollAnchorItemID: String?
    private(set) var scrollOffsetY: CGFloat = 0
    private(set) var columnCount = 1
    private(set) var itemFramesByID: [String: CGRect] = [:]

    private var scrollRequestSequence: UInt64 = 0
    private var isActive = true

    var restorationItemID: String? {
        scrollAnchorItemID ?? selectedItemID
    }

    func replaceItems(
        orderedItemIDs: [String],
        availableItemIDs: Set<String>,
        resetsSelection: Bool
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
                normalizedOrder.first(where: normalizedAvailability.contains),
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
        itemGap: CGFloat
    ) {
        guard isActive else {
            return
        }
        let resolvedWidth = max(0, containerWidth)
        let resolvedMinimum = max(1, minimumItemWidth)
        let resolvedGap = max(0, itemGap)
        let resolvedColumnCount = max(
            1,
            Int((resolvedWidth + resolvedGap) / (resolvedMinimum + resolvedGap))
        )
        guard columnCount != resolvedColumnCount else {
            return
        }
        columnCount = resolvedColumnCount
        itemFramesByID = [:]
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
        itemFramesByID = [:]
        requestScrollToSelected()
    }

    @discardableResult
    func move(_ direction: PlaybackMediaSelectionDirection) -> Bool {
        guard isActive,
              let selectedItemID,
              let selectedIndex = orderedItemIDs.firstIndex(of: selectedItemID),
              let targetIndex = targetIndex(
                  from: selectedIndex,
                  direction: direction
              )
        else {
            return false
        }

        select(orderedItemIDs[targetIndex])
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
        itemFramesByID = framesByItemID.filter { orderByID[$0.key] != nil }
        scrollAnchorItemID = framesByItemID
            .filter { itemID, frame in
                orderByID[itemID] != nil
                    && frame.maxY > 0
                    && frame.minY < viewportHeight
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

    func invalidate() {
        guard isActive else {
            return
        }
        isActive = false
        orderedItemIDs = []
        availableItemIDs = []
        selectedItemID = nil
        scrollAnchorItemID = nil
        scrollOffsetY = 0
        scrollRequest = nil
        columnCount = 1
        itemFramesByID = [:]
    }

    private func select(_ itemID: String?, forcesScroll: Bool = false) {
        guard selectedItemID != itemID || forcesScroll else {
            return
        }
        selectedItemID = itemID
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

    private func targetIndex(
        from selectedIndex: Int,
        direction: PlaybackMediaSelectionDirection
    ) -> Int? {
        if let frameTarget = frameTargetIndex(
            from: selectedIndex,
            direction: direction
        ) {
            return frameTarget
        }

        let selectedRow = selectedIndex / columnCount
        let selectedColumn = selectedIndex % columnCount

        let candidates = orderedItemIDs.indices.compactMap { index -> Candidate? in
            guard index != selectedIndex,
                  availableItemIDs.contains(orderedItemIDs[index])
            else {
                return nil
            }

            let row = index / columnCount
            let column = index % columnCount
            let rowDistance = abs(row - selectedRow)
            let columnDistance = abs(column - selectedColumn)

            switch direction {
            case .left:
                guard row == selectedRow, column < selectedColumn else {
                    return nil
                }
            case .right:
                guard row == selectedRow, column > selectedColumn else {
                    return nil
                }
            case .up:
                guard row < selectedRow else {
                    return nil
                }
            case .down:
                guard row > selectedRow else {
                    return nil
                }
            }

            return Candidate(
                index: index,
                squaredDistance: rowDistance * rowDistance
                    + columnDistance * columnDistance,
                primaryDistance: direction == .left || direction == .right
                    ? columnDistance
                    : rowDistance,
                crossDistance: direction == .left || direction == .right
                    ? rowDistance
                    : columnDistance
            )
        }

        return candidates.min { lhs, rhs in
            if lhs.squaredDistance != rhs.squaredDistance {
                return lhs.squaredDistance < rhs.squaredDistance
            }
            if lhs.primaryDistance != rhs.primaryDistance {
                return lhs.primaryDistance < rhs.primaryDistance
            }
            if lhs.crossDistance != rhs.crossDistance {
                return lhs.crossDistance < rhs.crossDistance
            }
            return lhs.index < rhs.index
        }?.index
    }

    private func frameTargetIndex(
        from selectedIndex: Int,
        direction: PlaybackMediaSelectionDirection
    ) -> Int? {
        let selectedID = orderedItemIDs[selectedIndex]
        guard let selectedFrame = itemFramesByID[selectedID] else {
            return nil
        }
        let selectedCenter = CGPoint(
            x: selectedFrame.midX,
            y: selectedFrame.midY
        )

        return orderedItemIDs.indices.compactMap { index -> FrameCandidate? in
            guard index != selectedIndex,
                  availableItemIDs.contains(orderedItemIDs[index]),
                  let frame = itemFramesByID[orderedItemIDs[index]]
            else {
                return nil
            }
            let dx = frame.midX - selectedCenter.x
            let dy = frame.midY - selectedCenter.y
            let primaryDistance: CGFloat
            let crossDistance: CGFloat
            switch direction {
            case .left:
                guard dx < -0.5, abs(dx) >= abs(dy) else {
                    return nil
                }
                primaryDistance = abs(dx)
                crossDistance = abs(dy)
            case .right:
                guard dx > 0.5, abs(dx) >= abs(dy) else {
                    return nil
                }
                primaryDistance = abs(dx)
                crossDistance = abs(dy)
            case .up:
                guard dy < -0.5, abs(dy) >= abs(dx) else {
                    return nil
                }
                primaryDistance = abs(dy)
                crossDistance = abs(dx)
            case .down:
                guard dy > 0.5, abs(dy) >= abs(dx) else {
                    return nil
                }
                primaryDistance = abs(dy)
                crossDistance = abs(dx)
            }
            return FrameCandidate(
                index: index,
                squaredDistance: dx * dx + dy * dy,
                primaryDistance: primaryDistance,
                crossDistance: crossDistance
            )
        }
        .min { lhs, rhs in
            if abs(lhs.squaredDistance - rhs.squaredDistance) > 0.5 {
                return lhs.squaredDistance < rhs.squaredDistance
            }
            if abs(lhs.primaryDistance - rhs.primaryDistance) > 0.5 {
                return lhs.primaryDistance < rhs.primaryDistance
            }
            if abs(lhs.crossDistance - rhs.crossDistance) > 0.5 {
                return lhs.crossDistance < rhs.crossDistance
            }
            return lhs.index < rhs.index
        }?
        .index
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

private struct Candidate {
    let index: Int
    let squaredDistance: Int
    let primaryDistance: Int
    let crossDistance: Int
}

private struct FrameCandidate {
    let index: Int
    let squaredDistance: CGFloat
    let primaryDistance: CGFloat
    let crossDistance: CGFloat
}
