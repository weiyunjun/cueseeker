import AppKit
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func urlSchemeSearchClearsFiltersAndForcesSearchRoute() throws {
    let suiteName = "URLSchemeSearchRoutingTests-\(UUID().uuidString)"
    let userDefaults = try #require(UserDefaults(suiteName: suiteName))
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("URLSchemeSearchRoutingTests-\(UUID().uuidString).sqlite")
    defer {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseURL)
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
        try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
    }

    _ = NSApplication.shared
    let app = AppCoordinator(userDefaults: userDefaults, databaseURL: databaseURL)
    app.workbenchLayout.selectPanelMode(.shiori)
    app.search.activeFilterSet = SubtitleSearchFilterSet(rules: [
        SubtitleSearchFilterRule(
            field: .display,
            operatorID: .contains,
            value: "old filter"
        )
    ])
    app.search.cueContextSearchRequest = CueContextSearchRequest(
        displayTitle: "Old context",
        subtitlePath: "/tmp/old.ass",
        targetCueID: 42
    )

    app.handleURLSchemeCommand(.search(keyword: "大丈夫"))

    #expect(app.workbenchLayout.panelMode == .search)
    #expect(app.search.searchQuery == "大丈夫")
    #expect(app.search.activeFilterSet.isEffectivelyEmpty)
    #expect(app.search.cueContextSearchRequest == nil)
}
