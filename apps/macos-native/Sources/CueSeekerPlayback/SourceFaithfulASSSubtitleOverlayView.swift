import AppKit
import CASSRendering
import CueSeekerCore
import CoreGraphics
import Foundation

struct ASSCroppedSurface: @unchecked Sendable {
    let rgbaData: Data
    let width: Int
    let height: Int
    let stride: Int
    let destinationX: Int
    let destinationY: Int
}

struct ASSSparseFrame: @unchecked Sendable {
    let surface: ASSCroppedSurface?
    let frameWidth: Int
    let frameHeight: Int
    let timestampMilliseconds: Int
}

enum SourceFaithfulASSSubtitleLayout {
    static func videoRect(videoSize: CGSize?, in bounds: CGRect) -> CGRect {
        guard let videoSize,
              videoSize.width > 0,
              videoSize.height > 0,
              bounds.width > 0,
              bounds.height > 0
        else {
            return bounds
        }

        let scale = min(
            bounds.width / videoSize.width,
            bounds.height / videoSize.height
        )
        let size = CGSize(
            width: videoSize.width * scale,
            height: videoSize.height * scale
        )
        return CGRect(
            x: bounds.midX - (size.width / 2),
            y: bounds.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    static func surfaceFrame(
        destinationX: Int,
        destinationY: Int,
        width: Int,
        height: Int,
        frameWidth: Int,
        frameHeight: Int,
        videoRect: CGRect
    ) -> CGRect? {
        guard frameWidth > 0, frameHeight > 0, width > 0, height > 0 else {
            return nil
        }

        let scaleX = videoRect.width / CGFloat(frameWidth)
        let scaleY = videoRect.height / CGFloat(frameHeight)
        return CGRect(
            x: videoRect.minX + (CGFloat(destinationX) * scaleX),
            y: videoRect.maxY - (CGFloat(destinationY + height) * scaleY),
            width: CGFloat(width) * scaleX,
            height: CGFloat(height) * scaleY
        )
    }
}

private enum ASSRenderedFrame: @unchecked Sendable {
    case sparse(ASSSparseFrame, validRangeMilliseconds: Range<Int>)
    case unchanged(timestampMilliseconds: Int, validRangeMilliseconds: Range<Int>)

    var timestampMilliseconds: Int {
        switch self {
        case .sparse(let frame, _):
            frame.timestampMilliseconds
        case .unchanged(let timestampMilliseconds, _):
            timestampMilliseconds
        }
    }

    var validRangeMilliseconds: Range<Int> {
        switch self {
        case .sparse(_, let range):
            range
        case .unchanged(_, let range):
            range
        }
    }
}

private struct ASSRenderWorkerError: Error, Sendable {
    let message: String
}

enum ASSIndexedPartialLoadDiagnostics {
    struct Snapshot: Equatable, Sendable {
        var indexedSessionLoadCount: Int = 0
        var fullFallbackSessionLoadCount: Int = 0
        var databaseIndexValidationCount: Int = 0
        var memoryCacheReuseCount: Int = 0
        var partialChunkReadCount: Int = 0
        var partialChunkBytesRead: Int = 0
    }

    private static let lock = NSLock()
    private static var storedSnapshot = Snapshot()
    private static var storedArtificialLoadDelaySeconds: TimeInterval = 0
    private static var storedScopedPathSubstring: String?

    static var snapshot: Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return storedSnapshot
    }

    static var scopedPathSubstringForTesting: String? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedScopedPathSubstring
        }
        set {
            lock.lock()
            storedScopedPathSubstring = newValue
            lock.unlock()
        }
    }

    static var artificialLoadDelaySecondsForTesting: TimeInterval {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedArtificialLoadDelaySeconds
        }
        set {
            lock.lock()
            storedArtificialLoadDelaySeconds = max(0, newValue)
            lock.unlock()
        }
    }

    static func artificialLoadDelaySeconds(forSourcePath sourcePath: String) -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        guard matchesScopeLocked(sourcePath) else { return 0 }
        return storedArtificialLoadDelaySeconds
    }

    private static func matchesScopeLocked(_ sourcePath: String) -> Bool {
        guard let substring = storedScopedPathSubstring else { return true }
        return sourcePath.contains(substring)
    }

    static func recordIndexedSessionLoad(sourcePath: String) {
        lock.lock()
        if matchesScopeLocked(sourcePath) {
            storedSnapshot.indexedSessionLoadCount += 1
        }
        lock.unlock()
    }

    static func recordFullFallbackSessionLoad(sourcePath: String) {
        lock.lock()
        if matchesScopeLocked(sourcePath) {
            storedSnapshot.fullFallbackSessionLoadCount += 1
        }
        lock.unlock()
    }

    static func recordDatabaseIndexValidation(sourcePath: String) {
        lock.lock()
        if matchesScopeLocked(sourcePath) {
            storedSnapshot.databaseIndexValidationCount += 1
        }
        lock.unlock()
    }

    static func recordMemoryCacheReuse(sourcePath: String) {
        lock.lock()
        if matchesScopeLocked(sourcePath) {
            storedSnapshot.memoryCacheReuseCount += 1
        }
        lock.unlock()
    }

    static func recordChunkRead(sourcePath: String, bytes: Int) {
        lock.lock()
        if matchesScopeLocked(sourcePath) {
            storedSnapshot.partialChunkReadCount += 1
            storedSnapshot.partialChunkBytesRead += max(0, bytes)
        }
        lock.unlock()
    }

    static func resetForTesting() {
        lock.lock()
        storedSnapshot = Snapshot()
        storedArtificialLoadDelaySeconds = 0
        storedScopedPathSubstring = nil
        lock.unlock()
        ValidatedASSOffsetIndexMemoryCache.shared.clear()
    }
}

private final class ValidatedASSOffsetIndexMemoryCache: @unchecked Sendable {
    static let shared = ValidatedASSOffsetIndexMemoryCache()

    private struct Key: Hashable {
        let mediaPath: String
        let cacheScopeID: String
    }

    private struct Entry {
        let key: Key
        let index: ASSEventOffsetIndex
        let requestedFontNames: [String]?
        let fileSize: Int64
        let modifiedAtInterval: TimeInterval?
    }

    private let lock = NSLock()
    private var entries: [Entry] = []
    private let maxEntries = 8

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    func invalidate(mediaPath: String, cacheScopeID: String?) {
        lock.lock()
        entries.removeAll { entry in
            entry.key.mediaPath == mediaPath
                && (cacheScopeID == nil || entry.key.cacheScopeID == cacheScopeID)
        }
        lock.unlock()
    }

    func resolve(
        for subtitleURL: URL,
        cacheProvider: any PlaybackSubtitleRenderCacheProviding
    ) throws -> (
        index: ASSEventOffsetIndex,
        requestedFontNames: [String]?,
        fileSize: Int64,
        modifiedAtInterval: TimeInterval?
    )? {
        let key = Key(
            mediaPath: subtitleURL.mediaPath,
            cacheScopeID: cacheProvider.cacheScopeID
        )

        let actualSize: Int64
        let actualModifiedAt: Date?
        if subtitleURL.isRemoteMediaURL {
            let cachedURL = cacheProvider.subtitleCache.cachedFileURL(for: subtitleURL)
            guard let handle = try? FileHandle(forReadingFrom: cachedURL) else {
                invalidate(mediaPath: key.mediaPath, cacheScopeID: key.cacheScopeID)
                return nil
            }
            try? handle.close()
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: cachedURL.path),
                  let size = (attributes[.size] as? NSNumber)?.int64Value,
                  size >= 0
            else {
                invalidate(mediaPath: key.mediaPath, cacheScopeID: key.cacheScopeID)
                return nil
            }
            actualSize = size
            actualModifiedAt = nil
        } else {
            let handle = try FileHandle(forReadingFrom: subtitleURL)
            try? handle.close()
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: subtitleURL.path),
                  let size = (attributes[.size] as? NSNumber)?.int64Value,
                  let modifiedDate = attributes[.modificationDate] as? Date
            else {
                invalidate(mediaPath: key.mediaPath, cacheScopeID: key.cacheScopeID)
                return nil
            }
            actualSize = size
            actualModifiedAt = modifiedDate
        }

        lock.lock()
        if let existingIdx = entries.firstIndex(where: { $0.key == key }) {
            let existing = entries[existingIdx]
            let matchesFingerprint: Bool
            if let actualModifiedAt {
                matchesFingerprint = existing.fileSize == actualSize
                    && existing.modifiedAtInterval != nil
                    && abs((existing.modifiedAtInterval ?? 0) - actualModifiedAt.timeIntervalSince1970) < 0.001
            } else {
                matchesFingerprint = existing.fileSize == actualSize
            }
            if matchesFingerprint {
                entries.remove(at: existingIdx)
                entries.append(existing)
                lock.unlock()
                ASSIndexedPartialLoadDiagnostics.recordMemoryCacheReuse(sourcePath: key.mediaPath)
                return (
                    existing.index,
                    existing.requestedFontNames,
                    existing.fileSize,
                    existing.modifiedAtInterval
                )
            }
            entries.remove(at: existingIdx)
        }
        lock.unlock()

        ASSIndexedPartialLoadDiagnostics.recordDatabaseIndexValidation(sourcePath: key.mediaPath)
        let validated: ASSEventOffsetIndex?
        if let actualModifiedAt {
            validated = try cacheProvider.validatedASSEventOffsetIndex(
                forSubtitleFile: subtitleURL,
                actualFileSize: actualSize,
                actualModifiedAt: actualModifiedAt
            )
        } else {
            validated = try cacheProvider.validatedASSEventOffsetIndex(forSubtitleFile: subtitleURL)
        }
        guard let validated else {
            return nil
        }

        let requestedFontNames = try? ASSPlaybackFontIntentProvider.requestedFontNames(
            sourcePath: subtitleURL.mediaPath,
            renderCacheProvider: cacheProvider
        )
        let newEntry = Entry(
            key: key,
            index: validated,
            requestedFontNames: requestedFontNames,
            fileSize: actualSize,
            modifiedAtInterval: actualModifiedAt?.timeIntervalSince1970
        )

        lock.lock()
        entries.removeAll { $0.key == key }
        entries.append(newEntry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()

        return (
            validated,
            requestedFontNames,
            newEntry.fileSize,
            newEntry.modifiedAtInterval
        )
    }
}

private final class SourceFaithfulASSRendererWorker: @unchecked Sendable {
    private let queue: DispatchQueue
    private let invalidationLock = NSLock()
    private var invalidated = false
    private var session: SFXASSRendererSession?
    private var usingIndexedSession = false
    private var sourcePath: String?
    private var sourceFormat: PlaybackSubtitleSourceFormat?
    private var renderCacheProvider: (any PlaybackSubtitleRenderCacheProviding)?
    private var frameWidth = 0
    private var frameHeight = 0
    private var requestedFontNames: [String]?

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func load(
        source: PlaybackSubtitleSource,
        frameWidth: Int,
        frameHeight: Int,
        completion: @escaping @Sendable (UUID, Result<Void, ASSRenderWorkerError>) -> Void
    ) -> UUID {
        let nextGeneration = UUID()

        queue.async { [
            sourcePath = source.url.mediaPath,
            sourceFormat = source.format,
            renderCacheProvider = source.renderCacheProvider
        ] in
            guard !self.isInvalidated else {
                return
            }

            let delaySeconds = ASSIndexedPartialLoadDiagnostics.artificialLoadDelaySeconds(
                forSourcePath: sourcePath
            )
            if delaySeconds > 0 {
                let deadline = CACurrentMediaTime() + delaySeconds
                while CACurrentMediaTime() < deadline {
                    if self.isInvalidated {
                        return
                    }
                    Thread.sleep(forTimeInterval: min(0.01, max(0, deadline - CACurrentMediaTime())))
                }
                guard !self.isInvalidated else {
                    return
                }
            }

            do {
                self.clearState()
                self.sourcePath = sourcePath
                self.sourceFormat = sourceFormat
                self.renderCacheProvider = renderCacheProvider
                self.frameWidth = frameWidth
                self.frameHeight = frameHeight

                let nextSession = try self.makeSession()
                guard !self.isInvalidated else {
                    nextSession.close()
                    return
                }

                self.session = nextSession
                completion(nextGeneration, .success(()))
            } catch {
                guard !self.isInvalidated else {
                    return
                }

                self.session = nil
                completion(
                    nextGeneration,
                    .failure(ASSRenderWorkerError(message: "ASS renderer failed to load source: \(error.localizedDescription)"))
                )
            }
        }

        return nextGeneration
    }

    func invalidate() {
        invalidationLock.lock()
        invalidated = true
        invalidationLock.unlock()

        queue.async {
            self.clearState()
        }
    }

    func updateFrameSize(frameWidth: Int, frameHeight: Int) {
        queue.async {
            guard !self.isInvalidated else {
                return
            }
            self.frameWidth = frameWidth
            self.frameHeight = frameHeight
            _ = self.session?.updateFrameWidth(frameWidth, frameHeight: frameHeight)
        }
    }

    func render(
        generation expectedGeneration: UUID,
        timestampMilliseconds: Int,
        completion: @escaping @Sendable (UUID, Result<ASSRenderedFrame, ASSRenderWorkerError>) -> Void
    ) {
        queue.async {
            guard !self.isInvalidated else {
                return
            }

            do {
                guard let currentSession = self.session else {
                    completion(
                        expectedGeneration,
                        .failure(ASSRenderWorkerError(message: "ASS renderer session is not ready."))
                    )
                    return
                }

                let output: SFXASSCroppedRenderOutput
                do {
                    output = try currentSession.renderCroppedImage(atTimestampMilliseconds: timestampMilliseconds)
                } catch {
                    guard self.usingIndexedSession, !self.isInvalidated else {
                        throw error
                    }
                    if let sourcePath = self.sourcePath {
                        ValidatedASSOffsetIndexMemoryCache.shared.invalidate(
                            mediaPath: sourcePath,
                            cacheScopeID: self.renderCacheProvider?.cacheScopeID
                        )
                    }
                    currentSession.close()
                    self.session = nil
                    self.usingIndexedSession = false
                    let fallbackSession = try self.makeFullFallbackSession()
                    guard !self.isInvalidated else {
                        fallbackSession.close()
                        return
                    }
                    self.session = fallbackSession
                    output = try fallbackSession.renderCroppedImage(atTimestampMilliseconds: timestampMilliseconds)
                }

                guard !self.isInvalidated else {
                    return
                }

                let validLower = max(0, output.unchangedFromMilliseconds)
                let validUpper = max(validLower + 1, output.unchangedUntilMilliseconds)
                let validRange = validLower ..< max(validLower + 1, validUpper)

                guard output.changed else {
                    completion(
                        expectedGeneration,
                        .success(.unchanged(timestampMilliseconds: timestampMilliseconds, validRangeMilliseconds: validRange))
                    )
                    return
                }

                let frame = ASSSparseFrame(
                    surface: Self.makeSurface(from: output),
                    frameWidth: output.frameWidth,
                    frameHeight: output.frameHeight,
                    timestampMilliseconds: timestampMilliseconds
                )
                completion(expectedGeneration, .success(.sparse(frame, validRangeMilliseconds: validRange)))
            } catch {
                guard !self.isInvalidated else {
                    return
                }

                completion(
                    expectedGeneration,
                    .failure(ASSRenderWorkerError(message: "ASS renderer failed at \(timestampMilliseconds) ms: \(error.localizedDescription)"))
                )
            }
        }
    }

    private var isInvalidated: Bool {
        invalidationLock.lock()
        defer {
            invalidationLock.unlock()
        }
        return invalidated
    }

    private func clearState() {
        session?.close()
        session = nil
        usingIndexedSession = false
        sourcePath = nil
        sourceFormat = nil
        renderCacheProvider = nil
        frameWidth = 0
        frameHeight = 0
        requestedFontNames = nil
    }

    private func makeSession() throws -> SFXASSRendererSession {
        guard let sourcePath,
              let sourceFormat,
              frameWidth > 0,
              frameHeight > 0
        else {
            throw ASSRenderWorkerError(message: "ASS renderer source is not ready.")
        }
        guard sourceFormat == .ass else {
            throw ASSRenderWorkerError(
                message: "ASS renderer received a non-ASS source."
            )
        }

        return try autoreleasepool {
            let sourceURL = URL.fromMediaPath(sourcePath)
            if let cacheProvider = renderCacheProvider,
               let resolved = try ValidatedASSOffsetIndexMemoryCache.shared.resolve(
                   for: sourceURL,
                   cacheProvider: cacheProvider
               ) {
                self.requestedFontNames = resolved.requestedFontNames
                let requestedFontNames = resolved.requestedFontNames
                let rewrittenHeader = ASSFontAliasResolver.shared.rewriteRenderScript(
                    resolved.index.headerText,
                    requestedFontNames: requestedFontNames
                )
                let subtitleCache = cacheProvider.subtitleCache
                let index = resolved.index
                let expectedFileSize = resolved.fileSize
                let expectedModifiedAtInterval = resolved.modifiedAtInterval
                let indexedSession = try SFXASSRendererSession(
                    assHeader: rewrittenHeader,
                    sourceIdentifier: sourcePath,
                    frameWidth: frameWidth,
                    frameHeight: frameHeight,
                    windowEventLinesProvider: { winStart, winEnd, errorPtr in
                        if !sourceURL.isRemoteMediaURL {
                            guard let attributes = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
                                  let liveSize = (attributes[.size] as? NSNumber)?.int64Value,
                                  let liveModifiedDate = attributes[.modificationDate] as? Date,
                                  liveSize == expectedFileSize,
                                  let expectedModifiedAtInterval,
                                  abs(liveModifiedDate.timeIntervalSince1970 - expectedModifiedAtInterval) < 0.001
                            else {
                                errorPtr?.pointee = NSError(
                                    domain: SFXASSRenderingErrorDomain,
                                    code: SFXASSRenderingErrorCode.loadFailed.rawValue,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Indexed ASS fingerprint changed for \(sourcePath)."
                                    ]
                                )
                                return nil
                            }
                        }
                        let safeEnd = max(winStart + 1, winEnd)
                        let ranges = index.overlappingEvents(in: winStart ..< safeEnd)
                        do {
                            guard let decodedLines = try index.readAndDecodeEventLines(
                                ranges,
                                from: sourceURL,
                                subtitleCache: subtitleCache,
                                onChunkRead: { _, byteCount in
                                    ASSIndexedPartialLoadDiagnostics.recordChunkRead(
                                        sourcePath: sourcePath,
                                        bytes: byteCount
                                    )
                                }
                            ) else {
                                errorPtr?.pointee = NSError(
                                    domain: SFXASSRenderingErrorDomain,
                                    code: SFXASSRenderingErrorCode.loadFailed.rawValue,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Indexed ASS slice decoding failed for \(sourcePath)."
                                    ]
                                )
                                return nil
                            }
                            return decodedLines.map { line in
                                guard line.contains("\\fn") else {
                                    return line
                                }
                                return ASSFontAliasResolver.shared.rewriteRenderScript(
                                    line,
                                    requestedFontNames: requestedFontNames
                                )
                            }
                        } catch {
                            errorPtr?.pointee = error as NSError
                            return nil
                        }
                    }
                )
                self.usingIndexedSession = true
                ASSIndexedPartialLoadDiagnostics.recordIndexedSessionLoad(sourcePath: sourcePath)
                return indexedSession
            }

            return try makeFullFallbackSession()
        }
    }

    private func makeFullFallbackSession() throws -> SFXASSRendererSession {
        guard let sourcePath,
              frameWidth > 0,
              frameHeight > 0
        else {
            throw ASSRenderWorkerError(message: "ASS renderer source is not ready.")
        }
        let sourceURL = URL.fromMediaPath(sourcePath)
        let subtitleCache = renderCacheProvider?.subtitleCache ?? .shared
        let rawData = try subtitleCache.readSubtitleData(from: sourceURL)
        let sourceScript = try SubtitleTextDecoder.decode(rawData, format: .ass)
        self.requestedFontNames = try? ASSPlaybackFontIntentProvider.requestedFontNames(
            sourcePath: sourcePath,
            renderCacheProvider: renderCacheProvider
        )
        let renderScript = rewriteFontAliases(in: sourceScript)
        let fallbackSession = try SFXASSRendererSession(
            assScript: renderScript,
            sourceIdentifier: sourcePath,
            frameWidth: frameWidth,
            frameHeight: frameHeight
        )
        self.usingIndexedSession = false
        ASSIndexedPartialLoadDiagnostics.recordFullFallbackSessionLoad(sourcePath: sourcePath)
        return fallbackSession
    }

    private func rewriteFontAliases(in script: String) -> String {
        return ASSFontAliasResolver.shared.rewriteRenderScript(
            script,
            requestedFontNames: requestedFontNames
        )
    }

    private static func makeSurface(from output: SFXASSCroppedRenderOutput) -> ASSCroppedSurface? {
        let width = output.width
        let height = output.height
        let stride = output.stride
        guard width > 0, height > 0, stride > 0, output.rgbaData.count > 0 else {
            return nil
        }

        return ASSCroppedSurface(
            rgbaData: output.rgbaData as Data,
            width: width,
            height: height,
            stride: stride,
            destinationX: output.destinationX,
            destinationY: output.destinationY
        )
    }
}

@MainActor
final class SourceFaithfulASSSubtitleOverlayView: NSView {
    var areSubtitlesVisible: Bool = true {
        didSet {
            if !isApplyingPresentation, oldValue != areSubtitlesVisible {
                subtitleContainerLayer.isHidden = !areSubtitlesVisible
                if areSubtitlesVisible {
                    requestRender(force: true)
                } else {
                    cancelPendingTelemetry()
                }
                needsDisplay = true
            }
        }
    }

    var currentTimeMilliseconds: Int = 0 {
        didSet {
            if !isApplyingPresentation, oldValue != currentTimeMilliseconds {
                requestRender()
            }
        }
    }

    var videoSize: CGSize? {
        didSet {
            if !isApplyingPresentation, oldValue != videoSize {
                if !updateRendererFrameSizeInPlaceIfPossible() {
                    reloadRendererIfPossible()
                }
                needsLayout = true
                needsDisplay = true
            }
        }
    }

    var onRenderingFailure: ((String) -> Void)?
    /// The subtitle file itself could not be read. Unlike the renderer's own
    /// in-flight failures this one is the user's to see, so it travels to the
    /// App and is shown in the player's error banner.
    var onSourceLoadFailure: ((URL) -> Void)?
    var onPreparedFrameReady: (() -> Void)?
    var defersLayerPresentation = false

    private struct PendingTelemetryRender {
        let attempt: PlaybackSubtitleFirstFrameAttempt
        var targetTimestampMilliseconds: Int
        var awaitingLoadCompletion: Bool
        var minCompletingRenderSequence: UInt
    }

    private var source: PlaybackSubtitleSource?
    private var generation: UUID?
    private var frameSizeRevision: UInt = 0
    private var isRendererReady = false
    private var isRenderInFlight = false
    private var pendingTimestampMilliseconds: Int?
    private var renderedTimestampMilliseconds: Int?
    private var renderedValidRangeMilliseconds: Range<Int>?
    private var renderedFrame: ASSRenderedFrame?
    private var renderedSurfaceImage: CGImage?
    private var displayedFrame: ASSSparseFrame?
    private var displayedVideoSize: CGSize?
    private var displayedSourceFormat: PlaybackSubtitleSourceFormat?
    private var stagedReadyAt: CFTimeInterval?
    private var loadFailedForCurrentSource = false
    private var failureMessage: String?
    private var isApplyingPresentation = false
    private var isSuppressingPreparedFrameReadyCallback = false
    private var currentLoadStartedAt: CFTimeInterval?
    private var pendingTelemetryRender: PendingTelemetryRender?
    private var nextRenderSequence: UInt = 0
    private let subtitleContainerLayer = CALayer()
    private var subtitleSurfaceLayer: CALayer?
    private let workerQueue: DispatchQueue
    private var rendererWorker: SourceFaithfulASSRendererWorker
    private(set) var rendererLoadCountForTesting = 0
    private(set) var rendererInPlaceResizeCountForTesting = 0

    var hasDisplayedSubtitleImage: Bool {
        !subtitleContainerLayer.isHidden && subtitleSurfaceLayer?.contents != nil
    }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        let workerQueue = DispatchQueue(label: "CueSeeker.SourceFaithfulASSRenderer")
        self.workerQueue = workerQueue
        self.rendererWorker = SourceFaithfulASSRendererWorker(queue: workerQueue)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        subtitleContainerLayer.frame = bounds
        subtitleContainerLayer.isGeometryFlipped = true
        subtitleContainerLayer.masksToBounds = false
        subtitleContainerLayer.actions = [
            "contents": NSNull(),
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull(),
            "sublayers": NSNull()
        ]
        layer?.addSublayer(subtitleContainerLayer)
        postsFrameChangedNotifications = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        rendererWorker.invalidate()
    }

    var rendererWorkerIdentityForTesting: ObjectIdentifier {
        ObjectIdentifier(rendererWorker)
    }

    func currentPresentationFrame() -> ASSSparseFrame? {
        guard areSubtitlesVisible else {
            return nil
        }
        if defersLayerPresentation {
            return displayedFrame
        }
        guard let renderedFrame else {
            return nil
        }

        switch renderedFrame {
        case .sparse(let frame, _):
            return frame
        case .unchanged:
            return nil
        }
    }

    func nextScheduledRenderMilliseconds(after timestampMilliseconds: Int) -> Int? {
        guard areSubtitlesVisible, source != nil else {
            return nil
        }
        guard isRendererReady, !isRenderInFlight, pendingTimestampMilliseconds == nil else {
            return timestampMilliseconds + 33
        }
        guard let validRange = renderedValidRangeMilliseconds,
              validRange.contains(timestampMilliseconds)
        else {
            return timestampMilliseconds
        }
        return validRange.upperBound < Int.max ? validRange.upperBound : nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func setFrameSize(_ newSize: NSSize) {
        let previousSize = frame.size
        super.setFrameSize(newSize)
        if source?.format == .srt, previousSize != newSize {
            reloadRendererIfPossible()
        }
    }

    override func layout() {
        super.layout()

        PlaybackPerformanceProbe.measure("SourceFaithfulASSSubtitleOverlayView.layout", thresholdMilliseconds: 8) {
            subtitleContainerLayer.frame = bounds
            if let displayedFrame {
                updatePresentationLayout(
                    for: displayedFrame,
                    layoutVideoSize: displayedVideoSize ?? videoSize,
                    layoutFormat: displayedSourceFormat ?? source?.format
                )
            } else if !defersLayerPresentation, let renderedFrame {
                updatePresentationLayout(for: renderedFrame)
            }
        }
    }

    func isPreparedForPresentation(
        atMilliseconds targetMilliseconds: Int,
        videoSize targetVideoSize: CGSize?
    ) -> Bool {
        guard let source, areSubtitlesVisible else {
            return true
        }
        if loadFailedForCurrentSource {
            return true
        }
        if source.format != .srt, let targetVideoSize, videoSize != targetVideoSize {
            return false
        }
        guard isRendererReady, !isRenderInFlight, pendingTimestampMilliseconds == nil else {
            return false
        }
        let safeMilliseconds = max(0, targetMilliseconds)
        return renderedTimestampMilliseconds == safeMilliseconds
            || renderedValidRangeMilliseconds?.contains(safeMilliseconds) == true
    }

    func isPreparedForManualSwitch(
        for targetSource: PlaybackSubtitleSource,
        videoSize targetVideoSize: CGSize?
    ) -> Bool {
        guard let source,
              source.url.standardizedMediaURL == targetSource.url.standardizedMediaURL,
              source.format == targetSource.format
        else {
            return false
        }
        guard areSubtitlesVisible else {
            return true
        }
        if loadFailedForCurrentSource || failureMessage != nil {
            return false
        }
        if source.format != .srt, let targetVideoSize, videoSize != targetVideoSize {
            return false
        }
        return isRendererReady && stagedReadyAt != nil
    }

    func retargetDeferredPresentation(
        videoSize nextVideoSize: CGSize?,
        milliseconds: Int
    ) {
        let safeMilliseconds = max(0, milliseconds)
        if var pending = pendingTelemetryRender, !pending.attempt.isCancelled {
            pending.targetTimestampMilliseconds = safeMilliseconds
            pendingTelemetryRender = pending
        }

        let shouldUpdateForVideoSize = source?.format != .srt
            && nextVideoSize != nil
            && videoSize != nextVideoSize
        if shouldUpdateForVideoSize {
            isApplyingPresentation = true
            videoSize = nextVideoSize
            currentTimeMilliseconds = safeMilliseconds
            isApplyingPresentation = false

            if updateRendererFrameSizeInPlaceIfPossible() {
                if var pending = pendingTelemetryRender, !pending.attempt.isCancelled {
                    pending.targetTimestampMilliseconds = safeMilliseconds
                    if !pending.awaitingLoadCompletion {
                        pending.minCompletingRenderSequence = pendingTimestampMilliseconds != nil
                            ? (nextRenderSequence &+ 1)
                            : max(nextRenderSequence, 1)
                    }
                    pendingTelemetryRender = pending
                }
                needsLayout = true
                needsDisplay = true
                return
            }

            reloadRendererIfPossible()
            if var pending = pendingTelemetryRender, !pending.attempt.isCancelled {
                if pending.attempt.prepStartedAt == nil {
                    pending.attempt.markPrepStarted(at: currentLoadStartedAt ?? CACurrentMediaTime())
                }
                pending.awaitingLoadCompletion = true
                pending.targetTimestampMilliseconds = safeMilliseconds
                pending.minCompletingRenderSequence = nextRenderSequence &+ 1
                pendingTelemetryRender = pending
            }
            return
        }

        isSuppressingPreparedFrameReadyCallback = true
        defer { isSuppressingPreparedFrameReadyCallback = false }

        if currentTimeMilliseconds != safeMilliseconds {
            currentTimeMilliseconds = safeMilliseconds
        } else if isRendererReady,
                  !isRenderInFlight,
                  pendingTimestampMilliseconds == nil,
                  renderedTimestampMilliseconds != safeMilliseconds,
                  renderedValidRangeMilliseconds?.contains(safeMilliseconds) != true {
            requestRender(force: true)
        }
    }

    func flushDeferredLayerPresentation(
        isSynchronousCommit: Bool,
        committedAt: CFTimeInterval = CACurrentMediaTime()
    ) {
        defersLayerPresentation = false
        subtitleContainerLayer.isHidden = !areSubtitlesVisible

        if source == nil || !areSubtitlesVisible || loadFailedForCurrentSource || failureMessage != nil {
            clearSubtitleLayers()
        } else if let renderedFrame, case .sparse(let sparseFrame, _) = renderedFrame {
            applySparseFrameToLayer(sparseFrame, precomputedImage: renderedSurfaceImage)
        } else {
            clearSubtitleLayers()
        }

        let hadStagedFrame = (stagedReadyAt != nil)
        let readyAt = stagedReadyAt ?? committedAt
        stagedReadyAt = nil
        if let pending = pendingTelemetryRender,
           !pending.awaitingLoadCompletion,
           ((!isSynchronousCommit && hadStagedFrame)
               || (!isRenderInFlight && pendingTimestampMilliseconds == nil)) {
            pendingTelemetryRender = nil
            if !pending.attempt.isCancelled {
                if isSynchronousCommit {
                    pending.attempt.completeSynchronouslyAtCommit(
                        at: committedAt,
                        frameReadyAt: readyAt
                    )
                } else {
                    pending.attempt.completeAsynchronously(at: committedAt)
                }
            }
        }
    }

    func releaseDeferredLayerPresentationForTimeout(
        committedAt: CFTimeInterval = CACurrentMediaTime()
    ) {
        defersLayerPresentation = false
        stagedReadyAt = nil
        clearSubtitleLayers()
        subtitleContainerLayer.isHidden = !areSubtitlesVisible
        pendingTelemetryRender?.attempt.markVideoCommitted(at: committedAt)
    }

    func clearDisplayedLayersImmediately() {
        defersLayerPresentation = false
        stagedReadyAt = nil
        clearSubtitleLayers()
    }

    func setSource(_ source: PlaybackSubtitleSource?) {
        cancelPendingTelemetry()
        self.source = source
        clearPresentationState()

        guard source != nil else {
            replaceRendererWorker()
            needsDisplay = true
            return
        }

        reloadRendererIfPossible()
        needsDisplay = true
    }

    func cancelPendingTelemetry() {
        pendingTelemetryRender?.attempt.cancel()
        pendingTelemetryRender = nil
    }

    func setPresentation(
        source nextSource: PlaybackSubtitleSource?,
        videoSize nextVideoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool
    ) {
        _ = setPresentation(
            source: nextSource,
            videoSize: nextVideoSize,
            milliseconds: milliseconds,
            isVisible: isVisible,
            telemetryAttempt: nil
        )
    }

    @discardableResult
    func setPresentation(
        source nextSource: PlaybackSubtitleSource?,
        videoSize nextVideoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool,
        telemetryAttempt: PlaybackSubtitleFirstFrameAttempt?
    ) -> PlaybackSubtitleCommitSyncState {
        cancelPendingTelemetry()
        let canReuseRenderer = rendererCanBeReused(
            for: nextSource,
            videoSize: nextVideoSize
        )
        let matchesLoadedOrLoadingSource = rendererMatchesSource(nextSource)
        let safeMilliseconds = max(0, milliseconds)

        isApplyingPresentation = true
        source = nextSource
        videoSize = nextVideoSize
        currentTimeMilliseconds = safeMilliseconds
        areSubtitlesVisible = isVisible
        isApplyingPresentation = false
        subtitleContainerLayer.isHidden = !isVisible

        guard nextSource != nil else {
            clearPresentationState()
            replaceRendererWorker()
            needsDisplay = true
            telemetryAttempt?.cancel()
            return .noSubtitle
        }

        if canReuseRenderer {
            failureMessage = nil
            requestRender(force: true)
            needsDisplay = true
        } else if matchesLoadedOrLoadingSource, updateRendererFrameSizeInPlaceIfPossible() {
            needsLayout = true
            needsDisplay = true
        } else {
            reloadRendererIfPossible()
            needsDisplay = true
        }
        return armTelemetryForCurrentState(
            attempt: telemetryAttempt,
            targetMilliseconds: safeMilliseconds,
            opStartedAt: telemetryAttempt?.startedAt ?? CACurrentMediaTime(),
            allowSynchronousCompletion: false
        )
    }

    func commitPreservedPresentation(
        videoSize nextVideoSize: CGSize?,
        milliseconds: Int,
        attempt: PlaybackSubtitleFirstFrameAttempt?
    ) -> PlaybackSubtitleCommitSyncState {
        if attempt != nil {
            cancelPendingTelemetry()
        }
        let opStartedAt = attempt?.startedAt ?? CACurrentMediaTime()
        let safeMilliseconds = max(0, milliseconds)

        videoSize = nextVideoSize
        currentTimeMilliseconds = safeMilliseconds

        return armTelemetryForCurrentState(
            attempt: attempt,
            targetMilliseconds: safeMilliseconds,
            opStartedAt: opStartedAt,
            allowSynchronousCompletion: true
        )
    }

    func bindTelemetryAttemptAfterLoadSetup(
        milliseconds: Int,
        attempt: PlaybackSubtitleFirstFrameAttempt
    ) {
        cancelPendingTelemetry()
        _ = armTelemetryForCurrentState(
            attempt: attempt,
            targetMilliseconds: max(0, milliseconds),
            opStartedAt: attempt.startedAt,
            allowSynchronousCompletion: true
        )
    }

    private func armTelemetryForCurrentState(
        attempt: PlaybackSubtitleFirstFrameAttempt?,
        targetMilliseconds: Int,
        opStartedAt: CFTimeInterval,
        allowSynchronousCompletion: Bool
    ) -> PlaybackSubtitleCommitSyncState {
        guard source != nil else {
            attempt?.cancel()
            return .noSubtitle
        }
        guard areSubtitlesVisible else {
            attempt?.cancel()
            return .hidden
        }

        if !isRendererReady {
            let waitingForDeferredVideoSize = defersLayerPresentation
                && !loadFailedForCurrentSource
                && renderFrameSize() == nil
            if let attempt, !attempt.isCancelled, (generation != nil || waitingForDeferredVideoSize) {
                attempt.markPrepStarted(at: currentLoadStartedAt ?? opStartedAt)
                pendingTelemetryRender = PendingTelemetryRender(
                    attempt: attempt,
                    targetTimestampMilliseconds: targetMilliseconds,
                    awaitingLoadCompletion: true,
                    minCompletingRenderSequence: nextRenderSequence &+ 1
                )
            } else {
                attempt?.cancel()
            }
            return .asyncPending
        }

        if allowSynchronousCompletion,
           !isRenderInFlight,
           pendingTimestampMilliseconds == nil,
           (renderedTimestampMilliseconds == targetMilliseconds
               || renderedValidRangeMilliseconds?.contains(targetMilliseconds) == true) {
            attempt?.markReusedSource(renderStartedAt: opStartedAt)
            if defersLayerPresentation {
                let now = CACurrentMediaTime()
                stagedReadyAt = now
                if let attempt, !attempt.isCancelled {
                    pendingTelemetryRender = PendingTelemetryRender(
                        attempt: attempt,
                        targetTimestampMilliseconds: targetMilliseconds,
                        awaitingLoadCompletion: false,
                        minCompletingRenderSequence: nextRenderSequence
                    )
                }
            } else {
                attempt?.completeSynchronouslyAtCommit(at: CACurrentMediaTime())
            }
            return .syncReady
        }

        if let attempt, !attempt.isCancelled {
            if isRenderInFlight || pendingTimestampMilliseconds != nil {
                attempt.markReusedSource(renderStartedAt: opStartedAt)
                let minSequence = pendingTimestampMilliseconds != nil
                    ? (nextRenderSequence &+ 1)
                    : max(nextRenderSequence, 1)
                pendingTelemetryRender = PendingTelemetryRender(
                    attempt: attempt,
                    targetTimestampMilliseconds: targetMilliseconds,
                    awaitingLoadCompletion: false,
                    minCompletingRenderSequence: minSequence
                )
            } else {
                attempt.cancel()
            }
        }
        return .asyncPending
    }

    private func reloadRendererIfPossible() {
        PlaybackPerformanceProbe.measure("SourceFaithfulASSSubtitleOverlayView.reloadRendererIfPossible", thresholdMilliseconds: 8) {
            guard let source else {
                return
            }

            isRendererReady = false
            clearPresentationState()
            replaceRendererWorker()

            guard let renderSize = renderFrameSize() else {
                loadFailedForCurrentSource = false
                failureMessage = "ASS renderer is waiting for a valid video size."
                if !defersLayerPresentation {
                    cancelPendingTelemetry()
                }
                needsDisplay = true
                return
            }

            loadFailedForCurrentSource = false
            failureMessage = nil
            needsDisplay = true
            currentLoadStartedAt = CACurrentMediaTime()

            let loadGeneration = rendererWorker.load(
                source: source,
                frameWidth: renderSize.width,
                frameHeight: renderSize.height
            ) { [weak self] returnedGeneration, result in
                let scheduledAt = PlaybackPerformanceProbe.now()
                DispatchQueue.main.async(execute: {
                    PlaybackPerformanceProbe.logElapsed(
                        "SourceFaithfulASSSubtitleOverlayView.loadCompletion.mainDelay",
                        since: scheduledAt,
                        thresholdMilliseconds: 50
                    )
                    guard let self, self.generation == returnedGeneration else {
                        return
                    }

                    switch result {
                    case .success:
                        self.isRendererReady = true
                        self.failureMessage = nil
                        if var pending = self.pendingTelemetryRender,
                           pending.awaitingLoadCompletion {
                            if pending.attempt.isCancelled {
                                self.pendingTelemetryRender = nil
                            } else {
                                let prepFinishedAt = CACurrentMediaTime()
                                pending.attempt.markPrepFinished(at: prepFinishedAt)
                                pending.awaitingLoadCompletion = false
                                pending.targetTimestampMilliseconds = max(0, self.currentTimeMilliseconds)
                                pending.minCompletingRenderSequence = self.nextRenderSequence &+ 1
                                self.pendingTelemetryRender = pending
                            }
                        }
                        self.requestRender(force: true)
                    case .failure(let error):
                        self.cancelPendingTelemetry()
                        self.isRendererReady = false
                        self.loadFailedForCurrentSource = true
                        self.renderedFrame = nil
                        self.failureMessage = error.message
                        self.onRenderingFailure?(error.message)
                        self.onSourceLoadFailure?(source.url)
                        self.needsDisplay = true
                    }
                })
            }
            rendererLoadCountForTesting += 1
            generation = loadGeneration
        }
    }

    private func rendererMatchesSource(_ nextSource: PlaybackSubtitleSource?) -> Bool {
        guard let source,
              let nextSource,
              generation != nil,
              !loadFailedForCurrentSource,
              failureMessage == nil
        else {
            return false
        }

        return source.url.standardizedMediaURL == nextSource.url.standardizedMediaURL
            && source.format == nextSource.format
            && source.renderCacheProvider?.cacheScopeID
                == nextSource.renderCacheProvider?.cacheScopeID
    }

    private func rendererCanBeReused(
        for nextSource: PlaybackSubtitleSource?,
        videoSize nextVideoSize: CGSize?
    ) -> Bool {
        rendererMatchesSource(nextSource) && videoSize == nextVideoSize
    }

    @discardableResult
    private func updateRendererFrameSizeInPlaceIfPossible() -> Bool {
        guard let source,
              source.format == .ass,
              generation != nil,
              !loadFailedForCurrentSource,
              failureMessage == nil,
              let renderSize = renderFrameSize()
        else {
            return false
        }

        frameSizeRevision &+= 1
        rendererInPlaceResizeCountForTesting += 1
        renderedTimestampMilliseconds = nil
        renderedValidRangeMilliseconds = nil
        renderedFrame = nil
        renderedSurfaceImage = nil
        stagedReadyAt = nil
        if !defersLayerPresentation {
            clearSubtitleLayers()
        }

        rendererWorker.updateFrameSize(
            frameWidth: renderSize.width,
            frameHeight: renderSize.height
        )
        if isRendererReady {
            requestRender(force: true)
        }
        return true
    }

    private func requestRender(force: Bool = false) {
        guard areSubtitlesVisible,
              isRendererReady,
              let generation
        else {
            return
        }

        let timestampMilliseconds = max(0, currentTimeMilliseconds)
        if !force, !isRenderInFlight, pendingTimestampMilliseconds == nil {
            if timestampMilliseconds == renderedTimestampMilliseconds {
                if defersLayerPresentation {
                    if stagedReadyAt == nil {
                        stagedReadyAt = CACurrentMediaTime()
                    }
                    if !isSuppressingPreparedFrameReadyCallback {
                        onPreparedFrameReady?()
                    }
                }
                return
            }
            if let validRange = renderedValidRangeMilliseconds,
               validRange.contains(timestampMilliseconds) {
                renderedTimestampMilliseconds = timestampMilliseconds
                if defersLayerPresentation {
                    if stagedReadyAt == nil {
                        stagedReadyAt = CACurrentMediaTime()
                    }
                    if !isSuppressingPreparedFrameReadyCallback {
                        onPreparedFrameReady?()
                    }
                }
                return
            }
        } else if force {
            renderedValidRangeMilliseconds = nil
        }

        pendingTimestampMilliseconds = timestampMilliseconds
        startNextRenderIfNeeded(generation: generation)
    }

    private func startNextRenderIfNeeded(generation: UUID) {
        guard !isRenderInFlight,
              let timestampMilliseconds = pendingTimestampMilliseconds
        else {
            return
        }

        pendingTimestampMilliseconds = nil
        isRenderInFlight = true
        nextRenderSequence &+= 1
        let renderSequence = nextRenderSequence
        let requestFrameSizeRevision = frameSizeRevision

        rendererWorker.render(
            generation: generation,
            timestampMilliseconds: timestampMilliseconds
        ) { [weak self] returnedGeneration, result in
            let scheduledAt = PlaybackPerformanceProbe.now()
            DispatchQueue.main.async(execute: {
                PlaybackPerformanceProbe.logElapsed(
                    "SourceFaithfulASSSubtitleOverlayView.renderCompletion.mainDelay",
                    since: scheduledAt,
                    thresholdMilliseconds: 50
                )
                guard let self, self.generation == returnedGeneration else {
                    return
                }

                self.isRenderInFlight = false

                guard requestFrameSizeRevision == self.frameSizeRevision else {
                    if self.pendingTimestampMilliseconds != nil, let generation = self.generation {
                        self.startNextRenderIfNeeded(generation: generation)
                    }
                    return
                }

                switch result {
                case .success(let frame):
                    self.renderedTimestampMilliseconds = frame.timestampMilliseconds
                    self.renderedValidRangeMilliseconds = frame.validRangeMilliseconds
                    self.apply(frame)
                    self.failureMessage = nil
                case .failure(let error):
                    let shouldReportSourceFailure = (self.renderedFrame == nil || self.defersLayerPresentation)
                    let failedSourceURL = self.source?.url
                    self.cancelPendingTelemetry()
                    self.clearPresentationState()
                    if shouldReportSourceFailure {
                        self.loadFailedForCurrentSource = true
                    }
                    self.failureMessage = error.message
                    self.onRenderingFailure?(error.message)
                    if shouldReportSourceFailure, let failedSourceURL {
                        self.onSourceLoadFailure?(failedSourceURL)
                    }
                    self.needsDisplay = true
                }

                if let nextPending = self.pendingTimestampMilliseconds,
                   let validRange = self.renderedValidRangeMilliseconds,
                   validRange.contains(nextPending) {
                    self.renderedTimestampMilliseconds = nextPending
                    self.pendingTimestampMilliseconds = nil
                }

                if case .success(let frame) = result, !self.defersLayerPresentation {
                    self.completePendingTelemetryAfterRenderIfNeeded(
                        frame: frame,
                        sequence: renderSequence
                    )
                }

                var didNotifyPreparedFrameReady = false
                if case .success = result,
                   self.defersLayerPresentation,
                   self.stagedReadyAt == nil {
                    self.stagedReadyAt = CACurrentMediaTime()
                    if !self.isSuppressingPreparedFrameReadyCallback {
                        didNotifyPreparedFrameReady = true
                        self.onPreparedFrameReady?()
                    }
                }

                if self.pendingTimestampMilliseconds != nil, let generation = self.generation {
                    self.startNextRenderIfNeeded(generation: generation)
                } else if case .success = result, !self.isRenderInFlight {
                    if self.defersLayerPresentation {
                        self.stagedReadyAt = CACurrentMediaTime()
                    }
                    if !didNotifyPreparedFrameReady, !self.isSuppressingPreparedFrameReadyCallback {
                        self.onPreparedFrameReady?()
                    }
                }
            })
        }
    }

    private func completePendingTelemetryAfterRenderIfNeeded(
        frame: ASSRenderedFrame,
        sequence: UInt
    ) {
        guard let pending = pendingTelemetryRender,
              !pending.awaitingLoadCompletion
        else {
            return
        }
        guard !pending.attempt.isCancelled else {
            pendingTelemetryRender = nil
            return
        }
        let coveredTarget = sequence >= pending.minCompletingRenderSequence
            || frame.timestampMilliseconds == pending.targetTimestampMilliseconds
            || frame.validRangeMilliseconds.contains(pending.targetTimestampMilliseconds)
            || renderedTimestampMilliseconds == pending.targetTimestampMilliseconds
        guard coveredTarget else {
            return
        }
        let presentedAt = CACurrentMediaTime()
        pendingTelemetryRender = nil
        pending.attempt.completeAsynchronously(at: presentedAt)
    }

    private func apply(_ frame: ASSRenderedFrame) {
        switch frame {
        case .sparse(let sparseFrame, _):
            renderedFrame = frame
            renderedSurfaceImage = sparseFrame.surface.flatMap { makeImage(from: $0) }
            if !defersLayerPresentation {
                applySparseFrameToLayer(sparseFrame, precomputedImage: renderedSurfaceImage)
            }
        case .unchanged:
            break
        }
    }

    private func clearPresentationState() {
        isRendererReady = false
        isRenderInFlight = false
        pendingTimestampMilliseconds = nil
        renderedTimestampMilliseconds = nil
        renderedValidRangeMilliseconds = nil
        renderedFrame = nil
        renderedSurfaceImage = nil
        stagedReadyAt = nil
        loadFailedForCurrentSource = false
        failureMessage = nil
        if !defersLayerPresentation {
            clearSubtitleLayers()
        }
    }

    private func replaceRendererWorker() {
        let previousWorker = rendererWorker
        previousWorker.invalidate()
        rendererWorker = SourceFaithfulASSRendererWorker(queue: workerQueue)
        generation = nil
    }

    private func updatePresentation(for renderedFrame: ASSRenderedFrame) {
        switch renderedFrame {
        case .sparse(let frame, _):
            applySparseFrameToLayer(frame, precomputedImage: renderedSurfaceImage)
        case .unchanged:
            break
        }
    }

    private func applySparseFrameToLayer(
        _ frame: ASSSparseFrame,
        precomputedImage: CGImage?
    ) {
        PlaybackPerformanceProbe.measure("SourceFaithfulASSSubtitleOverlayView.updatePresentation", thresholdMilliseconds: 8) {
            guard frame.frameWidth > 0, frame.frameHeight > 0 else {
                clearSubtitleLayers()
                return
            }

            subtitleContainerLayer.isHidden = !areSubtitlesVisible

            let resolvedImage = precomputedImage ?? frame.surface.flatMap { makeImage(from: $0) }
            guard frame.surface != nil, let surfaceImage = resolvedImage else {
                clearSubtitleLayers()
                return
            }

            let surfaceLayer: CALayer
            if let existingLayer = subtitleSurfaceLayer {
                surfaceLayer = existingLayer
            } else {
                let newLayer = CALayer()
                newLayer.contentsGravity = .resize
                newLayer.magnificationFilter = .linear
                newLayer.minificationFilter = .linear
                newLayer.actions = [
                    "contents": NSNull(),
                    "position": NSNull(),
                    "bounds": NSNull(),
                    "frame": NSNull()
                ]
                subtitleContainerLayer.addSublayer(newLayer)
                subtitleSurfaceLayer = newLayer
                surfaceLayer = newLayer
            }
            surfaceLayer.contents = surfaceImage
            surfaceLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            displayedFrame = frame
            displayedVideoSize = videoSize
            displayedSourceFormat = source?.format

            updatePresentationLayout(
                for: frame,
                layoutVideoSize: displayedVideoSize,
                layoutFormat: displayedSourceFormat
            )
        }
    }

    private func updatePresentationLayout(for renderedFrame: ASSRenderedFrame) {
        switch renderedFrame {
        case .sparse(let frame, _):
            updatePresentationLayout(
                for: frame,
                layoutVideoSize: videoSize,
                layoutFormat: source?.format
            )
        case .unchanged:
            break
        }
    }

    private func updatePresentationLayout(
        for frame: ASSSparseFrame,
        layoutVideoSize: CGSize?,
        layoutFormat: PlaybackSubtitleSourceFormat?
    ) {
        guard frame.frameWidth > 0, frame.frameHeight > 0 else {
            return
        }

        let presentationRect = layoutFormat == .srt
            ? bounds
            : SourceFaithfulASSSubtitleLayout.videoRect(
                videoSize: layoutVideoSize,
                in: bounds
            )
        guard presentationRect.width > 1, presentationRect.height > 1 else {
            return
        }

        if let surface = frame.surface, let subtitleSurfaceLayer {
            subtitleSurfaceLayer.frame = SourceFaithfulASSSubtitleLayout.surfaceFrame(
                destinationX: surface.destinationX,
                destinationY: surface.destinationY,
                width: surface.width,
                height: surface.height,
                frameWidth: frame.frameWidth,
                frameHeight: frame.frameHeight,
                videoRect: presentationRect
            ) ?? .zero
        }
    }

    private func clearSubtitleLayers() {
        subtitleSurfaceLayer?.removeFromSuperlayer()
        subtitleSurfaceLayer = nil
        displayedFrame = nil
        displayedVideoSize = nil
        displayedSourceFormat = nil
    }

    private func makeImage(from surface: ASSCroppedSurface) -> CGImage? {
        guard let provider = CGDataProvider(data: surface.rgbaData as CFData) else {
            failureMessage = "ASS renderer produced image data that could not be displayed."
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGImage(
            width: surface.width,
            height: surface.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: surface.stride,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private func renderFrameSize() -> (width: Int, height: Int)? {
        let size: CGSize
        if source?.format == .srt {
            size = bounds.size
        } else if let videoSize {
            size = videoSize
        } else if defersLayerPresentation {
            return nil
        } else {
            size = bounds.size
        }
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width > 1, height > 1 else {
            return nil
        }

        return (width, height)
    }

}
