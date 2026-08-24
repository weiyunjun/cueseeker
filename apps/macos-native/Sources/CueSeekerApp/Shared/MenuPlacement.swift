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
    /// Below the anchor first, above it when the menu would not fit below, and
    /// slid along the edge when neither side fits.
    static func openingFrame(
        anchor: CGRect,
        menuSize: CGSize,
        in container: CGRect,
        gap: CGFloat,
        edgeInset: CGFloat = 0
    ) -> CGRect {
        let minX = container.minX + edgeInset
        let maxX = container.maxX - edgeInset
        let minY = container.minY + edgeInset
        let maxY = container.maxY - edgeInset

        var y = anchor.maxY + gap
        if y + menuSize.height > maxY {
            let above = anchor.minY - gap - menuSize.height
            if above >= minY {
                y = above
            }
        }
        y = clamp(y, min: minY, max: maxY - menuSize.height)

        var x = anchor.minX
        if x + menuSize.width > maxX {
            x = maxX - menuSize.width
        }
        x = clamp(x, min: minX, max: maxX - menuSize.width)

        return CGRect(origin: CGPoint(x: x, y: y), size: menuSize)
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
