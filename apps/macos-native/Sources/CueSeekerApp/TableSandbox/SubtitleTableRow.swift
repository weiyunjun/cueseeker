import Foundation
import CueSeekerCore

enum SubtitleTableCueState: Equatable {
    case normal
    case contentChanged(previous: String, current: String)
    case unavailable(ShioriUnavailableReason)

    var isUnavailable: Bool {
        if case .unavailable = self {
            return true
        }
        return false
    }

    var systemImage: String? {
        switch self {
        case .normal:
            nil
        case .contentChanged:
            "clock.arrow.circlepath"
        case .unavailable:
            "questionmark.circle"
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
            return "The library source is currently unavailable."
        case .videoMissing:
            return "The video file is missing. The subtitle file is still available."
        case .subtitleMissing:
            return "The subtitle file is missing or could not be reconnected."
        case .cueMissing:
            return "This cue could not be found in the current subtitle file."
        }
    }

    var disabledRowActions: Set<SubtitleTableRowAction> {
        guard isUnavailable else {
            return []
        }
        var actions: Set<SubtitleTableRowAction> = [
            .play,
            .context,
            .moveToList,
            .duplicateToList,
        ]
        if !subtitleFileIsAvailable {
            actions.insert(.openSubtitleFolder)
        }
        return actions
    }
}

/// Row view-model shared by the Search, Shiori, and Context table surfaces.
struct SubtitleTableRow: Identifiable, Equatable {
    let id: Int
    /// Stable identity of the primary Cue. Shiori row identity remains the
    /// Shiori ID, so scroll anchoring cannot safely substitute `id` here.
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
    /// legacy Shiori snapshots that have no durable Cue identity.
    let primaryGroupIndex: Int?
    let tags: [WorkbenchTag]
    let shioriTags: [WorkbenchTag]
    let cueState: SubtitleTableCueState

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
        shioriTags: [WorkbenchTag] = [],
        cueState: SubtitleTableCueState = .normal
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
        self.shioriTags = shioriTags
        self.cueState = cueState
    }

    /// Compatibility initializer for fixtures and call sites that model only a
    /// single Cue. Production Search/Shiori mappings use the explicit group form.
    init(
        id: Int,
        subtitlePath: String = "",
        dateAdded: String = "",
        displayTitle: String,
        startTime: String = "",
        endTime: String = "",
        timeRange: String? = nil,
        cues: String,
        tags: [WorkbenchTag] = [],
        shioriTags: [WorkbenchTag] = []
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
            tags: tags,
            shioriTags: shioriTags
        )
    }

    func replacingShioriTags(_ nextShioriTags: [WorkbenchTag]) -> SubtitleTableRow {
        SubtitleTableRow(
            id: id,
            primaryCueID: primaryCueID,
            subtitlePath: subtitlePath,
            dateAdded: dateAdded,
            displayTitle: displayTitle,
            startTime: startTime,
            endTime: endTime,
            timeRange: timeRange,
            primaryCueText: primaryCueText,
            cueGroupTexts: cueGroupTexts,
            primaryGroupIndex: primaryGroupIndex,
            tags: tags,
            shioriTags: nextShioriTags,
            cueState: cueState
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
