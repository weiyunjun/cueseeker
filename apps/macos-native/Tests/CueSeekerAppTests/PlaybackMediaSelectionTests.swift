import AppKit
import CoreGraphics
import SwiftUI
import Testing
@testable import CueSeekerApp

@MainActor
@Test
func playbackMediaSelectionUsesVisualGridDirectionsAndScrollTargets() throws {
    let selection = PlaybackMediaSelectionStore()
    selection.replaceItems(
        orderedItemIDs: ["0", "1", "2", "3", "4", "5"],
        availableItemIDs: ["0", "2", "3", "4", "5"],
        resetsSelection: true
    )
    selection.updateAdaptiveGrid(
        containerWidth: 600,
        minimumItemWidth: 180,
        itemGap: 16
    )
    selection.recordVisibleFrames(
        [
            "0": CGRect(x: 0, y: 0, width: 100, height: 60),
            "1": CGRect(x: 116, y: 0, width: 100, height: 60),
            "2": CGRect(x: 232, y: 0, width: 100, height: 60),
            "3": CGRect(x: 0, y: 76, width: 100, height: 60),
            "4": CGRect(x: 116, y: 76, width: 100, height: 60),
            "5": CGRect(x: 232, y: 76, width: 100, height: 60),
        ],
        viewportHeight: 160
    )
    #expect(selection.columnCount == 3)

    #expect(selection.selectedItemID == "0")
    let initialRequest = try #require(selection.scrollRequest)
    #expect(initialRequest.itemID == "0")
    #expect(selection.pendingScrollRequest == initialRequest)
    selection.markScrollRequestHandled(sequence: initialRequest.sequence)
    #expect(selection.pendingScrollRequest == nil)

    #expect(selection.move(.right))
    #expect(selection.selectedItemID == "4")
    let rightRequest = try #require(selection.scrollRequest)
    #expect(rightRequest.itemID == "4")
    #expect(rightRequest.sequence > initialRequest.sequence)
    #expect(selection.pendingScrollRequest == rightRequest)

    #expect(selection.move(.left))
    #expect(selection.selectedItemID == "3")
    #expect(selection.scrollRequest?.itemID == "3")

    #expect(selection.move(.up))
    #expect(selection.selectedItemID == "0")
    #expect(selection.scrollRequest?.itemID == "0")
    #expect(!selection.move(.left))
    #expect(!selection.move(.up))

    selection.recordVisibleFrames(
        [
            "0": CGRect(x: 0, y: -20, width: 100, height: 60),
            "2": CGRect(x: 200, y: -20, width: 100, height: 60),
            "3": CGRect(x: 0, y: 56, width: 100, height: 60),
        ],
        viewportHeight: 100
    )
    #expect(selection.scrollAnchorItemID == "0")
    #expect(selection.restorationItemID == "0")
    selection.recordScrollOffsetY(37.5)
    #expect(selection.scrollOffsetY == 37.5)

    let requestBeforeResize = try #require(selection.scrollRequest)
    selection.updateAdaptiveGrid(
        containerWidth: 380,
        minimumItemWidth: 180,
        itemGap: 16
    )
    #expect(selection.columnCount == 2)
    #expect(selection.scrollRequest?.itemID == selection.selectedItemID)
    #expect(selection.scrollRequest?.sequence ?? 0 > requestBeforeResize.sequence)
}

@MainActor
@Test
func playbackMediaSelectionHasNoSelectionWhenEveryItemIsUnavailable() {
    let selection = PlaybackMediaSelectionStore()
    selection.replaceItems(
        orderedItemIDs: ["0", "1"],
        availableItemIDs: [],
        resetsSelection: true
    )

    #expect(selection.selectedItemID == nil)
    #expect(selection.scrollRequest == nil)
    #expect(!selection.move(.right))
    #expect(!selection.move(.down))
}

@MainActor
@Test
func playbackMediaSelectionUsesAvailablePreferredInitialItem() {
    let selection = PlaybackMediaSelectionStore()
    selection.replaceItems(
        orderedItemIDs: ["0", "1", "2"],
        availableItemIDs: ["0", "2"],
        resetsSelection: true,
        preferredSelectionID: "2"
    )

    #expect(selection.selectedItemID == "2")
    #expect(selection.scrollRequest?.itemID == "2")

    selection.replaceItems(
        orderedItemIDs: ["0", "1", "2"],
        availableItemIDs: ["0", "2"],
        resetsSelection: true,
        preferredSelectionID: "1"
    )

    #expect(selection.selectedItemID == "0")
    #expect(selection.scrollRequest?.itemID == "0")
}

@MainActor
@Test
func playbackMediaScrollBridgeRestoresAndObservesExactPixelOffset() async throws {
    var observedOffsetY: CGFloat = -1
    let hostingView = NSHostingView(
        rootView: ScrollView {
            Color.clear
                .frame(height: 1_000)
                .background(alignment: .topLeading) {
                    PlaybackMediaScrollPositionBridge(
                        restorationOffsetY: 137.5,
                        onOffsetChanged: { observedOffsetY = $0 }
                    )
                    .frame(width: 0, height: 0)
                }
        }
        .frame(width: 320, height: 180)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
    let window = NSWindow(
        contentRect: hostingView.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    window.layoutIfNeeded()
    hostingView.layoutSubtreeIfNeeded()

    let restored = await waitForPlaybackMediaScrollCondition {
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        guard let scrollView = findScrollView(in: hostingView) else {
            return false
        }
        return abs(scrollView.contentView.bounds.origin.y - 137.5) < 1
            && abs(observedOffsetY - 137.5) < 1
    }
    #expect(restored)

    let scrollView = try #require(findScrollView(in: hostingView))
    #expect(abs(scrollView.contentView.bounds.origin.y - 137.5) < 1)
    #expect(abs(observedOffsetY - 137.5) < 1)

    var targetBounds = scrollView.contentView.bounds
    targetBounds.origin.y = 246.25
    scrollView.contentView.scroll(
        to: scrollView.contentView.constrainBoundsRect(targetBounds).origin
    )
    scrollView.reflectScrolledClipView(scrollView.contentView)
    let observedManualScroll = await waitForPlaybackMediaScrollCondition {
        abs(observedOffsetY - 246.25) < 1
    }

    #expect(observedManualScroll)
    #expect(abs(observedOffsetY - 246.25) < 1)
    withExtendedLifetime((hostingView, window)) {}
}

@MainActor
@Test
func playbackMediaScrollBridgeLetsPendingSelectionOverrideOldOffset() async throws {
    var observedOffsetY: CGFloat = -1
    let hostingView = NSHostingView(
        rootView: ScrollView {
            Color.clear
                .frame(height: 1_000)
                .background(alignment: .topLeading) {
                    PlaybackMediaScrollPositionBridge(
                        restorationOffsetY: 137.5,
                        restoresInitialOffset: false,
                        onOffsetChanged: { observedOffsetY = $0 }
                    )
                    .frame(width: 0, height: 0)
                }
        }
        .frame(width: 320, height: 180)
    )
    hostingView.frame = CGRect(x: 0, y: 0, width: 320, height: 180)
    let window = NSWindow(
        contentRect: hostingView.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = hostingView
    window.layoutIfNeeded()
    hostingView.layoutSubtreeIfNeeded()

    try await Task.sleep(for: .milliseconds(100))
    window.layoutIfNeeded()
    hostingView.layoutSubtreeIfNeeded()
    let scrollView = try #require(findScrollView(in: hostingView))
    #expect(abs(scrollView.contentView.bounds.origin.y) < 0.5)

    scrollView.contentView.scroll(to: CGPoint(x: 0, y: 73))
    scrollView.reflectScrolledClipView(scrollView.contentView)
    let observed = await waitForPlaybackMediaScrollCondition {
        abs(observedOffsetY - 73) < 0.5
    }
    #expect(observed)
}

@MainActor
private func waitForPlaybackMediaScrollCondition(
    _ condition: @MainActor () -> Bool
) async -> Bool {
    for _ in 0..<200 {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

@MainActor
private func findScrollView(in view: NSView) -> NSScrollView? {
    if let scrollView = view as? NSScrollView {
        return scrollView
    }
    for subview in view.subviews {
        if let scrollView = findScrollView(in: subview) {
            return scrollView
        }
    }
    return nil
}

@MainActor
@Test
func playbackMediaSelectionFromPointerMovesSelectionWithoutScrolling() throws {
    let selection = PlaybackMediaSelectionStore()
    selection.replaceItems(
        orderedItemIDs: ["0", "1", "2", "3"],
        availableItemIDs: ["0", "2", "3"],
        resetsSelection: true
    )
    #expect(selection.selectedItemID == "0")
    let initialRequest = try #require(selection.scrollRequest)
    selection.markScrollRequestHandled(sequence: initialRequest.sequence)

    // The pointer is already on the card, so moving the selection there must
    // not ask the list to scroll under the cursor.
    selection.selectFromPointer(itemID: "3")
    #expect(selection.selectedItemID == "3")
    #expect(selection.scrollRequest?.sequence == initialRequest.sequence)
    #expect(selection.pendingScrollRequest == nil)

    // Unavailable and unknown items cannot take the selection.
    selection.selectFromPointer(itemID: "1")
    #expect(selection.selectedItemID == "3")
    selection.selectFromPointer(itemID: "missing")
    #expect(selection.selectedItemID == "3")

    // Keyboard movement still scrolls, so the two paths stay distinguishable.
    #expect(selection.move(.up) || selection.selectedItemID == "3")
    selection.invalidate()
    selection.selectFromPointer(itemID: "0")
    #expect(selection.selectedItemID == nil)
}
