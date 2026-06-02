import CueSeekerCore
import Foundation

struct VocabularyExample: Equatable, Identifiable {
    let shiori: Shiori
    let sourceTitle: String

    var id: Int64 {
        shiori.id
    }

    var sourceText: String {
        "\(sourceTitle) · \(formatTimestamp(shiori.startMilliseconds))"
    }

    var displayLines: [String] {
        subtitleDisplayLines(content: shiori.content, cueLines: shiori.cueLines)
    }
}

enum VocabularyExampleDeriver {
    static func examples(
        for entry: VocabularyEntry,
        shioris: [Shiori],
        displayTitlesBySubtitlePath: [String: String] = [:]
    ) -> [VocabularyExample] {
        let term = entry.term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            return []
        }

        return shioris
            .filter { shiori in
                shiori.content.range(
                    of: term,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }
            .map { shiori in
                VocabularyExample(
                    shiori: shiori,
                    sourceTitle: displayTitlesBySubtitlePath[shiori.subtitlePath]
                        ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: shiori.subtitlePath)
                )
            }
    }
}
