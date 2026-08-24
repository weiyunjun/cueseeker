import CoreGraphics
import SwiftUI

/// The measurements every menu shares.
enum MenuMetrics {
    /// The ring of space between a menu's edge and its items.
    ///
    /// It is exactly what a scrollbar occupies — the thumb's own width plus the
    /// gap it keeps from the edge — so a menu that scrolls draws its scrollbar
    /// inside this ring instead of over the items, the highlight or the
    /// dividers. Nothing has to move when a scrollbar appears, and nothing has
    /// to be measured to decide whether it will.
    static let padding: CGFloat = TableScrollbarPrimitiveMetrics.size
        + TableScrollbarPrimitiveMetrics.inset

    /// How tall a menu may grow before its content starts scrolling instead.
    static let maximumHeight: CGFloat = 480
}

/// Makes a menu as tall as its content, and no taller than the cap.
///
/// A `maxHeight` frame cannot do this. `maxHeight` means "you may grow this
/// large", so a menu sitting in a full-page overlay — every card's right-click
/// menu — grew straight to the cap no matter how few items it had. The menus
/// hung off an AppKit host escaped it only because nothing offers them a height
/// to grow into.
///
/// So the content is asked how tall it wants to be, and is then given that,
/// or the cap, whichever is smaller. The scroll view inside is handed a
/// definite height either way: its own content's height, in which case there is
/// nothing to scroll, or the cap, in which case it scrolls.
struct MenuHeightCap: Layout {
    let height: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }
        let wanted = subview.sizeThatFits(.unspecified)
        return CGSize(width: wanted.width, height: min(wanted.height, height))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else {
            return
        }
        subview.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(bounds.size)
        )
    }
}
