import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CueSeekerApp

@Test
func libraryCoverImageKeyRequiresPathAndRevisionPair() {
    #expect(LibraryCoverImageKey.current(path: nil, revision: "revision") == nil)
    #expect(LibraryCoverImageKey.current(path: "/display.jpg", revision: nil) == nil)
    #expect(LibraryCoverImageKey.current(path: "", revision: "revision") == nil)
    #expect(LibraryCoverImageKey.current(path: "/display.jpg", revision: "") == nil)

    let first = LibraryCoverImageKey.current(path: "/display.jpg", revision: "revision-1")
    let same = LibraryCoverImageKey.current(path: "/display.jpg", revision: "revision-1")
    let updated = LibraryCoverImageKey.current(path: "/display.jpg", revision: "revision-2")
    #expect(first == same)
    #expect(first != updated)
}

@Test
func libraryCoverImagePipelineUsesDeterministicCostLRU() async throws {
    #expect(LibraryCoverImagePipelineConfiguration.production.costLimitBytes == 16 * 1_024 * 1_024)
    #expect(LibraryCoverImagePipelineConfiguration.production.countLimit == 64)
    #expect(LibraryCoverImagePipelineConfiguration.production.maxConcurrentDecodes == 4)
    let probe = try LibraryCoverPipelineDecodeProbe(cost: 10)
    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 20,
            countLimit: 8,
            maxConcurrentDecodes: 4
        ),
        decoder: probe.decode
    )
    let keyA = coverPipelineKey("a")
    let keyB = coverPipelineKey("b")
    let keyC = coverPipelineKey("c")

    _ = try await pipeline.image(for: keyA)
    _ = try await pipeline.image(for: keyB)
    _ = try await pipeline.image(for: keyA)
    _ = try await pipeline.image(for: keyC)

    let diagnostics = await pipeline.diagnostics()
    #expect(diagnostics.totalCostBytes == 20)
    #expect(diagnostics.cachedKeys == [keyA, keyC])
    #expect(probe.snapshot().started == 3)
}

@Test
func libraryCoverImagePipelineCoalescesSameKeyWaiters() async throws {
    let probe = try LibraryCoverPipelineDecodeProbe(cost: 16, blocksUntilReleased: true)
    defer { probe.release(8) }
    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 1_024,
            countLimit: 8,
            maxConcurrentDecodes: 4
        ),
        decoder: probe.decode
    )
    let key = coverPipelineKey("shared")

    let first = Task { try await pipeline.image(for: key) }
    let second = Task { try await pipeline.image(for: key) }
    try await waitForCoverPipelineCondition {
        let diagnostics = await pipeline.diagnostics()
        return probe.snapshot().started == 1
            && diagnostics.activeDecodeCount == 1
            && diagnostics.waiterCount == 2
    }
    #expect(probe.snapshot().started == 1)

    probe.release(1)
    #expect(try await first.value != nil)
    #expect(try await second.value != nil)
    #expect(probe.snapshot().started == 1)
    #expect((await pipeline.diagnostics()).cachedKeys == [key])
}

@Test
func libraryCoverImagePipelineNeverExceedsDecodeConcurrency() async throws {
    let probe = try LibraryCoverPipelineDecodeProbe(cost: 16, blocksUntilReleased: true)
    defer { probe.release(16) }
    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 4_096,
            countLimit: 16,
            maxConcurrentDecodes: 4
        ),
        decoder: probe.decode
    )
    let tasks = (0..<6).map { index in
        let key = coverPipelineKey("concurrency-\(index)")
        return Task { try await pipeline.image(for: key) }
    }

    try await waitForCoverPipelineCondition {
        probe.snapshot().started == 4
    }
    let saturated = await pipeline.diagnostics()
    #expect(saturated.activeDecodeCount == 4)
    #expect(saturated.queuedDecodeCount == 2)
    #expect(probe.snapshot().maximumActive == 4)

    probe.release(4)
    try await waitForCoverPipelineCondition {
        probe.snapshot().started == 6
    }
    probe.release(2)
    for task in tasks {
        #expect(try await task.value != nil)
    }
    #expect(probe.snapshot().maximumActive == 4)
    let completed = await pipeline.diagnostics()
    #expect(completed.activeDecodeCount == 0)
    #expect(completed.queuedDecodeCount == 0)
}

@Test
func libraryCoverImagePipelineKeepsSharedDecodeWhenOneWaiterCancels() async throws {
    let probe = try LibraryCoverPipelineDecodeProbe(cost: 16, blocksUntilReleased: true)
    defer { probe.release(8) }
    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 1_024,
            countLimit: 8,
            maxConcurrentDecodes: 4
        ),
        decoder: probe.decode
    )
    let key = coverPipelineKey("partial-cancel")
    let cancelled = Task { try await pipeline.image(for: key) }
    let survivor = Task { try await pipeline.image(for: key) }
    try await waitForCoverPipelineCondition {
        (await pipeline.diagnostics()).waiterCount == 2
    }

    cancelled.cancel()
    await expectCoverPipelineCancellation(cancelled)
    try await waitForCoverPipelineCondition {
        (await pipeline.diagnostics()).waiterCount == 1
    }
    probe.release(1)

    #expect(try await survivor.value != nil)
    #expect(probe.snapshot().started == 1)
    #expect((await pipeline.diagnostics()).cachedKeys == [key])
}

@Test
func libraryCoverImagePipelineDiscardsLateResultAndRestartsForNewWaiter() async throws {
    let probe = try LibraryCoverPipelineDecodeProbe(cost: 16, blocksUntilReleased: true)
    defer { probe.release(8) }
    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 1_024,
            countLimit: 8,
            maxConcurrentDecodes: 1
        ),
        decoder: probe.decode
    )
    let key = coverPipelineKey("late-result")
    let abandoned = Task { try await pipeline.image(for: key) }
    try await waitForCoverPipelineCondition {
        probe.snapshot().started == 1
    }

    abandoned.cancel()
    await expectCoverPipelineCancellation(abandoned)
    let replacement = Task { try await pipeline.image(for: key) }
    try await waitForCoverPipelineCondition {
        (await pipeline.diagnostics()).waiterCount == 1
    }

    probe.release(1)
    try await waitForCoverPipelineCondition {
        probe.snapshot().started == 2
    }
    #expect((await pipeline.diagnostics()).cachedKeys.isEmpty)

    probe.release(1)
    #expect(try await replacement.value != nil)
    #expect(probe.snapshot().started == 2)
    #expect((await pipeline.diagnostics()).cachedKeys == [key])
}

@Test
func libraryCoverImagePipelineReturnsOversizedEntryWithoutCachingIt() async throws {
    let probe = try LibraryCoverPipelineDecodeProbe(cost: 128)
    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 64,
            countLimit: 8,
            maxConcurrentDecodes: 4
        ),
        decoder: probe.decode
    )
    let key = coverPipelineKey("oversized")

    #expect(try await pipeline.image(for: key) != nil)
    #expect(try await pipeline.image(for: key) != nil)
    let diagnostics = await pipeline.diagnostics()
    #expect(diagnostics.totalCostBytes == 0)
    #expect(diagnostics.cachedKeys.isEmpty)
    #expect(probe.snapshot().started == 2)
}

@Test
func libraryCoverImagePipelineImmediatelyCancelledRequestsLeaveNoState() async throws {
    let probe = try LibraryCoverPipelineDecodeProbe(cost: 16)
    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 1_024,
            countLimit: 8,
            maxConcurrentDecodes: 4
        ),
        decoder: probe.decode
    )

    for index in 0..<50 {
        let key = coverPipelineKey("cancel-before-register-\(index)")
        let task = Task { () throws -> CGImage? in
            withUnsafeCurrentTask { currentTask in
                currentTask?.cancel()
            }
            return try await pipeline.image(for: key)
        }
        await expectCoverPipelineCancellation(task)
    }

    try await waitForCoverPipelineCondition {
        let diagnostics = await pipeline.diagnostics()
        return diagnostics.inFlightRequestCount == 0
            && diagnostics.waiterCount == 0
            && diagnostics.activeDecodeCount == 0
            && diagnostics.queuedDecodeCount == 0
    }
    #expect(probe.snapshot().started == 0)
}

@Test
func libraryCoverImagePipelineRemoveAllCancelsWaitersAndRejectsLateResult() async throws {
    let probe = try LibraryCoverPipelineDecodeProbe(cost: 16, blocksUntilReleased: true)
    defer { probe.release(8) }
    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 1_024,
            countLimit: 8,
            maxConcurrentDecodes: 1
        ),
        decoder: probe.decode
    )
    let key = coverPipelineKey("remove-all")
    let pendingKey = coverPipelineKey("remove-all-pending")
    let request = Task { try await pipeline.image(for: key) }
    let pendingRequest = Task { try await pipeline.image(for: pendingKey) }
    try await waitForCoverPipelineCondition {
        let diagnostics = await pipeline.diagnostics()
        return probe.snapshot().started == 1
            && diagnostics.activeDecodeCount == 1
            && diagnostics.queuedDecodeCount == 1
            && diagnostics.waiterCount == 2
    }

    await pipeline.removeAll()
    await expectCoverPipelineCancellation(request)
    await expectCoverPipelineCancellation(pendingRequest)
    probe.release(1)
    try await waitForCoverPipelineCondition {
        let diagnostics = await pipeline.diagnostics()
        return diagnostics.inFlightRequestCount == 0
            && diagnostics.activeDecodeCount == 0
    }
    #expect((await pipeline.diagnostics()).cachedKeys.isEmpty)

    let replacement = Task { try await pipeline.image(for: key) }
    try await waitForCoverPipelineCondition {
        probe.snapshot().started == 2
    }
    probe.release(1)
    #expect(try await replacement.value != nil)
    #expect((await pipeline.diagnostics()).cachedKeys == [key])
}

@Test
func libraryCoverImagePipelineDefaultDecoderRejectsMasterSizedImages() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerCoverPipelineDecoderTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let displayURL = directory.appendingPathComponent("display.jpg")
    let oversizedURL = directory.appendingPathComponent("master.jpg")
    try writeCoverPipelineTestJPEG(width: 512, height: 288, to: displayURL)
    try writeCoverPipelineTestJPEG(width: 1_024, height: 576, to: oversizedURL)

    let pipeline = LibraryCoverImagePipeline(
        configuration: .init(
            costLimitBytes: 16 * 1_024 * 1_024,
            countLimit: 64,
            maxConcurrentDecodes: 4
        )
    )
    let displayImage = try await pipeline.image(
        for: LibraryCoverImageKey(path: displayURL.path, revision: "display")
    )
    #expect(displayImage?.width == 512)
    #expect(displayImage?.height == 288)
    let oversizedImage = try await pipeline.image(
        for: LibraryCoverImageKey(path: oversizedURL.path, revision: "master")
    )
    #expect(oversizedImage == nil)
}

private func coverPipelineKey(_ name: String) -> LibraryCoverImageKey {
    LibraryCoverImageKey(
        path: "/Covers/Display/v1/\(name).jpg",
        revision: "revision-\(name)"
    )
}

private func waitForCoverPipelineCondition(
    _ condition: @escaping @Sendable () async -> Bool
) async throws {
    for _ in 0..<300 {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: 5_000_000)
    }
    throw LibraryCoverPipelineTestError.timeout
}

private func expectCoverPipelineCancellation(
    _ task: Task<CGImage?, Error>
) async {
    do {
        _ = try await task.value
        Issue.record("Expected the cover image request to be cancelled")
    } catch is CancellationError {
        return
    } catch {
        Issue.record("Expected CancellationError, got \(error)")
    }
}

private final class LibraryCoverPipelineDecodeProbe: @unchecked Sendable {
    struct Snapshot: Sendable {
        let started: Int
        let active: Int
        let maximumActive: Int
    }

    private let lock = NSLock()
    private let image: CGImage
    private let cost: Int
    private let semaphore: DispatchSemaphore?
    private var started = 0
    private var active = 0
    private var maximumActive = 0

    init(cost: Int, blocksUntilReleased: Bool = false) throws {
        self.image = try makeCoverPipelineTestImage()
        self.cost = cost
        self.semaphore = blocksUntilReleased ? DispatchSemaphore(value: 0) : nil
    }

    func decode(_: LibraryCoverImageKey) -> LibraryDecodedCoverImage? {
        lock.lock()
        started += 1
        active += 1
        maximumActive = max(maximumActive, active)
        lock.unlock()

        semaphore?.wait()

        lock.lock()
        active = max(0, active - 1)
        lock.unlock()
        return LibraryDecodedCoverImage(image: image, cost: cost)
    }

    func release(_ count: Int) {
        guard let semaphore else {
            return
        }
        for _ in 0..<count {
            semaphore.signal()
        }
    }

    func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(
            started: started,
            active: active,
            maximumActive: maximumActive
        )
    }
}

private func makeCoverPipelineTestImage() throws -> CGImage {
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
        CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    return try #require(context.makeImage())
}

private func writeCoverPipelineTestJPEG(width: Int, height: Int, to url: URL) throws {
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    )
    context.setFillColor(red: 0.18, green: 0.36, blue: 0.72, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(context.makeImage())
    let destination = try #require(
        CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        )
    )
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
}

private enum LibraryCoverPipelineTestError: Error {
    case timeout
}
