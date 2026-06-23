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
func tableSandboxRowModelStoreHydratesSparseShioriRowsForVirtualTableActions() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }

    store.hydrateShioriRows(
        [
            shioriSource(id: 301, content: "visible shiori one", languages: [.japanese]),
            shioriSource(id: 302, content: "visible shiori two", languages: [.simplifiedChinese]),
        ],
        startIndex: 300,
        totalRowCount: 1_000,
        tableName: "shiori"
    )

    #expect(store.snapshot.totalRowCount == 1_000)
    #expect(store.snapshot.loadedReferenceCount == 2)
    #expect(store.snapshot.rows.isEmpty)
    #expect(store.snapshot.row(at: 299) == nil)
    #expect(store.snapshot.row(at: 300)?.cues == "visible shiori one")
    #expect(store.snapshot.row(at: 301)?.tags.map(\.label) == ["zh-hans"])
    #expect(store.snapshot.shiori(entryID: 301)?.content == "visible shiori one")
    #expect(store.snapshot.update == .append(300..<302))
}

@MainActor
@Test
func tableSandboxRowModelStorePrunesHydratedShioriRowsAroundVisibleWindow() {
    let store = TableSandboxRowModelStore(maximumHydratedSearchRows: 3) { _ in "Resolved" }

    store.hydrateShioriRows(
        [
            shioriSource(id: 1, content: "prefix one", languages: [.japanese]),
            shioriSource(id: 2, content: "prefix two", languages: [.japanese]),
            shioriSource(id: 3, content: "prefix three", languages: [.japanese]),
        ],
        startIndex: 0,
        totalRowCount: 100,
        tableName: "shiori"
    )
    store.hydrateShioriRows(
        [
            shioriSource(id: 51, content: "visible one", languages: [.japanese]),
            shioriSource(id: 52, content: "visible two", languages: [.japanese]),
        ],
        startIndex: 50,
        totalRowCount: 100,
        tableName: "shiori"
    )

    #expect(store.snapshot.totalRowCount == 100)
    #expect(store.snapshot.loadedReferenceCount == 3)
    #expect(store.snapshot.row(at: 50)?.cues == "visible one")
    #expect(store.snapshot.row(at: 51)?.cues == "visible two")
    #expect(store.snapshot.shiori(entryID: 1) == nil)
    #expect(store.snapshot.shiori(entryID: 51)?.content == "visible one")
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

@MainActor
@Test
func tableSandboxRowModelStoreMapsSearchSpeakersToTags() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows(
        [
            searchResult(
                id: 1,
                path: path,
                content: "speaker row",
                cueLines: ["speaker row"],
                speakers: ["高松灯", "长崎素世"]
            )
        ],
        tableName: "test-search"
    )

    let tags = store.snapshot.row(at: 0)?.speakerTags ?? []
    #expect(tags.map(\.key) == ["长崎素世", "高松灯"])
    #expect(tags.map(\.label) == ["长崎素世", "高松灯"])
    #expect(tags.map(\.colorID) == [.purple, .purple])
}

private func searchResult(
    id: Int64,
    path: String,
    displayTitle: String = "",
    content: String,
    cueLines: [String],
    languages: Set<SubtitleLanguageCode> = [.unknown],
    speakers: Set<String> = []
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
        languages: languages,
        speakers: speakers
    )
}

private func shioriSource(
    id: Int64,
    content: String,
    languages: Set<SubtitleLanguageCode>
) -> TableSandboxShioriRowSource {
    TableSandboxShioriRowSource(
        shiori: Shiori(
            id: id,
            subtitlePath: "/tmp/CueSeeker/Series/episode-\(id).ass",
            subtitleFormat: .ass,
            videoPath: "/tmp/CueSeeker/Series/episode-\(id).mkv",
            videoName: "episode-\(id).mkv",
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            content: content,
            isValid: true,
            createdAt: "2026-06-23T12:00:00Z"
        ),
        displayTitle: "Episode \(id)",
        dateAddedText: "26-06-23 12:00",
        languages: languages
    )
}
