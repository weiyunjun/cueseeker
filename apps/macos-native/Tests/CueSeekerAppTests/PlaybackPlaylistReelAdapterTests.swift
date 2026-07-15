import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackPlaylistReelAdapterLoadsCompleteDatasetOnceAndPreservesSequence() async throws {
    _ = NSApplication.shared
    var loaderCallCount = 0
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 40,
        knownItemIDsByOrdinal: [:]
    ) { request in
        loaderCallCount += 1
        return PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistReelItems(in: request.ordinalRange)
        )
    }
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: false
    )
    let initialSnapshot = adapter.snapshot

    #expect(initialSnapshot.datasetID.base is String)
    #expect(initialSnapshot.datasetID == AnyHashable(source.boundary.datasetID.uuidString))
    #expect(adapter.supportsWindowRequests)

    adapter.requestWindow(makePlaybackPlaylistReelRequest(
        snapshot: initialSnapshot,
        targetOrdinal: 20
    ))
    #expect(await waitForPlaybackPlaylistReelAdapter {
        adapter.snapshot.loadedItemCount == 40
    })

    #expect(loaderCallCount == 1)
    #expect(adapter.snapshot.loadedOrdinalRange == (0..<40))
    #expect(adapter.snapshot.isComplete)
    #expect(!adapter.supportsWindowRequests)
    #expect(adapter.itemID(at: 20) == AnyHashable(PlaybackPlaylistItemIdentity.search(1_020)))
    #expect(adapter.cueResult(at: 20)?.sequenceNumber == 21)
    #expect(adapter.cueResult(at: 20)?.additionalCueTexts == ["context-20"])
}

@MainActor
@Test
func playbackCueResultReelRapidScrollbarDragUsesOnlyRetainedDataset() async throws {
    _ = NSApplication.shared
    let totalCount = 50_000
    let expectedInitialLoadCalls = PlaybackCueResultCompleteLoadPolicy
        .batchRanges(in: 0..<totalCount).count
    var loaderCallCount = 0
    let source = PlaybackCueResultSource(
        kind: .shiori,
        totalCount: totalCount,
        knownItemIDsByOrdinal: [:]
    ) { request in
        loaderCallCount += 1
        return PlaybackCueResultSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistReelItems(in: request.ordinalRange)
        )
    }
    let dataset = try #require(source.makeSessionWindowStore())
    #expect(dataset.requestWindow(containing: 0))
    #expect(await waitForPlaybackPlaylistReelAdapter {
        dataset.snapshot.loadedItemCount == totalCount
    })
    #expect(loaderCallCount == expectedInitialLoadCalls)
    let adapter = PlaybackCueResultReelAdapter(
        windowStore: dataset,
        showsCueGroup: true,
        showsSequenceNumber: false
    )
    let view = PlaybackVirtualReelContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 1_280, height: 656)
    view.allowsNativeScrollbarInput = { true }
    view.onCommitVirtualReelSelection = dataset.commitSelection
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: 0,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    view.handleScrollbarDraggingChanged(true)
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .began,
        positionFraction: 0
    ))
    for step in 1...1_000 {
        view.handleScrollbarDrag(TableScrollbarDragEvent(
            axis: .vertical,
            phase: .changed,
            positionFraction: 0.75 * CGFloat(step) / 1_000
        ))
    }
    view.handleScrollbarDrag(TableScrollbarDragEvent(
        axis: .vertical,
        phase: .ended,
        positionFraction: 0.75
    ))
    view.handleScrollbarDraggingChanged(false)
    await Task.yield()

    #expect(loaderCallCount == expectedInitialLoadCalls)
    #expect(dataset.selectedOrdinal == 37_499)
    #expect(adapter.measurementCacheCountForTesting <= 64)
    #expect(adapter.measuredOrdinalsForTesting.count <= 64)
    #expect(view.placementsForTesting.count < 50)

    view.invalidate()
    dataset.invalidate()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistReelAdapterCueGroupRevisionAndMeasurementsStayBounded() async throws {
    _ = NSApplication.shared
    var loaderCallCount = 0
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 3,
        knownItemIDsByOrdinal: [:]
    ) { request in
        loaderCallCount += 1
        return PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistReelItems(in: request.ordinalRange)
        )
    }
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: false,
        measurementCacheCapacity: 2
    )
    adapter.requestWindow(makePlaybackPlaylistReelRequest(
        snapshot: adapter.snapshot,
        targetOrdinal: 0
    ))
    #expect(await waitForPlaybackPlaylistReelAdapter {
        adapter.snapshot.loadedItemCount == 3
    })

    let primaryOnlyExtent = try #require(adapter.extent(
        at: 0,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    ))
    _ = adapter.extent(
        at: 1,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    )
    _ = adapter.extent(
        at: 2,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    )

    #expect(adapter.measurementCacheCountForTesting == 2)
    #expect(adapter.measuredOrdinalsForTesting == [1, 2])

    let beforeCueGroup = adapter.snapshot
    #expect(adapter.setShowsCueGroup(true))
    let withCueGroup = adapter.snapshot

    #expect(withCueGroup.datasetID == beforeCueGroup.datasetID)
    #expect(withCueGroup.generation == beforeCueGroup.generation)
    #expect(withCueGroup.revision == beforeCueGroup.revision + 1)
    #expect(adapter.measurementCacheCountForTesting == 0)
    #expect(adapter.measuredOrdinalsForTesting.isEmpty)
    #expect(!adapter.setShowsCueGroup(true))

    let cueGroupExtent = try #require(adapter.extent(
        at: 0,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    ))
    #expect(cueGroupExtent.naturalHeight > primaryOnlyExtent.naturalHeight)

    adapter.requestWindow(makePlaybackPlaylistReelRequest(
        snapshot: beforeCueGroup,
        targetOrdinal: 1
    ))
    await Task.yield()
    #expect(loaderCallCount == 1)

    adapter.requestWindow(makePlaybackPlaylistReelRequest(
        snapshot: adapter.snapshot,
        targetOrdinal: 1
    ))
    await Task.yield()
    #expect(loaderCallCount == 1)
}

@MainActor
@Test
func playbackPlaylistReelAdapterInvalidationPreservesItsSessionWindow() async throws {
    let source = PlaybackPlaylistSource(
        kind: .search,
        totalCount: 2,
        knownItemIDsByOrdinal: [
            0: .search(1_000),
            1: .search(1_001),
        ]
    ) { request in
        PlaybackPlaylistSourceWindowResponse(
            request: request,
            items: makePlaybackPlaylistReelItems(in: request.ordinalRange)
        )
    }
    let originalBoundary = source.boundary
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: true
    )
    adapter.requestWindow(makePlaybackPlaylistReelRequest(
        snapshot: adapter.snapshot,
        targetOrdinal: 0
    ))
    #expect(await waitForPlaybackPlaylistReelAdapter {
        adapter.snapshot.loadedItemCount == 2
    })

    adapter.invalidate()

    #expect(!adapter.supportsWindowRequests)
    #expect(adapter.snapshot.totalCount == 2)
    #expect(adapter.item(at: 0) == nil)
    #expect(window.retainedItemCount == 2)
    #expect(window.selectedOrdinal == 0)
    #expect(source.hasItems)
    #expect(source.boundary == originalBoundary)

    window.invalidate()
    let replacementWindow = try #require(source.makeSessionWindowStore())
    #expect(replacementWindow.snapshot.totalCount == 2)
    replacementWindow.invalidate()
}

private func makePlaybackPlaylistReelItems(
    in ordinalRange: Range<Int>
) -> [PlaybackPlaylistItem] {
    ordinalRange.map { ordinal in
        let id = Int64(1_000 + ordinal)
        let primary = "primary-\(ordinal)"
        return PlaybackPlaylistItem(
            searchResult: SubtitleSearchResult(
                entryID: id,
                cueGroupID: id + 100,
                cueEventIndex: ordinal,
                cueDisplayOrder: 1,
                primaryGroupIndex: 1,
                subtitlePath: "/subtitle/\(id).ass",
                subtitleFormat: .ass,
                videoPath: "/video/\(id).mkv",
                videoName: "\(id).mkv",
                startMilliseconds: ordinal * 1_000,
                endMilliseconds: ordinal * 1_000 + 500,
                content: primary,
                cueLines: ["context-\(ordinal)", primary],
                cueGroupLines: ["context-\(ordinal)", primary],
                searchRank: ordinal
            ),
            ordinal: ordinal
        )
    }
}

private func makePlaybackPlaylistReelRequest(
    snapshot: PlaybackVirtualReelSnapshot,
    targetOrdinal: Int
) -> PlaybackVirtualReelWindowRequest {
    PlaybackVirtualReelWindowRequest(
        datasetID: snapshot.datasetID,
        generation: snapshot.generation,
        revision: snapshot.revision,
        targetOrdinal: targetOrdinal,
        suggestedOrdinalRange: PlaybackVirtualReelWindowPolicy.standard.windowRange(
            totalCount: snapshot.totalCount,
            targetOrdinal: targetOrdinal
        ),
        reason: .visible
    )
}

@MainActor
private func waitForPlaybackPlaylistReelAdapter(
    attempts: Int = 100,
    _ condition: () -> Bool
) async -> Bool {
    for _ in 0..<attempts {
        if condition() {
            return true
        }
        await Task.yield()
    }
    return condition()
}
