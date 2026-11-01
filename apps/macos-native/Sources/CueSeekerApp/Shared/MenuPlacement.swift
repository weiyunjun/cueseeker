import CoreGraphics

/// Where a menu sits relative to the thing it hangs off.
///
/// The direction is decided once, when the menu opens, and is never revisited.
/// A caller keeps the offset this returns and travels with its anchor, so a list
/// scrolling under an open menu carries the menu along instead of flipping it to
/// the other side halfway through the scroll.
///
/// Every menu surface in the App lays out top-left down, so one convention is
/// enough. Gaps and edge insets stay with the caller: each menu keeps the
/// spacing it already had.
enum MenuPlacement {
    /// The menu's frame when it opens. `anchor` is the button's rectangle, or a
    /// zero-size rectangle at the pointer for a menu opened by right-click.
    ///
    /// Below the anchor first, above it when the menu would not fit below.
    ///
    /// When neither single side can hold the menu whole, the menu keeps its full
    /// height whenever the container's total vertical room can hold it and slides
    /// along the container edge (so the pointer or trigger sits beside the middle
    /// of the menu instead of forcing a premature scrollbar). Only when the
    /// container's total vertical room is shorter than the menu does a scrolling
    /// menu (`shrinksToFit: true`) cut its height down to the container's room.
    static func openingFrame(
        anchor: CGRect,
        menuSize: CGSize,
        in container: CGRect,
        gap: CGFloat,
        edgeInset: CGFloat = 0,
        shrinksToFit: Bool = false
    ) -> CGRect {
        let minX = container.minX + edgeInset
        let maxX = container.maxX - edgeInset
        let minY = container.minY + edgeInset
        let maxY = container.maxY - edgeInset

        let availableHeight = max(0, maxY - minY)
        let roomBelow = maxY - (anchor.maxY + gap)
        let roomAbove = (anchor.minY - gap) - minY

        let height = shrinksToFit
            ? min(menuSize.height, availableHeight)
            : menuSize.height
        var y: CGFloat
        if height <= roomBelow {
            y = anchor.maxY + gap
        } else if height <= roomAbove {
            y = anchor.minY - gap - height
        } else {
            y = anchor.maxY + gap
        }
        y = clamp(y, min: minY, max: maxY - height)

        var x = anchor.minX
        if x + menuSize.width > maxX {
            if anchor.width == 0, anchor.minX - menuSize.width >= minX {
                x = anchor.minX - menuSize.width
            } else if anchor.width > 0,
                      anchor.width < menuSize.width,
                      y < anchor.maxY,
                      y + height > anchor.minY,
                      anchor.minX - gap - menuSize.width >= minX
            {
                x = anchor.minX - gap - menuSize.width
            } else {
                x = maxX - menuSize.width
            }
        }
        x = clamp(x, min: minX, max: maxX - menuSize.width)

        return CGRect(
            origin: CGPoint(x: x, y: y),
            size: CGSize(width: menuSize.width, height: height)
        )
    }

    /// The offset to carry: add it to the anchor's origin to keep the menu in
    /// the place `openingFrame` chose, whatever the anchor does afterwards.
    static func offset(from anchor: CGRect, to menuFrame: CGRect) -> CGSize {
        CGSize(
            width: menuFrame.minX - anchor.minX,
            height: menuFrame.minY - anchor.minY
        )
    }

    /// The menu's frame after its anchor moved. Pure translation: the side the
    /// menu opened on and its distance from the anchor both stay put.
    static func followingFrame(
        anchor: CGRect,
        offset: CGSize,
        menuSize: CGSize
    ) -> CGRect {
        CGRect(
            origin: CGPoint(
                x: anchor.minX + offset.width,
                y: anchor.minY + offset.height
            ),
            size: menuSize
        )
    }

    private static func clamp(
        _ value: CGFloat,
        min lower: CGFloat,
        max upper: CGFloat
    ) -> CGFloat {
        guard upper > lower else {
            return lower
        }
        return Swift.min(Swift.max(lower, value), upper)
    }
}
