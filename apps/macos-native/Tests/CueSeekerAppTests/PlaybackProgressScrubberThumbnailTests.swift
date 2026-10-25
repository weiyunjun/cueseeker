import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import CueSeekerApp
@testable import CueSeekerPlayback

@Suite(.serialized)
struct PlaybackProgressScrubberThumbnailTests {
@MainActor
@Test
func progressThumbnailTokensAndGeometryFollowSpec() {
    #expect(PlaybackChromeMetrics.progressThumbnailWidth == 240)
    #expect(PlaybackChromeMetrics.progressThumbnailRadius == 8)
    #expect(PlaybackChromeMetrics.progressThumbnailGap == 4)
    #expect(PlaybackChromeMetrics.progressWindowEdgeClampInset == 4)

    let size16x9 = PlaybackChromeMetrics.progressThumbnailSize(aspectRatio: 16.0 / 9.0)
    #expect(size16x9 == CGSize(width: 240, height: 135))

    let size4x3 = PlaybackChromeMetrics.progressThumbnailSize(aspectRatio: 4.0 / 3.0)
    #expect(size4x3 == CGSize(width: 240, height: 180))

    let size21x9 = PlaybackChromeMetrics.progressThumbnailSize(aspectRatio: 2.39)
    #expect(size21x9 == CGSize(width: 240, height: 100))

    let fallbackSize = PlaybackChromeMetrics.progressThumbnailSize(aspectRatio: 0)
    #expect(fallbackSize == CGSize(width: 240, height: 135))

    let yOffset = PlaybackChromeMetrics.progressThumbnailYOffset(thumbnailHeight: 135)
    // Time capsule top is at -26 (-22 height - 4 gap), thumbnail bottom is 4px above it (-30), so top is -165.
    #expect(yOffset == -165)
}

@MainActor
@Test
func progressThumbnailAndTimeCapsuleClampAgainstWindowEdgesWithSpacing1Inset() {
    let windowWidth: CGFloat = 1_000
    let scrubberOriginXInWindow: CGFloat = 80
    let scrubberWidth: CGFloat = 840
    let thumbnailWidth = PlaybackChromeMetrics.progressThumbnailWidth // 240
    let capsuleWidth: CGFloat = 46

    // Left end of progress bar (targetX = 0, which is x = 80 in window):
    // Thumbnail ideal x in scrubber coords is -120 (x = -40 in window), so it clamps to -76 (x = 4 in window, 4px inset).
    // Time capsule ideal x in scrubber coords is -23 (x = 57 in window), so it stays centered on targetX = 0.
    let leftThumbnailX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 0,
        capsuleWidth: thumbnailWidth,
        containerWidth: scrubberWidth,
        containerOriginXInWindow: scrubberOriginXInWindow,
        windowWidth: windowWidth
    )
    let leftCapsuleX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 0,
        capsuleWidth: capsuleWidth,
        containerWidth: scrubberWidth,
        containerOriginXInWindow: scrubberOriginXInWindow,
        windowWidth: windowWidth
    )
    #expect(leftThumbnailX == -76)
    #expect(leftThumbnailX + scrubberOriginXInWindow == 4)
    #expect(leftCapsuleX == -23)

    // Middle of progress bar (targetX = 420): both center on 420.
    let centerThumbnailX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 420,
        capsuleWidth: thumbnailWidth,
        containerWidth: scrubberWidth,
        containerOriginXInWindow: scrubberOriginXInWindow,
        windowWidth: windowWidth
    )
    let centerCapsuleX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 420,
        capsuleWidth: capsuleWidth,
        containerWidth: scrubberWidth,
        containerOriginXInWindow: scrubberOriginXInWindow,
        windowWidth: windowWidth
    )
    #expect(centerThumbnailX == 300)
    #expect(centerCapsuleX == 397)

    // Right end of progress bar (targetX = 840, which is x = 920 in window):
    // Thumbnail ideal x in scrubber coords is 720 (right edge at 720 + 80 + 240 = 1040 in window),
    // so it clamps to 676 (right edge at 676 + 80 + 240 = 996 = 1000 - 4 in window).
    // Time capsule ideal x in scrubber coords is 817 (right edge at 817 + 80 + 46 = 943 <= 996), so it stays centered.
    let rightThumbnailX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 840,
        capsuleWidth: thumbnailWidth,
        containerWidth: scrubberWidth,
        containerOriginXInWindow: scrubberOriginXInWindow,
        windowWidth: windowWidth
    )
    let rightCapsuleX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 840,
        capsuleWidth: capsuleWidth,
        containerWidth: scrubberWidth,
        containerOriginXInWindow: scrubberOriginXInWindow,
        windowWidth: windowWidth
    )
    #expect(rightThumbnailX == 676)
    #expect(rightThumbnailX + scrubberOriginXInWindow + thumbnailWidth == windowWidth - 4)
    #expect(rightCapsuleX == 817)
}

@MainActor
@Test
func timelineThumbnailStoreFiresImmediatelyWhenIdleAndCoalescesToLatestWhileInFlight() throws {
    let image0 = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 40))
    let image2000 = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 120))
    let image6000 = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 220))

    var requestedTargets: [(milliseconds: Int, pixelWidth: Int)] = []
    var pendingCompletion: (@MainActor (CGImage?, Int, CGSize?) -> Void)?
    var cancelCallCount = 0

    // Keyframes every 2000ms: [0, 2000, 4000, 6000]
    let store = PlaybackTimelineThumbnailStore(
        keyframeLookup: { ms in
            (max(0, ms) / 2_000) * 2_000
        },
        requestThumbnail: { milliseconds, targetPixelWidth, completion in
            requestedTargets.append((milliseconds, targetPixelWidth))
            pendingCompletion = completion
        },
        cancelRequests: {
            cancelCallCount += 1
        }
    )

    // 1. First hover enters at 0.3s (keyframe 0ms): fires immediately (0ms), no placeholder before decode finishes.
    store.updatePreview(forSeconds: 0.3, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 1)
    #expect(requestedTargets[0].milliseconds == 300)
    #expect(requestedTargets[0].pixelWidth == 480)
    #expect(store.thumbnailImage == nil)

    // 2. Micro-movement within the same keyframe interval (0.8s -> keyframe 0ms) while in-flight: no duplicate request.
    store.updatePreview(forSeconds: 0.8, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 1)

    // Complete first decode: image0 appears and aspect ratio updates.
    pendingCompletion?(image0, 0, CGSize(width: 1920, height: 1080))
    #expect(store.thumbnailImage === image0)
    #expect(store.thumbnailAspectRatio == 16.0 / 9.0)

    // 3. Another move within keyframe 0ms (1.5s -> keyframe 0ms): still 1 request, keeps image0.
    store.updatePreview(forSeconds: 1.5, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 1)
    #expect(store.thumbnailImage === image0)

    // 4. Cross into keyframe 2000ms (at 2.2s) while idle: fires immediately (0ms)!
    store.updatePreview(forSeconds: 2.2, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 2)
    #expect(requestedTargets[1].milliseconds == 2_200)
    // Previous thumbnail stays visible until the new keyframe finishes decoding.
    #expect(store.thumbnailImage === image0)

    // 5. While keyframe 2000ms is in-flight, user scrubs rapidly across keyframe 4000ms (4.3s) to keyframe 6000ms (6.4s):
    //    Should coalesce intermediate keyframes and keep only the latest target (6.4s -> keyframe 6000ms).
    store.updatePreview(forSeconds: 4.3, backingScaleFactor: 2.0)
    store.updatePreview(forSeconds: 6.4, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 2)

    // As soon as keyframe 2000ms finishes decoding, image2000 is displayed AND keyframe 6000ms starts immediately!
    let completionFor2000 = pendingCompletion
    completionFor2000?(image2000, 2_000, CGSize(width: 1920, height: 1080))
    #expect(store.thumbnailImage === image2000)
    #expect(requestedTargets.count == 3)
    #expect(requestedTargets[2].milliseconds == 6_400)

    // Complete keyframe 6000ms: image6000 is displayed and no further request is pending.
    pendingCompletion?(image6000, 6_000, CGSize(width: 1920, height: 1080))
    #expect(store.thumbnailImage === image6000)
    #expect(requestedTargets.count == 3)

    // 6. Clear when pointer exits scrubber: immediately clears image, aspect ratio, and cancels native decoder.
    store.clear()
    #expect(store.thumbnailImage == nil)
    #expect(store.thumbnailAspectRatio == nil)
    #expect(cancelCallCount == 1)
}

@MainActor
@Test
func scrubberHoverStateKeepsReleasePositionInsideHitAreaAndClearsOutsideHitArea() {
    var state = PlaybackProgressScrubberHoverState()
    let trackWidth: CGFloat = 800

    // Hover enters at x = 100 (drag start).
    state.handlePointerHover(true)
    state.handleContinuousHoverActive(x: 100)
    #expect(state.hoverX == 100)
    #expect(state.isHoveringScrubber == true)
    #expect(state.isHovered == true)

    // User drags to x = 520; during drag on macOS, .onContinuousHover may fire .ended if cursor drifts vertically,
    // which must be ignored while dragging, and hoverX must track the drag location.
    let draggedX = state.handleDragChanged(locationX: 520, trackWidth: trackWidth)
    state.handleContinuousHoverEnded()
    #expect(draggedX == 520)
    #expect(state.isDragging == true)
    #expect(state.hoverX == 520)

    // Release inside the 18px hit area at (520, 9): hoverX stays at 520 (does NOT flash back to 100).
    let releasedInsideX = state.handleDragEnded(
        location: CGPoint(x: 520, y: 9),
        trackWidth: trackWidth,
        hitAreaHeight: 18
    )
    #expect(releasedInsideX == 520)
    #expect(state.isDragging == false)
    #expect(state.hoverX == 520)
    #expect(state.isHoveringScrubber == true)
    #expect(state.isHovered == true)

    // Start another drag to x = 680, then release outside the hit area at (680, -30):
    _ = state.handleDragChanged(locationX: 680, trackWidth: trackWidth)
    let releasedOutsideX = state.handleDragEnded(
        location: CGPoint(x: 680, y: -30),
        trackWidth: trackWidth,
        hitAreaHeight: 18
    )
    #expect(releasedOutsideX == 680)
    #expect(state.isDragging == false)
    #expect(state.hoverX == nil)
    #expect(state.isHoveringScrubber == false)
    #expect(state.isHovered == false)
}

@MainActor
@Test
func scrubberFreezesHoverLocationAndThumbnailWhileUpperLayerIsOpenAndRestoresStationaryPointerOnClose() throws {
    AppCursorVisibility.resetForTesting()
    PointerHoverScrollState.shared.resetForTesting()
    defer { PointerHoverScrollState.shared.resetForTesting() }

    let imageA = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 60))
    let imageB = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 180))

    var requestedMilliseconds: [Int] = []
    var cancelCount = 0

    let player = PlaybackPlayer()
    let viewModel = PlaybackViewModel(player: player)
    viewModel.duration = 1_000
    viewModel.timelineThumbnailStore = PlaybackTimelineThumbnailStore(
        keyframeLookup: { ms in (max(0, ms) / 1_000) * 1_000 },
        requestThumbnail: { milliseconds, _, completion in
            requestedMilliseconds.append(milliseconds)
            completion(milliseconds < 300_000 ? imageA : imageB, milliseconds, CGSize(width: 1920, height: 1080))
        },
        cancelRequests: {
            cancelCount += 1
        }
    )

    let timeline = PlaybackTimelineInteractionStore()
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.playbackPage, true)

    let rootView = VStack(spacing: 0) {
        Spacer(minLength: 0)
        PlaybackProgressScrubber(
            viewModel: viewModel,
            timeline: timeline,
            windowWidth: 800
        )
        .frame(width: 800, height: PlaybackChromeMetrics.progressHitAreaHeight)
    }
    .frame(width: 800, height: 200)
    .interfaceLayer(.playbackPage)
    .modifier(InterfaceLayerCoverageBridge(layers: layers))

    let window = CueSeekerWindow(
        contentRect: NSRect(x: -5_000, y: -5_000, width: 800, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.isWindowFocusedOverrideForTesting = true
    let host = CueSeekerHostingView(rootView: rootView)
    window.contentView = host
    window.orderFrontRegardless()
    defer {
        window.contentView = nil
        window.orderOut(nil)
    }
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

    func sendMouseMoved(at point: CGPoint) {
        host.mouseLocationOverrideForTesting = point
        if let event = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: point,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ) {
            host.mouseMoved(with: event)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    }

    // 1. Hover scrubber at x = 160 (20% of 800 -> 200,000 ms), y = 9 (inside bottom 18pt hit area):
    sendMouseMoved(at: CGPoint(x: 160, y: 9))
    #expect(requestedMilliseconds == [200_000])
    #expect(viewModel.timelineThumbnailStore.thumbnailImage === imageA)
    #expect(cancelCount == 0)

    // 2. Scenario A: Open Command Panel (`K`), then move pointer along the scrubber to x = 480 (600,000 ms)
    //    and then move pointer completely outside the scrubber to (480, 120):
    //    Scrubber must remain frozen at 200,000 ms (imageA stays displayed, no new request, no clear).
    layers.setOpen(.commandPanel, true)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    #expect(layers.isFrozen(.playbackPage))

    sendMouseMoved(at: CGPoint(x: 480, y: 9))
    #expect(requestedMilliseconds == [200_000])
    #expect(viewModel.timelineThumbnailStore.thumbnailImage === imageA)
    #expect(cancelCount == 0)

    sendMouseMoved(at: CGPoint(x: 480, y: 120))
    #expect(requestedMilliseconds == [200_000])
    #expect(viewModel.timelineThumbnailStore.thumbnailImage === imageA)
    #expect(cancelCount == 0)

    // 3. Close Command Panel (`Esc`) while pointer is stationary outside at (480, 120):
    //    Scrubber immediately unfreezes and clears the frozen thumbnail without requiring mouse movement.
    layers.setOpen(.commandPanel, false)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    #expect(!layers.isFrozen(.playbackPage))
    #expect(viewModel.timelineThumbnailStore.thumbnailImage == nil)
    #expect(cancelCount == 1)

    // 4. Scenario B: Open Command Panel (`K`) while unhovered, move pointer onto scrubber at x = 480 (600,000 ms)
    //    and stop there, then press `Esc` to close Command Panel without moving the mouse again:
    //    While Command Panel is open, no thumbnail is requested; the instant Command Panel closes,
    //    the stationary pointer at x = 480 immediately triggers the thumbnail at 600,000 ms!
    layers.setOpen(.commandPanel, true)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    sendMouseMoved(at: CGPoint(x: 480, y: 9))
    #expect(requestedMilliseconds == [200_000])
    #expect(viewModel.timelineThumbnailStore.thumbnailImage == nil)

    layers.setOpen(.commandPanel, false)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    #expect(requestedMilliseconds == [200_000, 600_000])
    #expect(viewModel.timelineThumbnailStore.thumbnailImage === imageB)
}

@MainActor
@Test
func stationaryScrubberPointerRefreshesThumbnailWhenSwitchingToEpisodeWithIdenticalDuration() throws {
    AppCursorVisibility.resetForTesting()
    PointerHoverScrollState.shared.resetForTesting()
    defer { PointerHoverScrollState.shared.resetForTesting() }

    let episode1Image = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 70))
    let episode2Image = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 200))

    var activeEpisode = 1
    var requestedEpisodesAndMilliseconds: [(episode: Int, milliseconds: Int)] = []

    let player = PlaybackPlayer()
    let viewModel = PlaybackViewModel(player: player)
    // Both Episode 1 and Episode 2 have the exact same duration (1421.090s).
    let sharedDuration = 1_421.090
    viewModel.duration = sharedDuration
    viewModel.timelineThumbnailStore = PlaybackTimelineThumbnailStore(
        keyframeLookup: { ms in (max(0, ms) / 2_000) * 2_000 },
        requestThumbnail: { milliseconds, _, completion in
            requestedEpisodesAndMilliseconds.append((activeEpisode, milliseconds))
            let image = activeEpisode == 1 ? episode1Image : episode2Image
            completion(image, milliseconds, CGSize(width: 1920, height: 1080))
        },
        cancelRequests: {}
    )

    let timeline = PlaybackTimelineInteractionStore()
    let layers = InterfaceLayerRegistry()
    layers.setOpen(.playbackPage, true)

    let rootView = VStack(spacing: 0) {
        Spacer(minLength: 0)
        PlaybackProgressScrubber(
            viewModel: viewModel,
            timeline: timeline,
            windowWidth: 800
        )
        .frame(width: 800, height: PlaybackChromeMetrics.progressHitAreaHeight)
    }
    .frame(width: 800, height: 200)
    .interfaceLayer(.playbackPage)
    .modifier(InterfaceLayerCoverageBridge(layers: layers))

    let window = CueSeekerWindow(
        contentRect: NSRect(x: -5_000, y: -5_000, width: 800, height: 200),
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.isWindowFocusedOverrideForTesting = true
    let host = CueSeekerHostingView(rootView: rootView)
    window.contentView = host
    window.orderFrontRegardless()
    defer {
        window.contentView = nil
        window.orderOut(nil)
    }
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

    // 1. Hover near the end of Episode 1 (x = 799 of 800 -> ~1419.314s = 23:39) and keep pointer stationary:
    let stationaryPoint = CGPoint(x: 799, y: 9)
    host.mouseLocationOverrideForTesting = stationaryPoint
    if let event = NSEvent.mouseEvent(
        with: .mouseMoved,
        location: stationaryPoint,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 0,
        pressure: 0
    ) {
        host.mouseMoved(with: event)
    }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))

    #expect(requestedEpisodesAndMilliseconds.count == 1)
    #expect(requestedEpisodesAndMilliseconds[0].episode == 1)
    #expect(viewModel.timelineThumbnailStore.thumbnailImage === episode1Image)

    // 2. Episode 1 finishes and switches to Episode 2 (which has the exact same duration 1421.090s)
    //    while the pointer remains completely stationary on the progress bar:
    activeEpisode = 2
    viewModel.playerDidResetTimelineThumbnails(player)
    #expect(viewModel.timelineThumbnailStore.thumbnailImage == nil)

    // Simulate Episode 2 committing its presentation with the identical duration (1421.090s):
    viewModel.player(player, didUpdateDuration: sharedDuration)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

    // Without moving the mouse, Episode 2's thumbnail at the stationary position is immediately fetched and displayed!
    #expect(requestedEpisodesAndMilliseconds.count == 2)
    #expect(requestedEpisodesAndMilliseconds[1].episode == 2)
    #expect(requestedEpisodesAndMilliseconds[1].milliseconds == requestedEpisodesAndMilliseconds[0].milliseconds)
    #expect(viewModel.timelineThumbnailStore.thumbnailImage === episode2Image)
}

private func makeTestSolidCGImage(
    width: Int,
    height: Int,
    gray: UInt8
) -> CGImage? {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    var pixels = [UInt8](repeating: gray, count: height * bytesPerRow)
    for index in stride(from: 3, to: pixels.count, by: 4) {
        pixels[index] = 255
    }
    let data = Data(pixels) as CFData
    guard let provider = CGDataProvider(data: data),
          let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    else {
        return nil
    }
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )
}
}
