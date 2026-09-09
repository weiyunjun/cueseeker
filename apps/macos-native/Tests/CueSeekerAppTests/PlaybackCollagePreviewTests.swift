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
            return collagePreviewComposition(groupCount: groups.count)
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
    // Each finished group is published as it lands and the full plan once more
    // on commit. The second plan changes one group, whose old image stands in,
    // so nothing is published until the new render lands. The composes run as
    // separate tasks, so only their set is deterministic.
    #expect(composedGroupCounts.sorted() == [1, 2, 3, 3, 3, 3])
    #expect(store.image?.width == 3)
}

@MainActor
@Test
func playbackCollagePreviewPublishesRenderedGroupsBeforeThePlanCompletes() async throws {
    let first = collagePreviewCue(
        id: 70,
        ordinal: 0,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000
    )
    let second = collagePreviewCue(
        id: 71,
        ordinal: 1,
        startMilliseconds: 4_000,
        endMilliseconds: 5_000
    )
    let plan = try SubtitleCollageSelectionPlan(selectedCues: [first, second])
    var continuations: [
        Int: CheckedContinuation<SubtitleCollageRenderedGroup, Never>
    ] = [:]
    var renderCallCount = 0
    let store = PlaybackCollagePreviewStore(
        renderGroup: { _ in
            renderCallCount += 1
            let call = renderCallCount
            return await withCheckedContinuation { continuation in
                continuations[call] = continuation
            }
        },
        compose: { groups in
            collagePreviewComposition(groupCount: groups.count)
        }
    )

    store.update(plan: plan)
    await waitForCollagePreviewCondition {
        continuations.count == 2
    }
    #expect(store.image == nil)

    // The second group lands first and shows alone; Copy and Export wait.
    continuations[2]?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewCondition {
        store.image != nil
    }
    #expect(store.image?.width == 1)
    #expect(store.isRendering)
    #expect(!store.canUseCurrentResult)

    continuations[1]?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewToSettle(store)
    #expect(store.image?.width == 2)
    #expect(store.canUseCurrentResult)

    // Deselecting needs no render: the remaining group is shown from cache.
    store.update(plan: try SubtitleCollageSelectionPlan(selectedCues: [first]))
    await waitForCollagePreviewToSettle(store)
    #expect(renderCallCount == 2)
    #expect(store.image?.width == 1)
    #expect(store.canUseCurrentResult)
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
            collagePreviewComposition(groupCount: groups.count)
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
            collagePreviewComposition(groupCount: groups.count)
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
func playbackCollagePreviewRendersMissingGroupsFourAtATime() async throws {
    var cues: [SubtitleFocusCue] = []
    for index in 0..<5 {
        let offset = index * 3_000
        cues.append(collagePreviewCue(
            id: Int64(50 + index),
            ordinal: index,
            startMilliseconds: 1_000 + offset,
            endMilliseconds: 2_000 + offset
        ))
    }
    let plan = try SubtitleCollageSelectionPlan(selectedCues: cues)
    var continuations: [
        Int: CheckedContinuation<SubtitleCollageRenderedGroup, Never>
    ] = [:]
    var renderCallCount = 0
    let store = PlaybackCollagePreviewStore(
        renderGroup: { _ in
            renderCallCount += 1
            let call = renderCallCount
            return await withCheckedContinuation { continuation in
                continuations[call] = continuation
            }
        },
        compose: { groups in
            collagePreviewComposition(groupCount: groups.count)
        }
    )

    store.update(plan: plan)
    await waitForCollagePreviewCondition {
        continuations.count == 4
    }
    for _ in 0..<50 {
        await Task.yield()
    }
    // The fifth group waits for the batch: four render side by side, no more.
    #expect(renderCallCount == 4)

    for call in 1...4 {
        continuations[call]?.resume(returning: collagePreviewRenderedGroup())
    }
    await waitForCollagePreviewCondition {
        continuations[5] != nil
    }
    #expect(renderCallCount == 5)
    continuations[5]?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewToSettle(store)
    #expect(store.image?.width == 5)
    #expect(store.currentActionResult()?.plan == plan)
}

@MainActor
@Test
func playbackCollagePreviewMovesOnFromAFailedGroupThePlanNoLongerNeeds() async throws {
    let stalePlan = try SubtitleCollageSelectionPlan(selectedCues: [
        collagePreviewCue(
            id: 60,
            ordinal: 0,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000
        )
    ])
    let currentPlan = try SubtitleCollageSelectionPlan(selectedCues: [
        collagePreviewCue(
            id: 61,
            ordinal: 1,
            startMilliseconds: 4_000,
            endMilliseconds: 5_000
        )
    ])
    let failingPlan = try SubtitleCollageSelectionPlan(selectedCues: [
        collagePreviewCue(
            id: 62,
            ordinal: 2,
            startMilliseconds: 7_000,
            endMilliseconds: 8_000
        )
    ])
    var pendingRender: CheckedContinuation<SubtitleCollageRenderedGroup, Error>?
    let store = PlaybackCollagePreviewStore(
        renderGroup: { group in
            if group.cues[0].id == 61 {
                return collagePreviewRenderedGroup()
            }
            return try await withCheckedThrowingContinuation { continuation in
                pendingRender = continuation
            }
        },
        compose: { groups in
            collagePreviewComposition(groupCount: groups.count)
        }
    )

    store.update(plan: stalePlan)
    await waitForCollagePreviewCondition {
        pendingRender != nil
    }
    store.update(plan: currentPlan)
    pendingRender?.resume(
        throwing: PlaybackCollagePreviewError.renderedGroupCountMismatch
    )
    pendingRender = nil
    await waitForCollagePreviewToSettle(store)
    // The failed group is not in the current plan, so the loop moves on to it.
    #expect(store.errorDescription == nil)
    #expect(store.currentActionResult()?.plan == currentPlan)
    #expect(store.image?.width == 1)

    store.update(plan: failingPlan)
    await waitForCollagePreviewCondition {
        pendingRender != nil
    }
    pendingRender?.resume(
        throwing: PlaybackCollagePreviewError.renderedGroupCountMismatch
    )
    await waitForCollagePreviewToSettle(store)
    // The failed group is what the current plan needs, so it is reported.
    #expect(store.errorDescription != nil)
    #expect(store.image == nil)
    #expect(!store.canUseCurrentResult)
}

@MainActor
@Test
func playbackCollagePreviewKeepsAChangedGroupsImageUntilItsNewRenderLands() async throws {
    let second = collagePreviewCue(
        id: 80,
        ordinal: 0,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000
    )
    let third = collagePreviewCue(
        id: 81,
        ordinal: 1,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000
    )
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
            collagePreviewComposition(groupCount: groups.count)
        }
    )

    var plan = try SubtitleCollageSelectionPlan(selectedCues: [second])
    store.update(plan: plan)
    await waitForCollagePreviewToSettle(store)
    #expect(store.image?.width == 1)

    // The third cue shares the second cue's timestamps, so it joins that group
    // and changes it: the group's old image stays in place until the new one.
    _ = plan.select(third)
    #expect(plan.groups.count == 1)
    store.update(plan: plan)
    #expect(store.image?.width == 1)
    #expect(!store.canUseCurrentResult)
    await waitForCollagePreviewCondition {
        pendingRender != nil
    }
    #expect(store.image?.width == 1)

    pendingRender?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewToSettle(store)
    #expect(store.image?.width == 1)
    #expect(store.canUseCurrentResult)
    #expect(store.currentActionResult()?.plan == plan)
    #expect(renderCallCount == 2)
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
            collagePreviewComposition(groupCount: groups.count)
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
func playbackCollagePreviewPublishesASegmentPerDrawnGroup() async throws {
    // One timestamp, so one group; its first cue is the lower reel ordinal.
    let laterInReel = collagePreviewCue(
        id: 80,
        ordinal: 3,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000
    )
    let firstInReel = collagePreviewCue(
        id: 81,
        ordinal: 1,
        startMilliseconds: 1_000,
        endMilliseconds: 2_000
    )
    let second = collagePreviewCue(
        id: 82,
        ordinal: 2,
        startMilliseconds: 4_000,
        endMilliseconds: 5_000
    )
    var continuations: [
        Int: CheckedContinuation<SubtitleCollageRenderedGroup, Never>
    ] = [:]
    var renderCallCount = 0
    let store = PlaybackCollagePreviewStore(
        renderGroup: { _ in
            renderCallCount += 1
            let call = renderCallCount
            return await withCheckedContinuation { continuation in
                continuations[call] = continuation
            }
        },
        compose: { groups in
            SubtitleCollageComposition(
                image: collagePreviewImage(width: groups.count, height: 1),
                groupHeights: groups.indices.map { $0 + 10 }
            )
        }
    )

    var plan = try SubtitleCollageSelectionPlan(
        selectedCues: [laterInReel, firstInReel, second]
    )
    store.update(plan: plan)
    await waitForCollagePreviewCondition {
        continuations.count == 2
    }
    continuations[1]?.resume(returning: collagePreviewRenderedGroup())
    continuations[2]?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewToSettle(store)
    #expect(store.segments == [
        PlaybackCollagePreviewSegment(height: 10, firstCueOrdinal: 1),
        PlaybackCollagePreviewSegment(height: 11, firstCueOrdinal: 2),
    ])

    // Changing the second group keeps its old image in place, and the segment
    // names the group drawn there, not the one it stands in for.
    _ = plan.select(collagePreviewCue(
        id: 83,
        ordinal: 0,
        startMilliseconds: 4_000,
        endMilliseconds: 5_000
    ))
    store.update(plan: plan)
    await waitForCollagePreviewCondition {
        continuations.count == 3
    }
    #expect(store.segments.map(\.firstCueOrdinal) == [1, 2])
    continuations[3]?.resume(returning: collagePreviewRenderedGroup())
    await waitForCollagePreviewToSettle(store)
    #expect(store.segments.map(\.firstCueOrdinal) == [1, 0])

    store.update(plan: SubtitleCollageSelectionPlan())
    #expect(store.image == nil)
    #expect(store.segments.isEmpty)
}

@MainActor
@Test
func playbackCollagePreviewHoverEnlargesOnlyOnRealPointerMovement() throws {
    _ = NSApplication.shared
    let view = PlaybackCollagePreviewScrollContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
    view.layoutSubtreeIfNeeded()
    let segments = [
        PlaybackCollagePreviewSegment(height: 400, firstCueOrdinal: 7),
        PlaybackCollagePreviewSegment(height: 800, firstCueOrdinal: 3),
    ]
    view.updateImage(
        collagePreviewImage(width: 800, height: 1_200),
        segments: segments
    )
    view.layoutSubtreeIfNeeded()
    let hoverScale = WorkbenchControlMetrics.redesignCollageGroupHoverScale

    // Scaled to the 400pt viewport the strips span 0–200 and 200–600.
    view.pointerMoved(toWindowPoint: collagePreviewWindowPoint(fromTop: 50))
    #expect(view.hoveredSegmentIndex == 0)
    #expect(view.hoveredStripScaleForTesting == hoverScale)
    #expect(view.retiringStripIndicesForTesting.isEmpty)

    // Moving on shrinks the first strip while the second grows.
    view.pointerMoved(toWindowPoint: collagePreviewWindowPoint(fromTop: 250))
    #expect(view.hoveredSegmentIndex == 1)
    #expect(view.hoveredStripScaleForTesting == hoverScale)
    #expect(view.retiringStripIndicesForTesting == [0])

    // The enlarged strip is hit as far as it has grown: 2pt above its rest
    // edge, and past the image's left edge.
    view.pointerMoved(toWindowPoint: collagePreviewWindowPoint(fromTop: 199))
    #expect(view.hoveredSegmentIndex == 1)
    view.pointerMoved(toWindowPoint: CGPoint(x: -2, y: 300 - 250))
    #expect(view.hoveredSegmentIndex == 1)
    // Not hovered, that same point is outside the image.
    view.pointerMoved(toWindowPoint: collagePreviewWindowPoint(fromTop: 100))
    #expect(view.hoveredSegmentIndex == 0)
    view.pointerMoved(toWindowPoint: CGPoint(x: -2, y: 300 - 250))
    #expect(view.hoveredSegmentIndex == nil)

    // A new picture ends the hover until the pointer moves again; the strip
    // under the still pointer inherits the size and shrinks back.
    view.pointerMoved(toWindowPoint: collagePreviewWindowPoint(fromTop: 250))
    #expect(view.hoveredSegmentIndex == 1)
    view.updateImage(
        collagePreviewImage(width: 800, height: 1_200),
        segments: segments
    )
    #expect(view.hoveredSegmentIndex == nil)
    #expect(view.hoveredStripScaleForTesting == nil)
    #expect(view.retiringStripIndicesForTesting == [1])
    view.pointerMoved(toWindowPoint: collagePreviewWindowPoint(fromTop: 250))
    #expect(view.hoveredSegmentIndex == 1)

    // Frozen, the hover keeps the strip it had.
    view.isInteractionEnabled = false
    view.pointerMoved(toWindowPoint: collagePreviewWindowPoint(fromTop: 50))
    #expect(view.hoveredSegmentIndex == 1)
    view.isInteractionEnabled = true

    // Outside the viewport there is no strip; a picture arriving with no
    // strip under the pointer has nothing to hand its size to.
    view.pointerMoved(toWindowPoint: collagePreviewWindowPoint(fromTop: 350))
    #expect(view.hoveredSegmentIndex == nil)
    view.updateImage(
        collagePreviewImage(width: 800, height: 1_200),
        segments: segments
    )
    #expect(view.retiringStripIndicesForTesting.isEmpty)
}

@MainActor
@Test
func playbackCollagePreviewClickJumpsToTheStripReleasedOn() throws {
    _ = NSApplication.shared
    let view = PlaybackCollagePreviewScrollContainerView()
    view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
    view.layoutSubtreeIfNeeded()
    view.updateImage(
        collagePreviewImage(width: 800, height: 1_200),
        segments: [
            PlaybackCollagePreviewSegment(height: 400, firstCueOrdinal: 7),
            PlaybackCollagePreviewSegment(height: 800, firstCueOrdinal: 3),
        ]
    )
    view.layoutSubtreeIfNeeded()
    var jumped: [Int] = []
    view.onJumpToCue = { jumped.append($0) }

    view.press(atWindowPoint: collagePreviewWindowPoint(fromTop: 250))
    view.release(atWindowPoint: collagePreviewWindowPoint(fromTop: 250))
    #expect(jumped == [3])
    #expect(view.hoveredSegmentIndex == 1)

    // Released on another strip, or off the image, nothing happens.
    view.press(atWindowPoint: collagePreviewWindowPoint(fromTop: 50))
    view.release(atWindowPoint: collagePreviewWindowPoint(fromTop: 250))
    view.press(atWindowPoint: collagePreviewWindowPoint(fromTop: 250))
    view.release(atWindowPoint: collagePreviewWindowPoint(fromTop: 350))
    #expect(jumped == [3])

    view.isInteractionEnabled = false
    view.press(atWindowPoint: collagePreviewWindowPoint(fromTop: 50))
    view.release(atWindowPoint: collagePreviewWindowPoint(fromTop: 50))
    #expect(jumped == [3])
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

/// Without a window, a view converts "window" points from the unflipped base
/// coordinates of its top-level view, so a point measured from the top of the
/// 300pt-tall container is given as its distance from the bottom.
private func collagePreviewWindowPoint(fromTop y: CGFloat) -> CGPoint {
    CGPoint(x: 100, y: 300 - y)
}

private func collagePreviewComposition(
    groupCount: Int
) -> SubtitleCollageComposition {
    SubtitleCollageComposition(
        image: collagePreviewImage(width: groupCount, height: 1),
        groupHeights: Array(repeating: 1, count: groupCount)
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
