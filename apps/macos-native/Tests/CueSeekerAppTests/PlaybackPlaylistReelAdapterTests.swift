import AppKit
import CueSeekerCore
import Foundation
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackPlaylistReelAdapterUsesResidentDatasetImmediately() throws {
    _ = NSApplication.shared
    let source = playbackPlaylistReelSource(totalCount: 40)
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: false
    )

    #expect(adapter.snapshot.datasetID.base is String)
    #expect(adapter.snapshot.datasetID == AnyHashable(source.boundary.datasetID.uuidString))
    #expect(adapter.snapshot.loadedOrdinalRange == (0..<40))
    #expect(adapter.snapshot.isComplete)
    #expect(!adapter.supportsWindowRequests)
    #expect(adapter.itemID(at: 20) == AnyHashable(PlaybackPlaylistItemIdentity.search(1_020)))
    let item = try #require(adapter.item(at: 20))
    #expect(adapter.cueResult(at: 20)?.metadata?.displayTitle == item.displayTitle)
    #expect(adapter.cueResult(at: 20)?.metadata?.timeRange == item.timeRange)
    #expect(adapter.cueResult(at: 20)?.additionalCueTexts == ["context-20"])
}

@MainActor
@Test
func playbackCueResultReelRapidScrollbarDragUsesResidentDataset() async throws {
    _ = NSApplication.shared
    let totalCount = 50_000
    let source = playbackPlaylistReelSource(
        kind: .excerpt,
        totalCount: totalCount
    )
    let dataset = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackCueResultReelAdapter(
        windowStore: dataset,
        showsCueGroup: true
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

    #expect(dataset.snapshot.loadedItemCount == totalCount)
    #expect(dataset.selectedOrdinal == 37_499)
    #expect(adapter.measurementCacheCountForTesting <= 64)
    #expect(adapter.measuredOrdinalsForTesting.count <= 64)
    #expect(view.placementsForTesting.count < 50)

    let selectedOrdinal = try #require(dataset.selectedOrdinal)
    let nextOrdinal = selectedOrdinal + 1
    let selectedBefore = try #require(
        view.placementsForTesting.first { $0.ordinal == selectedOrdinal }
    )
    let nextBefore = try #require(
        view.placementsForTesting.first { $0.ordinal == nextOrdinal }
    )
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: nextOrdinal,
        keyboardNavigationRequest: nil,
        reducesMotion: true,
        isInteractionEnabled: true,
        cancelsWheelMotion: false
    )
    view.layoutSubtreeIfNeeded()

    let selectedAfter = try #require(
        view.placementsForTesting.first { $0.ordinal == selectedOrdinal }
    )
    let nextAfter = try #require(
        view.placementsForTesting.first { $0.ordinal == nextOrdinal }
    )
    #expect(view.displayedSelectedOrdinalForTesting == nextOrdinal)
    #expect(adapter.measuredOrdinalsForTesting.contains(selectedOrdinal))
    #expect(adapter.measuredOrdinalsForTesting.contains(nextOrdinal))
    #expect(selectedBefore.extent == selectedAfter.extent)
    #expect(nextBefore.extent == nextAfter.extent)
    #expect(
        abs(
            (nextBefore.rect.midY - selectedBefore.rect.midY)
                - (nextAfter.rect.midY - selectedAfter.rect.midY)
        ) < 0.000_001
    )
    #expect(
        adapter.cueResult(at: selectedOrdinal)?.additionalCueTexts
            == ["context-\(selectedOrdinal)"]
    )
    #expect(
        adapter.cueResult(at: nextOrdinal)?.additionalCueTexts
            == ["context-\(nextOrdinal)"]
    )

    let keyboardTarget = nextOrdinal + 1
    let keyboardDatasetID = try #require(
        adapter.snapshot.datasetID.base as? String
    )
    view.update(
        contentAdapter: adapter,
        selectedOrdinal: nextOrdinal,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: 1,
            direction: .forward,
            targetOrdinal: keyboardTarget,
            contentDatasetID: keyboardDatasetID,
            contentGeneration: adapter.snapshot.generation
        ),
        reducesMotion: true,
        isInteractionEnabled: false,
        cancelsWheelMotion: true
    )
    await Task.yield()
    await Task.yield()
    #expect(dataset.selectedOrdinal == keyboardTarget)
    #expect(view.displayedSelectedOrdinalForTesting == keyboardTarget)
    #expect(
        adapter.cueResult(at: keyboardTarget)?.additionalCueTexts
            == ["context-\(keyboardTarget)"]
    )

    view.invalidate()
    dataset.invalidate()
    source.invalidate()
}

@MainActor
@Test
func playbackPlaylistReelAdapterCueGroupRevisionAndMeasurementsStayBounded() throws {
    _ = NSApplication.shared
    let source = playbackPlaylistReelSource(totalCount: 3)
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: false,
        measurementCacheCapacity: 2
    )

    let primaryOnlyExtent = try #require(adapter.extent(
        at: 0,
        isSelected: false,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    ))
    let selectedPrimaryOnlyExtent = try #require(adapter.extent(
        at: 0,
        isSelected: true,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    ))
    #expect(adapter.measurementCacheCountForTesting == 1)
    #expect(selectedPrimaryOnlyExtent == primaryOnlyExtent)
    _ = adapter.extent(
        at: 1,
        isSelected: false,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    )
    _ = adapter.extent(
        at: 2,
        isSelected: false,
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
        isSelected: false,
        contentWidth: 600,
        viewportHeight: 400,
        uiProbeScope: nil
    ))
    #expect(cueGroupExtent.naturalHeight > primaryOnlyExtent.naturalHeight)
}

@MainActor
@Test
func playbackPlaylistReelAdapterInvalidationPreservesItsSessionWindow() throws {
    let source = playbackPlaylistReelSource(totalCount: 2)
    let originalBoundary = source.boundary
    let window = try #require(source.makeSessionWindowStore())
    let adapter = PlaybackPlaylistReelAdapter(
        windowStore: window,
        showsCueGroup: true
    )

    adapter.invalidate()

    #expect(!adapter.supportsWindowRequests)
    #expect(adapter.snapshot.totalCount == 2)
    #expect(adapter.item(at: 0) == nil)
    #expect(window.item(at: 0)?.identity == .search(1_000))
    #expect(window.selectedOrdinal == 0)
    #expect(source.hasItems)
    #expect(source.boundary == originalBoundary)

    window.invalidate()
    let replacementWindow = try #require(source.makeSessionWindowStore())
    #expect(replacementWindow.snapshot.totalCount == 2)
    replacementWindow.invalidate()
}

@MainActor
private func playbackPlaylistReelSource(
    kind: PlaybackPlaylistSourceKind = .search,
    totalCount: Int
) -> PlaybackPlaylistSource {
    PlaybackPlaylistSource(kind: kind, totalCount: totalCount) { ordinal in
        guard ordinal >= 0, ordinal < totalCount else {
            return nil
        }
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
