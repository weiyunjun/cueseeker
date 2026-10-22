import CueSeekerCore

enum PlaybackSubtitleFocusAction: Equatable, Sendable {
    case excerpt
    case copyCueText
    case copyCueMarkdownLink
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

    var cueID: Int64? {
        actionContext?.cue.id
    }

    var sourceVideoName: String? {
        let item: PlaybackCueResultItem
        switch self {
        case .current:
            return nil
        case .playlist(let playlistItem):
            item = playlistItem
        }
        switch item.target {
        case .search(let result):
            return result.videoName
        case .excerpt(let excerpt):
            return excerpt.videoName
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
            preconditionFailure(
                "Cue Result action execution has no required Current context"
            )
        }
        return context
    }
}

enum PlaybackSubtitleFocusKeyboardActionRequestResult: Equatable, Sendable {
    case rejected
    case deferred
    case ready(PlaybackSubtitleFocusActionExecution)
}
