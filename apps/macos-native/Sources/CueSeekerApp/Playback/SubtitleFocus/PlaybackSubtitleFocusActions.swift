import AppKit
import CueSeekerCore

enum PlaybackSubtitleFocusClipboard {
    static func copy(
        _ text: String,
        to pasteboard: NSPasteboard
    ) -> Bool {
        guard !text.isEmpty else {
            return false
        }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

enum PlaybackSubtitleFocusAction: Equatable, Sendable {
    case shiori
    case copyCueText
    case playFromThisCue
}

struct PlaybackSubtitleFocusActionContext: Equatable, Sendable {
    let source: SubtitleFocusSourceIdentity
    let cue: SubtitleFocusCue

    var cueTextSelection: SubtitleCueTextSelection {
        SubtitleCueTextSelection(
            cueGroupID: cue.cueGroupID,
            cueLineID: cue.id,
            startMilliseconds: cue.startMilliseconds,
            endMilliseconds: cue.endMilliseconds,
            cueEventIndex: cue.eventIndex,
            cueDisplayOrder: cue.displayOrder,
            content: cue.content
        )
    }
}

struct PlaybackSubtitleFocusActionExecution: Equatable, Sendable {
    let action: PlaybackSubtitleFocusAction
    let context: PlaybackSubtitleFocusActionContext
    let generation: Int
}

enum PlaybackSubtitleFocusKeyboardActionRequestResult: Equatable, Sendable {
    case rejected
    case deferred
    case ready(PlaybackSubtitleFocusActionExecution)
}
