import Foundation
import CueSeekerCore

enum SubtitleTableCueState: Equatable {
    case normal
    case contentChanged(previous: String, current: String)
    case unavailable(ExcerptUnavailableReason)

    var isUnavailable: Bool {
        if case .unavailable = self {
            return true
        }
        return false
    }

    var icon: AppIcon? {
        switch self {
        case .normal:
            nil
        case .contentChanged:
            .clockCounterClockwise
        case .unavailable:
            .questionMark
        }
    }

    var subtitleFileIsAvailable: Bool {
        switch self {
        case .normal, .contentChanged, .unavailable(.videoMissing), .unavailable(.cueMissing):
            true
        case .unavailable:
            false
        }
    }

    var unavailableMessage: String? {
        guard case .unavailable(let reason) = self else {
            return nil
        }
        switch reason {
        case .libraryUnavailable:
            return L("table.state.library_unavailable")
        case .videoMissing:
            return L("table.state.video_missing")
        case .subtitleMissing:
            return L("table.state.subtitle_missing")
        case .cueMissing:
            return L("table.state.cue_missing")
        }
    }

    var tooltipMessage: String? {
        switch self {
        case .normal:
            nil
        case .contentChanged:
            L("table.state.changed_after_reindex")
        case .unavailable:
            unavailableMessage
        }
    }

    var disabledRowActions: Set<SubtitleTableRowAction> {
        guard isUnavailable else {
            return []
        }
        var actions: Set<SubtitleTableRowAction> = [
            .play,
            .saveToExcerpt,
            .moveToList,
            .duplicateToList,
        ]
        if !subtitleFileIsAvailable {
            actions.insert(.openSubtitleFolder)
        }
        return actions
    }
}

/// Row view-model shared by the Search and Excerpt table surfaces.
struct SubtitleTableRow: Identifiable, Equatable {
    let id: Int
    /// Stable identity of the primary Cue. Excerpt row identity remains the
    /// Excerpt ID, so scroll anchoring cannot safely substitute `id` here.
    let primaryCueID: Int64?
    let subtitlePath: String
    let dateAdded: String
    let displayTitle: String
    let startTime: String
    let endTime: String
    let timeRange: String
    /// Exact source text for the Cue that owns the row and all default actions.
    let primaryCueText: String
    /// Exact Cue texts in stable source display order for the owning Cue Group.
    let cueGroupTexts: [String]
    /// Position of the primary Cue in `cueGroupTexts`, or `nil` for unresolved
    /// legacy Excerpt snapshots that have no durable Cue identity.
    let primaryGroupIndex: Int?
    let tags: [WorkbenchTag]
    let cueState: SubtitleTableCueState
    /// 1-based `#` column sequence number for available rows, or `nil` for
    /// unavailable rows (or when falls back to `rowIndex + 1`).
    var displayIndex: Int?

    /// Compatibility alias used by existing table drawing and clipboard paths.
    /// It intentionally never expands when Show Cue Group is enabled.
    var cues: String {
        primaryCueText
    }

    var primaryCueIdentity: SubtitleTablePrimaryCueIdentity {
        primaryCueID.map(SubtitleTablePrimaryCueIdentity.cue) ?? .rowFallback(id)
    }

    /// Additional Cue texts keep their stable source order. Index-based removal
    /// is required because two sibling Cues may contain identical text.
    var additionalCueTexts: [String] {
        guard let primaryGroupIndex,
              cueGroupTexts.indices.contains(primaryGroupIndex)
        else {
            return []
        }

        return cueGroupTexts.enumerated().compactMap { index, text in
            index == primaryGroupIndex ? nil : text
        }
    }

    /// Clipboard payload for the complete Cue Group in stable source order.
    var cueGroupCopyText: String {
        cueGroupTexts.joined(separator: "\n")
    }

    init(
        id: Int,
        primaryCueID: Int64? = nil,
        subtitlePath: String = "",
        dateAdded: String = "",
        displayTitle: String,
        startTime: String = "",
        endTime: String = "",
        timeRange: String? = nil,
        primaryCueText: String,
        cueGroupTexts: [String],
        primaryGroupIndex: Int?,
        tags: [WorkbenchTag] = [],
        cueState: SubtitleTableCueState = .normal,
        displayIndex: Int? = nil
    ) {
        self.id = id
        self.primaryCueID = primaryCueID
        self.subtitlePath = subtitlePath
        self.dateAdded = dateAdded
        self.displayTitle = displayTitle
        self.startTime = startTime
        self.endTime = endTime
        self.timeRange = timeRange ?? SubtitleTableTimeRange.text(
            startTime: startTime,
            endTime: endTime
        )
        let candidateCueGroupTexts = cueGroupTexts.isEmpty ? [primaryCueText] : cueGroupTexts
        let resolvedPrimaryGroupIndex = primaryGroupIndex.flatMap { index in
            candidateCueGroupTexts.indices.contains(index) ? index : nil
        }
        let resolvedCueGroupTexts = primaryGroupIndex != nil && resolvedPrimaryGroupIndex == nil
            ? [primaryCueText]
            : candidateCueGroupTexts
        self.primaryCueText = primaryCueText
        self.cueGroupTexts = resolvedCueGroupTexts
        self.primaryGroupIndex = resolvedPrimaryGroupIndex
        self.tags = tags
        self.cueState = cueState
        self.displayIndex = displayIndex
    }

    /// Compatibility initializer for fixtures and call sites that model only a
    /// single Cue. Production Search/Excerpt mappings use the explicit group form.
    init(
        id: Int,
        subtitlePath: String = "",
        dateAdded: String = "",
        displayTitle: String,
        startTime: String = "",
        endTime: String = "",
        timeRange: String? = nil,
        cues: String,
        tags: [WorkbenchTag] = []
    ) {
        self.init(
            id: id,
            primaryCueID: Int64(id),
            subtitlePath: subtitlePath,
            dateAdded: dateAdded,
            displayTitle: displayTitle,
            startTime: startTime,
            endTime: endTime,
            timeRange: timeRange,
            primaryCueText: cues,
            cueGroupTexts: [cues],
            primaryGroupIndex: 0,
            tags: tags
        )
    }
}

enum SubtitleTablePrimaryCueIdentity: Hashable {
    case cue(Int64)
    case rowFallback(Int)
}

enum SubtitleTableTimeRange {
    static func text(startTime: String, endTime: String) -> String {
        let trimmedStart = startTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEnd = endTime.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedStart.isEmpty else {
            return trimmedEnd
        }
        guard !trimmedEnd.isEmpty else {
            return trimmedStart
        }

        guard let start = TimeParts(trimmedStart),
              let end = TimeParts(trimmedEnd)
        else {
            return "\(trimmedStart) - \(trimmedEnd)"
        }

        if start.hours == 0, end.hours == 0 {
            return "\(start.shortText) - \(end.shortText)"
        }
        return "\(start.fullText) - \(end.fullText)"
    }

    private struct TimeParts {
        let hours: Int
        let minutes: Int
        let seconds: Int

        init?(_ value: String) {
            let parts = value.split(separator: ":").map(String.init)
            guard parts.count == 2 || parts.count == 3,
                  let last = parts.last,
                  let seconds = Int(last),
                  let minutes = Int(parts[parts.count - 2])
            else {
                return nil
            }

            let hours: Int
            if parts.count == 3 {
                guard let parsedHours = Int(parts[0]) else { return nil }
                hours = parsedHours
            } else {
                hours = 0
            }

            self.hours = max(0, hours)
            self.minutes = max(0, minutes)
            self.seconds = max(0, seconds)
        }

        var shortText: String {
            String(format: "%02d:%02d", minutes, seconds)
        }

        var fullText: String {
            String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

enum SubtitleTableSampleData {
    private static let base: [(name: String, cues: String)] = [
        (
            "The Shawshank Redemption (1994)",
            "Hope is a good thing, maybe the best of things.\n希望是美好的，也许是人间至善。"
        ),
        (
            "Spirited Away",
            "Once you've met someone you never really forget them.\n一度出会った人のことは忘れないものさ。"
        ),
        (
            "A Very Long Documentary Title That Will Not Fit On A Single Line And Must Wrap Across Several Lines",
            "This is an intentionally long single-language line used to verify that the cue column wraps cleanly across multiple lines and that the row grows to fit its tallest cell while every cell stays anchored to the top."
        ),
        (
            "Your Name.",
            "I was searching for someone.\nずっと何かを、誰かを探している。"
        ),
        (
            "Interstellar",
            "Love is the one thing we're capable of perceiving that transcends dimensions of time and space."
        ),
        (
            "千と千尋の神隠し / Spirited Away (extended alias to test name wrapping behaviour)",
            "Nothing that happens is ever forgotten, even if you can't remember it.\n起こったことは決して忘れない。思い出せないだけ。"
        ),
        (
            "Coco",
            "Remember me."
        ),
        (
            "The Grand Budapest Hotel",
            "There are still faint glimmers of civilization left in this barbaric slaughterhouse that was once known as humanity."
        ),
    ]

    /// The 8 base rows repeated 10 times (80 rows) so the sandbox has enough
    /// content to test scrolling and drag auto-scroll. Ids are sequential.
    static let rows: [SubtitleTableRow] = {
        var result: [SubtitleTableRow] = []
        var id = 1
        for _ in 0..<10 {
            for entry in base {
                result.append(SubtitleTableRow(id: id, displayTitle: entry.name, cues: entry.cues))
                id += 1
            }
        }
        return result
    }()
}
