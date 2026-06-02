import AppKit
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func requestingVocabularyEntryCreationSelectsVocabularyModeAndPresentsEditor() async throws {
    try await withTemporaryVocabularyApp { app in
        #expect(app.workbenchLayout.panelMode == .search)
        #expect(!app.vocabulary.isAddVocabularyEntryEditorPresented)

        app.requestVocabularyEntryCreation()

        #expect(app.workbenchLayout.panelMode == .vocabulary)
        #expect(app.vocabulary.isAddVocabularyEntryEditorPresented)
    }
}

@MainActor
private func withTemporaryVocabularyApp(
    _ body: @MainActor (AppCoordinator) throws -> Void
) async throws {
    let suiteName = "CueSeekerVocabularyStoreTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVocabularyStoreTests-\(UUID().uuidString)")
        .appendingPathExtension("sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    await app.startupDatabaseTask?.value
    try #require(app.subtitleDatabase != nil)
    try body(app)
}
