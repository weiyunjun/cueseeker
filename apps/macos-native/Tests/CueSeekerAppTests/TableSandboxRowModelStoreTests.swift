import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@Test
func tableSandboxShioriDateAddedDisplayConvertsUTCToLocalTime() throws {
    let shanghaiTimeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))

    #expect(
        tableSandboxShioriDateAddedDisplayText(
            for: "2026-07-23T18:20:49Z",
            timeZone: shanghaiTimeZone
        ) == "26-07-24 02:20"
    )
}

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
    #expect(store.snapshot.rows[0].startTime == "00:01")
    #expect(store.snapshot.rows[0].endTime == "00:02")
    #expect(store.snapshot.rows[0].cues == "line one\nline two")
    #expect(resolvedPaths == [path])

    store.updateSearchRows(results, tableName: "test-search")

    #expect(store.snapshot.version == 1)
    #expect(store.snapshot.update == .append(0..<2))
    #expect(resolvedPaths == [path])
}

@MainActor
@Test
func tableSandboxRowModelStoreRecordsSnapshotAndHydrationProbeOwners() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    let recording = UIInvalidationProbe.recordForTesting {
        store.updateSearchRows(
            [searchResult(id: 1, path: path, content: "one", cueLines: ["one"])],
            tableName: "search"
        )
        store.hydrateSearchRows(
            [searchResult(id: 2, path: path, content: "two", cueLines: ["two"])],
            startIndex: 1,
            totalRowCount: 2,
            tableName: "search"
        )
    }.recording

    #expect(recording.count("table.search.snapshot_rebuild") == 2)
    #expect(recording.count("table.search.row_hydration_applied") == 1)
}

@MainActor
@Test
func tableSandboxRowModelStoreFormatsCueTimeColumns() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows(
        [
            searchResult(
                id: 1,
                path: path,
                content: "short cue",
                cueLines: ["short cue"],
                startMilliseconds: 918_000,
                endMilliseconds: 4_592_000
            )
        ],
        tableName: "test-search"
    )

    #expect(store.snapshot.rows[0].startTime == "15:18")
    #expect(store.snapshot.rows[0].endTime == "01:16:32")
    #expect(store.snapshot.rows[0].timeRange == "00:15:18 - 01:16:32")
}

@MainActor
@Test
func tableSandboxRowModelStoreUsesPrecomputedSearchTimeRange() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows(
        [
            searchResult(
                id: 1,
                path: path,
                content: "short cue",
                cueLines: ["short cue"],
                timeRange: "01:02:03 - 01:02:04",
                startMilliseconds: 918_000,
                endMilliseconds: 4_592_000
            )
        ],
        tableName: "test-search"
    )

    #expect(store.snapshot.rows[0].startTime == "15:18")
    #expect(store.snapshot.rows[0].endTime == "01:16:32")
    #expect(store.snapshot.rows[0].timeRange == "01:02:03 - 01:02:04")
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
func tableSandboxRowModelStoreCarriesSubtitlePathsIntoRows() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let searchPath = "/tmp/CueSeeker/Search/episode-01.ass"

    store.updateSearchRows(
        [
            searchResult(
                id: 1,
                path: searchPath,
                content: "line",
                cueLines: ["line"]
            ),
        ],
        tableName: "test-search"
    )

    #expect(store.snapshot.rows[0].subtitlePath == searchPath)

    store.hydrateShioriRows(
        [
            shioriSource(id: 2, content: "saved line", languages: [.japanese]),
        ],
        startIndex: 0,
        totalRowCount: 1,
        tableName: "shiori"
    )

    #expect(store.snapshot.rows[0].subtitlePath == "/tmp/CueSeeker/Series/episode-2.ass")
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
func tableSandboxRowModelStoreIgnoresVirtualSearchTotalForRenderedRows() {
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

    #expect(store.snapshot.totalRowCount == 100)
    #expect(store.snapshot.loadedReferenceCount == 100)
    #expect(store.snapshot.rows.count == 100)
    #expect(store.snapshot.row(at: 0)?.cues == "loaded row 0")
    #expect(store.snapshot.row(at: 99)?.cues == "loaded row 99")
}

@MainActor
@Test
func tableSandboxRowModelStoreRejectsSparseVisibleSearchRows() {
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

    #expect(store.snapshot.totalRowCount == 100)
    #expect(store.snapshot.loadedReferenceCount == 100)
    #expect(store.snapshot.rows.count == 100)
    #expect(store.snapshot.row(at: 99)?.cues == "loaded row 99")
    #expect(store.snapshot.row(at: 100) == nil)
    #expect(store.snapshot.row(at: 1_000_000) == nil)
    #expect(store.snapshot.searchResult(entryID: 1_000_001) == nil)
    #expect(store.snapshot.update == .append(0..<100))
}

@MainActor
@Test
func tableSandboxRowModelStoreAppendsContiguousSearchRowsWithRenderableTotal() {
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

    #expect(store.snapshot.totalRowCount == 112)
    #expect(store.snapshot.row(at: 111)?.cues == "visible row")
}

@MainActor
@Test
func tableSandboxRowModelStorePrependsSearchRowsForCueContextWindow() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows(
        [
            searchResult(id: 3, path: path, content: "target cue", cueLines: ["target cue"]),
            searchResult(id: 4, path: path, content: "following cue", cueLines: ["following cue"]),
        ],
        totalRowCount: 6,
        tableName: "test-search"
    )
    let prependedCount = store.prependSearchRows(
        [
            searchResult(id: 1, path: path, content: "earlier cue one", cueLines: ["earlier cue one"]),
            searchResult(id: 2, path: path, content: "earlier cue two", cueLines: ["earlier cue two"]),
        ],
        tableName: "test-search"
    )

    #expect(prependedCount == 2)
    #expect(store.snapshot.totalRowCount == 4)
    #expect(store.snapshot.update == .reload)
    #expect(store.snapshot.rows.map(\.id) == [1, 2, 3, 4])
    #expect(store.snapshot.row(at: 0)?.cues == "earlier cue one")
    #expect(store.snapshot.row(at: 2)?.cues == "target cue")
    #expect(store.snapshot.searchResult(entryID: 1)?.content == "earlier cue one")
    #expect(store.snapshot.searchResult(entryID: 3) == nil)
}

@MainActor
@Test
func tableSandboxRowModelStoreAppendsSearchRowsInDisplayOrderForCueContextWindow() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/episode-01.ass"

    store.updateSearchRows(
        [
            searchResult(id: 3, path: path, content: "target cue", cueLines: ["target cue"]),
        ],
        totalRowCount: 6,
        tableName: "test-search"
    )
    let appendedCount = store.appendSearchRows(
        [
            searchResult(id: 4, path: path, content: "following cue", cueLines: ["following cue"]),
            searchResult(id: 5, path: path, content: "next cue", cueLines: ["next cue"]),
        ],
        tableName: "test-search"
    )

    #expect(appendedCount == 2)
    #expect(store.snapshot.totalRowCount == 3)
    #expect(store.snapshot.update == .append(1..<3))
    #expect(store.snapshot.rows.map(\.id) == [3, 4, 5])
    #expect(store.snapshot.searchResult(entryID: 4)?.content == "following cue")
}

@MainActor
@Test
func tableSandboxRowModelStoreCachesOnlyContiguouslyHydratedSearchResultsForActions() {
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
            searchResult(id: 2, path: path, content: "hydrated row", cueLines: ["hydrated row"]),
        ],
        startIndex: 1,
        totalRowCount: 500,
        tableName: "test-search"
    )

    #expect(store.snapshot.searchResult(entryID: 1) == nil)
    #expect(store.snapshot.searchResult(entryID: 2)?.content == "hydrated row")
}

@MainActor
@Test
func tableSandboxRowModelStoreRejectsSparseShioriRowsForVirtualTableActions() {
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

    #expect(store.snapshot.totalRowCount == 0)
    #expect(store.snapshot.loadedReferenceCount == 0)
    #expect(store.snapshot.rows.isEmpty)
    #expect(store.snapshot.row(at: 299) == nil)
    #expect(store.snapshot.row(at: 300) == nil)
    #expect(store.snapshot.shiori(entryID: 301) == nil)
    #expect(store.snapshot.update == .none)
}

@MainActor
@Test
func tableSandboxRowModelStoreAppendsContiguousShioriRows() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }

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
            shioriSource(id: 4, content: "visible one", languages: [.japanese]),
            shioriSource(id: 5, content: "visible two", languages: [.japanese]),
        ],
        startIndex: 3,
        totalRowCount: 100,
        tableName: "shiori"
    )

    #expect(store.snapshot.totalRowCount == 5)
    #expect(store.snapshot.loadedReferenceCount == 5)
    #expect(store.snapshot.row(at: 0)?.cues == "prefix one")
    #expect(store.snapshot.row(at: 1)?.cues == "prefix two")
    #expect(store.snapshot.row(at: 2)?.cues == "prefix three")
    #expect(store.snapshot.row(at: 3)?.cues == "visible one")
    #expect(store.snapshot.row(at: 4)?.cues == "visible two")
    #expect(store.snapshot.shiori(entryID: 1)?.content == "prefix one")
    #expect(store.snapshot.shiori(entryID: 4)?.content == "visible one")
}

@MainActor
@Test
func tableSandboxRowModelStoreRejectsNonContiguousSearchRows() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
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

    #expect(store.snapshot.totalRowCount == 4)
    #expect(store.snapshot.loadedReferenceCount == 4)
    #expect(store.snapshot.row(at: 0)?.cues == "prefix row 0")
    #expect(store.snapshot.row(at: 1)?.cues == "prefix row 1")
    #expect(store.snapshot.row(at: 2)?.cues == "prefix row 2")
    #expect(store.snapshot.row(at: 3)?.cues == "prefix row 3")
    #expect(store.snapshot.row(at: 500) == nil)
    #expect(store.snapshot.searchResult(entryID: 501) == nil)
}

@MainActor
@Test
func tableSandboxRowModelStorePreservesCompletePrimaryCueText() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/effects.ass"
    let longLine = String(repeating: "x", count: 520)
    let sourceLines = [
        "line 0",
        "",
        longLine,
        "line 3",
        "line 4",
        "line 5",
        "line 6",
        "line 7",
        "line 8",
    ]
    let content = sourceLines.joined(separator: "\n")

    store.updateSearchRows(
        [
            searchResult(
                id: 1,
                path: path,
                content: content,
                cueLines: [content],
                cueGroupLines: [content]
            )
        ],
        tableName: "test-search"
    )

    let row = store.snapshot.row(at: 0)
    #expect(row?.primaryCueText == content)
    #expect(row?.cues == content)
    #expect(row?.cues.components(separatedBy: "\n") == sourceLines)
    #expect(row?.cueGroupTexts == [content])
    #expect(row?.additionalCueTexts.isEmpty == true)
    #expect(row?.cueGroupCopyText == content)
}

@MainActor
@Test
func tableSandboxRowModelStoreSeparatesDuplicateSiblingByPrimaryIndex() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let path = "/tmp/CueSeeker/Series/duplicates.ass"
    let repeatedText = "same subtitle"
    let trailingText = "tail line one\n\ntail line three"

    store.updateSearchRows(
        [
            searchResult(
                id: 91,
                cueGroupID: 12,
                path: path,
                content: repeatedText,
                cueLines: [repeatedText],
                primaryGroupIndex: 1,
                cueGroupLines: [repeatedText, repeatedText, trailingText]
            )
        ],
        tableName: "test-search"
    )

    let row = store.snapshot.row(at: 0)
    #expect(row?.id == 91)
    #expect(row?.primaryCueID == 91)
    #expect(row?.primaryCueText == repeatedText)
    #expect(row?.primaryGroupIndex == 1)
    #expect(row?.additionalCueTexts == [repeatedText, trailingText])
    #expect(row?.cueGroupCopyText == "\(repeatedText)\n\(repeatedText)\n\(trailingText)")
}

@MainActor
@Test
func tableSandboxRowModelStoreTrustsResolvedPrimaryIndexWhenSnapshotTextDiffers() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let primarySnapshot = "persisted primary snapshot"

    store.updateSearchRows(
        [
            searchResult(
                id: 92,
                cueGroupID: 13,
                path: "/tmp/CueSeeker/Series/changed.ass",
                content: primarySnapshot,
                cueLines: [primarySnapshot],
                primaryGroupIndex: 1,
                cueGroupLines: ["upper sibling", "currently indexed primary", "lower sibling"]
            )
        ],
        tableName: "test-search"
    )

    let row = store.snapshot.row(at: 0)
    #expect(row?.primaryCueText == primarySnapshot)
    #expect(row?.primaryGroupIndex == 1)
    #expect(row?.cueGroupTexts == ["upper sibling", "currently indexed primary", "lower sibling"])
    #expect(row?.additionalCueTexts == ["upper sibling", "lower sibling"])
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
func tableSandboxRowModelStoreMapsShioriTagsToNeutralTags() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }

    store.hydrateShioriRows(
        [
            shioriSource(
                id: 1,
                content: "saved row",
                languages: [.japanese],
                shioriTags: [
                    ShioriTag(id: 7, name: "Review", createdAt: "2026-07-08T00:00:00Z"),
                    ShioriTag(id: 8, name: "Grammar", createdAt: "2026-07-08T00:01:00Z"),
                ]
            ),
        ],
        startIndex: 0,
        totalRowCount: 1,
        tableName: "shiori"
    )

    let row = store.snapshot.row(at: 0)
    #expect(row?.tags.map(\.key) == ["jp"])
    #expect(row?.shioriTags.map(\.key) == ["7", "8"])
    #expect(row?.shioriTags.map(\.label) == ["Review", "Grammar"])
    #expect(row?.shioriTags.map(\.colorID) == [.gray, .gray])
}

@MainActor
@Test
func tableSandboxRowModelStoreUsesShioriCuePresentationAndKeepsShioriRowIdentity() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let repeatedText = "same subtitle"
    let cuePresentation = ShioriCuePresentation(
        cueID: 901,
        cueGroupID: 77,
        primaryGroupIndex: 1,
        cueGroupTexts: [repeatedText, repeatedText, "lower sibling"],
        languages: [.japanese],
    )

    store.hydrateShioriRows(
        [
            shioriSource(
                id: 41,
                content: repeatedText,
                languages: [.unknown],
                cuePresentation: cuePresentation
            ),
        ],
        startIndex: 0,
        totalRowCount: 1,
        tableName: "shiori"
    )

    let row = store.snapshot.row(at: 0)
    #expect(row?.id == 41)
    #expect(row?.primaryCueID == 901)
    #expect(row?.primaryCueIdentity == .cue(901))
    #expect(row?.primaryCueText == repeatedText)
    #expect(row?.cueGroupTexts == cuePresentation.cueGroupTexts)
    #expect(row?.primaryGroupIndex == 1)
    #expect(row?.additionalCueTexts == [repeatedText, "lower sibling"])
    #expect(row?.tags.map(\.key) == ["jp"])
}

@MainActor
@Test
func tableSandboxRowModelStoreFallsBackToExactOrphanShioriSnapshot() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let content = "orphan line one\n\norphan line three"
    let cuePresentation = ShioriCuePresentation(
        cueID: nil,
        cueGroupID: nil,
        primaryGroupIndex: nil,
        cueGroupTexts: [content],
        languages: [.unknown],
    )

    store.hydrateShioriRows(
        [
            shioriSource(
                id: 42,
                content: content,
                languages: [.unknown],
                cuePresentation: cuePresentation
            ),
        ],
        startIndex: 0,
        totalRowCount: 1,
        tableName: "shiori"
    )

    let row = store.snapshot.row(at: 0)
    #expect(row?.id == 42)
    #expect(row?.primaryCueID == nil)
    #expect(row?.primaryCueIdentity == .rowFallback(42))
    #expect(row?.primaryCueText == content)
    #expect(row?.cueGroupTexts == [content])
    #expect(row?.primaryGroupIndex == nil)
    #expect(row?.additionalCueTexts.isEmpty == true)
    #expect(row?.cueGroupCopyText == content)
}

@Test
func shioriTagComposerInputRulesFilterInvalidCharactersAndCapLength() {
    #expect(
        ShioriTagComposerInputRules.normalizedInput("123456789012345678901") ==
            "12345678901234567890"
    )
    #expect(ShioriTagComposerInputRules.normalizedInput("hello\n\t\u{200B}world") == "helloworld")
    #expect(ShioriTagComposerInputRules.isValidTrimmedTagText("Review"))
    #expect(!ShioriTagComposerInputRules.isValidTrimmedTagText(""))
    #expect(!ShioriTagComposerInputRules.isValidTrimmedTagText("123456789012345678901"))
    #expect(!ShioriTagComposerInputRules.isValidTrimmedTagText("hello\nworld"))
}

@MainActor
@Test
func tableSandboxRowModelStorePatchesShioriTagCells() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let cuePresentation = ShioriCuePresentation(
        cueID: 101,
        cueGroupID: 11,
        primaryGroupIndex: 1,
        cueGroupTexts: ["upper sibling", "saved row"],
        languages: [.japanese],
    )

    store.hydrateShioriRows(
        [
            shioriSource(
                id: 1,
                content: "saved row",
                languages: [.japanese],
                cuePresentation: cuePresentation
            ),
        ],
        startIndex: 0,
        totalRowCount: 1,
        tableName: "shiori"
    )

    let rowBeforePatch = store.snapshot.row(at: 0)
    let patched = store.updateShioriTags(
        [
            ShioriTag(id: 7, name: "Review", createdAt: "2026-07-08T00:00:00Z"),
        ],
        forShioriID: 1,
        tableName: "shiori"
    )

    #expect(patched)
    let rowAfterPatch = store.snapshot.row(at: 0)
    #expect(rowAfterPatch?.shioriTags.map(\.label) == ["Review"])
    #expect(rowAfterPatch?.id == rowBeforePatch?.id)
    #expect(rowAfterPatch?.primaryCueText == rowBeforePatch?.primaryCueText)
    #expect(rowAfterPatch?.cueGroupTexts == rowBeforePatch?.cueGroupTexts)
    #expect(rowAfterPatch?.primaryGroupIndex == rowBeforePatch?.primaryGroupIndex)
    #expect(rowAfterPatch?.additionalCueTexts == rowBeforePatch?.additionalCueTexts)
    #expect(rowAfterPatch?.cueGroupCopyText == rowBeforePatch?.cueGroupCopyText)
    #expect(store.snapshot.update == .cells([TableSandboxCellInvalidation(row: 0, columnID: "tags")]))
}

@MainActor
@Test
func tableSandboxRowModelStorePatchesOnlyMatchingShioriTagCell() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }

    store.hydrateShioriRows(
        [
            shioriSource(id: 1, content: "first saved row", languages: [.japanese]),
            shioriSource(id: 2, content: "second saved row", languages: [.japanese]),
        ],
        startIndex: 0,
        totalRowCount: 2,
        tableName: "shiori"
    )

    let patched = store.updateShioriTags(
        [
            ShioriTag(id: 7, name: "Review", createdAt: "2026-07-08T00:00:00Z"),
        ],
        forShioriID: 1,
        tableName: "shiori"
    )

    #expect(patched)
    #expect(store.snapshot.row(at: 0)?.shioriTags.map(\.label) == ["Review"])
    #expect(store.snapshot.row(at: 1)?.shioriTags.isEmpty == true)
    #expect(store.snapshot.update == .cells([TableSandboxCellInvalidation(row: 0, columnID: "tags")]))
}

@MainActor
@Test
func tableSandboxRowModelStoreRemovesDeletedShioriTagFromAffectedVisibleRows() {
    let store = TableSandboxRowModelStore { _ in "Resolved" }
    let sharedTag = ShioriTag(id: 7, name: "Review", createdAt: "2026-07-08T00:00:00Z")

    store.hydrateShioriRows(
        [
            shioriSource(id: 1, content: "first", languages: [.japanese], shioriTags: [sharedTag]),
            shioriSource(id: 2, content: "second", languages: [.japanese], shioriTags: [sharedTag]),
            shioriSource(id: 3, content: "third", languages: [.japanese]),
        ],
        startIndex: 0,
        totalRowCount: 3,
        tableName: "shiori"
    )

    let patchedIDs = store.removeShioriTagFromVisibleRows(
        tagID: 7,
        affectedShioriIDs: [1, 2, 99],
        tableName: "shiori"
    )

    #expect(patchedIDs == [1, 2])
    #expect(store.snapshot.row(at: 0)?.shioriTags.isEmpty == true)
    #expect(store.snapshot.row(at: 1)?.shioriTags.isEmpty == true)
    #expect(store.snapshot.update == .cells([
        TableSandboxCellInvalidation(row: 0, columnID: "tags"),
        TableSandboxCellInvalidation(row: 1, columnID: "tags"),
    ]))
}

@MainActor
@Test
func tableSandboxRowModelStoreProjectsResidentShioriRowsWithoutMaterializingCollection() {
    let store = TableSandboxRowModelStore { _ in "unused" }
    let relations = (1...10_000).map { value in
        ShioriRelation(
            id: Int64(value),
            listID: ShioriListIdentity.defaultListID,
            cueID: Int64(value),
            createdAt: "2026-07-21T12:00:00Z"
        )
    }
    let selectedCue = residentCueContent(cueID: 10_000, content: "Last resident Cue")
    let selectedTag = ShioriTag(
        id: 7,
        name: "Review",
        createdAt: "2026-07-21T12:00:00Z"
    )

    store.updateResidentShioriRelations(
        relations,
        tagsByShioriID: [10_000: [selectedTag]],
        cueContentProvider: { cueID in
            cueID == selectedCue.cueID ? selectedCue : residentCueContent(
                cueID: cueID,
                content: "Cue \(cueID)"
            )
        },
        tableName: "shiori"
    )

    #expect(store.snapshot.totalRowCount == 10_000)
    #expect(store.snapshot.loadedReferenceCount == 10_000)
    #expect(store.snapshot.materializedRowCount == 0)
    #expect(store.snapshot.row(at: 9_999)?.primaryCueText == "Last resident Cue")
    #expect(store.snapshot.row(at: 9_999)?.shioriTags.map(\.label) == ["Review"])
    #expect(store.snapshot.shiori(entryID: 10_000)?.content == "Last resident Cue")
    #expect(store.snapshot.rowIndex(entryID: 10_000) == 9_999)
}

@MainActor
@Test
func tableSandboxRowModelStoreProjectsShioriLifecycleStatesAndExactSnapshot() {
    let store = TableSandboxRowModelStore { _ in "unused" }
    let unavailableRelation = ShioriRelation(
        id: 7,
        listID: ShioriListIdentity.defaultListID,
        cueID: 42,
        createdAt: "2026-07-21T12:00:00Z"
    )
    let changedRelation = ShioriRelation(
        id: 8,
        listID: ShioriListIdentity.defaultListID,
        cueID: 43,
        createdAt: "2026-07-21T12:01:00Z"
    )
    let unavailable = Shiori(
        id: unavailableRelation.id,
        subtitlePath: "/tmp/CueSeeker/Series/episode.ass",
        subtitleFormat: .ass,
        videoPath: "/tmp/CueSeeker/Series/episode.mkv",
        videoName: "Episode.mkv",
        displayTitle: "Series - 03",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "Primary\nmultiline",
        cueGroupContent: [
            "Primary\nmultiline",
            "Sibling",
        ].joined(separator: Shiori.cueGroupContentSeparator),
        isValid: false,
        unavailableReason: .cueMissing,
        createdAt: unavailableRelation.createdAt
    )
    let changed = Shiori(
        id: changedRelation.id,
        subtitlePath: "/tmp/CueSeeker/Series/episode.ass",
        subtitleFormat: .ass,
        videoPath: "/tmp/CueSeeker/Series/episode.mkv",
        videoName: "Episode",
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        content: "Current",
        isValid: true,
        contentChange: ShioriCueContentChange(
            previousContent: "Previous",
            currentContent: "Current"
        ),
        createdAt: changedRelation.createdAt
    )

    store.updateResidentShioriRelations(
        [unavailableRelation, changedRelation],
        tagsByShioriID: [:],
        resolvedShiorisByID: [
            unavailable.id: unavailable,
            changed.id: changed,
        ],
        cueContentProvider: { cueID in
            cueID == changedRelation.cueID
                ? residentCueContent(cueID: cueID, content: "Current")
                : nil
        },
        tableName: "shiori"
    )

    let unavailableRow = store.snapshot.row(at: 0)
    #expect(unavailableRow?.displayTitle == "Series - 03")
    #expect(unavailableRow?.primaryCueText == "Primary\nmultiline")
    #expect(unavailableRow?.cueGroupTexts == ["Primary\nmultiline", "Sibling"])
    #expect(unavailableRow?.cueState == .unavailable(.cueMissing))
    #expect(
        store.snapshot.row(at: 1)?.cueState
            == .contentChanged(previous: "Previous", current: "Current")
    )
}

@MainActor
@Test
func tableSandboxRowModelStoreProjectsSearchCueIDsWithoutMaterializingRows() {
    let cueStore = CueContentStore()
    let results = (1...10_000).map { value in
        SubtitleSearchResult(
            cueContent: residentCueContent(
                cueID: Int64(value),
                content: "Search Cue \(value)"
            ),
            searchRank: value - 1
        )
    }
    cueStore.install(results.map(\.cueContent))
    let store = TableSandboxRowModelStore { _ in "unused" }

    store.updateResidentSearchResults(
        results,
        cueContentProvider: { cueStore.content(for: $0) },
        tableName: "search"
    )

    #expect(store.snapshot.totalRowCount == 10_000)
    #expect(store.snapshot.loadedReferenceCount == 10_000)
    #expect(store.snapshot.materializedRowCount == 0)
    #expect(store.snapshot.row(at: 9_999)?.primaryCueText == "Search Cue 10000")
    #expect(store.snapshot.searchResult(entryID: 10_000)?.searchRank == 9_999)
    #expect(store.snapshot.rowIndex(entryID: 10_000) == 9_999)
}

@MainActor
@Test
func tableSandboxSearchProjectionReloadsWhenCanonicalCueContentChanges() {
    let cueStore = CueContentStore()
    let original = residentCueContent(cueID: 42, content: "Original Cue")
    let changed = residentCueContent(cueID: 42, content: "Changed Cue")
    cueStore.install([original])
    let store = TableSandboxRowModelStore { _ in "unused" }
    store.updateResidentSearchReferences(
        cueIDs: [original.cueID],
        ranksByCueID: [original.cueID: 0],
        cueContentProvider: { cueStore.content(for: $0) },
        cueContentRevision: cueStore.revision,
        sourceRevision: 1,
        tableName: "search"
    )
    let originalVersion = store.snapshot.version
    cueStore.install([changed])
    store.updateResidentSearchReferences(
        cueIDs: [original.cueID],
        ranksByCueID: [original.cueID: 0],
        cueContentProvider: { cueStore.content(for: $0) },
        cueContentRevision: cueStore.revision,
        sourceRevision: 1,
        tableName: "search"
    )

    #expect(store.snapshot.version == originalVersion + 1)
    #expect(store.snapshot.update == .reload)
    #expect(store.snapshot.row(at: 0)?.primaryCueText == "Changed Cue")
}

@MainActor
@Test
func tableSandboxShioriProjectionReloadsWhenCanonicalCueContentChanges() {
    let cueStore = CueContentStore()
    let original = residentCueContent(cueID: 42, content: "Original Shiori Cue")
    let changed = residentCueContent(cueID: 42, content: "Changed Shiori Cue")
    cueStore.install([original])
    let store = TableSandboxRowModelStore { _ in "unused" }
    let relations = [
        ShioriRelation(
            id: 7,
            listID: ShioriListIdentity.defaultListID,
            cueID: 42,
            createdAt: "2026-07-21T12:00:00Z"
        ),
    ]

    store.updateResidentShioriRelations(
        relations,
        tagsByShioriID: [:],
        cueContentProvider: { cueStore.content(for: $0) },
        cueContentRevision: cueStore.revision,
        tableName: "shiori"
    )
    let originalVersion = store.snapshot.version
    cueStore.install([changed])
    store.updateResidentShioriRelations(
        relations,
        tagsByShioriID: [:],
        cueContentProvider: { cueStore.content(for: $0) },
        cueContentRevision: cueStore.revision,
        tableName: "shiori"
    )

    #expect(store.snapshot.version == originalVersion + 1)
    #expect(store.snapshot.update == .reload)
    #expect(store.snapshot.row(at: 0)?.primaryCueText == "Changed Shiori Cue")
}

@MainActor
@Test
func shioriStoreExcludesUnavailableRowsOnlyFromPlaybackScope() {
    let store = ShioriStore()
    store.setActiveListID(ShioriListIdentity.defaultListID)
    let relations = [
        ShioriRelation(
            id: 1,
            listID: ShioriListIdentity.defaultListID,
            cueID: 101,
            createdAt: "2026-07-21T12:00:00Z"
        ),
        ShioriRelation(
            id: 2,
            listID: ShioriListIdentity.defaultListID,
            cueID: 102,
            createdAt: "2026-07-21T12:01:00Z"
        ),
    ]
    let available = shioriSource(
        id: 1,
        content: "Available",
        languages: [.japanese]
    ).shiori
    let unavailable = Shiori(
        id: 2,
        subtitlePath: "/tmp/CueSeeker/Series/missing.ass",
        subtitleFormat: .ass,
        videoPath: "/tmp/CueSeeker/Series/missing.mkv",
        videoName: "Missing",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "Unavailable",
        isValid: false,
        unavailableReason: .videoMissing,
        createdAt: relations[1].createdAt
    )

    store.installResidentSnapshot(
        ShioriResidentSnapshot(
            relations: relations,
            resolvedShioris: [available, unavailable],
            cueContents: [],
            tagsByShioriID: [:],
            facetSnapshot: CueFacetSnapshot(
                cueIDs: [101, 102],
                durationFacets: [.oneToUnderThreeSeconds, .oneToUnderThreeSeconds],
                characterFacets: [.oneToTen, .elevenToTwenty],
                languageFacets: [[.japanese], [.unknown]],
                watchStateFacets: [.watching, .unwatched]
            )
        ),
        dataRevision: 1
    )
    store.installTableResultShioriIDs([1, 2])

    #expect(store.tableResultRowCount == 2)
    #expect(store.tableResultShioriIDs == [1, 2])
    #expect(store.playbackTableResultShioriIDs == [1])
    #expect(store.residentFacetProjection(
        using: CueFacetFilter(languages: [.japanese])
    ).shioriIDs == [1])

    store.removeShioriFromCurrentProjection(id: 1)

    #expect(store.residentFacetSnapshot?.distribution.totalCount == 1)
    #expect(store.residentFacetProjection(using: CueFacetFilter()).shioriIDs == [2])
}

@MainActor
@Test
func shioriStoreKeepsTableStateAndRowsForViewRemounts() {
    let store = ShioriStore()
    store.tableSearchDraft = "tomori"
    store.tableVisibleColumnIDs = ["display", "cues"]
    store.tableFilterRules = [
        SchemaWorkbenchSearchDefaults.makeFilterRule(
            join: nil,
            fieldID: "cues",
            operatorID: .contains,
            value: "星"
        )
    ]
    store.tableRowStore.hydrateShioriRows(
        [
            shioriSource(id: 1, content: "cached shiori", languages: [.japanese]),
        ],
        startIndex: 0,
        totalRowCount: 1,
        tableName: "shiori"
    )
    store.tableResultRowCount = 37
    store.tableViewportAnchor = TableViewportAnchor(entryID: 1, rowIndex: 0)
    var selection = TableSandboxRowSelectionState()
    selection.toggleAll(rowCount: 1)
    store.tableSelectionState = selection
    store.tableSelectionEntryIDs = [1]
    store.markTableRowsLoaded(totalSavedRowCount: 1)

    #expect(store.tableSearchDraft == "tomori")
    #expect(store.tableVisibleColumnIDs == ["display", "cues"])
    #expect(store.tableFilterRules.count == 1)
    #expect(store.tableHasLoadedInitialPage)
    #expect(store.tableTotalSavedRowCount == 1)
    #expect(store.tableResultRowCount == 37)
    #expect(store.tableViewportAnchor == TableViewportAnchor(entryID: 1, rowIndex: 0))
    #expect(store.tableSelectionState.headerState(rowCount: 1) == .checked)
    #expect(store.tableSelectionEntryIDs == [1])
    #expect(store.tableRowStore.snapshot.row(at: 0)?.cues == "cached shiori")
}

@MainActor
@Test
func shioriStoreInvalidatesTableRowsWithoutResettingControls() {
    let store = ShioriStore()
    store.tableSearchDraft = "soyo"
    store.tableVisibleColumnIDs = ["dateAdded", "cues"]
    store.tableRowStore.hydrateShioriRows(
        [
            shioriSource(id: 1, content: "old shiori", languages: [.japanese]),
        ],
        startIndex: 0,
        totalRowCount: 1,
        tableName: "shiori"
    )
    store.tableResultRowCount = 12
    store.markTableRowsLoaded(totalSavedRowCount: 1)

    store.invalidateTableRows()

    #expect(store.tableSearchDraft == "soyo")
    #expect(store.tableVisibleColumnIDs == ["dateAdded", "cues"])
    #expect(!store.tableHasLoadedInitialPage)
    #expect(store.tableTotalSavedRowCount == 0)
    #expect(store.tableResultRowCount == 0)
    #expect(store.tableRowStore.snapshot.totalRowCount == 0)
    #expect(store.tableRowStore.snapshot.row(at: 0) == nil)
}

private func searchResult(
    id: Int64,
    cueGroupID: Int64? = nil,
    path: String,
    displayTitle: String = "",
    content: String,
    cueLines: [String],
    primaryGroupIndex: Int = 0,
    cueGroupLines: [String]? = nil,
    languages: Set<SubtitleLanguageCode> = [.unknown],
    timeRange: String = "",
    startMilliseconds: Int = 1_000,
    endMilliseconds: Int = 2_000
) -> SubtitleSearchResult {
    SubtitleSearchResult(
        entryID: id,
        cueGroupID: cueGroupID,
        primaryGroupIndex: primaryGroupIndex,
        subtitlePath: path,
        subtitleFormat: .ass,
        videoPath: path.replacingOccurrences(of: ".ass", with: ".mkv"),
        videoName: "episode.mkv",
        displayTitle: displayTitle,
        timeRange: timeRange,
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        content: content,
        cueLines: cueLines,
        cueGroupLines: cueGroupLines ?? [content],
        languages: languages
    )
}

private func shioriSource(
    id: Int64,
    content: String,
    languages: Set<SubtitleLanguageCode>,
    shioriTags: [ShioriTag] = [],
    cuePresentation: ShioriCuePresentation? = nil,
    startMilliseconds: Int = 1_000,
    endMilliseconds: Int = 2_000
) -> TableSandboxShioriRowSource {
    TableSandboxShioriRowSource(
        shiori: Shiori(
            id: id,
            subtitlePath: "/tmp/CueSeeker/Series/episode-\(id).ass",
            subtitleFormat: .ass,
            videoPath: "/tmp/CueSeeker/Series/episode-\(id).mkv",
            videoName: "episode-\(id).mkv",
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            content: content,
            isValid: true,
            createdAt: "2026-06-23T12:00:00Z"
        ),
        displayTitle: "Episode \(id)",
        dateAddedText: "26-06-23 12:00",
        languages: languages,
        shioriTags: shioriTags,
        cuePresentation: cuePresentation
    )
}

private func residentCueContent(cueID: Int64, content: String) -> CueContent {
    CueContent(
        cueID: cueID,
        cueGroupID: cueID,
        cueEventIndex: Int(cueID),
        cueDisplayOrder: Int(cueID),
        primaryGroupIndex: 0,
        subtitlePath: "/tmp/CueSeeker/Series/episode-\(cueID).ass",
        subtitleFormat: .ass,
        videoPath: "/tmp/CueSeeker/Series/episode-\(cueID).mkv",
        videoName: "episode-\(cueID).mkv",
        displayTitle: "Episode \(cueID)",
        timeRange: "00:01 - 00:02",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: content,
        cueLines: [content],
        cueGroupLines: [content],
        languages: [.japanese],
    )
}
