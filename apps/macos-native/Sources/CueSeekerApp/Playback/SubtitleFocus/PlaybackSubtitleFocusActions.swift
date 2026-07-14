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

enum PlaybackSubtitleFocusActionTarget: Equatable, Sendable {
    case current(PlaybackSubtitleFocusActionContext)
    case playlist(PlaybackPlaylistItem)

    var primaryCueText: String {
        switch self {
        case .current(let context):
            context.cue.text
        case .playlist(let item):
            item.primaryCueText
        }
    }

    var actionContext: PlaybackSubtitleFocusActionContext? {
        switch self {
        case .current(let context):
            context
        case .playlist(let item):
            item.actionContext
        }
    }

    var sourceVideoName: String? {
        guard case .playlist(let item) = self else {
            return nil
        }
        switch item.target {
        case .search(let result):
            return result.videoName
        case .shiori(let shiori):
            return shiori.videoName
        }
    }
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
    let target: PlaybackSubtitleFocusActionTarget
    let generation: Int

    init(
        action: PlaybackSubtitleFocusAction,
        context: PlaybackSubtitleFocusActionContext,
        generation: Int
    ) {
        self.action = action
        target = .current(context)
        self.generation = generation
    }

    init(
        action: PlaybackSubtitleFocusAction,
        playlistItem: PlaybackPlaylistItem,
        generation: Int
    ) {
        self.action = action
        target = .playlist(playlistItem)
        self.generation = generation
    }

    /// Compatibility accessor for Current-only callers and tests.
    var context: PlaybackSubtitleFocusActionContext {
        guard case .current(let context) = target else {
            preconditionFailure("Playlist action execution has no required Current context")
        }
        return context
    }
}

enum PlaybackSubtitleFocusKeyboardActionRequestResult: Equatable, Sendable {
    case rejected
    case deferred
    case ready(PlaybackSubtitleFocusActionExecution)
}
