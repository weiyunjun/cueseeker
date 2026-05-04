import AppKit

@MainActor
final class NativeASSSubtitleOverlayView: NSView {
    var areSubtitlesVisible: Bool = true {
        didSet {
            if oldValue != areSubtitlesVisible {
                needsDisplay = true
            }
        }
    }

    var currentTimeMilliseconds: Int = 0 {
        didSet {
            if oldValue != currentTimeMilliseconds {
                needsDisplay = true
            }
        }
    }

    var videoSize: CGSize? {
        didSet {
            if oldValue != videoSize {
                needsDisplay = true
            }
        }
    }

    var onRenderingFailure: ((String) -> Void)?

    private var source: PlaybackSubtitleSource?
    private var document: NativeASSDocument?
    private var loadTask: Task<Void, Never>?
    private var generation = UUID()
    private var failureMessage: String?

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        postsFrameChangedNotifications = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setSource(_ source: PlaybackSubtitleSource?) {
        loadTask?.cancel()
        generation = UUID()
        self.source = source
        document = nil
        failureMessage = nil

        guard let source else {
            needsDisplay = true
            return
        }

        let sourceURL = source.url
        let loadGeneration = generation
        loadTask = Task { [weak self] in
            do {
                let document = try await Task.detached(priority: .userInitiated) {
                    let contents = try String(contentsOf: sourceURL)
                    return NativeASSParser.parse(contents)
                }.value

                await MainActor.run {
                    guard let self,
                          self.generation == loadGeneration,
                          self.source == source
                    else {
                        return
                    }

                    self.document = document
                    self.failureMessage = nil
                    self.needsDisplay = true
                }
            } catch {
                await MainActor.run {
                    guard let self,
                          self.generation == loadGeneration,
                          self.source == source
                    else {
                        return
                    }

                    let message = "Native ASS renderer failed to load source: \(error.localizedDescription)"
                    self.document = nil
                    self.failureMessage = message
                    self.onRenderingFailure?(message)
                    self.needsDisplay = true
                }
            }
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard areSubtitlesVisible else {
            return
        }

        if let document {
            let surfaces = NativeASSSubtitleRenderer.renderSurfaces(
                document: document,
                atMilliseconds: currentTimeMilliseconds,
                containerBounds: bounds,
                videoSize: videoSize,
                backingScale: window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
            )

            for surface in surfaces {
                NSImage(cgImage: surface.image, size: surface.frame.size).draw(in: surface.frame)
            }
        }

        if let failureMessage {
            drawFailure(message: failureMessage)
        }
    }

    private func drawFailure(message: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.systemRed.withAlphaComponent(0.82)
        ]
        let text = NSAttributedString(string: "Native ASS renderer failure: \(message)", attributes: attributes)
        text.draw(
            with: bounds.insetBy(dx: 16, dy: 16),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
    }
}
