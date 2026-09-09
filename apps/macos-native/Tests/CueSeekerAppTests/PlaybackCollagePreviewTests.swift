import AppKit
import CoreGraphics
import CueSeekerCore
import CueSeekerPlayback
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackCollagePreviewRendersOnlyChangedGroups() async throws {
    let first = collagePreviewCue(
        id: 1,
        ordinal: 0,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000
    )
    let second = collagePreviewCue(
        id: 2,
        ordinal: 1,
        startMilliseconds: 4_000,
        endMilliseconds: 5_000
    )
    let third = collagePreviewCue(
        id: 3,
        ordinal: 2,
        startMilliseconds: 7_000,
        endMilliseconds: 8_000
    )
    let matchingSecondTimestamp = collagePreviewCue(
        id: 4,
        ordinal: 3,
        startMilliseconds: 4_000,
        endMilliseconds: 5_000
    )
    var renderedGroups: [SubtitleCollageGroup] = []
    var composedGroupCounts: [Int] = []
    let store = PlaybackCollagePreviewStore(
        renderGroup: { group in
            renderedGroups.append(group)
            return collagePreviewRenderedGroup()
        },
        compose: { groups in
            composedGroupCounts.append(groups.count)
            return collagePreviewImage(width: groups.count, height: 1)
        }
    )

    var plan = try SubtitleCollageSelectionPlan(
        selectedCues: [first, second, third]
    )
    store.update(plan: plan)
    await waitForCollagePreviewToSettle(store)

    _ = plan.select(matchingSecondTimestamp)
    store.update(plan: plan)
    await waitForCollagePreviewToSettle(store)

    #expect(renderedGroups.count == 4)
    #expect(renderedGroups[3] == plan.groups[1])
    #expect(composedGroupCounts == [3, 3])
    #expect(store.image?.width == 3)
}

@MainActor
@Test
func playbackCollagePreviewRejectsObsoleteAsyncResults() async throws {
    let firstPlan = try SubtitleCollageSelectionPlan(selectedCues: [
        collagePreviewCue(
            id: 10,
            ordinal: 0,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000
        )
    ])
    let secondPlan = try SubtitleCollageSelectionPlan(selectedCues: [
        collagePreviewCue(
            id: 20,
            ordinal: 0,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000
        ),
        collagePreviewCue(
            id: 21,
            ordinal: 1,
            startMilliseconds: 4_000,
            endMilliseconds: 5_000
        )
    ])
    var continuations: [
        Int: CheckedContinuation<SubtitleCollageRenderedGroup, Never>
    ] = [:]
    var pendingRenderCallCount = 0
    let store = PlaybackCollagePreviewStore(
        renderGroup: { _ in
            pendingRenderCallCount += 1
            let call = pendingRenderCallCount
            return await withCheckedContinuation { continuation in
                continuations[call] = continuation
            }
        },
        compose: { groups in
            collagePreviewImage(width: groups.count, height: 1)
        }
    )

    store.update(plan: firstPlan)
    #expect(!store.canUseCurrentResult)
    await waitForCollagePreviewCondition {
        continuations[1] != nil
    }

    // Superseding the plan must not start a second render of its own; the group
    // already in flight finishes first.
    store.update(plan: secondPlan)
    #expect(!store.canUseCurrentResult)
    #expect(continuations[2] == nil)

    continuations[1]?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewCondition {
        continuations[2] != nil
    }
    #expect(store.image == nil)
    #expect(!store.canUseCurrentResult)

    continuations[2]?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewCondition {
        continuations[3] != nil
    }
    continuations[3]?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewToSettle(store)
    #expect(store.image?.width == 2)
    #expect(store.canUseCurrentResult)
    #expect(store.currentActionResult()?.plan == secondPlan)
    #expect(store.currentActionResult()?.image.width == 2)
    #expect(pendingRenderCallCount == 3)
}

@MainActor
@Test
func playbackCollagePreviewActionsRejectVisiblePreviousGeneration() async throws {
    let firstPlan = try SubtitleCollageSelectionPlan(selectedCues: [
        collagePreviewCue(
            id: 30,
            ordinal: 0,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000
        )
    ])
    let secondPlan = try SubtitleCollageSelectionPlan(selectedCues: [
        firstPlan.selectedCues[0],
        collagePreviewCue(
            id: 31,
            ordinal: 1,
            startMilliseconds: 4_000,
            endMilliseconds: 5_000
        ),
    ])
    var renderCallCount = 0
    var pendingRender: CheckedContinuation<
        SubtitleCollageRenderedGroup,
        Never
    >?
    let store = PlaybackCollagePreviewStore(
        renderGroup: { _ in
            renderCallCount += 1
            if renderCallCount == 2 {
                return await withCheckedContinuation { continuation in
                    pendingRender = continuation
                }
            }
            return collagePreviewRenderedGroup()
        },
        compose: { groups in
            collagePreviewImage(width: groups.count, height: 1)
        }
    )

    store.update(plan: firstPlan)
    await waitForCollagePreviewToSettle(store)
    #expect(store.currentActionResult()?.plan == firstPlan)
    #expect(store.image?.width == 1)

    store.update(plan: secondPlan)
    await waitForCollagePreviewCondition {
        pendingRender != nil
    }
    #expect(store.image?.width == 1)
    #expect(!store.canUseCurrentResult)

    pendingRender?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewToSettle(store)
    #expect(store.currentActionResult()?.plan == secondPlan)
    #expect(store.currentActionResult()?.image.width == 2)
}

@MainActor
@Test
func playbackCollagePreviewPublicationStaysInsidePreviewBranch() async throws {
    _ = NSApplication.shared
    let uiProbeScope = UUID().uuidString
    let recordingSession = UIInvalidationProbe.beginAsyncRecordingForTesting(
        scope: uiProbeScope
    )
    defer { recordingSession.finish() }
    let store = PlaybackCollagePreviewStore(
        renderGroup: { _ in
            collagePreviewRenderedGroup()
        },
        compose: { groups in
            collagePreviewImage(width: groups.count, height: 1)
        }
    )
    let hostingView = NSHostingView(
        rootView: PlaybackCollageRefreshBoundaryRoot(
            store: store,
            uiProbeScope: uiProbeScope
        )
        .frame(width: 800, height: 600)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
    hostingView.layoutSubtreeIfNeeded()
    try await Task.sleep(nanoseconds: 50_000_000)
    let recordingBefore = recordingSession.recording()
    let plan = try SubtitleCollageSelectionPlan(selectedCues: [
        collagePreviewCue(
            id: 40,
            ordinal: 0,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000
        )
    ])

    store.update(plan: plan)
    await waitForCollagePreviewToSettle(store)
    try await Task.sleep(nanoseconds: 50_000_000)
    hostingView.layoutSubtreeIfNeeded()
    let recording = recordingSession.recording().delta(
        since: recordingBefore
    )

    #expect(recording.count("UI.PlaybackCollagePreviewPane.body") > 0)
    #expect(recording.count("playback.collage_preview.native_update") > 0)
    #expect(recording.count("test.playback_collage.preview_owner_body") > 0)
    #expect(recording.count("test.playback_collage.root_body") == 0)
    #expect(recording.count("test.playback_collage.sibling_body") == 0)
    withExtendedLifetime(hostingView) {}
}

@MainActor
@Test
func playbackCollagePreviewUsesEqualColumnsAndTableScrollbar() throws {
    _ = NSApplication.shared
    #expect(PlaybackCollageEditorLayout.columnWidth(totalWidth: 901) == 450.5)

    let view = PlaybackCollagePreviewScrollContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
    view.layoutSubtreeIfNeeded()

    view.updateImage(collagePreviewImage(width: 800, height: 1_200))
    view.layoutSubtreeIfNeeded()
    #expect(view.renderedImageSizeForTesting == CGSize(width: 400, height: 600))
    #expect(view.isVerticalScrollbarPresentedForTesting)

    view.updateImage(collagePreviewImage(width: 800, height: 400))
    view.layoutSubtreeIfNeeded()
    #expect(view.renderedImageSizeForTesting == CGSize(width: 400, height: 200))
    #expect(!view.isVerticalScrollbarPresentedForTesting)
}

private func collagePreviewCue(
    id: Int64,
    ordinal: Int,
    startMilliseconds: Int,
    endMilliseconds: Int
) -> SubtitleFocusCue {
    SubtitleFocusCue(
        id: id,
        cueGroupID: id,
        ordinal: ordinal,
        eventIndex: ordinal,
        displayOrder: ordinal,
        startMilliseconds: startMilliseconds,
        endMilliseconds: endMilliseconds,
        content: "Cue \(id)"
    )
}

private func collagePreviewRenderedGroup() -> SubtitleCollageRenderedGroup {
    SubtitleCollageRenderedGroup(
        image: collagePreviewImage(width: 2, height: 2),
        subtitleBands: [0...1]
    )
}

private func collagePreviewImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: max(1, width),
        height: max(1, height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
}

private struct PlaybackCollageRefreshBoundaryRoot: View {
    let store: PlaybackCollagePreviewStore
    let uiProbeScope: String

    var body: some View {
        let _ = UIInvalidationProbe.count(
            "test.playback_collage.root_body",
            scope: uiProbeScope
        )
        HStack(spacing: 0) {
            PlaybackCollageRefreshBoundaryOwner(
                store: store,
                uiProbeScope: uiProbeScope
            )
            PlaybackCollageRefreshBoundarySibling(
                uiProbeScope: uiProbeScope
            )
        }
    }
}

private struct PlaybackCollageRefreshBoundaryOwner: View {
    @StateObject private var store: PlaybackCollagePreviewStore
    let uiProbeScope: String

    init(store: PlaybackCollagePreviewStore, uiProbeScope: String) {
        _store = StateObject(wrappedValue: store)
        self.uiProbeScope = uiProbeScope
    }

    var body: some View {
        let _ = UIInvalidationProbe.count(
            "test.playback_collage.preview_owner_body",
            scope: uiProbeScope
        )
        PlaybackCollagePreviewPane(
            store: store,
            displayTitle: "Show - 01",
            uiProbeScope: uiProbeScope
        )
    }
}

private struct PlaybackCollageRefreshBoundarySibling: View {
    let uiProbeScope: String

    var body: some View {
        let _ = UIInvalidationProbe.count(
            "test.playback_collage.sibling_body",
            scope: uiProbeScope
        )
        Color.clear
    }
}

@MainActor
private func waitForCollagePreviewToSettle(
    _ store: PlaybackCollagePreviewStore
) async {
    for _ in 0..<1_000 {
        if !store.isRendering {
            return
        }
        await Task.yield()
    }
    Issue.record("Collage preview did not settle.")
}

@MainActor
private func waitForCollagePreviewCondition(
    _ condition: @MainActor () -> Bool
) async {
    for _ in 0..<1_000 {
        if condition() {
            return
        }
        await Task.yield()
    }
    Issue.record("Collage preview render request did not start.")
}
