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
    #expect(PlaybackChromeMetrics.progressThumbnailDebounceDelay == 0.03)

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
func progressThumbnailAndTimeCapsuleClampIndependentlyAtTrackEdges() {
    let containerWidth: CGFloat = 800
    let thumbnailWidth = PlaybackChromeMetrics.progressThumbnailWidth // 160
    let capsuleWidth: CGFloat = 46

    // Near left edge (targetX = 40): thumbnail clamps to 0 while time capsule stays centered at 17.
    let leftThumbnailX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 40,
        capsuleWidth: thumbnailWidth,
        containerWidth: containerWidth
    )
    let leftCapsuleX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 40,
        capsuleWidth: capsuleWidth,
        containerWidth: containerWidth
    )
    #expect(leftThumbnailX == 0)
    #expect(leftCapsuleX == 17)

    // Middle (targetX = 400): both center on 400.
    let centerThumbnailX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 400,
        capsuleWidth: thumbnailWidth,
        containerWidth: containerWidth
    )
    let centerCapsuleX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 400,
        capsuleWidth: capsuleWidth,
        containerWidth: containerWidth
    )
    #expect(centerThumbnailX == 320)
    #expect(centerCapsuleX == 377)

    // Near right edge (targetX = 760): thumbnail clamps to 640 while time capsule stays centered at 737.
    let rightThumbnailX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 760,
        capsuleWidth: thumbnailWidth,
        containerWidth: containerWidth
    )
    let rightCapsuleX = PlaybackProgressTimeCapsulePlacementLayout.clampedX(
        targetX: 760,
        capsuleWidth: capsuleWidth,
        containerWidth: containerWidth
    )
    #expect(rightThumbnailX == 640)
    #expect(rightCapsuleX == 737)
}

@MainActor
@Test
func timelineThumbnailStoreFiresFirstRequestImmediatelyAndDeduplicatesSameKeyframeAndDebouncesCrossKeyframe() async throws {
    let image0 = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 40))
    let image2000 = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 160))
    let image4000 = try #require(makeTestSolidCGImage(width: 320, height: 180, gray: 220))

    var requestedTargets: [(milliseconds: Int, pixelWidth: Int)] = []
    var pendingCompletion: (@MainActor (CGImage?, Int, CGSize?) -> Void)?
    var cancelCallCount = 0

    // Keyframes every 2000ms: [0, 2000, 4000, 6000]
    let store = PlaybackTimelineThumbnailStore(
        debounceDelay: 0.03,
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

    // 1. First hover enters at 0.3s (keyframe 0ms): fires immediately (0ms debounce), no placeholder image before decode finishes.
    store.updatePreview(forSeconds: 0.3, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 1)
    #expect(requestedTargets[0].milliseconds == 300)
    #expect(requestedTargets[0].pixelWidth == 320)
    #expect(store.thumbnailImage == nil)

    // 2. Micro-movement within the same keyframe interval (0.8s -> keyframe 0ms) while in-flight: no duplicate request.
    store.updatePreview(forSeconds: 0.8, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 1)

    // Complete first decode: image appears and aspect ratio updates.
    pendingCompletion?(image0, 0, CGSize(width: 1920, height: 1080))
    #expect(store.thumbnailImage === image0)
    #expect(store.thumbnailAspectRatio == 16.0 / 9.0)

    // 3. Another move within keyframe 0ms (1.5s -> keyframe 0ms): still 1 request, keeps image0.
    store.updatePreview(forSeconds: 1.5, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 1)
    #expect(store.thumbnailImage === image0)

    // 4. Cross into keyframe 2000ms (at 2.2s), then move within keyframe 2000ms (2.6s) after 15ms:
    //    Should NOT fire immediately, and moving within keyframe 2000ms must NOT reset the 30ms debounce timer.
    store.updatePreview(forSeconds: 2.2, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 1)
    #expect(store.thumbnailImage === image0)

    try await Task.sleep(nanoseconds: 15_000_000)
    store.updatePreview(forSeconds: 2.6, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 1)

    // Wait another 25ms (total ~40ms since crossing into keyframe 2000ms, but only 25ms since the 2.6s micro-move):
    // Because the 2.6s move stayed in keyframe 2000ms and did NOT reset the debounce timer, the request has now fired!
    try await Task.sleep(nanoseconds: 25_000_000)
    #expect(requestedTargets.count == 2)
    #expect(requestedTargets[1].milliseconds == 2_200)
    // Previous thumbnail stays visible until the new keyframe finishes decoding.
    #expect(store.thumbnailImage === image0)

    pendingCompletion?(image2000, 2_000, CGSize(width: 1920, height: 1080))
    #expect(store.thumbnailImage === image2000)

    // 5. Rapidly cross into keyframe 4000ms (at 4.1s) and then back into already-displayed keyframe 2000ms (at 2.9s) within 10ms:
    //    Cancels the pending 4000ms debounce and does not re-decode 2000ms.
    store.updatePreview(forSeconds: 4.1, backingScaleFactor: 2.0)
    try await Task.sleep(nanoseconds: 10_000_000)
    store.updatePreview(forSeconds: 2.9, backingScaleFactor: 2.0)
    try await Task.sleep(nanoseconds: 35_000_000)
    #expect(requestedTargets.count == 2)
    #expect(store.thumbnailImage === image2000)

    // 6. Cross into keyframe 4000ms (at 4.5s) and wait for debounce:
    store.updatePreview(forSeconds: 4.5, backingScaleFactor: 2.0)
    try await Task.sleep(nanoseconds: 45_000_000)
    #expect(requestedTargets.count == 3)
    pendingCompletion?(image4000, 4_000, CGSize(width: 1440, height: 1080))
    #expect(store.thumbnailImage === image4000)
    #expect(store.thumbnailAspectRatio == 4.0 / 3.0)

    // 7. Pointer leaves scrubber (clear()): immediately clears thumbnail state and cancels native requests.
    store.clear()
    #expect(store.thumbnailImage == nil)
    #expect(store.thumbnailAspectRatio == nil)
    #expect(cancelCallCount == 1)

    // 8. Re-entering scrubber after clear fires immediately again without debounce.
    store.updatePreview(forSeconds: 0.4, backingScaleFactor: 2.0)
    #expect(requestedTargets.count == 4)
}

private func makeTestSolidCGImage(width: Int, height: Int, gray: UInt8) -> CGImage? {
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: gray, count: bytesPerRow * height)
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
        shouldInterpolate: false,
        intent: .defaultIntent
    )
}
