import Foundation
import CueSeekerCore

enum VocabularyEntryCreationError: LocalizedError, Equatable {
    case databaseUnavailable
    case emptyTerm
    case emptyExplanation

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return "Vocabulary database is unavailable."
        case .emptyTerm:
            return "Word is required."
        case .emptyExplanation:
            return "Explanation is required."
        }
    }
}

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
        if vocabulary.selectedEntryID == nil {
            vocabulary.selectedEntryID = entries.first?.id
        }
    }

    func requestVocabularyEntryCreation() {
        UIInvalidationProbe.mark("ACTION UI.Vocabulary.addRequested")
        activateWorkbenchPanelMode(.vocabulary)
        vocabulary.isAddVocabularyEntryEditorPresented = true
    }

    @discardableResult
    func addVocabularyEntry(term: String, explanation: String) throws -> VocabularyEntry {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExplanation = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else {
            throw VocabularyEntryCreationError.emptyTerm
        }
        guard !trimmedExplanation.isEmpty else {
            throw VocabularyEntryCreationError.emptyExplanation
        }
        guard let database = subtitleDatabase else {
            throw VocabularyEntryCreationError.databaseUnavailable
        }

        UIInvalidationProbe.mark("ACTION UI.Vocabulary.addConfirmed")
        vocabularyTask?.cancel()
        vocabularyTask = nil

        let entry = try database.addVocabularyEntry(
            term: trimmedTerm,
            explanation: trimmedExplanation
        )
        applyVocabularyEntries(try database.vocabularyEntries())
        vocabulary.selectedEntryID = entry.id
        vocabulary.isAddVocabularyEntryEditorPresented = false
        return entry
    }
}
