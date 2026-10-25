import CoreGraphics
import Foundation
import Testing
@testable import CueSeekerApp
@testable import CueSeekerPlayback

@MainActor
@Test
func progressThumbnailTokensAndGeometryFollowSpec() {
    #expect(PlaybackChromeMetrics.progressThumbnailWidth == 160)
    #expect(PlaybackChromeMetrics.progressThumbnailRadius == 8)
    #expect(PlaybackChromeMetrics.progressThumbnailGap == 4)
    #expect(PlaybackChromeMetrics.progressWindowEdgeClampInset == 4)

    let size16x9 = PlaybackChromeMetrics.progressThumbnailSize(aspectRatio: 16.0 / 9.0)
    #expect(size16x9 == CGSize(width: 160, height: 90))

    let size4x3 = PlaybackChromeMetrics.progressThumbnailSize(aspectRatio: 4.0 / 3.0)
    #expect(size4x3 == CGSize(width: 160, height: 120))

    let size21x9 = PlaybackChromeMetrics.progressThumbnailSize(aspectRatio: 2.39)
    #expect(size21x9 == CGSize(width: 160, height: 67))

    let fallbackSize = PlaybackChromeMetrics.progressThumbnailSize(aspectRatio: 0)
    #expect(fallbackSize == CGSize(width: 160, height: 90))

    let yOffset = PlaybackChromeMetrics.progressThumbnailYOffset(thumbnailHeight: 90)
    // Time capsule top is at -26 (-22 height - 4 gap), thumbnail bottom is 4px above it (-30), so top is -120.
    #expect(yOffset == -120)
}

@MainActor
@Test
func progressThumbnailAndTimeCapsuleClampAgainstWindowEdgesWithSpacing1Inset() {
    let windowWidth: CGFloat = 1_000
    let scrubberOriginXInWindow: CGFloat = 80
    let scrubberWidth: CGFloat = 840
    let thumbnailWidth = PlaybackChromeMetrics.progressThumbnailWidth // 160
    let capsuleWidth: CGFloat = 46

    // Left end of progress bar (targetX = 0, which is x = 80 in window):
    // Thumbnail ideal x in scrubber coords is -80 (x = 0 in window), so it clamps to -76 (x = 4 in window, 4px inset).
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
    #expect(centerThumbnailX == 340)
    #expect(centerCapsuleX == 397)

    // Right end of progress bar (targetX = 840, which is x = 920 in window):
    // Thumbnail ideal x in scrubber coords is 760 (right edge at 760 + 80 + 160 = 1000 in window),
    // so it clamps to 756 (right edge at 756 + 80 + 160 = 996 = 1000 - 4 in window).
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
    #expect(rightThumbnailX == 756)
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
    #expect(requestedTargets[0].pixelWidth == 320)
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
