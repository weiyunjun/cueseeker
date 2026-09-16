import CoreGraphics
import SwiftUI

/// Which trigger's submenu is open and how the pointer may cross to it, for
/// any menu whose items open submenus. `Parent` names the triggers; callers
/// only hand it the items that do open a submenu.
@MainActor
final class MenuSubmenuState<Parent: Hashable>: ObservableObject {
    @Published private(set) var highlightedParent: Parent?
    @Published private(set) var openParent: Parent?
    var onOpenParentChange: ((Parent?) -> Void)?
    /// Set while the pointer is crossing to the open submenu. The menu's own
    /// rows ask before reacting, so a row the pointer merely passes over on
    /// the way does not take the highlight or close anything.
    private(set) var isPointerInSafeArea = false
    private var parentItemFrames: [Parent: CGRect] = [:]
    private var safeAreaAnchor: CGPoint?

    /// The pointer reaching a trigger opens its submenu there and then. Moving
    /// between the two triggers closes the one it left before opening the one
    /// it reached, so the destination highlight starts at the first item again.
    func setParentHovered(_ action: Parent, isHovered: Bool) {
        guard !isPointerInSafeArea else {
            return
        }
        guard isHovered else {
            if openParent != action, highlightedParent == action {
                highlightedParent = nil
            }
            return
        }
        highlightedParent = action
        if openParent != action {
            updateOpenParent(nil)
        }
        updateOpenParent(action)
    }

    func setOtherItemHovered(_ isHovered: Bool) {
        guard isHovered, !isPointerInSafeArea else {
            return
        }
        highlightedParent = nil
        updateOpenParent(nil)
    }

    func open(_ action: Parent) {
        highlightedParent = action
        updateOpenParent(action)
    }

    @discardableResult
    func closeSubmenu() -> Bool {
        guard openParent != nil else {
            return false
        }
        clearSafeArea()
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

    /// Where the pointer is, told by the menu gate rather than waited for from
    /// the menu's own views: an open menu's barrier spends the moves that land
    /// outside it, and those moves are what AppKit needs to notice a pointer
    /// leaving. Every frame is in the container's space.
    func notePointer(
        _ point: CGPoint,
        parentMenuFrame: CGRect,
        triggerFrame: CGRect,
        submenuFrame: CGRect
    ) {
        guard openParent != nil else {
            clearSafeArea()
            return
        }
        if triggerFrame.contains(point) {
            // The crossing starts wherever the pointer last stood on the
            // trigger, so the safe area follows it along that item.
            safeAreaAnchor = point
            isPointerInSafeArea = false
            return
        }
        if submenuFrame.contains(point) {
            // Arrived: there is nothing left to cross.
            clearSafeArea()
            return
        }
        isPointerInSafeArea = MenuSubmenuSafeArea.contains(
            point,
            anchor: safeAreaAnchor,
            parentMenuFrame: parentMenuFrame,
            submenuFrame: submenuFrame
        )
        if !isPointerInSafeArea, !parentMenuFrame.contains(point) {
            closeSubmenu()
        }
    }

    func reset() {
        clearSafeArea()
        highlightedParent = nil
        updateOpenParent(nil)
    }

    private func clearSafeArea() {
        safeAreaAnchor = nil
        isPointerInSafeArea = false
    }

    private func updateOpenParent(_ action: Parent?) {
        guard openParent != action else {
            return
        }
        openParent = action
        onOpenParentChange?(action)
    }
}

/// The area the pointer may cross without the open submenu closing: the
/// triangle from where it left the trigger to the submenu's near edge, plus
/// whatever gap separates the two menus. Inside it the pointer is on its way
/// to the submenu, so the rows it passes over are not what it means.
enum MenuSubmenuSafeArea {
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
