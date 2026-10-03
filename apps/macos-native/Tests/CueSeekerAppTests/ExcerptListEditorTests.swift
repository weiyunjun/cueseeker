import AppKit
import Combine
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func excerptListEditorTracksDirtyStateAndExactValidationMessages() {
    let session = ExcerptListEditorSession(mode: .newList)
    #expect(!session.hasUnsavedChanges)

    session.name = String(repeating: "N", count: 31)
    session.listDescription = String(repeating: "D", count: 101)
    #expect(session.hasUnsavedChanges)
    session.apply(validation: ExcerptListValidation(
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

    session.apply(validation: ExcerptListValidation(
        nameError: .duplicateName,
        descriptionError: nil
    ))
    #expect(
        session.nameValidationMessage
            == "A list with this name already exists."
    )
    #expect(session.descriptionValidationMessage == nil)

    session.apply(validation: ExcerptListValidation(
        nameError: .emptyName,
        descriptionError: nil
    ))
    #expect(session.nameValidationMessage == "Enter a list name.")
}

@MainActor
@Test
func appCoordinatorCreatesEditsAndDeletesExcerptListsFromEditorSessions() async throws {
    let suiteName = "CueSeekerExcerptListEditorTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerExcerptListEditorTests-\(UUID().uuidString)",
            isDirectory: true
        )
    let databaseURL = directory.appendingPathComponent("CueSeeker.sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    let database = try #require(app.excerptDatabase)
    app.reloadExcerptListOverview()
    try await waitForExcerptListEditorTasks(app)
    #expect(app.excerpt.hasLoadedListOverview)

    var loadedStates: [Bool] = []
    let loadedStateCancellable = app.excerpt.$hasLoadedListOverview
        .dropFirst()
        .sink { loadedStates.append($0) }
    defer { loadedStateCancellable.cancel() }

    app.beginCreatingExcerptList()
    let newSession = try #require(app.excerpt.listEditorSession)
    newSession.name = "Study"
    newSession.listDescription = "Review later"
    app.saveExcerptListEditor(newSession)
    try await waitForExcerptListEditorTasks(app)

    let created = try #require(try database.excerptLists().first {
        $0.name == "Study"
    })
    #expect(created.description == "Review later")
    #expect(app.excerpt.listEditorSession == nil)
    #expect(app.excerpt.listOverview.lists.last?.id == created.id)
    #expect(!loadedStates.contains(false))

    app.beginEditingExcerptList(created)
    let editSession = try #require(app.excerpt.listEditorSession)
    #expect(!editSession.hasUnsavedChanges)
    editSession.name = "Study Queue"
    editSession.listDescription = ""
    app.saveExcerptListEditor(editSession)
    try await waitForExcerptListEditorTasks(app)

    let updated = try #require(try database.excerptList(id: created.id))
    #expect(updated.name == "Study Queue")
    #expect(updated.description.isEmpty)
    #expect(app.excerpt.listOverview.lists.last?.list == updated)
    #expect(!loadedStates.contains(false))
    #expect(app.deleteExcerptList(id: ExcerptListIdentity.defaultListID))
    try await waitForExcerptListEditorTasks(app)
    #expect(try database.excerptLists().map(\.id) == [updated.id])
    #expect(app.excerpt.listOverview.lists.map(\.id) == [updated.id])
    #expect(!loadedStates.contains(false))
}

@MainActor
private func waitForExcerptListEditorTasks(_ app: AppCoordinator) async throws {
    for _ in 0..<200 {
        if app.excerptListSaveTask == nil, app.excerptListOverviewTask == nil {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting for Excerpt list editor tasks")
}
