import AppKit
import CoreGraphics
import QuartzCore
import SwiftUI

struct PlaybackCollagePreviewPane: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    // Covered by the Command Panel, or under an open menu, the preview keeps
    // its hover where it is and takes no click.
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
                    icon: .copy,
                    isRedesign: true,
                    action: onCopy
                )
                WorkbenchButton(
                    title: L("playback.collage.export"),
                    icon: .export,
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
    private static let hoverScale = WorkbenchControlMetrics.redesignCollageGroupHoverScale
    private static let hoverDuration = WorkbenchControlMetrics.redesignCollageGroupHoverDuration

    private let scrollView = NSScrollView()
    private let imageDocumentView = PlaybackCollagePreviewImageDocumentView()
    private let imageView = NSImageView()
    // Enlarged strips live here, above the scroll view and below the
    // scrollbar: outside the clip, so a strip can grow past the image's edges.
    private let spillView = PlaybackCollagePreviewSpillView()
    private let scrollbarView = PlaybackCollagePreviewScrollbarView()
    private var image: CGImage?
    private var segments: [PlaybackCollagePreviewSegment] = []
    /// The strip under the pointer at its last real movement. Nothing else
    /// moves it: the wheel scrolls it along with the image, and a new image
    /// only ends it until the pointer moves again.
    private(set) var hoveredSegmentIndex: Int?
    private var pressedSegmentIndex: Int?
    private var lastPointerWindowPoint: CGPoint?
    /// The strip under the pointer, growing or grown.
    private var hoveredStrip: PlaybackCollagePreviewStrip?
    /// Strips shrinking back to their place; gone once they arrive.
    private var retiringStrips: [PlaybackCollagePreviewStrip] = []
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
        scrollView.documentView = imageDocumentView

        scrollbarView.scrollView = scrollView
        addSubview(scrollView)
        addSubview(spillView)
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
        spillView.frame = bounds
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

        // A new picture ends the hover until the pointer moves again. The size
        // stays continuous: whatever strip of the new picture lies under the
        // pointer starts at the size shown there now and shrinks back.
        let inheritedScale = displayedScaleAtPointer()
        removeAllStrips()
        self.image = image
        self.segments = segments
        hoveredSegmentIndex = nil
        pressedSegmentIndex = nil
        imageView.image = image.map {
            NSImage(
                cgImage: $0,
                size: NSSize(width: $0.width, height: $0.height)
            )
        }
        updateImageLayout()

        guard inheritedScale > 1,
              let pointer = lastPointerWindowPoint,
              let index = baseSegmentIndex(atLocalPoint: convert(pointer, from: nil))
        else {
            return
        }
        let strip = makeStrip(for: index)
        strip.setScale(inheritedScale)
        retire(strip)
    }

    var renderedImageSizeForTesting: CGSize {
        imageView.frame.size
    }

    var isVerticalScrollbarPresentedForTesting: Bool {
        scrollbarView.isPresented
    }

    /// The hovered strip's target scale, or nil without one.
    var hoveredStripScaleForTesting: CGFloat? {
        hoveredStrip?.targetScale
    }

    var retiringStripIndicesForTesting: [Int] {
        retiringStrips.map(\.index)
    }

    /// A real pointer movement, from the window's event: the hover goes to
    /// the strip under the pointer, or away when there is none.
    func pointerMoved(toWindowPoint windowPoint: CGPoint) {
        lastPointerWindowPoint = windowPoint
        guard isInteractionEnabled else {
            return
        }
        setHoveredSegment(segmentIndex(atWindowPoint: windowPoint))
    }

    func press(atWindowPoint windowPoint: CGPoint) {
        pressedSegmentIndex = isInteractionEnabled
            ? segmentIndex(atWindowPoint: windowPoint)
            : nil
    }

    /// The action is on release, inside the strip the press began on. The
    /// hover follows the click as it would any pointer hit, and the target is
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
        // One monitor answers every pointer event from the event's own
        // location, so an enlarged strip is hit wherever it has grown to —
        // past the container's edge included, where view hit testing would
        // never reach — and a synthesized move drives it too. A click that
        // lands on a strip is the preview's and goes no further.
        pointerMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        ) { [weak self] event in
            var consumed = false
            MainActor.assumeIsolated {
                guard let self,
                      let window = self.window,
                      event.window === window
                else {
                    return
                }
                consumed = self.handlePointerEvent(
                    type: event.type,
                    atWindowPoint: event.locationInWindow
                )
            }
            return consumed ? nil : event
        }
    }

    /// Returns whether the event was the preview's to keep.
    private func handlePointerEvent(
        type: NSEvent.EventType,
        atWindowPoint point: CGPoint
    ) -> Bool {
        switch type {
        case .leftMouseDown:
            guard isInteractionEnabled,
                  segmentIndex(atWindowPoint: point) != nil
            else {
                return false
            }
            press(atWindowPoint: point)
            return true
        case .leftMouseUp:
            guard pressedSegmentIndex != nil else {
                return false
            }
            release(atWindowPoint: point)
            return true
        default:
            pointerMoved(toWindowPoint: point)
            return false
        }
    }

    private func removePointerMonitor() {
        guard let pointerMonitor else {
            return
        }
        NSEvent.removeMonitor(pointerMonitor)
        self.pointerMonitor = nil
    }

    // MARK: Hit testing

    /// The enlarged strip is hit over the whole rectangle it has grown to,
    /// and wins where that overlaps its neighbours.
    private func segmentIndex(atWindowPoint windowPoint: CGPoint) -> Int? {
        let local = convert(windowPoint, from: nil)
        if let hoveredStrip,
           scaledRect(of: hoveredStrip.index).contains(local) {
            return hoveredStrip.index
        }
        return baseSegmentIndex(atLocalPoint: local)
    }

    private func baseSegmentIndex(atLocalPoint local: CGPoint) -> Int? {
        guard scrollView.frame.contains(local) else {
            return nil
        }
        let point = imageDocumentView.convert(local, from: self)
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

    // MARK: Geometry

    private var segmentScale: CGFloat {
        guard let image, image.width > 0 else {
            return 0
        }
        return imageView.frame.width / CGFloat(image.width)
    }

    /// The strip's rectangle in the image, in image pixels.
    private func pixelRect(of index: Int) -> CGRect {
        let top = segments.prefix(index).reduce(0) { $0 + $1.height }
        return CGRect(
            x: 0,
            y: top,
            width: image?.width ?? 0,
            height: segments[index].height
        )
    }

    /// The strip's rectangle at rest, in this view's coordinates.
    private func baseRect(of index: Int) -> CGRect {
        let scale = segmentScale
        let pixels = pixelRect(of: index)
        let documentRect = CGRect(
            x: 0,
            y: pixels.minY * scale,
            width: imageView.frame.width,
            height: pixels.height * scale
        )
        return imageDocumentView.convert(documentRect, to: self)
    }

    /// How far the strip grows on each side at the hover scale.
    private func growth(of rect: CGRect) -> CGSize {
        let factor = (Self.hoverScale - 1) / 2
        return CGSize(width: rect.width * factor, height: rect.height * factor)
    }

    /// Where the strip may draw: the viewport plus its own growth, so the
    /// image's edges do not clip it, yet nothing scrolled out of view shows.
    private func spillRect(of index: Int) -> CGRect {
        let growth = growth(of: baseRect(of: index))
        return scrollView.frame.insetBy(dx: -growth.width, dy: -growth.height)
    }

    /// The strip's rectangle once enlarged, as far as it may draw.
    private func scaledRect(of index: Int) -> CGRect {
        let rect = baseRect(of: index)
        let growth = growth(of: rect)
        return rect.insetBy(dx: -growth.width, dy: -growth.height)
            .intersection(spillRect(of: index))
    }

    // MARK: Strips

    private func setHoveredSegment(_ index: Int?) {
        guard index != hoveredSegmentIndex else {
            return
        }
        hoveredSegmentIndex = index
        if let hoveredStrip {
            self.hoveredStrip = nil
            retire(hoveredStrip)
        }
        guard let index else {
            return
        }
        let strip = takeStrip(for: index)
        hoveredStrip = strip
        animate(strip, toScale: Self.hoverScale)
    }

    /// A strip still shrinking is taken back rather than made again, so the
    /// pointer returning to it grows it from where it is.
    private func takeStrip(for index: Int) -> PlaybackCollagePreviewStrip {
        if let position = retiringStrips.firstIndex(where: { $0.index == index }) {
            return retiringStrips.remove(at: position)
        }
        return makeStrip(for: index)
    }

    private func makeStrip(for index: Int) -> PlaybackCollagePreviewStrip {
        let strip = PlaybackCollagePreviewStrip(index: index)
        strip.content.contents = image?.cropping(to: pixelRect(of: index))
        strip.content.contentsScale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        spillView.layer?.addSublayer(strip.clip)
        position(strip)
        return strip
    }

    private func retire(_ strip: PlaybackCollagePreviewStrip) {
        retiringStrips.append(strip)
        animate(strip, toScale: 1) { [weak self, weak strip] in
            guard let self, let strip,
                  let position = self.retiringStrips.firstIndex(where: { $0 === strip })
            else {
                return
            }
            self.retiringStrips.remove(at: position)
            strip.clip.removeFromSuperlayer()
        }
    }

    private func removeAllStrips() {
        for strip in retiringStrips {
            strip.clip.removeFromSuperlayer()
        }
        retiringStrips = []
        hoveredStrip?.clip.removeFromSuperlayer()
        hoveredStrip = nil
    }

    /// The size shown at the pointer right now: the hovered strip's, or that
    /// of a strip still shrinking under it; 1 when nothing is enlarged there.
    private func displayedScaleAtPointer() -> CGFloat {
        if let hoveredStrip {
            return hoveredStrip.displayedScale
        }
        guard let pointer = lastPointerWindowPoint else {
            return 1
        }
        let local = convert(pointer, from: nil)
        return retiringStrips
            .first { baseRect(of: $0.index).contains(local) }?
            .displayedScale ?? 1
    }

    /// Every change of size starts from the size on screen at that moment and
    /// runs at one speed — the hover scale's distance in the hover duration —
    /// so a strip caught mid-way neither jumps nor slows down.
    private func animate(
        _ strip: PlaybackCollagePreviewStrip,
        toScale target: CGFloat,
        completion: (() -> Void)? = nil
    ) {
        let current = strip.displayedScale
        let duration = Self.hoverDuration
            * Double(abs(target - current) / (Self.hoverScale - 1))
        strip.animationGeneration += 1
        let generation = strip.animationGeneration
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { [weak strip] in
            guard let strip, strip.animationGeneration == generation else {
                return
            }
            completion?()
        }
        strip.targetScale = target
        strip.content.transform = CATransform3DMakeScale(target, target, 1)
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = current
        animation.toValue = target
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        strip.content.add(animation, forKey: "scale")
        CATransaction.commit()
    }

    private func position(_ strip: PlaybackCollagePreviewStrip) {
        let spill = spillRect(of: strip.index)
        let rect = baseRect(of: strip.index)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        strip.clip.frame = spill
        strip.content.frame = rect.offsetBy(dx: -spill.minX, dy: -spill.minY)
        CATransaction.commit()
    }

    private func positionStrips() {
        guard image != nil else {
            return
        }
        for strip in retiringStrips {
            position(strip)
        }
        if let hoveredStrip {
            position(hoveredStrip)
        }
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

        let maximumOffset = max(
            0,
            imageDocumentView.frame.height - viewportSize.height
        )
        var origin = scrollView.contentView.bounds.origin
        origin.x = 0
        origin.y = min(max(0, origin.y), maximumOffset)
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        positionStrips()

        scrollbarView.isPresented = imageSize.height > viewportSize.height + 0.5
        scrollbarView.scrollbarMetricsDidChange()
    }

    @objc
    private func scrollBoundsDidChange() {
        positionStrips()
        scrollbarView.scrollbarMetricsDidChange()
    }
}

/// One group's strip drawn above the image: a clip the size of the viewport
/// plus the strip's own growth, holding the strip's pixels scaled about
/// their centre.
private final class PlaybackCollagePreviewStrip {
    let index: Int
    let clip = CALayer()
    let content = CALayer()
    var targetScale: CGFloat = 1
    var animationGeneration = 0

    init(index: Int) {
        self.index = index
        clip.masksToBounds = true
        content.contentsGravity = .resize
        clip.addSublayer(content)
    }

    /// The scale on screen right now, mid-animation included.
    var displayedScale: CGFloat {
        (content.presentation() ?? content).transform.m11
    }

    func setScale(_ scale: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        targetScale = scale
        content.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }
}

private final class PlaybackCollagePreviewImageDocumentView: NSView {
    override var isFlipped: Bool {
        true
    }
}

/// Hosts the enlarged strips; takes no clicks of its own.
private final class PlaybackCollagePreviewSpillView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
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
