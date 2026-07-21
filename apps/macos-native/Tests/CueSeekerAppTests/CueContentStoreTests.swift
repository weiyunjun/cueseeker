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
