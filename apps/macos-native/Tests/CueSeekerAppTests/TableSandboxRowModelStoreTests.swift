import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func tableSandboxRowModelStoreCachesTitlesAndKeepsStableVersionForSameRows() {
    var resolvedPaths: [String] = []
    let store = TableSandboxRowModelStore { path in
        resolvedPaths.append(path)
        return "Resolved \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    let path = "/tmp/CueSeeker/Series/episode-01.ass"
    let results = [
        searchResult(id: 1, path: path, content: "line one\nline two", cueLines: ["line one", "line two"]),
        searchResult(id: 2, path: path, content: "line three", cueLines: ["line three"]),
    ]

    store.updateSearchRows(results, tableName: "test-search")

    #expect(store.snapshot.version == 1)
    #expect(store.snapshot.update == .append(0..<2))
    #expect(store.snapshot.rows.count == 2)
    #expect(store.snapshot.rows[0].displayTitle == "Resolved episode-01.ass")
    #expect(store.snapshot.rows[0].cues == "line one\nline two")
    #expect(resolvedPaths == [path])

    store.updateSearchRows(results, tableName: "test-search")

    #expect(store.snapshot.version == 1)
    #expect(store.snapshot.update == .append(0..<2))
    #expect(resolvedPaths == [path])
}

@MainActor
@Test
func tableSandboxRowModelStoreUsesSearchDisplayTitleWithoutResolvingPath() {
    var resolvedPaths: [String] = []
    let store = TableSandboxRowModelStore { path in
        resolvedPaths.append(path)
        return "Resolved \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    let path = "/tmp/CueSeeker/Ave Mujica/episode-01.ass"
    store.updateSearchRows(
        [
            searchResult(
                id: 1,
                path: path,
                displayTitle: "Ave Mujica - 01",
                content: "line",
                cueLines: ["line"]
            )
        ],
        tableName: "test-search"
    )

    #expect(store.snapshot.rows[0].displayTitle == "Ave Mujica - 01")
    #expect(resolvedPaths.isEmpty)
}

@MainActor
@Test
func tableSandboxRowModelStoreUpdatesVersionWhenRowContentChangesWithoutReResolvingTitle() {
    var resolvedPaths: [String] = []
    let store = TableSandboxRowModelStore { path in
        resolvedPaths.append(path)
        return "Resolved \(URL(fileURLWithPath: path).lastPathComponent)"
    }

    let path = "/tmp/CueSeeker/Series/episode-01.ass"
    store.updateSearchRows([
        searchResult(id: 1, path: path, content: "old", cueLines: ["old"]),
    ], tableName: "test-search")

    store.updateSearchRows([
        searchResult(id: 1, path: path, content: "new", cueLines: ["new"]),
    ], tableName: "test-search")

    #expect(store.snapshot.version == 2)
    #expect(store.snapshot.update == .reload)
    #expect(store.snapshot.rows.map(\.cues) == ["new"])
    #expect(resolvedPaths == [path])
}

@MainActor
@Test
func tableSandboxRowModelStoreMarksAppendedSearchRows() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows([
        searchResult(id: 1, path: path, content: "one", cueLines: ["one"]),
        searchResult(id: 2, path: path, content: "two", cueLines: ["two"]),
    ], tableName: "test-search")

    store.updateSearchRows([
        searchResult(id: 1, path: path, content: "one", cueLines: ["one"]),
        searchResult(id: 2, path: path, content: "two", cueLines: ["two"]),
        searchResult(id: 3, path: path, content: "three", cueLines: ["three"]),
        searchResult(id: 4, path: path, content: "four", cueLines: ["four"]),
    ], tableName: "test-search")

    #expect(store.snapshot.version == 2)
    #expect(store.snapshot.update == .append(2..<4))
    #expect(store.snapshot.rows.map(\.id) == [1, 2, 3, 4])
}

@MainActor
@Test
func tableSandboxRowModelStoreTracksVirtualSearchTotalWithoutMaterializingUnloadedRows() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"
    let loadedResults = (0..<100).map { index in
        searchResult(
            id: Int64(index + 1),
            path: path,
            content: "loaded row \(index)",
            cueLines: ["loaded row \(index)"]
        )
    }

    store.updateSearchRows(
        loadedResults,
        totalRowCount: 2_000_000,
        tableName: "test-search"
    )

    #expect(store.snapshot.totalRowCount == 2_000_000)
    #expect(store.snapshot.loadedReferenceCount == 100)
    #expect(store.snapshot.rows.count == 100)
    #expect(store.snapshot.references.first == TableSandboxRowReference(source: .search, sourceIndex: 0, id: 1))
    #expect(store.snapshot.references.last == TableSandboxRowReference(source: .search, sourceIndex: 99, id: 100))
}

@MainActor
@Test
func tableSandboxRowModelStoreHydratesSparseVisibleSearchRows() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"
    let loadedResults = (0..<100).map { index in
        searchResult(
            id: Int64(index + 1),
            path: path,
            content: "loaded row \(index)",
            cueLines: ["loaded row \(index)"]
        )
    }
    store.updateSearchRows(
        loadedResults,
        totalRowCount: 2_000_000,
        tableName: "test-search"
    )

    store.hydrateSearchRows(
        [
            searchResult(id: 1_000_001, path: path, content: "jumped row one", cueLines: ["jumped row one"]),
            searchResult(id: 1_000_002, path: path, content: "jumped row two", cueLines: ["jumped row two"]),
        ],
        startIndex: 1_000_000,
        totalRowCount: 2_000_000,
        tableName: "test-search"
    )

    #expect(store.snapshot.totalRowCount == 2_000_000)
    #expect(store.snapshot.loadedReferenceCount == 102)
    #expect(store.snapshot.rows.count == 100)
    #expect(store.snapshot.row(at: 99)?.cues == "loaded row 99")
    #expect(store.snapshot.row(at: 100) == nil)
    #expect(store.snapshot.row(at: 1_000_000)?.cues == "jumped row one")
    #expect(store.snapshot.update == .append(1_000_000..<1_000_002))
}

@MainActor
@Test
func tableSandboxRowModelStoreDoesNotShrinkAuthoritativeTotalDuringHydration() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"
    let loadedResults = (0..<111).map { index in
        searchResult(
            id: Int64(index + 1),
            path: path,
            content: "loaded row \(index)",
            cueLines: ["loaded row \(index)"]
        )
    }

    store.updateSearchRows(
        loadedResults,
        totalRowCount: 1_335,
        tableName: "test-search"
    )
    store.hydrateSearchRows(
        [
            searchResult(id: 112, path: path, content: "visible row", cueLines: ["visible row"]),
        ],
        startIndex: 111,
        totalRowCount: 111,
        tableName: "test-search"
    )

    #expect(store.snapshot.totalRowCount == 1_335)
    #expect(store.snapshot.row(at: 111)?.cues == "visible row")
}

@MainActor
@Test
func tableSandboxRowModelStoreCachesHydratedSearchResultsForActions() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows(
        [
            searchResult(id: 1, path: path, content: "loaded row", cueLines: ["loaded row"]),
        ],
        totalRowCount: 500,
        tableName: "test-search"
    )
    store.hydrateSearchRows(
        [
            searchResult(id: 301, path: path, content: "hydrated row", cueLines: ["hydrated row"]),
        ],
        startIndex: 300,
        totalRowCount: 500,
        tableName: "test-search"
    )

    #expect(store.snapshot.searchResult(entryID: 1)?.content == "loaded row")
    #expect(store.snapshot.searchResult(entryID: 301)?.content == "hydrated row")
}

@MainActor
@Test
func tableSandboxRowModelStorePrunesHydratedSearchRowsAroundVisibleWindow() {
    let store = TableSandboxRowModelStore(maximumHydratedSearchRows: 4) { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows(
        (0..<4).map { index in
            searchResult(
                id: Int64(index + 1),
                path: path,
                content: "prefix row \(index)",
                cueLines: ["prefix row \(index)"]
            )
        },
        totalRowCount: 1_000,
        tableName: "test-search"
    )
    store.hydrateSearchRows(
        [
            searchResult(id: 501, path: path, content: "visible one", cueLines: ["visible one"]),
            searchResult(id: 502, path: path, content: "visible two", cueLines: ["visible two"]),
        ],
        startIndex: 500,
        totalRowCount: 1_000,
        tableName: "test-search"
    )

    #expect(store.snapshot.totalRowCount == 1_000)
    #expect(store.snapshot.loadedReferenceCount == 4)
    #expect(store.snapshot.row(at: 500)?.cues == "visible one")
    #expect(store.snapshot.row(at: 501)?.cues == "visible two")
}

@MainActor
@Test
func tableSandboxRowModelStoreLimitsTableDisplayTextBudget() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/effects.ass"
    let longLine = String(repeating: "x", count: TableSandboxDisplayTextBudget.maximumCharactersPerLine + 20)
    let cueLines = (0..<(TableSandboxDisplayTextBudget.maximumLines + 4)).map { index in
        index == 0 ? longLine : "line \(index)"
    }

    store.updateSearchRows(
        [
            searchResult(
                id: 1,
                path: path,
                content: cueLines.joined(separator: "\n"),
                cueLines: cueLines
            )
        ],
        tableName: "test-search"
    )

    let row = store.snapshot.row(at: 0)
    let displayLines = row?.cues.components(separatedBy: "\n") ?? []
    #expect(displayLines.count == TableSandboxDisplayTextBudget.maximumLines)
    #expect(displayLines.first?.count == TableSandboxDisplayTextBudget.maximumCharactersPerLine + 3)
}

@MainActor
@Test
func tableSandboxRowModelStoreMapsSearchLanguagesToDefaultBlueTags() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows(
        [
            searchResult(
                id: 1,
                path: path,
                content: "bilingual row",
                cueLines: ["bilingual row"],
                languages: [.japanese, .simplifiedChinese]
            )
        ],
        tableName: "test-search"
    )

    let tags = store.snapshot.row(at: 0)?.tags ?? []
    #expect(tags.map(\.key) == ["zh-hans", "jp"])
    #expect(tags.map(\.label) == ["zh-hans", "jp"])
    #expect(tags.map(\.colorID) == [.blue, .blue])
}

private func searchResult(
    id: Int64,
    path: String,
    displayTitle: String = "",
    content: String,
    cueLines: [String],
    languages: Set<SubtitleLanguageCode> = [.unknown]
) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        subtitlePath: path,
        subtitleFormat: .ass,
        videoPath: path.replacingOccurrences(of: ".ass", with: ".mkv"),
        videoName: "episode.mkv",
        displayTitle: displayTitle,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: content,
        cueLines: cueLines,
        languages: languages
    )
}
