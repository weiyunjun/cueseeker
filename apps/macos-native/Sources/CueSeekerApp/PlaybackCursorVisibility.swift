import AppKit

@MainActor
enum PlaybackCursorVisibility {
    enum Reason: Hashable {
        case expandedPlayback
        case playbackFullscreen
    }

    private static var hiddenReasons: Set<Reason> = []

    static func hide(for reason: Reason) {
        let inserted = hiddenReasons.insert(reason).inserted
        if inserted {
            NSCursor.hide()
        }
    }

    static func show(for reason: Reason) {
        guard hiddenReasons.remove(reason) != nil else {
            return
        }
        NSCursor.unhide()
    }
}
