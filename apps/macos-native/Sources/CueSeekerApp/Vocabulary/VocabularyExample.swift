import CueSeekerCore
import Foundation

struct VocabularyExample: Equatable, Identifiable {
    let vocabularyEntryID: Int64
    let term: String
    let shiori: Shiori
    let sourceTitle: String

    var id: String {
        "\(vocabularyEntryID)-\(shiori.id)"
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
                guard shiori.isValid else {
                    return false
                }

                return shiori.content.range(
                    of: term,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) != nil
            }
            .map { shiori in
                VocabularyExample(
                    vocabularyEntryID: entry.id,
                    term: entry.term,
                    shiori: shiori,
                    sourceTitle: displayTitlesBySubtitlePath[shiori.subtitlePath]
                        ?? SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: shiori.subtitlePath)
                )
            }
    }

    static func allExamples(
        for entries: [VocabularyEntry],
        shioris: [Shiori],
        displayTitlesBySubtitlePath: [String: String] = [:]
    ) -> [VocabularyExample] {
        entries.flatMap { entry in
            examples(
                for: entry,
                shioris: shioris,
                displayTitlesBySubtitlePath: displayTitlesBySubtitlePath
            )
        }
    }
}
