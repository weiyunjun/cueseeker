import AppKit
import Foundation
import Testing
@testable import CueSeekerCore
@testable import CueSeekerApp

@MainActor
@Test
func playbackPlaylistSearchItemMapsPrimaryCueAndRemovesOnlyPrimaryGroupIndex() throws {
    let searchResult = makePlaybackPlaylistSearchResult(
        id: 42,
        content: "same",
        primaryGroupIndex: 1,
        cueGroupLines: ["same", "same", "tail"]
    )

    let item = PlaybackPlaylistItem(searchResult: searchResult, ordinal: 7)
    let actionContext = try #require(item.actionContext)
    let cueResult = item.cueResult()

    #expect(item.identity == .search(42))
    #expect(item.primaryCueIdentity == .cue(42))
    #expect(item.ordinal == 7)
    #expect(item.primaryCueText == "same")
    #expect(item.additionalCueTexts == ["same", "tail"])
    #expect(item.target == .search(searchResult))
    #expect(actionContext.source.videoPath == "/video/42.mkv")
    #expect(actionContext.source.subtitlePath == "/subtitle/42.ass")
    #expect(actionContext.cue.id == 42)
    #expect(actionContext.cue.cueGroupID == 142)
    #expect(actionContext.cue.ordinal == 7)
    #expect(cueResult.itemID == AnyHashable(PlaybackPlaylistItemIdentity.search(42)))
    #expect(cueResult.metadata == PlaybackCueMetadata(
        ordinal: 7,
        displayTitle: searchResult.displayTitle,
        timeRange: searchResult.timeRange
    ))
    #expect(cueResult.metadata?.ordinalText == "#8")
}

@MainActor
@Test
func playbackPlaylistExcerptItemMapsPrimaryCueAndRemovesOnlyPrimaryGroupIndex() throws {
    let excerpt = makePlaybackPlaylistExcerpt(
        id: 9,
        content: "same",
        cueEventIndex: 19,
        cueDisplayOrder: 2
    )
    let presentation = ExcerptCuePresentation(
        cueID: 209,
        cueGroupID: 309,
        primaryGroupIndex: 1,
        cueGroupTexts: ["same", "same", "tail"],
        languages: [.unknown],
    )

    let item = PlaybackPlaylistItem(
        excerpt: excerpt,
        cuePresentation: presentation,
        ordinal: 4
    )
    let actionContext = try #require(item.actionContext)

    #expect(item.identity == .excerpt(9))
    #expect(item.primaryCueIdentity == .cue(209))
    #expect(item.ordinal == 4)
    #expect(item.primaryCueText == "same")
    #expect(item.additionalCueTexts == ["same", "tail"])
    #expect(item.target == .excerpt(excerpt))
    #expect(actionContext.cue.id == 209)
    #expect(actionContext.cue.cueGroupID == 309)
    #expect(actionContext.cue.eventIndex == 19)
}

@MainActor
@Test
func playbackPlaylistSessionReadsCompleteResidentDatasetWithoutRetainingCopy() throws {
    let totalCount = 50_000
    let source = PlaybackPlaylistSource(kind: .search, totalCount: totalCount) {
        ordinal in
        guard ordinal >= 0, ordinal < totalCount else {
            return nil
        }
        return PlaybackPlaylistItem(
            searchResult: makePlaybackPlaylistSearchResult(
                id: Int64(1_000 + ordinal)
            ),
            ordinal: ordinal
        )
    }
    let window = try #require(source.makeSessionWindowStore())

    #expect(window.snapshot.isValid)
    #expect(window.snapshot.isComplete)
    #expect(window.snapshot.loadedOrdinalRange == (0..<totalCount))
    #expect(window.snapshot.loadedItemCount == totalCount)
    #expect(window.item(at: 25_000)?.identity == .search(26_000))

    let datasetID = try #require(window.reelDatasetID)
    #expect(window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable(datasetID),
        generation: window.snapshot.generation,
        ordinal: totalCount - 1
    )))
    #expect(window.selectedOrdinal == totalCount - 1)
    #expect(window.selectedItemIdentity == .search(Int64(1_000 + totalCount - 1)))
}

@MainActor
@Test
func playbackPlaylistSessionRestoresHighLogicalPositionWithOneProviderRead() throws {
    let totalCount = 50_000
    let targetOrdinal = 37_499
    var requestedOrdinals: [Int] = []
    let source = PlaybackPlaylistSource(kind: .search, totalCount: totalCount) {
        ordinal in
        requestedOrdinals.append(ordinal)
        guard ordinal >= 0, ordinal < totalCount else {
            return nil
        }
        return PlaybackPlaylistItem(
            searchResult: makePlaybackPlaylistSearchResult(
                id: Int64(1_000 + ordinal)
            ),
            ordinal: ordinal
        )
    }
    let position = PlaybackPlaylistPosition(
        datasetID: source.boundary.datasetID,
        itemIdentity: .search(Int64(1_000 + targetOrdinal)),
        ordinal: targetOrdinal
    )

    let window = try #require(source.makeSessionWindowStore(
        initialPosition: position
    ))

    #expect(window.selectedOrdinal == targetOrdinal)
    #expect(window.selectedItemIdentity == position.itemIdentity)
    #expect(requestedOrdinals == [targetOrdinal])
    #expect(window.snapshot.loadedItemCount == totalCount)
}

@MainActor
@Test
func playbackPlaylistBoundaryRefreshUpdatesResidentSnapshotAndSelection() throws {
    var items = makePlaybackPlaylistSearchItems(in: 0..<2)
    let source = PlaybackPlaylistSource(kind: .search, totalCount: items.count) {
        ordinal in
        guard items.indices.contains(ordinal) else {
            return nil
        }
        return items[ordinal]
    }
    let window = try #require(source.makeSessionWindowStore())
    let initial = source.boundary
    let datasetID = try #require(window.reelDatasetID)
    #expect(
        PlaybackCueFooterStatus.cues(
            totalCount: window.snapshot.totalCount
        ) == "2 cues"
    )
    #expect(window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable(datasetID),
        generation: initial.generation,
        ordinal: 1
    )))

    items.append(contentsOf: makePlaybackPlaylistSearchItems(in: 2..<3))
    #expect(source.updateBoundary(totalCount: items.count))
    let grown = source.boundary

    #expect(grown.datasetID == initial.datasetID)
    #expect(grown.generation == initial.generation + 1)
    #expect(grown.revision == 0)
    #expect(window.snapshot.loadedOrdinalRange == (0..<3))
    #expect(window.snapshot.isComplete)
    #expect(window.selectedOrdinal == 1)
    #expect(window.selectedItemIdentity == .search(1_001))
    #expect(
        PlaybackCueFooterStatus.cues(
            totalCount: window.snapshot.totalCount
        ) == "3 cues"
    )

    items[1] = PlaybackPlaylistItem(
        searchResult: makePlaybackPlaylistSearchResult(id: 9_001),
        ordinal: 1
    )
    #expect(source.updateBoundary(totalCount: items.count))

    #expect(source.boundary.generation == grown.generation)
    #expect(source.boundary.revision == grown.revision + 1)
    #expect(window.snapshot.revision == source.boundary.revision)
    #expect(window.selectedItemIdentity == .search(9_001))
}

@MainActor
@Test
func playbackPlaylistSelectionRejectsStaleAndOutOfRangeCommits() throws {
    let items = makePlaybackPlaylistSearchItems(in: 0..<2)
    let source = PlaybackPlaylistSource(kind: .search, totalCount: items.count) {
        ordinal in
        items.indices.contains(ordinal) ? items[ordinal] : nil
    }
    let window = try #require(source.makeSessionWindowStore())
    let datasetID = try #require(window.reelDatasetID)

    #expect(!window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable("stale"),
        generation: window.snapshot.generation,
        ordinal: 1
    )))
    #expect(!window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable(datasetID),
        generation: window.snapshot.generation + 1,
        ordinal: 1
    )))
    #expect(!window.commitSelection(PlaybackVirtualReelSelectionCommit(
        datasetID: AnyHashable(datasetID),
        generation: window.snapshot.generation,
        ordinal: 2
    )))
    #expect(window.selectedOrdinal == 0)
}

@MainActor
@Test
func playbackPlaylistWindowInvalidationDoesNotInvalidateSharedSource() throws {
    let items = makePlaybackPlaylistSearchItems(in: 0..<2)
    let source = PlaybackPlaylistSource(kind: .search, totalCount: items.count) {
        ordinal in
        items.indices.contains(ordinal) ? items[ordinal] : nil
    }
    let originalBoundary = source.boundary
    let window = try #require(source.makeSessionWindowStore())

    window.invalidate()

    #expect(window.snapshot.totalCount == 0)
    #expect(window.item(at: 0) == nil)
    #expect(source.hasItems)
    #expect(source.boundary == originalBoundary)
    let replacementWindow = try #require(source.makeSessionWindowStore())
    #expect(replacementWindow.snapshot.loadedItemCount == 2)
    #expect(replacementWindow.item(at: 1)?.identity == .search(1_001))

    source.invalidate()
    #expect(!source.hasItems)
    #expect(replacementWindow.snapshot.totalCount == 0)
    #expect(source.makeSessionWindowStore() == nil)
}

@MainActor
@Test
func searchPlaybackPlaylistTracksAndRetainsItsWorkbenchResultRun() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-playlist-search-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    let initialGeneration = app.search.advanceResultListGeneration()
    let initialResults = (0..<2).map { ordinal in
        makePlaybackPlaylistSearchResult(
            id: Int64(100 + ordinal),
            searchRank: ordinal
        )
    }
    app.search.replaceResultState(
        results: initialResults,
        status: .completed,
        totalCount: initialResults.count,
        fileSummaries: [],
        countState: .exact,
        knownResultCount: initialResults.count,
        knownFileCount: 0,
        hasMore: false
    )
    app.installSearchPlaybackPlaylistSource(seed: initialResults[1])
    let source = try #require(app.playback.playlistSource)
    let window = try #require(source.makeSessionWindowStore())
    let logicalPosition = try #require(app.playback.playlistPosition)

    #expect(window.snapshot.isComplete)
    #expect(window.item(at: 1)?.identity == .search(101))
    #expect(logicalPosition.datasetID == source.boundary.datasetID)
    #expect(logicalPosition.itemIdentity == .search(101))
    #expect(logicalPosition.ordinal == 1)
    let focusedWindow = try #require(source.makeSessionWindowStore(
        initialPosition: logicalPosition
    ))
    #expect(focusedWindow.selectedOrdinal == 1)

    let updatedResults = (0..<5).map { ordinal in
        makePlaybackPlaylistSearchResult(
            id: Int64(200 + ordinal),
            searchRank: ordinal
        )
    }
    app.search.replaceResultState(
        results: updatedResults,
        status: .completed,
        totalCount: updatedResults.count,
        fileSummaries: [],
        countState: .exact,
        knownResultCount: updatedResults.count,
        knownFileCount: 0,
        hasMore: false
    )
    app.refreshSearchPlaybackPlaylistSource(
        resultListGeneration: initialGeneration
    )

    #expect(app.playback.playlistSource === source)
    #expect(app.playback.playlistPosition == nil)
    #expect(window.snapshot.loadedOrdinalRange == (0..<5))
    #expect(window.item(at: 4)?.identity == .search(204))

    let replacementGeneration = app.search.advanceResultListGeneration()
    app.search.clearResults()
    app.refreshSearchPlaybackPlaylistSource(
        resultListGeneration: replacementGeneration
    )

    #expect(source.boundary.totalCount == 5)
    #expect(window.item(at: 4)?.identity == .search(204))
    let reopenedWindow = try #require(source.makeSessionWindowStore())
    #expect(reopenedWindow.snapshot.loadedOrdinalRange == (0..<5))
    #expect(reopenedWindow.item(at: 0)?.identity == .search(200))
    #expect(reopenedWindow.item(at: 4)?.identity == .search(204))
    app.playback.clearPlaylistSource()
}

@MainActor
@Test
func searchPlaybackPlaylistUsesTheFilteredResults() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-playlist-search-facet-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    app.search.updateQuery("query")
    app.search.updateSearchFacetFilter(CueFacetFilter(
        durations: [.underOneSecond]
    ))
    let generation = app.search.prepareSearch(
        appending: false,
        filterSet: SubtitleSearchFilterSet()
    )
    // The scan matched 120 cues; the filter kept the 60 even ones as the results.
    let matchedCueIDs = (0..<120).map { Int64(100 + $0) }
    let results = (0..<60).map { ordinal in
        makePlaybackPlaylistSearchResult(
            id: Int64(100 + ordinal * 2),
            searchRank: ordinal
        )
    }
    let facetSnapshot = CueFacetSnapshot(
        cueIDs: matchedCueIDs,
        durationFacets: matchedCueIDs.indices.map {
            $0.isMultiple(of: 2) ? .underOneSecond : .fiveSecondsOrMore
        },
        characterFacets: Array(repeating: .oneToTen, count: matchedCueIDs.count),
        languageFacets: Array(repeating: [.english], count: matchedCueIDs.count),
        watchStateFacets: Array(repeating: .unwatched, count: matchedCueIDs.count)
    )
    let page = SubtitleSearchPage(
        results: results,
        cueIDs: results.map(\.entryID),
        totalCount: results.count,
        fileSummaries: [],
        facetSnapshot: facetSnapshot
    )
    #expect(app.search.commitExactSearchPage(page, generation: generation))

    app.installSearchPlaybackPlaylistSource(seed: results[59])

    let source = try #require(app.playback.playlistSource)
    let position = try #require(app.playback.playlistPosition)
    #expect(source.boundary.totalCount == 60)
    #expect(source.item(at: 0)?.identity == .search(100))
    #expect(source.item(at: 1)?.identity == .search(102))
    #expect(source.item(at: 59)?.identity == .search(218))
    #expect(position.itemIdentity == .search(218))
    #expect(position.ordinal == 59)
    app.playback.clearPlaylistSource()
}

@MainActor
@Test
func excerptPlaybackPlaylistReadsWorkbenchScopeOrderDirectly() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-playlist-excerpt-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    app.excerptPlaybackNavigationScopeIDs = [9, 3, 7]
    let relations = [9, 3, 7].map {
        ExcerptRelation(
            id: $0,
            listID: ExcerptListIdentity.defaultListID,
            cueID: $0,
            createdAt: "2026-07-15T00:00:00Z"
        )
    }
    let contents = [9, 3, 7].map(makePlaybackPlaylistCueContent)
    app.cueContent.install(contents)
    app.excerpt.installResidentSnapshot(
        ExcerptResidentSnapshot(
            relations: relations,
            cueContents: contents
        ),
        dataRevision: app.excerpt.tableDataRevision
    )

    app.installExcerptPlaybackPlaylistSource()

    let source = try #require(app.playback.playlistSource)
    let window = try #require(source.makeSessionWindowStore())
    #expect(source.origin == .excerpt(scope: .explicitIDs([9, 3, 7])))
    #expect(window.snapshot.loadedOrdinalRange == (0..<3))
    #expect(window.snapshot.isComplete)
    #expect(window.item(at: 0)?.identity == .excerpt(9))
    #expect(window.item(at: 1)?.identity == .excerpt(3))
    #expect(window.item(at: 2)?.identity == .excerpt(7))

    app.openExcerpt(
        Excerpt(relation: relations[1], cueContent: contents[1]),
        navigationScopeIDs: [9, 3, 7],
        playlistScope: .explicitIDs([9, 3, 7]),
        playlistSelectedOrdinal: 1
    )
    let position = try #require(app.playback.playlistPosition)
    #expect(position.datasetID == source.boundary.datasetID)
    #expect(position.itemIdentity == .excerpt(3))
    #expect(position.ordinal == 1)
    let focusedWindow = try #require(source.makeSessionWindowStore(
        initialPosition: position
    ))
    #expect(focusedWindow.selectedOrdinal == 1)
    app.playback.clearPlaylistSource()
}

private func makePlaybackPlaylistSearchResult(
    id: Int64,
    content: String? = nil,
    primaryGroupIndex: Int = 0,
    cueGroupLines: [String]? = nil,
    searchRank: Int? = nil
) -> SubtitleSearchResult {
    let resolvedContent = content ?? "cue-\(id)"
    let resolvedCueGroupLines = cueGroupLines ?? [resolvedContent]
    return SubtitleSearchResult(
        entryID: id,
        cueGroupID: id + 100,
        cueEventIndex: Int(id + 200),
        cueDisplayOrder: primaryGroupIndex,
        primaryGroupIndex: primaryGroupIndex,
        subtitlePath: "/subtitle/\(id).ass",
        subtitleFormat: .ass,
        videoPath: "/video/\(id).mkv",
        videoName: "\(id).mkv",
        startMilliseconds: Int(id * 1_000),
        endMilliseconds: Int(id * 1_000 + 500),
        content: resolvedContent,
        cueLines: resolvedCueGroupLines,
        cueGroupLines: resolvedCueGroupLines,
        searchRank: searchRank ?? Int(id)
    )
}

private func makePlaybackPlaylistSearchItems(
    in ordinalRange: Range<Int>
) -> [PlaybackPlaylistItem] {
    ordinalRange.map { ordinal in
        PlaybackPlaylistItem(
            searchResult: makePlaybackPlaylistSearchResult(
                id: Int64(1_000 + ordinal)
            ),
            ordinal: ordinal
        )
    }
}

private func makePlaybackPlaylistExcerpt(
    id: Int64,
    content: String? = nil,
    cueEventIndex: Int? = nil,
    cueDisplayOrder: Int? = nil
) -> Excerpt {
    Excerpt(
        id: id,
        subtitlePath: "/subtitle/excerpt-\(id).ass",
        subtitleFormat: .ass,
        videoPath: "/video/excerpt-\(id).mkv",
        videoName: "excerpt-\(id).mkv",
        startMilliseconds: Int(id * 1_000),
        endMilliseconds: Int(id * 1_000 + 500),
        cueEventIndex: cueEventIndex,
        cueDisplayOrder: cueDisplayOrder,
        content: content ?? "excerpt-\(id)",
        isValid: true,
        createdAt: "2026-07-15T00:00:00Z"
    )
}

private func makePlaybackPlaylistCueContent(id: Int64) -> CueContent {
    let excerpt = makePlaybackPlaylistExcerpt(id: id)
    return CueContent(
        cueID: id,
        cueGroupID: id + 100,
        cueEventIndex: excerpt.cueEventIndex ?? Int(id),
        cueDisplayOrder: excerpt.cueDisplayOrder ?? 0,
        primaryGroupIndex: 0,
        subtitlePath: excerpt.subtitlePath,
        subtitleFormat: excerpt.subtitleFormat,
        videoPath: excerpt.videoPath,
        videoName: excerpt.videoName,
        displayTitle: "Excerpt \(id)",
        timeRange: excerpt.timeRange,
        startMilliseconds: excerpt.startMilliseconds,
        endMilliseconds: excerpt.endMilliseconds,
        content: excerpt.content,
        cueLines: excerpt.cueLines,
        cueGroupLines: excerpt.cueLines,
        languages: [.unknown],
    )
}
