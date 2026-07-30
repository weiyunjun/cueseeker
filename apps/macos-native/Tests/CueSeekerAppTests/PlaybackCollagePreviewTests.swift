import AppKit
import CoreGraphics
import CueSeekerCore
import CueSeekerPlayback
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
    var renderedBatches: [[SubtitleCollageGroup]] = []
    var composedGroupCounts: [Int] = []
    let store = PlaybackCollagePreviewStore(
        renderGroups: { groups in
            renderedBatches.append(groups)
            return groups.map { _ in collagePreviewRenderedGroup() }
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

    #expect(renderedBatches.map(\.count) == [3, 1])
    #expect(renderedBatches[1][0] == plan.groups[1])
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
        Int: CheckedContinuation<[SubtitleCollageRenderedGroup], Never>
    ] = [:]
    let store = PlaybackCollagePreviewStore(
        renderGroups: { groups in
            await withCheckedContinuation { continuation in
                continuations[groups.count] = continuation
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
    store.update(plan: secondPlan)
    #expect(!store.canUseCurrentResult)
    await waitForCollagePreviewCondition {
        continuations[2] != nil
    }

    continuations[2]?.resume(
        returning: Array(repeating: collagePreviewRenderedGroup(), count: 2)
    )
    await waitForCollagePreviewToSettle(store)
    #expect(store.image?.width == 2)
    #expect(store.canUseCurrentResult)
    #expect(store.currentActionResult()?.plan == secondPlan)
    #expect(store.currentActionResult()?.image.width == 2)

    continuations[1]?.resume(
        returning: [collagePreviewRenderedGroup()]
    )
    for _ in 0..<20 {
        await Task.yield()
    }
    #expect(store.image?.width == 2)
    #expect(store.currentActionResult()?.plan == secondPlan)
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
        [SubtitleCollageRenderedGroup],
        Never
    >?
    let store = PlaybackCollagePreviewStore(
        renderGroups: { groups in
            renderCallCount += 1
            if renderCallCount == 2 {
                return await withCheckedContinuation { continuation in
                    pendingRender = continuation
                }
            }
            return groups.map { _ in collagePreviewRenderedGroup() }
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

    pendingRender?.resume(returning: [collagePreviewRenderedGroup()])
    await waitForCollagePreviewToSettle(store)
    #expect(store.currentActionResult()?.plan == secondPlan)
    #expect(store.currentActionResult()?.image.width == 2)
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
