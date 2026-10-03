import AppKit
@testable import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func historyEntriesReadAsUnknownOnlyOnceTheirStoreKnowsThePageIsGone() throws {
    _ = NSApplication.shared
    let suiteName = "WorkbenchRouteUnknown-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults.temporary(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(suiteName).sqlite")
    defer {
        userDefaults.removePersistentDomainAndPlist(forName: suiteName)
        removeTemporaryDatabase(at: databaseURL)
    }
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)

    let goneFolder = WorkbenchRoute.libraryFolder(folderPath: "/Media/Gone")
    let keptFolder = WorkbenchRoute.libraryFolder(folderPath: "/Media/Show")
    #expect(!app.isWorkbenchRouteUnknown(goneFolder))
    app.library.completeLibraryFolderSummaries = [
        CompleteLibraryFolderSummaryPresentation(
            folderPath: "/Media/Show",
            folderTitle: "Show",
            coverPath: nil,
            coverRevision: nil,
            episodeCount: 1
        ),
    ]
    app.library.completeLibraryStatus = .loading
    #expect(!app.isWorkbenchRouteUnknown(goneFolder))
    app.library.completeLibraryStatus = .completed
    #expect(app.isWorkbenchRouteUnknown(goneFolder))
    #expect(!app.isWorkbenchRouteUnknown(keptFolder))

    let goneList = WorkbenchRoute.excerptList(id: 99)
    #expect(!app.isWorkbenchRouteUnknown(goneList))
    app.excerpt.installListOverview(
        ExcerptListOverview(lists: [], uniqueCueCount: 0)
    )
    #expect(app.isWorkbenchRouteUnknown(goneList))

    for route in [WorkbenchRoute.search, .recent, .library, .file, .excerpt] {
        #expect(!app.isWorkbenchRouteUnknown(route))
    }
}

@MainActor
@Test
func appTopBarPageTitleRemainsFixedForLibraryAndExcerptAcrossLevels() {
    #expect(AppTopBar.pageTitle(for: .library) == L("sidebar.library"))
    #expect(AppTopBar.pageTitle(for: .libraryFolder(folderPath: "/Media/Show")) == L("sidebar.library"))
    #expect(AppTopBar.pageTitle(for: .libraryFolder(folderPath: "/Media/Gone")) == L("sidebar.library"))
    #expect(AppTopBar.pageTitle(for: .excerpt) == L("sidebar.excerpt"))
    #expect(AppTopBar.pageTitle(for: .excerptList(id: 1)) == L("sidebar.excerpt"))
    #expect(AppTopBar.pageTitle(for: .excerptList(id: 99)) == L("sidebar.excerpt"))
}

@Test
func missingRouteLocalizationStringsAreAvailable() {
    let folderNotFound = L("library.folder.not_found")
    #expect(!folderNotFound.isEmpty)
    #expect(folderNotFound != "library.folder.not_found")

    let listNotFound = L("excerpt.list.not_found")
    #expect(!listNotFound.isEmpty)
    #expect(listNotFound != "excerpt.list.not_found")
}
