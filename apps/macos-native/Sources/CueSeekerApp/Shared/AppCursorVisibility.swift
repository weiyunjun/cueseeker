import AppKit

/// The App's only owner of system cursor visibility.
///
/// `NSCursor.hide()` and `NSCursor.unhide()` are counted, so two independent
/// hiders can leave the cursor permanently invisible. Every hide therefore goes
/// through this type: it keeps exactly one hide outstanding while any owner asks
/// for it, and releases it once no owner does.
///
/// Debug E2E `inspect` reports `isCursorHidden`, because a capture never
/// contains the cursor and pointer-visibility rules would otherwise have no
/// observable evidence.
@MainActor
enum AppCursorVisibility {
    enum Owner: Hashable {
        /// The playback page, which hides the cursor on keyboard input and
        /// while the player is idle.
        case player
        /// One open menu surface, identified by its highlight model, which
        /// hides the cursor while its highlight is being moved by the keyboard.
        /// A parent menu and its submenu are separate owners, so closing the
        /// submenu must not reveal the cursor the parent still hides.
        case menu(ObjectIdentifier)
    }

    private(set) static var isCursorHidden = false
    private static var hidingOwners: Set<Owner> = []

    static func setHidden(_ shouldHide: Bool, owner: Owner) {
        if shouldHide {
            hidingOwners.insert(owner)
        } else {
            hidingOwners.remove(owner)
        }
        apply()
    }

    private static func apply() {
        let shouldHide = !hidingOwners.isEmpty
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
        hidingOwners.removeAll()
        if isCursorHidden {
            isCursorHidden = false
            NSCursor.unhide()
        }
    }
}
