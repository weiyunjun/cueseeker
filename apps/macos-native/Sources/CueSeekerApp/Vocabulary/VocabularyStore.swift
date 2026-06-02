import Foundation
import CueSeekerCore

@MainActor
final class VocabularyStore: ObservableObject {
    @Published var entries: [VocabularyEntry] = []
    @Published var selectedEntryID: Int64?
    @Published var isAddVocabularyEntryEditorPresented = false
    @Published var playbackExamples: [VocabularyExample] = []
    @Published var selectedPlaybackExampleID: String?

    var hasEntries: Bool {
        !entries.isEmpty
    }

    var selectedEntry: VocabularyEntry? {
        guard let selectedEntryID else {
            return nil
        }

        return entries.first { $0.id == selectedEntryID }
    }

    var selectedPlaybackExample: VocabularyExample? {
        guard let selectedPlaybackExampleID else {
            return nil
        }

        return playbackExamples.first { $0.id == selectedPlaybackExampleID }
    }

    func applyPlaybackExamples(
        _ examples: [VocabularyExample],
        selectedExampleID: String?
    ) {
        playbackExamples = examples
        if let selectedExampleID,
           examples.contains(where: { $0.id == selectedExampleID }) {
            selectedPlaybackExampleID = selectedExampleID
        } else {
            selectedPlaybackExampleID = examples.first?.id
        }
    }

    func clearPlaybackExamples() {
        playbackExamples = []
        selectedPlaybackExampleID = nil
    }
}
