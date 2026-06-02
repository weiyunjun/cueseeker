import Foundation
import CueSeekerCore

@MainActor
final class VocabularyStore: ObservableObject {
    @Published var entries: [VocabularyEntry] = []
    @Published var selectedEntryID: Int64?
    @Published var isAddVocabularyEntryEditorPresented = false

    var hasEntries: Bool {
        !entries.isEmpty
    }

    var selectedEntry: VocabularyEntry? {
        guard let selectedEntryID else {
            return nil
        }

        return entries.first { $0.id == selectedEntryID }
    }
}
