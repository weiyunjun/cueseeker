import Foundation

public enum CueDeepLink {
    private static let markdownLinkEscapedCharacters: Set<Character> = [
        "\\", "[", "]", "<", ">", "*", "_", "`", "~", "&", "|",
    ]

    public static func markdownLink(cueText: String, cueID: Int64) -> String? {
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

    public static func markdownLinks(
        _ cues: [(cueText: String, cueID: Int64)]
    ) -> String? {
        guard !cues.isEmpty else {
            return nil
        }
        var links: [String] = []
        links.reserveCapacity(cues.count)
        for cue in cues {
            guard let link = markdownLink(
                cueText: cue.cueText,
                cueID: cue.cueID
            ) else {
                return nil
            }
            links.append(link)
        }
        return links.joined(separator: "\n")
    }
}
