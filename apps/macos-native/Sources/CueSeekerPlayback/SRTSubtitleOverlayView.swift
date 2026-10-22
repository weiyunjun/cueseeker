import AppKit
import CueSeekerCore
import Foundation
import QuartzCore

@MainActor
final class SRTSubtitleOverlayView: NSView {
    var areSubtitlesVisible = true {
        didSet {
            guard !isApplyingPresentation,
                  oldValue != areSubtitlesVisible
            else { return }
            imageLayer.isHidden = !areSubtitlesVisible
            updateImage(force: true)
        }
    }
    var currentTimeMilliseconds = 0 {
        didSet {
            guard !isApplyingPresentation else { return }
            updateImage()
        }
    }
    var videoSize: CGSize? {
        didSet {
            guard !isApplyingPresentation, oldValue != videoSize else { return }
            rebuildLayout()
            needsLayout = true
        }
    }
    var style = SRTSubtitleStyle() {
        didSet {
            guard oldValue != style else { return }
            rebuildLayout()
        }
    }
    var onRenderingFailure: ((String) -> Void)?
    /// The subtitle file itself could not be read. Unlike the renderer's own
    /// in-flight failures this one is the user's to see, so it travels to the
    /// App and is shown in the player's error banner.
    var onSourceLoadFailure: ((URL) -> Void)?

    private var source: PlaybackSubtitleSource?
    private var loadTask: Task<Void, Never>?
    private var layoutTask: Task<Void, Never>?
    private var loadingSourceIdentity: URL?
    private var loadedSourceIdentity: URL?
    private var cues: [PlaybackSubtitleCue] = []
    private var preparedLayout: SRTSubtitleLayout?
    private var activeOrdinals: [Int] = []
    private var activeValidRangeMilliseconds: Range<Int>?
    private var renderedImage: CGImage?
    private var isApplyingPresentation = false
    private let imageLayer = CALayer()

    private(set) var sourceLoadCountForTesting = 0
    private(set) var layoutBuildCountForTesting = 0

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .linear
        imageLayer.minificationFilter = .linear
        imageLayer.actions = [
            "contents": NSNull(), "position": NSNull(),
            "bounds": NSNull(), "frame": NSNull()
        ]
        layer?.addSublayer(imageLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    deinit {
        loadTask?.cancel()
        layoutTask?.cancel()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        imageLayer.frame = videoRect()
    }

    func setSource(_ source: PlaybackSubtitleSource?) {
        guard let source, source.format == .srt else {
            loadTask?.cancel()
            layoutTask?.cancel()
            self.source = nil
            loadingSourceIdentity = nil
            loadedSourceIdentity = nil
            cues = []
            preparedLayout = nil
            activeOrdinals = []
            activeValidRangeMilliseconds = nil
            renderedImage = nil
            imageLayer.contents = nil
            return
        }

        let nextIdentity = Self.identity(for: source)
        let currentIdentity = self.source.map(Self.identity(for:))
        self.source = source
        if nextIdentity == currentIdentity,
           nextIdentity == loadingSourceIdentity
            || nextIdentity == loadedSourceIdentity {
            return
        }

        loadTask?.cancel()
        layoutTask?.cancel()
        loadingSourceIdentity = nextIdentity
        loadedSourceIdentity = nil
        cues = []
        preparedLayout = nil
        activeOrdinals = []
        activeValidRangeMilliseconds = nil
        renderedImage = nil
        imageLayer.contents = nil
        sourceLoadCountForTesting += 1

        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let cues = try SRTSubtitleRenderer.loadPlaybackCues(
                    from: source,
                    isCancelled: { Task.isCancelled }
                )
                guard !Task.isCancelled else { return }
                let scheduledAt = PlaybackPerformanceProbe.now()
                await self?.finishLoading(
                    cues,
                    sourceIdentity: nextIdentity,
                    scheduledAt: scheduledAt
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let scheduledAt = PlaybackPerformanceProbe.now()
                await self?.finishLoading(
                    nil,
                    sourceIdentity: nextIdentity,
                    scheduledAt: scheduledAt,
                    errorMessage: "SRT renderer failed to load source: \(error.localizedDescription)"
                )
            }
        }
    }

    func setPresentation(
        source nextSource: PlaybackSubtitleSource?,
        videoSize nextVideoSize: CGSize?,
        milliseconds: Int,
        isVisible: Bool
    ) {
        let previousVideoSize = videoSize
        let previousIdentity = source.map(Self.identity(for:))

        isApplyingPresentation = true
        videoSize = nextVideoSize
        currentTimeMilliseconds = max(0, milliseconds)
        areSubtitlesVisible = isVisible
        isApplyingPresentation = false
        imageLayer.isHidden = !isVisible

        setSource(nextSource)

        guard let nextSource,
              previousIdentity == Self.identity(for: nextSource)
        else {
            return
        }

        if previousVideoSize != nextVideoSize {
            rebuildLayout()
            needsLayout = true
        } else {
            updateImage(force: true)
        }
    }

    private func finishLoading(
        _ cues: [PlaybackSubtitleCue]?,
        sourceIdentity expectedSourceIdentity: URL,
        scheduledAt: UInt64,
        errorMessage: String? = nil
    ) {
        PlaybackPerformanceProbe.logElapsed(
            "SRTSubtitleOverlayView.loadCompletion.mainDelay",
            since: scheduledAt,
            thresholdMilliseconds: 8
        )
        guard source.map(Self.identity(for:)) == expectedSourceIdentity,
              loadingSourceIdentity == expectedSourceIdentity
        else {
            return
        }
        loadTask = nil
        loadingSourceIdentity = nil
        if let errorMessage {
            loadedSourceIdentity = nil
            onRenderingFailure?(errorMessage)
            if let sourceURL = source?.url {
                onSourceLoadFailure?(sourceURL)
            }
            return
        }
        loadedSourceIdentity = expectedSourceIdentity
        self.cues = cues ?? []
        rebuildLayout()
    }

    private func rebuildLayout() {
        layoutTask?.cancel()
        guard let source, let videoSize else {
            preparedLayout = nil
            activeValidRangeMilliseconds = nil
            renderedImage = nil
            imageLayer.contents = nil
            return
        }
        let sourceIdentity = Self.identity(for: source)
        guard loadedSourceIdentity == sourceIdentity, !cues.isEmpty else {
            return
        }
        preparedLayout = nil
        renderedImage = nil
        activeOrdinals = []
        activeValidRangeMilliseconds = nil
        imageLayer.contents = nil
        let cues = self.cues
        let style = self.style
        layoutBuildCountForTesting += 1
        layoutTask = Task.detached(priority: .userInitiated) { [weak self] in
            let layout = PlaybackPerformanceProbe.measure(
                "SRTSubtitleRenderer.makeLayout",
                thresholdMilliseconds: 8
            ) {
                SRTSubtitleRenderer.makeLayout(
                    cues: cues,
                    canvasSize: videoSize,
                    style: style,
                    isCancelled: { Task.isCancelled }
                )
            }
            guard !Task.isCancelled else { return }
            let scheduledAt = PlaybackPerformanceProbe.now()
            await self?.finishLayout(
                layout,
                sourceIdentity: sourceIdentity,
                videoSize: videoSize,
                style: style,
                scheduledAt: scheduledAt
            )
        }
    }

    private func finishLayout(
        _ layout: SRTSubtitleLayout?,
        sourceIdentity expectedSourceIdentity: URL,
        videoSize expectedVideoSize: CGSize,
        style expectedStyle: SRTSubtitleStyle,
        scheduledAt: UInt64
    ) {
        PlaybackPerformanceProbe.logElapsed(
            "SRTSubtitleOverlayView.layoutCompletion.mainDelay",
            since: scheduledAt,
            thresholdMilliseconds: 8
        )
        guard source.map(Self.identity(for:)) == expectedSourceIdentity,
              loadedSourceIdentity == expectedSourceIdentity,
              videoSize == expectedVideoSize,
              style == expectedStyle
        else {
            return
        }
        layoutTask = nil
        preparedLayout = layout
        updateImage(force: true)
    }

    private func updateImage(force: Bool = false) {
        guard areSubtitlesVisible, let preparedLayout else {
            activeValidRangeMilliseconds = nil
            renderedImage = nil
            imageLayer.contents = nil
            return
        }
        if !force,
           let activeValidRangeMilliseconds,
           activeValidRangeMilliseconds.contains(currentTimeMilliseconds) {
            return
        }
        let nextValidRange = Self.validRange(
            for: preparedLayout.track.cues,
            at: currentTimeMilliseconds
        )
        activeValidRangeMilliseconds = nextValidRange
        let ordinals = preparedLayout.track
            .activeCues(atMilliseconds: currentTimeMilliseconds)
            .map(\.sourceOrdinal)
        guard force || ordinals != activeOrdinals else { return }
        activeOrdinals = ordinals
        renderedImage = PlaybackPerformanceProbe.measure(
            "SRTSubtitleRenderer.image",
            thresholdMilliseconds: 8
        ) {
            SRTSubtitleRenderer.image(
                layout: preparedLayout,
                atMilliseconds: currentTimeMilliseconds
            )
        }
        imageLayer.contents = renderedImage
    }

    func nextScheduledRenderMilliseconds(after timestampMilliseconds: Int) -> Int? {
        guard areSubtitlesVisible, source != nil else { return nil }
        guard let preparedLayout else {
            return timestampMilliseconds + 33
        }
        let range = activeValidRangeMilliseconds ?? Self.validRange(
            for: preparedLayout.track.cues,
            at: timestampMilliseconds
        )
        guard range.contains(timestampMilliseconds) else {
            return timestampMilliseconds
        }
        guard range.upperBound < Int.max else { return nil }
        return max(timestampMilliseconds + 1, range.upperBound)
    }

    private static func validRange(
        for cues: [PlaybackSubtitleCue],
        at timestampMilliseconds: Int
    ) -> Range<Int> {
        var lowerBound = 0
        var upperBound = Int.max
        for cue in cues {
            let startMs = max(0, cue.startMilliseconds)
            let endMs = max(startMs, cue.endMilliseconds)
            guard endMs > startMs else { continue }
            if timestampMilliseconds >= startMs && timestampMilliseconds < endMs {
                if startMs > lowerBound { lowerBound = startMs }
                if endMs < upperBound { upperBound = endMs }
            } else if endMs <= timestampMilliseconds {
                if endMs > lowerBound { lowerBound = endMs }
            } else if startMs > timestampMilliseconds {
                if startMs < upperBound { upperBound = startMs }
            }
        }
        if upperBound <= lowerBound {
            upperBound = max(lowerBound + 1, timestampMilliseconds + 1)
        }
        return lowerBound..<upperBound
    }

    func currentPresentationImage() -> CGImage? {
        areSubtitlesVisible ? renderedImage : nil
    }

    nonisolated private static func identity(
        for source: PlaybackSubtitleSource
    ) -> URL {
        source.url.standardizedMediaURL
    }

    private func videoRect() -> CGRect {
        guard let videoSize, videoSize.width > 0, videoSize.height > 0 else {
            return bounds
        }
        let scale = min(bounds.width / videoSize.width, bounds.height / videoSize.height)
        let size = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        return CGRect(
            x: bounds.midX - (size.width / 2),
            y: bounds.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

}
