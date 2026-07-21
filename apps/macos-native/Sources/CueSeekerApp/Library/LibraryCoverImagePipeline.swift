import CoreGraphics
import Foundation
import ImageIO
import CueSeekerCore
import CueSeekerPlayback

struct LibraryCoverImageKey: Hashable, Sendable {
    let path: String
    let revision: String
    let profileVersion: Int

    init(
        path: String,
        revision: String,
        profileVersion: Int = LibraryCoverDisplayProfileVersion.current
    ) {
        self.path = path
        self.revision = revision
        self.profileVersion = profileVersion
    }

    static func current(path: String?, revision: String?) -> LibraryCoverImageKey? {
        guard let path, !path.isEmpty,
              let revision, !revision.isEmpty
        else {
            return nil
        }
        return LibraryCoverImageKey(path: path, revision: revision)
    }

    fileprivate var deterministicSortKey: String {
        "\(path)\n\(revision)\n\(profileVersion)"
    }
}

struct LibraryDecodedCoverImage: @unchecked Sendable {
    let image: CGImage
    let cost: Int
}

struct LibraryCoverImagePipelineConfiguration: Equatable, Sendable {
    static let production = LibraryCoverImagePipelineConfiguration(
        costLimitBytes: 16 * 1_024 * 1_024,
        countLimit: 64,
        maxConcurrentDecodes: 4
    )

    let costLimitBytes: Int
    let countLimit: Int
    let maxConcurrentDecodes: Int

    init(
        costLimitBytes: Int,
        countLimit: Int,
        maxConcurrentDecodes: Int
    ) {
        self.costLimitBytes = max(0, costLimitBytes)
        self.countLimit = max(0, countLimit)
        self.maxConcurrentDecodes = max(1, maxConcurrentDecodes)
    }
}

struct LibraryCoverImagePipelineDiagnostics: Equatable, Sendable {
    let totalCostBytes: Int
    let cachedKeys: Set<LibraryCoverImageKey>
    let inFlightRequestCount: Int
    let waiterCount: Int
    let activeDecodeCount: Int
    let queuedDecodeCount: Int
}

private final class LibraryCoverImageWaiterCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

actor LibraryCoverImagePipeline {
    typealias Decoder = @Sendable (LibraryCoverImageKey) -> LibraryDecodedCoverImage?

    static let shared = LibraryCoverImagePipeline()

    private struct CacheEntry {
        let decodedImage: LibraryDecodedCoverImage
        let cost: Int
        var lastAccess: UInt64
    }

    private struct InFlightRequest {
        struct Waiter {
            let continuation: CheckedContinuation<LibraryDecodedCoverImage?, Error>
            let cancellation: LibraryCoverImageWaiterCancellation
        }

        var generation: UInt64
        var waiters: [UUID: Waiter]
        var task: Task<Void, Never>?
        var acceptsResult: Bool
    }

    private let configuration: LibraryCoverImagePipelineConfiguration
    private let decoder: Decoder
    private var cache: [LibraryCoverImageKey: CacheEntry] = [:]
    private var totalCostBytes = 0
    private var accessClock: UInt64 = 0
    private var requestGeneration: UInt64 = 0
    private var inFlight: [LibraryCoverImageKey: InFlightRequest] = [:]
    private var pendingKeys: [LibraryCoverImageKey] = []
    private var activeDecodeCount = 0

    init(
        configuration: LibraryCoverImagePipelineConfiguration = .production,
        decoder: @escaping Decoder = LibraryCoverImageDecoder.decode
    ) {
        self.configuration = configuration
        self.decoder = decoder
    }

    func image(for key: LibraryCoverImageKey) async throws -> CGImage? {
        try Task.checkCancellation()
        if let decodedImage = cachedDecodedImage(for: key) {
            return decodedImage.image
        }

        let waiterID = UUID()
        let cancellation = LibraryCoverImageWaiterCancellation()
        let decodedImage = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                registerWaiter(
                    continuation,
                    cancellation: cancellation,
                    waiterID: waiterID,
                    key: key
                )
            }
        } onCancel: {
            cancellation.cancel()
            Task {
                await self.cancelWaiter(waiterID: waiterID, key: key)
            }
        }
        try Task.checkCancellation()
        return decodedImage?.image
    }

    func diagnostics() -> LibraryCoverImagePipelineDiagnostics {
        LibraryCoverImagePipelineDiagnostics(
            totalCostBytes: totalCostBytes,
            cachedKeys: Set(cache.keys),
            inFlightRequestCount: inFlight.count,
            waiterCount: inFlight.values.reduce(0) { total, request in
                total + request.waiters.values.filter { !$0.cancellation.isCancelled }.count
            },
            activeDecodeCount: activeDecodeCount,
            queuedDecodeCount: pendingKeys.count
        )
    }

    func removeAll() {
        cache.removeAll(keepingCapacity: false)
        totalCostBytes = 0

        pendingKeys.removeAll(keepingCapacity: false)
        for key in Array(inFlight.keys) {
            guard var request = inFlight[key] else {
                continue
            }
            for waiter in request.waiters.values {
                waiter.cancellation.cancel()
                waiter.continuation.resume(throwing: CancellationError())
            }
            request.waiters.removeAll(keepingCapacity: false)
            request.acceptsResult = false
            if let task = request.task {
                task.cancel()
                inFlight[key] = request
            } else {
                inFlight.removeValue(forKey: key)
            }
        }
    }

    func remove(path: String) {
        let cachedKeys = cache.keys.filter { $0.path == path }
        for key in cachedKeys {
            if let entry = cache.removeValue(forKey: key) {
                totalCostBytes = max(0, totalCostBytes - entry.cost)
            }
        }

        pendingKeys.removeAll { $0.path == path }
        let requestKeys = inFlight.keys.filter { $0.path == path }
        for key in requestKeys {
            guard var request = inFlight[key] else {
                continue
            }
            for waiter in request.waiters.values {
                waiter.cancellation.cancel()
                waiter.continuation.resume(throwing: CancellationError())
            }
            request.waiters.removeAll(keepingCapacity: false)
            request.acceptsResult = false
            if let task = request.task {
                task.cancel()
                inFlight[key] = request
            } else {
                inFlight.removeValue(forKey: key)
            }
        }
    }

    private func registerWaiter(
        _ continuation: CheckedContinuation<LibraryDecodedCoverImage?, Error>,
        cancellation: LibraryCoverImageWaiterCancellation,
        waiterID: UUID,
        key: LibraryCoverImageKey
    ) {
        guard !cancellation.isCancelled else {
            continuation.resume(throwing: CancellationError())
            return
        }
        if let decodedImage = cachedDecodedImage(for: key) {
            continuation.resume(returning: decodedImage)
            return
        }

        if var request = inFlight[key] {
            request.waiters[waiterID] = InFlightRequest.Waiter(
                continuation: continuation,
                cancellation: cancellation
            )
            inFlight[key] = request
            return
        }

        requestGeneration &+= 1
        inFlight[key] = InFlightRequest(
            generation: requestGeneration,
            waiters: [
                waiterID: InFlightRequest.Waiter(
                    continuation: continuation,
                    cancellation: cancellation
                )
            ],
            task: nil,
            acceptsResult: true
        )
        pendingKeys.append(key)
        startPendingDecodesIfPossible()
    }

    private func cancelWaiter(waiterID: UUID, key: LibraryCoverImageKey) {
        guard var request = inFlight[key],
              let waiter = request.waiters.removeValue(forKey: waiterID)
        else {
            return
        }

        waiter.continuation.resume(throwing: CancellationError())
        guard request.waiters.isEmpty else {
            inFlight[key] = request
            return
        }

        if let task = request.task {
            request.acceptsResult = false
            task.cancel()
            inFlight[key] = request
        } else {
            inFlight.removeValue(forKey: key)
            pendingKeys.removeAll { $0 == key }
        }
    }

    private func startPendingDecodesIfPossible() {
        while activeDecodeCount < configuration.maxConcurrentDecodes,
              !pendingKeys.isEmpty {
            let key = pendingKeys.removeFirst()
            guard var request = inFlight[key],
                  request.task == nil,
                  !request.waiters.isEmpty
            else {
                continue
            }

            let generation = request.generation
            let decoder = self.decoder
            activeDecodeCount += 1
            let task = Task.detached(priority: .utility) {
                let decodedImage: LibraryDecodedCoverImage?
                if Task.isCancelled {
                    decodedImage = nil
                } else {
                    decodedImage = decoder(key)
                }
                await self.finishDecode(
                    decodedImage,
                    key: key,
                    generation: generation
                )
            }
            request.task = task
            inFlight[key] = request
        }
    }

    private func finishDecode(
        _ decodedImage: LibraryDecodedCoverImage?,
        key: LibraryCoverImageKey,
        generation: UInt64
    ) {
        guard var request = inFlight[key],
              request.generation == generation,
              request.task != nil
        else {
            return
        }

        activeDecodeCount = max(0, activeDecodeCount - 1)
        request.task = nil
        let liveWaiters = request.waiters.filter { !$0.value.cancellation.isCancelled }
        let cancelledWaiters = request.waiters.filter { $0.value.cancellation.isCancelled }
        if request.acceptsResult {
            inFlight.removeValue(forKey: key)
            if let decodedImage, !liveWaiters.isEmpty {
                insert(decodedImage, for: key)
            }
            for waiter in liveWaiters.values {
                waiter.continuation.resume(returning: decodedImage)
            }
            for waiter in cancelledWaiters.values {
                waiter.continuation.resume(throwing: CancellationError())
            }
        } else if liveWaiters.isEmpty {
            inFlight.removeValue(forKey: key)
            for waiter in cancelledWaiters.values {
                waiter.continuation.resume(throwing: CancellationError())
            }
        } else {
            requestGeneration &+= 1
            request.generation = requestGeneration
            request.waiters = liveWaiters
            request.acceptsResult = true
            inFlight[key] = request
            pendingKeys.append(key)
            for waiter in cancelledWaiters.values {
                waiter.continuation.resume(throwing: CancellationError())
            }
        }

        startPendingDecodesIfPossible()
    }

    private func cachedDecodedImage(
        for key: LibraryCoverImageKey
    ) -> LibraryDecodedCoverImage? {
        guard var entry = cache[key] else {
            return nil
        }
        accessClock &+= 1
        entry.lastAccess = accessClock
        cache[key] = entry
        return entry.decodedImage
    }

    private func insert(
        _ decodedImage: LibraryDecodedCoverImage,
        for key: LibraryCoverImageKey
    ) {
        let cost = max(1, decodedImage.cost)
        guard configuration.costLimitBytes > 0,
              configuration.countLimit > 0,
              cost <= configuration.costLimitBytes
        else {
            return
        }

        if let existing = cache.removeValue(forKey: key) {
            totalCostBytes = max(0, totalCostBytes - existing.cost)
        }
        accessClock &+= 1
        cache[key] = CacheEntry(
            decodedImage: decodedImage,
            cost: cost,
            lastAccess: accessClock
        )
        totalCostBytes += cost

        while totalCostBytes > configuration.costLimitBytes
                || cache.count > configuration.countLimit {
            guard let victim = cache.min(by: { lhs, rhs in
                if lhs.value.lastAccess != rhs.value.lastAccess {
                    return lhs.value.lastAccess < rhs.value.lastAccess
                }
                return lhs.key.deterministicSortKey < rhs.key.deterministicSortKey
            }) else {
                break
            }
            cache.removeValue(forKey: victim.key)
            totalCostBytes = max(0, totalCostBytes - victim.value.cost)
        }
    }
}

private enum LibraryCoverImageDecoder {
    static func decode(key: LibraryCoverImageKey) -> LibraryDecodedCoverImage? {
        autoreleasepool {
            guard key.profileVersion == LibraryCoverDisplayProfileVersion.current else {
                return nil
            }
            let sourceOptions: [CFString: Any] = [
                kCGImageSourceShouldCache: false
            ]
            guard let imageSource = CGImageSourceCreateWithURL(
                URL(fileURLWithPath: key.path) as CFURL,
                sourceOptions as CFDictionary
            ) else {
                return nil
            }
            guard !Task.isCancelled else {
                return nil
            }
            let decodeOptions: [CFString: Any] = [
                kCGImageSourceShouldCache: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let image = CGImageSourceCreateImageAtIndex(
                imageSource,
                0,
                decodeOptions as CFDictionary
            ),
                  image.width > 0,
                  image.height > 0,
                  image.width <= LibraryCoverDisplayProfile.current.maximumPixelWidth,
                  image.height <= LibraryCoverDisplayProfile.current.maximumPixelHeight
            else {
                return nil
            }
            guard !Task.isCancelled else {
                return nil
            }

            let (cost, overflow) = image.bytesPerRow.multipliedReportingOverflow(by: image.height)
            guard !overflow else {
                return nil
            }
            return LibraryDecodedCoverImage(image: image, cost: max(1, cost))
        }
    }
}
