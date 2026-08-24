import CoreGraphics

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
