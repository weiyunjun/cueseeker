import Foundation

/// Row view-model for the table sandbox. Phase B feeds this from static sample
/// data; Phase C will map it from real search results / Shiori entries
/// (displayTitle = user-facing subtitle title, cues = merged same-timestamp subtitle text).
struct SubtitleTableRow: Identifiable, Equatable {
    let id: Int
    let subtitlePath: String
    let dateAdded: String
    let displayTitle: String
    let startTime: String
    let endTime: String
    let timeRange: String
    /// Merged subtitle text for one timestamp. Bilingual entries keep one line
    /// per language, joined with "\n", so the cell wraps to multiple lines.
    let cues: String
    let tags: [WorkbenchTag]
    let speakerTags: [WorkbenchTag]
    let shioriTags: [WorkbenchTag]

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
        speakerTags: [WorkbenchTag] = [],
        shioriTags: [WorkbenchTag] = []
    ) {
        self.id = id
        self.subtitlePath = subtitlePath
        self.dateAdded = dateAdded
        self.displayTitle = displayTitle
        self.startTime = startTime
        self.endTime = endTime
        self.timeRange = timeRange ?? SubtitleTableTimeRange.text(
            startTime: startTime,
            endTime: endTime
        )
        self.cues = cues
        self.tags = tags
        self.speakerTags = speakerTags
        self.shioriTags = shioriTags
    }

    func replacingShioriTags(_ nextShioriTags: [WorkbenchTag]) -> SubtitleTableRow {
        SubtitleTableRow(
            id: id,
            subtitlePath: subtitlePath,
            dateAdded: dateAdded,
            displayTitle: displayTitle,
            startTime: startTime,
            endTime: endTime,
            timeRange: timeRange,
            cues: cues,
            tags: tags,
            speakerTags: speakerTags,
            shioriTags: nextShioriTags
        )
    }
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
