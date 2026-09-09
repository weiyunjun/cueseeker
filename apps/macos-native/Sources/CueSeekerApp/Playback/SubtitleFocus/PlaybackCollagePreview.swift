import AppKit
import CoreGraphics
import SwiftUI

struct PlaybackCollagePreviewPane: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    // Covered by the Command Panel, or under an open menu, the preview keeps
    // its frame where it is and takes no click.
    @Environment(\.interfaceLayerContext) private var layerContext
    @ObservedObject var store: PlaybackCollagePreviewStore
    let uiProbeScope: String?
    // The session owns both actions: a result that is not ready yet answers
    // with a feedback capsule, so the buttons are never disabled.
    var onCopy: () -> Void = {}
    var onExport: () -> Void = {}
    /// A click on a group's strip, with the reel ordinal of the first cue of
    /// the group drawn there.
    var onJumpToCue: (Int) -> Void = { _ in }

    var body: some View {
        let _ = UIInvalidationProbe.count(
            "UI.PlaybackCollagePreviewPane.body",
            scope: uiProbeScope
        )
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing4
        ) {
            Text(L("playback.collage.preview"))
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeSectionTitle,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .accessibilityIdentifier("playback-collage-preview-title")

            PlaybackCollagePreviewImageScrollView(
                image: store.image,
                segments: store.segments,
                isInteractionEnabled: !layerContext.isFrozen,
                onJumpToCue: onJumpToCue,
                uiProbeScope: uiProbeScope
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("playback-collage-preview-image")

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                WorkbenchButton(
                    title: L("playback.collage.copy"),
                    systemImage: "doc.on.doc",
                    isRedesign: true,
                    action: onCopy
                )
                WorkbenchButton(
                    title: L("playback.collage.export"),
                    systemImage: "square.and.arrow.up",
                    isRedesign: true,
                    action: onExport
                )
            }
            .accessibilityIdentifier("playback-collage-preview-actions")
        }
        .padding(PlaybackSubtitleFocusMetrics.contentInset)
    }
}

struct PlaybackCollagePreviewImageScrollView: NSViewRepresentable {
    let image: CGImage?
    let segments: [PlaybackCollagePreviewSegment]
    let isInteractionEnabled: Bool
    let onJumpToCue: (Int) -> Void
    let uiProbeScope: String?

    func makeNSView(context: Context) -> PlaybackCollagePreviewScrollContainerView {
        UIInvalidationProbe.count(
            "playback.collage_preview.native_make",
            scope: uiProbeScope
        )
        let view = PlaybackCollagePreviewScrollContainerView()
        configure(view)
        return view
    }

    func updateNSView(
        _ nsView: PlaybackCollagePreviewScrollContainerView,
        context: Context
    ) {
        UIInvalidationProbe.count(
            "playback.collage_preview.native_update",
            scope: uiProbeScope
        )
        configure(nsView)
    }

    private func configure(_ view: PlaybackCollagePreviewScrollContainerView) {
        view.isInteractionEnabled = isInteractionEnabled
        view.onJumpToCue = onJumpToCue
        view.updateImage(image, segments: segments)
    }
}

final class PlaybackCollagePreviewScrollContainerView: NSView {
    private let scrollView = NSScrollView()
    private let imageDocumentView = PlaybackCollagePreviewImageDocumentView()
    private let imageView = NSImageView()
    private let groupFrameView = PlaybackCollagePreviewGroupFrameView()
    private let scrollbarView = PlaybackCollagePreviewScrollbarView()
    private var image: CGImage?
    private var segments: [PlaybackCollagePreviewSegment] = []
    /// The strip under the pointer at its last real movement. Nothing else
    /// moves it: the wheel scrolls it along with the image, and a new image
    /// only clears it until the pointer moves again.
    private(set) var hoveredSegmentIndex: Int?
    private var pressedSegmentIndex: Int?
    nonisolated(unsafe) private var pointerMonitor: Any?

    var isInteractionEnabled = true
    var onJumpToCue: (Int) -> Void = { _ in }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .allowed
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.postsBoundsChangedNotifications = true

        imageView.imageAlignment = .alignTop
        imageView.imageFrameStyle = .none
        imageView.imageScaling = .scaleAxesIndependently
        imageView.isEditable = false
        imageDocumentView.addSubview(imageView)
        // In the document, so it scrolls with the strip it frames.
        groupFrameView.isHidden = true
        imageDocumentView.addSubview(groupFrameView)
        scrollView.documentView = imageDocumentView

        scrollbarView.scrollView = scrollView
        addSubview(scrollView)
        addSubview(scrollbarView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let pointerMonitor {
            NSEvent.removeMonitor(pointerMonitor)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removePointerMonitor()
        } else {
            installPointerMonitorIfNeeded()
        }
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        scrollbarView.frame = bounds
        updateImageLayout()
    }

    func updateImage(
        _ image: CGImage?,
        segments: [PlaybackCollagePreviewSegment] = []
    ) {
        if let currentImage = self.image,
           let image,
           currentImage === image {
            return
        }
        if self.image == nil, image == nil {
            return
        }

        self.image = image
        self.segments = segments
        // A new picture clears the frame; the next real movement decides again.
        hoveredSegmentIndex = nil
        pressedSegmentIndex = nil
        imageView.image = image.map {
            NSImage(
                cgImage: $0,
                size: NSSize(width: $0.width, height: $0.height)
            )
        }
        updateImageLayout()
    }

    var renderedImageSizeForTesting: CGSize {
        imageView.frame.size
    }

    var isVerticalScrollbarPresentedForTesting: Bool {
        scrollbarView.isPresented
    }

    var groupFrameRectForTesting: CGRect? {
        groupFrameView.isHidden ? nil : groupFrameView.frame
    }

    /// A real pointer movement, from the window's event: the frame goes to
    /// the strip under the pointer, or away when there is none.
    func pointerMoved(toWindowPoint windowPoint: CGPoint) {
        guard isInteractionEnabled else {
            return
        }
        setHoveredSegment(segmentIndex(atWindowPoint: windowPoint))
    }

    override func mouseDown(with event: NSEvent) {
        press(atWindowPoint: event.locationInWindow)
    }

    override func mouseUp(with event: NSEvent) {
        release(atWindowPoint: event.locationInWindow)
    }

    func press(atWindowPoint windowPoint: CGPoint) {
        pressedSegmentIndex = isInteractionEnabled
            ? segmentIndex(atWindowPoint: windowPoint)
            : nil
    }

    /// The action is on release, inside the strip the press began on. The
    /// frame follows the click as it would any pointer hit, and the target is
    /// read from the segments of the picture on screen right now.
    func release(atWindowPoint windowPoint: CGPoint) {
        let pressed = pressedSegmentIndex
        pressedSegmentIndex = nil
        guard isInteractionEnabled,
              let index = segmentIndex(atWindowPoint: windowPoint),
              index == pressed
        else {
            return
        }
        setHoveredSegment(index)
        onJumpToCue(segments[index].firstCueOrdinal)
    }

    private func installPointerMonitorIfNeeded() {
        guard pointerMonitor == nil else {
            return
        }
        // A local monitor sees every real pointer movement in the window and
        // reads the event's own location, so the frame can clear when the
        // pointer leaves the image, and a synthesized move drives it too.
        pointerMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self,
                      let window = self.window,
                      event.window === window
                else {
                    return
                }
                self.pointerMoved(toWindowPoint: event.locationInWindow)
            }
            return event
        }
    }

    private func removePointerMonitor() {
        guard let pointerMonitor else {
            return
        }
        NSEvent.removeMonitor(pointerMonitor)
        self.pointerMonitor = nil
    }

    private func segmentIndex(atWindowPoint windowPoint: CGPoint) -> Int? {
        guard bounds.contains(convert(windowPoint, from: nil)) else {
            return nil
        }
        let point = imageDocumentView.convert(windowPoint, from: nil)
        guard imageView.frame.contains(point) else {
            return nil
        }
        let scale = segmentScale
        var top: CGFloat = 0
        for (index, segment) in segments.enumerated() {
            let bottom = top + CGFloat(segment.height) * scale
            if point.y < bottom {
                return index
            }
            top = bottom
        }
        return nil
    }

    private var segmentScale: CGFloat {
        guard let image, image.width > 0 else {
            return 0
        }
        return imageView.frame.width / CGFloat(image.width)
    }

    private func setHoveredSegment(_ index: Int?) {
        hoveredSegmentIndex = index
        positionGroupFrame()
    }

    private func positionGroupFrame() {
        guard let index = hoveredSegmentIndex,
              segments.indices.contains(index)
        else {
            groupFrameView.isHidden = true
            return
        }
        let scale = segmentScale
        let top = segments.prefix(index).reduce(CGFloat(0)) {
            $0 + CGFloat($1.height) * scale
        }
        groupFrameView.frame = CGRect(
            x: 0,
            y: top,
            width: imageView.frame.width,
            height: CGFloat(segments[index].height) * scale
        )
        groupFrameView.isHidden = false
        groupFrameView.needsDisplay = true
    }

    private func updateImageLayout() {
        scrollView.tile()
        let viewportSize = scrollView.contentView.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0 else {
            return
        }

        let imageSize: CGSize
        if let image, image.width > 0, image.height > 0 {
            let width = viewportSize.width
            imageSize = CGSize(
                width: width,
                height: width * CGFloat(image.height) / CGFloat(image.width)
            )
        } else {
            imageSize = .zero
        }

        imageDocumentView.frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: viewportSize.width,
                height: max(viewportSize.height, imageSize.height)
            )
        )
        imageView.frame = CGRect(origin: .zero, size: imageSize)
        positionGroupFrame()

        let maximumOffset = max(
            0,
            imageDocumentView.frame.height - viewportSize.height
        )
        var origin = scrollView.contentView.bounds.origin
        origin.x = 0
        origin.y = min(max(0, origin.y), maximumOffset)
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        scrollbarView.isPresented = imageSize.height > viewportSize.height + 0.5
        scrollbarView.scrollbarMetricsDidChange()
    }

    @objc
    private func scrollBoundsDidChange() {
        scrollbarView.scrollbarMetricsDidChange()
    }
}

private final class PlaybackCollagePreviewImageDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }

    /// Clicks anywhere on the document are the container's: the image view
    /// would otherwise keep them as a control, and the frame is not a target.
    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }
}

/// The accent frame around the hovered group — the search field's focus
/// border, drawn inside the strip so the image's edges do not clip it.
private final class PlaybackCollagePreviewGroupFrameView: NSView {
    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        let width = WorkbenchControlMetrics.redesignControlBorderWidth
        WorkbenchRedesignColors.NS.borderFocus.setStroke()
        let path = NSBezierPath(
            rect: bounds.insetBy(dx: width / 2, dy: width / 2)
        )
        path.lineWidth = width
        path.stroke()
    }
}

private final class PlaybackCollagePreviewScrollbarView:
    TableScrollbarOverlayView
{
    weak var scrollView: NSScrollView? {
        didSet {
            scrollbarMetricsDidChange()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        presentationProvider = { [weak self] in
            self?.presentation()
        }
        onDrag = { [weak self] event in
            self?.handleDrag(event)
        }
        onScrollWheel = { [weak self] event in
            self?.scrollView?.scrollWheel(with: event)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func presentation() -> TableScrollbarPresentation? {
        guard let scrollView,
              let documentView = scrollView.documentView
        else {
            return nil
        }

        let viewportHeight = scrollView.contentView.bounds.height
        let contentHeight = documentView.frame.height
        let maximumOffset = max(0, contentHeight - viewportHeight)
        guard maximumOffset > 0.5 else {
            return TableScrollbarPresentation()
        }

        return TableScrollbarPresentation(
            vertical: TableScrollbarAxisPresentation(
                visibleFraction: viewportHeight / contentHeight,
                positionFraction: scrollView.contentView.bounds.minY
                    / maximumOffset
            )
        )
    }

    private func handleDrag(_ event: TableScrollbarDragEvent) {
        guard event.axis == .vertical,
              event.phase == .changed,
              let scrollView,
              let documentView = scrollView.documentView
        else {
            return
        }

        let maximumOffset = max(
            0,
            documentView.frame.height - scrollView.contentView.bounds.height
        )
        var origin = scrollView.contentView.bounds.origin
        origin.y = maximumOffset * event.positionFraction
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        scrollbarMetricsDidChange()
    }
}
