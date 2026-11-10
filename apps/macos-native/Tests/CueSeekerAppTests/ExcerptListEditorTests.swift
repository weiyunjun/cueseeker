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
    #expect(app.excerpt.listOverview.lists.isEmpty)
    #expect(app.excerpt.recentListSummaries.isEmpty)

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
    #expect(app.excerpt.listOverview.lists.map(\.id) == [created.id])
    #expect(app.excerpt.recentListSummaries.map(\.id) == [created.id])
    #expect(app.excerpt.recentListSummaries.first?.list.recentPlayedAt == nil)
    #expect(!loadedStates.contains(false))

    app.beginCreatingExcerptList()
    let secondSession = try #require(app.excerpt.listEditorSession)
    secondSession.name = "Archive"
    app.saveExcerptListEditor(secondSession)
    try await waitForExcerptListEditorTasks(app)
    let second = try #require(try database.excerptLists().first {
        $0.name == "Archive"
    })
    #expect(app.excerpt.listOverview.lists.map(\.id) == [created.id, second.id])
    #expect(app.excerpt.recentListSummaries.map(\.id) == [created.id, second.id])

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
    #expect(app.excerpt.listOverview.lists.first?.list == updated)
    #expect(!loadedStates.contains(false))

    #expect(app.deleteExcerptList(id: second.id))
    try await waitForExcerptListEditorTasks(app)
    #expect(try database.excerptLists().map(\.id) == [updated.id])
    #expect(app.excerpt.listOverview.lists.map(\.id) == [updated.id])
    #expect(app.excerpt.recentListSummaries.map(\.id) == [updated.id])
    #expect(!loadedStates.contains(false))

    // Deleting the last remaining Excerpt List is allowed and leaves 0 lists.
    #expect(app.deleteExcerptList(id: updated.id))
    try await waitForExcerptListEditorTasks(app)
    #expect(try database.excerptLists().isEmpty)
    #expect(app.excerpt.listOverview.lists.isEmpty)
    #expect(app.excerpt.recentListSummaries.isEmpty)
    #expect(!loadedStates.contains(false))
}

@MainActor
@Test
func deletingActiveLastExcerptListNavigatesBackToEmptyOnboardingAndClearsSearchDraft() async throws {
    let suiteName = "CueSeekerExcerptLastListOnboardingTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerExcerptLastListOnboardingTests-\(UUID().uuidString)",
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
    let onlyList = try database.createExcerptList(name: "Only List")

    app.navigateWorkbench(to: .excerpt)
    app.reloadExcerptListOverview()
    try await waitForExcerptListEditorTasks(app)
    #expect(app.excerpt.listOverview.lists.map(\.id) == [onlyList.id])
    let targetsWithList = app.currentWorkbenchAccessibilityTargets()
    #expect(targetsWithList.contains(.toolbarSearchField))
    #expect(targetsWithList.contains(.toolbarSortButton))
    #expect(targetsWithList.contains(.excerptNewListButton))

    app.excerpt.overviewSearchDraft = "Only"
    app.openExcerptList(id: onlyList.id)
    await app.excerptTableRowsTask?.value
    #expect(app.workbenchLayout.currentRoute == .excerptList(id: onlyList.id))
    #expect(app.workbenchLayout.selectedExcerptListID == onlyList.id)

    #expect(app.deleteExcerptList(id: onlyList.id))
    try await waitForExcerptListEditorTasks(app)

    #expect(app.workbenchLayout.currentRoute == .excerpt)
    #expect(app.workbenchLayout.selectedExcerptListID == nil)
    #expect(app.excerpt.listOverview.lists.isEmpty)
    #expect(app.excerpt.recentListSummaries.isEmpty)
    #expect(app.excerpt.overviewSearchDraft.isEmpty)
    let targetsWhenEmpty = app.currentWorkbenchAccessibilityTargets()
    #expect(!targetsWhenEmpty.contains(.toolbarSearchField))
    #expect(!targetsWhenEmpty.contains(.toolbarSortButton))
    #expect(targetsWhenEmpty.contains(.excerptNewListButton))
}

@MainActor
@Test
func savingCueWhenZeroListsExistShowsOnlyNewListAndSavesIntoCreatedList() async throws {
    let suiteName = "CueSeekerExcerptZeroListSaveTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "CueSeekerExcerptZeroListSaveTests-\(UUID().uuidString)",
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
    let indexingDatabase = try #require(app.indexingDatabase)
    let excerptDatabase = try #require(app.excerptDatabase)
    try indexingDatabase.replaceEntries(
        subtitleFile: URL(fileURLWithPath: "/Media/FirstSave.srt"),
        videoFile: URL(fileURLWithPath: "/Media/FirstSave.mkv"),
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                text: "First cue with zero lists"
            )
        ]
    )
    let cue = try #require(try SearchDatabase(path: databaseURL).search("First").first)

    app.reloadExcerptListOverview()
    try await waitForExcerptListEditorTasks(app)
    #expect(app.excerpt.saveDestinations.isEmpty)
    #expect(ExcerptDestinationMenu.selectablePositions(destinationCount: app.excerpt.saveDestinations.count) == [0])
    #expect(ExcerptDestinationMenu.defaultPosition(destinations: app.excerpt.saveDestinations) == nil)

    app.beginCreatingExcerptList(
        pendingTransfer: ExcerptListEditorPendingTransfer(
            action: .saveToExcerpt,
            target: .cue(cue.entryID),
            report: .toast
        )
    )
    let session = try #require(app.excerpt.listEditorSession)
    session.name = "First Created"
    app.saveExcerptListEditor(session)
    try await waitForExcerptListEditorTasks(app)
    await app.excerptMutationTask?.value

    let created = try #require(try excerptDatabase.excerptLists().first)
    #expect(created.name == "First Created")
    #expect(try excerptDatabase.excerpt(cueID: cue.entryID, listID: created.id) != nil)
    #expect(app.toast.visibleItems.last?.request == ExcerptToastRequest.saveSucceeded(listName: "First Created"))
    #expect(app.excerpt.listOverview.lists.map(\.id) == [created.id])
    #expect(app.excerpt.listOverview.lists.first?.cueCount == 1)
    #expect(app.excerpt.recentListSummaries.map(\.id) == [created.id])
    #expect(app.excerpt.recentListSummaries.first?.list.recentPlayedAt == nil)
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
