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
    #expect(store.snapshot.rows[0].name == "Resolved episode-01.ass")
    #expect(store.snapshot.rows[0].cues == "line one\nline two")
    #expect(resolvedPaths == [path])

    store.updateSearchRows(results, tableName: "test-search")

    #expect(store.snapshot.version == 1)
    #expect(store.snapshot.update == .append(0..<2))
    #expect(resolvedPaths == [path])
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

private func searchResult(
    id: Int64,
    path: String,
    content: String,
    cueLines: [String]
) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        subtitlePath: path,
        subtitleFormat: .ass,
        videoPath: path.replacingOccurrences(of: ".ass", with: ".mkv"),
        videoName: "episode.mkv",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: content,
        cueLines: cueLines
    )
}
