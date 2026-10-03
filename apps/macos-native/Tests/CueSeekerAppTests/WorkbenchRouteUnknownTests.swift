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
