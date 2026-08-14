import AppKit
import Combine
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func shioriListEditorTracksDirtyStateAndExactValidationMessages() {
    let session = ShioriListEditorSession(mode: .newList)
    #expect(!session.hasUnsavedChanges)

    session.name = String(repeating: "N", count: 31)
    session.listDescription = String(repeating: "D", count: 101)
    #expect(session.hasUnsavedChanges)
    session.apply(validation: ShioriListValidation(
        nameError: .nameTooLong(maximumCharacters: 30, currentCharacters: 31),
        descriptionError: .descriptionTooLong(
            maximumCharacters: 100,
            currentCharacters: 101
        )
    ))
    #expect(
        session.nameValidationMessage
            == "List name must be 30 characters or fewer."
    )
    #expect(
        session.descriptionValidationMessage
            == "Description must be 100 characters or fewer."
    )

    session.apply(validation: ShioriListValidation(
        nameError: .duplicateName,
        descriptionError: nil
    ))
    #expect(
        session.nameValidationMessage
            == "A list with this name already exists."
    )
    #expect(session.descriptionValidationMessage == nil)

    session.apply(validation: ShioriListValidation(
        nameError: .emptyName,
        descriptionError: nil
    ))
    #expect(session.nameValidationMessage == "Enter a list name.")
}

@MainActor
@Test
func appCoordinatorCreatesEditsAndDeletesShioriListsFromEditorSessions() async throws {
    let suiteName = "CueSeekerShioriListEditorTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerShioriListEditorTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = directory.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.shioriDatabase)
    app.reloadShioriListOverview()
    try await waitForShioriListEditorTasks(app)
    #expect(app.shiori.hasLoadedListOverview)

    var loadedStates: [Bool] = []
    let loadedStateCancellable = app.shiori.$hasLoadedListOverview
        .dropFirst()
        .sink { loadedStates.append($0) }
    defer { loadedStateCancellable.cancel() }

    app.beginCreatingShioriList()
    let newSession = try #require(app.shiori.listEditorSession)
    newSession.name = "Study"
    newSession.listDescription = "Review later"
    app.saveShioriListEditor(newSession)
    try await waitForShioriListEditorTasks(app)

    let created = try #require(try database.shioriLists().first {
        $0.name == "Study"
    })
    #expect(created.description == "Review later")
    #expect(app.shiori.listEditorSession == nil)
    #expect(app.shiori.listOverview.lists.first?.id == created.id)
    #expect(!loadedStates.contains(false))

    app.beginEditingShioriList(created)
    let editSession = try #require(app.shiori.listEditorSession)
    #expect(!editSession.hasUnsavedChanges)
    editSession.name = "Study Queue"
    editSession.listDescription = ""
    app.saveShioriListEditor(editSession)
    try await waitForShioriListEditorTasks(app)

    let updated = try #require(try database.shioriList(id: created.id))
    #expect(updated.name == "Study Queue")
    #expect(updated.description.isEmpty)
    #expect(app.shiori.listOverview.lists.first?.list == updated)
    #expect(!loadedStates.contains(false))
    #expect(app.deleteShioriList(id: ShioriListIdentity.defaultListID))
    try await waitForShioriListEditorTasks(app)
    #expect(try database.shioriLists().map(\.id) == [updated.id])
    #expect(app.shiori.listOverview.lists.map(\.id) == [updated.id])
    #expect(!loadedStates.contains(false))
}

@MainActor
private func waitForShioriListEditorTasks(_ app: AppCoordinator) async throws {
    for _ in 0..<200 {
        if app.shioriListSaveTask == nil, app.shioriListOverviewTask == nil {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting for Shiori list editor tasks")
}
