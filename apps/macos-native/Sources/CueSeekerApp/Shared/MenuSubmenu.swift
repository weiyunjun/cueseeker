import CoreGraphics
import SwiftUI

/// Which trigger's submenu is open and how the pointer may cross to it, for
/// any menu whose items open submenus. `Parent` names the triggers.
@MainActor
final class MenuSubmenuState<Parent: Hashable>: ObservableObject {
    @Published private(set) var highlightedParent: Parent?
    @Published private(set) var openParent: Parent?
    var onOpenParentChange: ((Parent?) -> Void)?
    weak var parentHighlight: MenuHighlightModel?
    /// Set while the pointer is crossing to the open submenu. The items it
    /// merely passes over on the way do not take the highlight or close
    /// anything until the crossing ends.
    private(set) var isPointerInSafeArea = false
    private var parentItemFrames: [Parent: CGRect] = [:]
    private var safeAreaAnchor: CGPoint?
    /// Whether the pointer's last sideways step went toward the submenu. A
    /// step straight up or down keeps what the one before it said.
    private var isMovingTowardSubmenu = true
    private var lastPointerX: CGFloat?
    private var safeAreaTimeout: Task<Void, Never>?
    /// Set when a click or a key opens the submenu. Until the pointer really
    /// moves, what the items report is the submenu appearing under a pointer
    /// that stands still, not the pointer going anywhere.
    private var waitsForPointerMove = false
    /// The item under the pointer as the items last reported it, whether or
    /// not that report has taken effect yet.
    private var hoveredItem: HoveredItem?

    private struct HoveredItem {
        let position: Int
        let trigger: Parent?
        let highlight: MenuHighlightModel?
    }

    /// Every item of the menu reports its hover here. `trigger` is the submenu
    /// an enabled trigger opens and nil for every other item; `highlight` is
    /// the menu's highlight, nil for items that never take it.
    ///
    /// While the pointer is crossing to the submenu, or has not moved since a
    /// click or a key opened it, the report is only remembered. It takes
    /// effect once the pointer's own rules apply again.
    func noteItemHover(
        _ isHovered: Bool,
        at position: Int,
        trigger: Parent?,
        highlight: MenuHighlightModel?
    ) {
        if let highlight {
            parentHighlight = highlight
        }
        let item = HoveredItem(
            position: position,
            trigger: trigger,
            highlight: highlight
        )
        if isHovered {
            hoveredItem = item
        } else if hoveredItem?.position == position {
            hoveredItem = nil
        }
        if highlight?.isSuppressedByKeyboard == true {
            highlight?.noteHover(isHovered, at: position)
            return
        }
        guard !isPointerInSafeArea, !waitsForPointerMove else {
            if waitsForPointerMove {
                highlight?.noteHover(isHovered, at: position)
            }
            return
        }
        apply(item, isHovered: isHovered)
    }

    func open(_ action: Parent) {
        if openParent != nil, openParent != action {
            parentHighlight?.setPinnedPosition(nil)
            updateOpenParent(nil)
        }
        highlightedParent = action
        if let parentHighlight, let position = parentHighlight.highlightedPosition {
            parentHighlight.setPinnedPosition(position)
        }
        updateOpenParent(action)
        waitsForPointerMove = true
        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
    }

    @discardableResult
    func closeSubmenu() -> Bool {
        guard openParent != nil else {
            return false
        }
        parentHighlight?.unpinKeepingHighlight()
        updateOpenParent(nil)
        waitsForPointerMove = true
        PointerHoverScrollState.shared.noteSelectionMovedByKeyboardOrController()
        return true
    }

    @discardableResult
    private func closeSubmenuForPointerExit() -> Bool {
        guard openParent != nil else {
            return false
        }
        parentHighlight?.setPinnedPosition(nil)
        updateOpenParent(nil)
        return true
    }

    func updateParentItemFrames(
        _ frames: [Parent: CGRect]
    ) {
        guard parentItemFrames != frames else {
            return
        }
        parentItemFrames = frames
        if let openParent {
            onOpenParentChange?(openParent)
        }
    }

    func parentItemFrame(
        for action: Parent
    ) -> CGRect? {
        parentItemFrames[action]
    }

    /// Where the pointer moved to, told by the menu gate rather than waited
    /// for from the menu's own views: an open menu's barrier spends the moves
    /// that land outside it, and those moves are what AppKit needs to notice a
    /// pointer leaving. Only real moves are told. Every frame is in the
    /// container's space.
    func notePointer(
        _ point: CGPoint,
        parentMenuFrame: CGRect,
        triggerFrame: CGRect,
        submenuFrame: CGRect
    ) {
        PointerHoverScrollState.shared.notePointerMoved()
        guard let parent = openParent else {
            clearSafeArea()
            return
        }
        if let lastPointerX, point.x != lastPointerX {
            isMovingTowardSubmenu = (submenuFrame.midX >= parentMenuFrame.midX)
                == (point.x > lastPointerX)
        }
        lastPointerX = point.x
        if waitsForPointerMove {
            // The first real move since a click or a key opened the submenu:
            // whatever the pointer rests on takes effect now.
            waitsForPointerMove = false
            if let hoveredItem, parentMenuFrame.contains(point) {
                apply(hoveredItem, isHovered: true)
            }
            guard openParent == parent else {
                // The frames describe the submenu that just closed.
                return
            }
        }
        if triggerFrame.contains(point) {
            // The crossing starts wherever the pointer last stood on the
            // trigger, so the safe area follows it along that item.
            clearSafeArea()
            safeAreaAnchor = point
            return
        }
        if submenuFrame.contains(point) {
            // Arrived: there is nothing left to cross.
            clearSafeArea()
            return
        }
        let wasInSafeArea = isPointerInSafeArea
        if isMovingTowardSubmenu,
           MenuSubmenuSafeArea.contains(
               point,
               anchor: safeAreaAnchor,
               parentMenuFrame: parentMenuFrame,
               submenuFrame: submenuFrame
           ) {
            isPointerInSafeArea = true
            restartSafeAreaTimeout()
            return
        }
        // Out of the area or turned away: the crossing is over until the
        // pointer comes back to the trigger.
        clearSafeArea()
        if !parentMenuFrame.contains(point) {
            closeSubmenuForPointerExit()
        } else if wasInSafeArea {
            settleCrossing()
        }
    }

    func reset() {
        hoveredItem = nil
        highlightedParent = nil
        parentHighlight?.setPinnedPosition(nil)
        updateOpenParent(nil)
        clearSafeArea()
    }

    /// The pointer reaching a trigger opens its submenu there and then. Moving
    /// between the two triggers closes the one it left before opening the one
    /// it reached, so the destination highlight starts with no item selected.
    /// Any other item closes the submenu.
    private func apply(_ item: HoveredItem, isHovered: Bool) {
        item.highlight?.noteHover(isHovered, at: item.position)
        guard let trigger = item.trigger else {
            if isHovered {
                highlightedParent = nil
                parentHighlight?.setPinnedPosition(nil)
                updateOpenParent(nil)
            }
            return
        }
        guard isHovered else {
            if openParent != trigger, highlightedParent == trigger {
                highlightedParent = nil
            }
            return
        }
        highlightedParent = trigger
        if openParent != trigger {
            parentHighlight?.setPinnedPosition(nil)
            updateOpenParent(nil)
        }
        item.highlight?.setPinnedPosition(item.position)
        updateOpenParent(trigger)
    }

    /// The crossing ended over the menu: the item the pointer rests on takes
    /// effect as if the pointer had just reached it, and resting on no item
    /// closes the submenu.
    private func settleCrossing() {
        if let hoveredItem {
            apply(hoveredItem, isHovered: true)
        } else {
            closeSubmenuForPointerExit()
        }
    }

    private func restartSafeAreaTimeout() {
        safeAreaTimeout?.cancel()
        safeAreaTimeout = Task { [weak self] in
            try? await Task.sleep(
                nanoseconds: MenuSubmenuSafeArea.pointerRestLimitNanoseconds
            )
            guard !Task.isCancelled, let self, self.isPointerInSafeArea else {
                return
            }
            // The pointer stopped inside the area instead of crossing it.
            self.clearSafeArea()
            self.settleCrossing()
        }
    }

    private func clearSafeArea() {
        safeAreaAnchor = nil
        isPointerInSafeArea = false
        safeAreaTimeout?.cancel()
        safeAreaTimeout = nil
    }

    private func updateOpenParent(_ action: Parent?) {
        guard openParent != action else {
            return
        }
        openParent = action
        if action == nil {
            waitsForPointerMove = false
            clearSafeArea()
        } else {
            lastPointerX = nil
            isMovingTowardSubmenu = true
        }
        onOpenParentChange?(action)
    }
}

/// The area the pointer may cross without the open submenu closing: the
/// triangle from where it left the trigger to the submenu's near edge, plus
/// whatever gap separates the two menus. Inside it, moving toward the submenu,
/// the pointer is on its way there, so the rows it passes over are not what it
/// means.
enum MenuSubmenuSafeArea {
    /// How long the pointer may stand still inside the area before it counts
    /// as having stopped there rather than crossing it.
    static let pointerRestLimitNanoseconds: UInt64 = 300_000_000

    static func contains(
        _ point: CGPoint,
        anchor: CGPoint?,
        parentMenuFrame: CGRect,
        submenuFrame: CGRect
    ) -> Bool {
        guard let anchor,
              submenuFrame.width > 0,
              submenuFrame.height > 0
        else {
            return false
        }
        if let gap = gapRect(
            parentMenuFrame: parentMenuFrame,
            submenuFrame: submenuFrame
        ), gap.contains(point) {
            return true
        }
        let edgeX = submenuFrame.midX >= parentMenuFrame.midX
            ? submenuFrame.minX
            : submenuFrame.maxX
        return triangleContains(
            point,
            anchor,
            CGPoint(x: edgeX, y: submenuFrame.minY),
            CGPoint(x: edgeX, y: submenuFrame.maxY)
        )
    }

    /// The strip between the two menus, as wide as they are apart and as tall
    /// as the submenu. Nil when they touch, which is how this table places
    /// them.
    private static func gapRect(
        parentMenuFrame: CGRect,
        submenuFrame: CGRect
    ) -> CGRect? {
        let leading = submenuFrame.midX >= parentMenuFrame.midX
            ? parentMenuFrame.maxX
            : submenuFrame.maxX
        let trailing = submenuFrame.midX >= parentMenuFrame.midX
            ? submenuFrame.minX
            : parentMenuFrame.minX
        guard trailing > leading else {
            return nil
        }
        return CGRect(
            x: leading,
            y: submenuFrame.minY,
            width: trailing - leading,
            height: submenuFrame.height
        )
    }

    private static func triangleContains(
        _ point: CGPoint,
        _ a: CGPoint,
        _ b: CGPoint,
        _ c: CGPoint
    ) -> Bool {
        let d1 = cross(point, a, b)
        let d2 = cross(point, b, c)
        let d3 = cross(point, c, a)
        let hasNegative = d1 < 0 || d2 < 0 || d3 < 0
        let hasPositive = d1 > 0 || d2 > 0 || d3 > 0
        return !(hasNegative && hasPositive)
    }

    private static func cross(
        _ point: CGPoint,
        _ a: CGPoint,
        _ b: CGPoint
    ) -> CGFloat {
        (point.x - b.x) * (a.y - b.y) - (a.x - b.x) * (point.y - b.y)
    }
}

enum MenuSubmenuGeometry {
    static let horizontalGap: CGFloat = 0

    static func frame(
        parentMenuFrame: CGRect,
        parentItemFrame: CGRect,
        submenuSize: CGSize,
        visibleRect: CGRect
    ) -> CGRect {
        let width = max(0, submenuSize.width)
        // A submenu never flips to the other side of its parent. When the
        // boundary cannot hold it, it gives up height and scrolls the rest.
        let height = max(0, min(submenuSize.height, visibleRect.height))

        var x = parentMenuFrame.maxX + horizontalGap
        if x + width > visibleRect.maxX {
            x = parentMenuFrame.minX - horizontalGap - width
        }
        x = max(
            visibleRect.minX,
            min(x, visibleRect.maxX - width)
        )

        var y = parentMenuFrame.minY + parentItemFrame.minY
        if y < visibleRect.minY {
            y = visibleRect.minY
        }
        if y + height > visibleRect.maxY {
            y = max(visibleRect.minY, visibleRect.maxY - height)
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
