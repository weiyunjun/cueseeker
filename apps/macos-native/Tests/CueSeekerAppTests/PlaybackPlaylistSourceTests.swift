import AppKit
import CueSeekerCore
import Foundation
import Testing
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
    let cueResult = item.cueResult(sequenceNumber: 8)

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
    #expect(cueResult.sequenceNumber == 8)
}

@MainActor
@Test
func playbackPlaylistShioriItemMapsPrimaryCueAndRemovesOnlyPrimaryGroupIndex() throws {
    let shiori = makePlaybackPlaylistShiori(
        id: 9,
        content: "same",
        cueEventIndex: 19,
        cueDisplayOrder: 2
    )
    let presentation = ShioriCuePresentation(
        cueID: 209,
        cueGroupID: 309,
        primaryGroupIndex: 1,
        cueGroupTexts: ["same", "same", "tail"],
        languages: [.unknown],
        speakers: []
    )

    let item = PlaybackPlaylistItem(
        shiori: shiori,
        cuePresentation: presentation,
        ordinal: 4
    )
    let actionContext = try #require(item.actionContext)

    #expect(item.identity == .shiori(9))
    #expect(item.primaryCueIdentity == .cue(209))
    #expect(item.ordinal == 4)
    #expect(item.primaryCueText == "same")
    #expect(item.additionalCueTexts == ["same", "tail"])
    #expect(item.target == .shiori(shiori))
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
    app.searchResultListGeneration = 7
    let initialResults = (0..<2).map { ordinal in
        makePlaybackPlaylistSearchResult(
            id: Int64(100 + ordinal),
            searchRank: ordinal
        )
    }
    app.search.searchResults = initialResults
    app.search.searchResultTotalCount = initialResults.count
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
    app.search.searchResults = updatedResults
    app.search.searchResultTotalCount = updatedResults.count
    app.refreshSearchPlaybackPlaylistSource(resultListGeneration: 7)

    #expect(app.playback.playlistSource === source)
    #expect(app.playback.playlistPosition == nil)
    #expect(window.snapshot.loadedOrdinalRange == (0..<5))
    #expect(window.item(at: 4)?.identity == .search(204))

    app.searchResultListGeneration = 8
    app.search.searchResults = []
    app.search.searchResultTotalCount = 0
    app.refreshSearchPlaybackPlaylistSource(resultListGeneration: 8)

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
func shioriPlaybackPlaylistReadsWorkbenchScopeOrderDirectly() throws {
    _ = NSApplication.shared
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("playback-playlist-shiori-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: databaseURL) }
    let app = AppCoordinator(databaseURL: databaseURL)
    app.shioriPlaybackNavigationScopeIDs = [9, 3, 7]
    let relations = [9, 3, 7].map {
        ShioriRelation(
            id: $0,
            listID: ShioriListIdentity.defaultListID,
            cueID: $0,
            createdAt: "2026-07-15T00:00:00Z"
        )
    }
    let contents = [9, 3, 7].map(makePlaybackPlaylistCueContent)
    app.cueContent.install(contents)
    app.shiori.installResidentSnapshot(
        ShioriResidentSnapshot(
            relations: relations,
            cueContents: contents,
            tagsByShioriID: [:]
        ),
        dataRevision: app.shiori.tableDataRevision
    )

    app.installShioriPlaybackPlaylistSource()

    let source = try #require(app.playback.playlistSource)
    let window = try #require(source.makeSessionWindowStore())
    #expect(source.origin == .shiori(scope: .explicitIDs([9, 3, 7])))
    #expect(window.snapshot.loadedOrdinalRange == (0..<3))
    #expect(window.snapshot.isComplete)
    #expect(window.item(at: 0)?.identity == .shiori(9))
    #expect(window.item(at: 1)?.identity == .shiori(3))
    #expect(window.item(at: 2)?.identity == .shiori(7))

    app.openShiori(
        Shiori(relation: relations[1], cueContent: contents[1]),
        navigationScopeIDs: [9, 3, 7],
        playlistScope: .explicitIDs([9, 3, 7]),
        playlistSelectedOrdinal: 1
    )
    let position = try #require(app.playback.playlistPosition)
    #expect(position.datasetID == source.boundary.datasetID)
    #expect(position.itemIdentity == .shiori(3))
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

private func makePlaybackPlaylistShiori(
    id: Int64,
    content: String? = nil,
    cueEventIndex: Int? = nil,
    cueDisplayOrder: Int? = nil
) -> Shiori {
    Shiori(
        id: id,
        subtitlePath: "/subtitle/shiori-\(id).ass",
        subtitleFormat: .ass,
        videoPath: "/video/shiori-\(id).mkv",
        videoName: "shiori-\(id).mkv",
        startMilliseconds: Int(id * 1_000),
        endMilliseconds: Int(id * 1_000 + 500),
        cueEventIndex: cueEventIndex,
        cueDisplayOrder: cueDisplayOrder,
        content: content ?? "shiori-\(id)",
        isValid: true,
        createdAt: "2026-07-15T00:00:00Z"
    )
}

private func makePlaybackPlaylistCueContent(id: Int64) -> CueContent {
    let shiori = makePlaybackPlaylistShiori(id: id)
    return CueContent(
        cueID: id,
        cueGroupID: id + 100,
        cueEventIndex: shiori.cueEventIndex ?? Int(id),
        cueDisplayOrder: shiori.cueDisplayOrder ?? 0,
        primaryGroupIndex: 0,
        subtitlePath: shiori.subtitlePath,
        subtitleFormat: shiori.subtitleFormat,
        videoPath: shiori.videoPath,
        videoName: shiori.videoName,
        displayTitle: "Shiori \(id)",
        timeRange: shiori.timeRange,
        startMilliseconds: shiori.startMilliseconds,
        endMilliseconds: shiori.endMilliseconds,
        content: shiori.content,
        cueLines: shiori.cueLines,
        cueGroupLines: shiori.cueLines,
        languages: [.unknown],
        speakers: []
    )
}
