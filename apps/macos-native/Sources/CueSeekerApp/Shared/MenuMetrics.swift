import CoreGraphics
import SwiftUI

/// The measurements every menu shares.
enum MenuMetrics {
    /// The ring of space between a menu's edge and its items.
    ///
    /// It no longer stands in for the scrollbar's width. A menu that scrolls
    /// widens by `scrollbarStrip` instead, so this is the gap the items keep
    /// from the menu's edge when nothing scrolls and the gap they keep from the
    /// scrollbar when something does — the same distance either way.
    static let padding: CGFloat = 6

    /// What a menu's scrollbar keeps clear of the menu's own edge, on every
    /// side of its track.
    static let scrollbarOuterGap: CGFloat = 6

    /// How much wider a menu gets while its scrollbar is up: the scrollbar and
    /// the gap outside it. The items keep the width they had.
    static let scrollbarStrip: CGFloat = TableScrollbarPrimitiveMetrics.size
        + scrollbarOuterGap

    /// How tall a menu may grow before its content starts scrolling instead.
    static let maximumHeight: CGFloat = 480
}

/// Lays a menu's items inside the menu's padding, and reserves the strip its
/// scrollbar needs when — and only when — the items outgrow the cap.
///
/// The reservation belongs here rather than around the scroll view. The
/// scrollbar is drawn against the scroll view's own trailing edge, so the room
/// it needs has to come out of the item stack; taking it off the menu's width
/// afterwards would leave the scrollbar sitting over the items. An item's
/// height does not depend on the room reserved beside it, so measuring once is
/// enough and nothing oscillates.
struct MenuItemStack: Layout {
    let padding: CGFloat
    let strip: CGFloat
    let cap: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }
        let wanted = subview.sizeThatFits(.unspecified)
        return CGSize(
            width: wanted.width + 2 * padding + reserve(forContentHeight: wanted.height),
            height: wanted.height + 2 * padding
        )
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
        let wanted = subview.sizeThatFits(.unspecified)
        let reserved = reserve(forContentHeight: wanted.height)
        subview.place(
            at: CGPoint(x: bounds.minX + padding, y: bounds.minY + padding),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: max(0, bounds.width - 2 * padding - reserved),
                height: wanted.height
            )
        )
    }

    private func reserve(forContentHeight height: CGFloat) -> CGFloat {
        height + 2 * padding > cap ? strip : 0
    }
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
