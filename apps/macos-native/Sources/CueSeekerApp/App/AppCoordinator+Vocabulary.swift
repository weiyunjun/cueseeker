import Foundation
import CueSeekerCore

@MainActor
extension AppCoordinator {
    func hydrateVocabularyEntriesAsync() {
        guard let database = subtitleDatabase else {
            return
        }

        vocabularyTask?.cancel()
        vocabularyTask = Task { [weak self] in
            do {
                let entries = try await Task.detached(priority: .userInitiated) {
                    try database.vocabularyEntries()
                }.value

                guard !Task.isCancelled else {
                    return
                }

                self?.applyVocabularyEntries(entries)
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                print("Failed to load vocabulary entries asynchronously: \(error)")
            }
        }
    }

    func applyVocabularyEntries(_ entries: [VocabularyEntry]) {
        vocabulary.entries = entries
        if let selectedEntryID = vocabulary.selectedEntryID,
           !entries.contains(where: { $0.id == selectedEntryID }) {
            vocabulary.selectedEntryID = nil
        }
    }

    func requestVocabularyEntryCreation() {
        UIInvalidationProbe.mark("ACTION UI.Vocabulary.addRequested")
        activateWorkbenchPanelMode(.vocabulary)
        vocabulary.isAddVocabularyEntryEditorPresented = true
    }
}
