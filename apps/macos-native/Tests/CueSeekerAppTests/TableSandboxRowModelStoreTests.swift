import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@Test
func tableSandboxExcerptDateAddedDisplayConvertsUTCToLocalTime() throws {
    let shanghaiTimeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))

    #expect(
        tableSandboxExcerptDateAddedDisplayText(
            for: "2026-07-23T18:20:49Z",
            timeZone: shanghaiTimeZone
        ) == "26-07-24 02:20"
    )
}

@MainActor
@Test
func tableSandboxRowModelStoreProjectsResidentExcerptRowsWithoutMaterializingCollection() {
    let store = TableSandboxRowModelStore()
    let relations = (1...10_000).map { value in
        ExcerptRelation(
            id: Int64(value),
            listID: ExcerptListIdentity.defaultListID,
            cueID: Int64(value),
            createdAt: "2026-07-21T12:00:00Z"
        )
    }
    let selectedCue = residentCueContent(cueID: 10_000, content: "Last resident Cue")
    store.updateResidentExcerptRelations(
        relations,
        cueContentProvider: { cueID in
            cueID == selectedCue.cueID ? selectedCue : residentCueContent(
                cueID: cueID,
                content: "Cue \(cueID)"
            )
        },
        tableName: "excerpt"
    )

    #expect(store.snapshot.totalRowCount == 10_000)
    #expect(store.snapshot.loadedReferenceCount == 10_000)
    #expect(store.snapshot.materializedRowCount == 0)
    #expect(store.snapshot.row(at: 9_999)?.primaryCueText == "Last resident Cue")
    #expect(store.snapshot.excerpt(entryID: 10_000)?.content == "Last resident Cue")
    #expect(store.snapshot.rowIndex(entryID: 10_000) == 9_999)
}

@MainActor
@Test
func tableSandboxRowModelStoreProjectsExcerptLifecycleStatesAndExactSnapshot() {
    let store = TableSandboxRowModelStore()
    let unavailableRelation = ExcerptRelation(
        id: 7,
        listID: ExcerptListIdentity.defaultListID,
        cueID: 42,
        createdAt: "2026-07-21T12:00:00Z"
    )
    let changedRelation = ExcerptRelation(
        id: 8,
        listID: ExcerptListIdentity.defaultListID,
        cueID: 43,
        createdAt: "2026-07-21T12:01:00Z"
    )
    let unavailable = Excerpt(
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
        ].joined(separator: Excerpt.cueGroupContentSeparator),
        isValid: false,
        unavailableReason: .cueMissing,
        createdAt: unavailableRelation.createdAt
    )
    let changed = Excerpt(
        id: changedRelation.id,
        subtitlePath: "/tmp/CueSeeker/Series/episode.ass",
        subtitleFormat: .ass,
        videoPath: "/tmp/CueSeeker/Series/episode.mkv",
        videoName: "Episode",
        startMilliseconds: 3_000,
        endMilliseconds: 4_000,
        content: "Current",
        isValid: true,
        contentChange: ExcerptCueContentChange(
            previousContent: "Previous",
            currentContent: "Current"
        ),
        createdAt: changedRelation.createdAt
    )

    store.updateResidentExcerptRelations(
        [unavailableRelation, changedRelation],
        resolvedExcerptsByID: [
            unavailable.id: unavailable,
            changed.id: changed,
        ],
        cueContentProvider: { cueID in
            cueID == changedRelation.cueID
                ? residentCueContent(cueID: cueID, content: "Current")
                : nil
        },
        tableName: "excerpt"
    )

    let unavailableRow = store.snapshot.row(at: 0)
    #expect(unavailableRow?.displayTitle == "Series - 03")
    #expect(unavailableRow?.primaryCueText == "Primary\nmultiline")
    #expect(unavailableRow?.cueGroupTexts == ["Primary\nmultiline", "Sibling"])
    #expect(unavailableRow?.cueState == .unavailable(.cueMissing))
    // A changed Cue still plays, so only the unavailable row is unselectable.
    #expect(store.snapshot.unavailableRows == [0])
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
    let store = TableSandboxRowModelStore()

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
    let store = TableSandboxRowModelStore()
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
func tableSandboxExcerptProjectionReloadsWhenCanonicalCueContentChanges() {
    let cueStore = CueContentStore()
    let original = residentCueContent(cueID: 42, content: "Original Excerpt Cue")
    let changed = residentCueContent(cueID: 42, content: "Changed Excerpt Cue")
    cueStore.install([original])
    let store = TableSandboxRowModelStore()
    let relations = [
        ExcerptRelation(
            id: 7,
            listID: ExcerptListIdentity.defaultListID,
            cueID: 42,
            createdAt: "2026-07-21T12:00:00Z"
        ),
    ]

    store.updateResidentExcerptRelations(
        relations,
        cueContentProvider: { cueStore.content(for: $0) },
        cueContentRevision: cueStore.revision,
        tableName: "excerpt"
    )
    let originalVersion = store.snapshot.version
    cueStore.install([changed])
    store.updateResidentExcerptRelations(
        relations,
        cueContentProvider: { cueStore.content(for: $0) },
        cueContentRevision: cueStore.revision,
        tableName: "excerpt"
    )

    #expect(store.snapshot.version == originalVersion + 1)
    #expect(store.snapshot.update == .reload)
    #expect(store.snapshot.row(at: 0)?.primaryCueText == "Changed Excerpt Cue")
}

@MainActor
@Test
func excerptStoreExcludesUnavailableRowsOnlyFromPlaybackScope() {
    let store = ExcerptStore()
    store.setActiveListID(ExcerptListIdentity.defaultListID)
    let relations = [
        ExcerptRelation(
            id: 1,
            listID: ExcerptListIdentity.defaultListID,
            cueID: 101,
            createdAt: "2026-07-21T12:00:00Z"
        ),
        ExcerptRelation(
            id: 2,
            listID: ExcerptListIdentity.defaultListID,
            cueID: 102,
            createdAt: "2026-07-21T12:01:00Z"
        ),
    ]
    let available = Excerpt(
        id: 1,
        subtitlePath: "/tmp/CueSeeker/Series/episode-1.ass",
        subtitleFormat: .ass,
        videoPath: "/tmp/CueSeeker/Series/episode-1.mkv",
        videoName: "episode-1.mkv",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: "Available",
        isValid: true,
        createdAt: "2026-06-23T12:00:00Z"
    )
    let unavailable = Excerpt(
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
        ExcerptResidentSnapshot(
            relations: relations,
            resolvedExcerpts: [available, unavailable],
            cueContents: [],
            facetSnapshot: CueFacetSnapshot(
                cueIDs: [101, 102],
                durationFacets: [.oneToUnderThreeSeconds, .oneToUnderThreeSeconds],
                characterFacets: [.oneToTen, .elevenToTwenty],
                languageFacets: [[.japanese], [.unknown]],
                watchStateFacets: [.watching, .unwatched],
                folderFacets: Array(repeating: "/Media", count: ([101, 102]).count)
            )
        ),
        dataRevision: 1
    )
    store.installTableResultExcerptIDs([1, 2])

    #expect(store.tableResultRowCount == 2)
    #expect(store.tableResultExcerptIDs == [1, 2])
    #expect(store.playbackTableResultExcerptIDs == [1])
    #expect(store.residentFacetProjection(
        using: CueFacetFilter(languages: [.japanese])
    ).excerptIDs == [1])

    store.removeExcerptFromCurrentProjection(id: 1)

    #expect(store.residentFacetSnapshot?.distribution.totalCount == 1)
    #expect(store.residentFacetProjection(using: CueFacetFilter()).excerptIDs == [2])
}

@MainActor
@Test
func excerptStoreKeepsTableStateAndRowsForViewRemounts() {
    let store = ExcerptStore()
    store.tableSearchDraft = "tomori"
    let relation = ExcerptRelation(
        id: 1,
        listID: ExcerptListIdentity.defaultListID,
        cueID: 1,
        createdAt: "2026-06-23T12:00:00Z"
    )
    let cue = residentCueContent(cueID: 1, content: "cached excerpt")
    store.tableRowStore.updateResidentExcerptRelations(
        [relation],
        cueContentProvider: { $0 == 1 ? cue : nil },
        tableName: "excerpt"
    )
    store.tableResultRowCount = 37
    store.tableViewportAnchor = TableViewportAnchor(entryID: 1, rowIndex: 0)
    var selection = TableSandboxRowSelectionState()
    selection.toggleAll(rowCount: 1)
    store.tableSelectionState = selection
    store.tableSelectionEntryIDs = [1]
    store.markTableRowsLoaded(totalSavedRowCount: 1)

    #expect(store.tableSearchDraft == "tomori")
    #expect(store.tableHasLoadedInitialPage)
    #expect(store.tableTotalSavedRowCount == 1)
    #expect(store.tableResultRowCount == 37)
    #expect(store.tableViewportAnchor == TableViewportAnchor(entryID: 1, rowIndex: 0))
    #expect(store.tableSelectionState.headerState(rowCount: 1) == .checked)
    #expect(store.tableSelectionEntryIDs == [1])
    #expect(store.tableRowStore.snapshot.row(at: 0)?.cues == "cached excerpt")
}

@MainActor
@Test
func excerptStoreInvalidatesTableRowsWithoutResettingControls() {
    let store = ExcerptStore()
    store.tableSearchDraft = "soyo"
    let relation = ExcerptRelation(
        id: 1,
        listID: ExcerptListIdentity.defaultListID,
        cueID: 1,
        createdAt: "2026-06-23T12:00:00Z"
    )
    let cue = residentCueContent(cueID: 1, content: "old excerpt")
    store.tableRowStore.updateResidentExcerptRelations(
        [relation],
        cueContentProvider: { $0 == 1 ? cue : nil },
        tableName: "excerpt"
    )
    store.tableResultRowCount = 12
    store.markTableRowsLoaded(totalSavedRowCount: 1)

    store.invalidateTableRows()

    #expect(store.tableSearchDraft == "soyo")
    #expect(!store.tableHasLoadedInitialPage)
    #expect(store.tableTotalSavedRowCount == 0)
    #expect(store.tableResultRowCount == 0)
    #expect(store.tableRowStore.snapshot.totalRowCount == 0)
    #expect(store.tableRowStore.snapshot.row(at: 0) == nil)
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
