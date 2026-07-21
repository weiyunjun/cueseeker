import Testing
import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func cueContentStoreKeepsOneCurrentValuePerCueID() {
    let store = CueContentStore()
    let original = cueContent(cueID: 7, content: "Original")
    let updated = cueContent(cueID: 7, content: "Updated")

    #expect(store.install([original]))
    #expect(store.count == 1)
    #expect(store.content(for: 7) == original)
    let firstRevision = store.revision

    #expect(!store.install([original]))
    #expect(store.revision == firstRevision)
    #expect(store.install([updated]))
    #expect(store.count == 1)
    #expect(store.content(for: 7)?.content == "Updated")
    #expect(store.revision == firstRevision + 1)
}

@MainActor
@Test
func cueContentStoreResolvesOrderedCueIDCollectionsWithoutCopiesOfOwnership() {
    let store = CueContentStore()
    let first = cueContent(cueID: 1, content: "First")
    let second = cueContent(cueID: 2, content: "Second")
    store.install([first, second])

    #expect(store.contents(for: [2, 1])?.map(\.cueID) == [2, 1])
    #expect(store.contents(for: [1, 3]) == nil)
    #expect(store.remove(cueIDs: [1]))
    #expect(store.content(for: 1) == nil)
    #expect(store.content(for: 2) == second)
}

@MainActor
@Test
func searchStoreKeepsOnlyOrderAndResolvesCurrentCanonicalCueContent() {
    let cueStore = CueContentStore()
    let searchStore = SearchStore(cueContentStore: cueStore)
    let original = cueContent(cueID: 7, content: "Original")
    let updated = cueContent(cueID: 7, content: "Updated")

    searchStore.replaceLoadedSearchResults([
        SubtitleSearchResult(cueContent: original, searchRank: 12),
    ])
    cueStore.install([updated])

    #expect(searchStore.searchResultCueIDs == [7])
    #expect(searchStore.searchResults.map(\.content) == ["Updated"])
    #expect(searchStore.searchResults.map(\.searchRank) == [12])
}

@MainActor
@Test
func canonicalCueChangeAutomaticallyReloadsResidentSearchTableProjection() {
    let cueStore = CueContentStore()
    let searchStore = SearchStore(cueContentStore: cueStore)
    let original = cueContent(cueID: 7, content: "Original")
    let updated = cueContent(cueID: 7, content: "Updated")
    searchStore.replaceLoadedSearchResults([
        SubtitleSearchResult(cueContent: original, searchRank: 12),
    ])
    searchStore.activateResidentSearchTableProjection()
    let originalSnapshotVersion = searchStore.tableRowStore.snapshot.version
    let originalProjectionRevision = searchStore.tableProjectionRevision

    cueStore.install([updated])

    #expect(searchStore.tableProjectionRevision == originalProjectionRevision)
    #expect(searchStore.tableRowStore.snapshot.version == originalSnapshotVersion + 1)
    #expect(searchStore.tableRowStore.snapshot.update == .reload)
    #expect(searchStore.tableRowStore.snapshot.row(at: 0)?.primaryCueText == "Updated")
}

@MainActor
@Test
func unrelatedCanonicalCueChangeDoesNotReloadCoveredResidentSearch() {
    let cueStore = CueContentStore()
    let searchStore = SearchStore(cueContentStore: cueStore)
    let resident = cueContent(cueID: 7, content: "Resident")
    searchStore.replaceLoadedSearchResults([
        SubtitleSearchResult(cueContent: resident, searchRank: 12),
    ])
    searchStore.activateResidentSearchTableProjection()
    let originalSnapshotVersion = searchStore.tableRowStore.snapshot.version
    let originalProjectionRevision = searchStore.tableProjectionRevision

    searchStore.setTableProjectionResponseActive(false)
    cueStore.install([cueContent(cueID: 99, content: "Unrelated")])
    searchStore.setTableProjectionResponseActive(true)

    #expect(searchStore.tableProjectionRevision == originalProjectionRevision)
    #expect(searchStore.tableRowStore.snapshot.version == originalSnapshotVersion)
    #expect(searchStore.tableRowStore.snapshot.row(at: 0)?.primaryCueText == "Resident")
}

@MainActor
@Test
func coveredResidentSearchCoalescesRelevantAndUnrelatedCueChangesIntoOneReload() {
    let cueStore = CueContentStore()
    let searchStore = SearchStore(cueContentStore: cueStore)
    let original = cueContent(cueID: 7, content: "Original")
    searchStore.replaceLoadedSearchResults([
        SubtitleSearchResult(cueContent: original, searchRank: 12),
    ])
    searchStore.activateResidentSearchTableProjection()
    let originalSnapshotVersion = searchStore.tableRowStore.snapshot.version

    searchStore.setTableProjectionResponseActive(false)
    cueStore.install([cueContent(cueID: 99, content: "Unrelated")])
    cueStore.install([cueContent(cueID: 7, content: "Updated")])
    searchStore.setTableProjectionResponseActive(true)

    #expect(searchStore.tableRowStore.snapshot.version == originalSnapshotVersion + 1)
    #expect(searchStore.tableRowStore.snapshot.update == .reload)
    #expect(searchStore.tableRowStore.snapshot.row(at: 0)?.primaryCueText == "Updated")
}

@MainActor
@Test
func canonicalCueChangeAutomaticallyReloadsResidentShioriTableProjection() {
    let cueStore = CueContentStore()
    let shioriStore = ShioriStore(cueContentStore: cueStore)
    let original = cueContent(cueID: 7, content: "Original Shiori")
    let updated = cueContent(cueID: 7, content: "Updated Shiori")
    let relation = ShioriRelation(
        id: 70,
        listID: ShioriListIdentity.defaultListID,
        cueID: 7,
        createdAt: "2026-07-22T00:00:00Z"
    )
    cueStore.install([original])
    shioriStore.tableRowStore.updateResidentShioriRelations(
        [relation],
        tagsByShioriID: [:],
        cueContentProvider: { cueStore.content(for: $0) },
        cueContentRevision: cueStore.revision,
        tableName: "shiori"
    )
    let originalSnapshotVersion = shioriStore.tableRowStore.snapshot.version

    cueStore.install([updated])

    #expect(shioriStore.tableRowStore.snapshot.version == originalSnapshotVersion + 1)
    #expect(shioriStore.tableRowStore.snapshot.update == .reload)
    #expect(shioriStore.tableRowStore.snapshot.row(at: 0)?.primaryCueText == "Updated Shiori")
}

@MainActor
@Test
func unrelatedCanonicalCueChangeDoesNotReloadCoveredResidentShiori() {
    let cueStore = CueContentStore()
    let shioriStore = ShioriStore(cueContentStore: cueStore)
    let resident = cueContent(cueID: 7, content: "Resident Shiori")
    let relation = ShioriRelation(
        id: 70,
        listID: ShioriListIdentity.defaultListID,
        cueID: 7,
        createdAt: "2026-07-22T00:00:00Z"
    )
    cueStore.install([resident])
    shioriStore.tableRowStore.updateResidentShioriRelations(
        [relation],
        tagsByShioriID: [:],
        cueContentProvider: { cueStore.content(for: $0) },
        cueContentRevision: cueStore.revision,
        tableName: "shiori"
    )
    let originalSnapshotVersion = shioriStore.tableRowStore.snapshot.version

    shioriStore.setTableProjectionResponseActive(false)
    cueStore.install([cueContent(cueID: 99, content: "Unrelated")])
    shioriStore.setTableProjectionResponseActive(true)

    #expect(shioriStore.tableRowStore.snapshot.version == originalSnapshotVersion)
    #expect(shioriStore.tableRowStore.snapshot.row(at: 0)?.primaryCueText == "Resident Shiori")
}

private func cueContent(cueID: Int64, content: String) -> CueContent {
    CueContent(
        cueID: cueID,
        cueGroupID: cueID,
        cueEventIndex: Int(cueID),
        cueDisplayOrder: 0,
        primaryGroupIndex: 0,
        subtitlePath: "/Media/\(cueID).srt",
        subtitleFormat: .srt,
        videoPath: "/Media/\(cueID).mkv",
        videoName: "\(cueID).mkv",
        displayTitle: "Cue \(cueID)",
        timeRange: "00:01 - 00:02",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        content: content,
        cueLines: [content],
        cueGroupLines: [content],
        languages: [.unknown],
        speakers: []
    )
}
