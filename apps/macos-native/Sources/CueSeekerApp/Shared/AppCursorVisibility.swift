import AppKit

/// The App's only owner of system cursor visibility.
///
/// `NSCursor.hide()` and `NSCursor.unhide()` are counted, so an unbalanced pair
/// can leave the cursor permanently invisible. Every hide therefore goes through
/// this type, which keeps at most one hide outstanding.
///
/// The idle player is the only thing that hides the cursor. The keyboard does
/// not: see
/// `docs/human/requirements/20260826-UI-Card Highlight Single Authority And
/// Menu Input Rules.md` §7.
///
/// Debug E2E `inspect` reports `isCursorHidden`, because a capture never
/// contains the cursor and pointer-visibility rules would otherwise have no
/// observable evidence.
@MainActor
enum AppCursorVisibility {
    private(set) static var isCursorHidden = false

    static func setHidden(_ shouldHide: Bool) {
        guard shouldHide != isCursorHidden else {
            return
        }
        isCursorHidden = shouldHide
        if shouldHide {
            NSCursor.hide()
        } else {
            NSCursor.unhide()
        }
    }

    static func resetForTesting() {
        setHidden(false)
    }
}
