import SwiftUI

/// The hand pointer for SwiftUI surfaces.
///
/// SwiftUI decides the pointer for everything it draws: its hosting view keeps
/// a cursor-update tracking area and states the shape again on every move. A
/// shape pushed or set from outside that — from a hover handler, or from a
/// cursor rect on a view of our own, which SwiftUI keeps out of hit testing
/// anyway — is overwritten by the next move, which is why the hand used to
/// flicker or never appear at all. So the shape is asked of SwiftUI itself.
///
/// SwiftUI gained that ability in macOS 15. Below it a card keeps the plain
/// arrow: there is no way to hold a hand there that does not flicker, and a
/// flicker is worse than the arrow. The subtitle table is unaffected either
/// way — it is AppKit, takes hits, and answers the pointer question itself.
///
/// See `docs/human/requirements/20260826-UI-Pointer Cursor Single Authority.md`.
extension View {
    /// Shows the hand over this view while `isEnabled`, on macOS 15 and newer.
    @ViewBuilder
    func handPointer(isEnabled: Bool) -> some View {
        if #available(macOS 15.0, *) {
            pointerStyle(isEnabled ? .link : nil)
        } else {
            self
        }
    }
}
