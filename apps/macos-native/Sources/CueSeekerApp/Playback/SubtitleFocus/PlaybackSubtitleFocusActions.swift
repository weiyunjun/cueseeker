import AppKit
import CueSeekerCore

enum PlaybackSubtitleFocusClipboard {
    private static let markdownLinkEscapedCharacters: Set<Character> = [
        "\\", "[", "]", "<", ">", "*", "_", "`", "~", "&", "|",
    ]

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

    static func markdownLink(cueText: String, cueID: Int64) -> String? {
        guard cueID > 0 else {
            return nil
        }

        let normalizedCueText = cueText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let label = normalizedCueText.isEmpty
            ? "Cue #\(cueID)"
            : normalizedCueText
        var escapedLabel = ""
        escapedLabel.reserveCapacity(label.count)
        for character in label {
            if markdownLinkEscapedCharacters.contains(character) {
                escapedLabel.append("\\")
            }
            escapedLabel.append(character)
        }
        return "[\(escapedLabel)](cueseeker://cue?id=\(cueID))"
    }

    static func copyMarkdownLink(
        cueText: String,
        cueID: Int64,
        to pasteboard: NSPasteboard
    ) -> Bool {
        guard let markdownLink = markdownLink(cueText: cueText, cueID: cueID) else {
            return false
        }
        return copy(markdownLink, to: pasteboard)
    }
}

enum PlaybackSubtitleFocusAction: Equatable, Sendable {
    case shiori
    case copyCueText
    case copyCueMarkdownLink
    case playFromThisCue
}

enum PlaybackSubtitleFocusActionTarget: Equatable, Sendable {
    case current(PlaybackSubtitleFocusActionContext)
    case playlist(PlaybackPlaylistItem)
    case search(PlaybackCueResultItem)
    case shiori(PlaybackCueResultItem)

    var primaryCueText: String {
        switch self {
        case .current(let context):
            context.cue.text
        case .playlist(let item), .search(let item), .shiori(let item):
            item.primaryCueText
        }
    }

    var actionContext: PlaybackSubtitleFocusActionContext? {
        switch self {
        case .current(let context):
            context
        case .playlist(let item), .search(let item), .shiori(let item):
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
        case .search(let searchItem):
            item = searchItem
        case .shiori(let shioriItem):
            item = shioriItem
        }
        switch item.target {
        case .search(let result):
            return result.videoName
        case .shiori(let shiori):
            return shiori.videoName
        }
    }

    var representsSavedShiori: Bool {
        switch self {
        case .current:
            return false
        case .playlist(let item), .search(let item), .shiori(let item):
            if case .shiori = item.target {
                return true
            }
            return false
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

    init(
        searchItem: PlaybackCueResultItem,
        generation: Int
    ) {
        action = .playFromThisCue
        target = .search(searchItem)
        self.generation = generation
    }

    init(
        action: PlaybackSubtitleFocusAction,
        shioriItem: PlaybackCueResultItem,
        generation: Int
    ) {
        self.action = action
        target = .shiori(shioriItem)
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
