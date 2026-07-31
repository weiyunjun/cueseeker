import AppKit
import CoreGraphics
import SwiftUI

struct PlaybackCollagePreviewPane: View {
    @ObservedObject var store: PlaybackCollagePreviewStore
    let displayTitle: String
    let uiProbeScope: String?

    var body: some View {
        let _ = UIInvalidationProbe.count(
            "UI.PlaybackCollagePreviewPane.body",
            scope: uiProbeScope
        )
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing4
        ) {
            Text("Collage Preview")
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeSectionTitle,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .accessibilityIdentifier("playback-collage-preview-title")

            PlaybackCollagePreviewImageScrollView(
                image: store.image,
                uiProbeScope: uiProbeScope
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("playback-collage-preview-image")

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                WorkbenchButton(
                    title: "Copy Collage",
                    systemImage: "doc.on.doc",
                    isRedesign: true,
                    action: {
                        _ = store.copyCurrentResult()
                    }
                )
                WorkbenchButton(
                    title: "Export Collage",
                    systemImage: "square.and.arrow.up",
                    isRedesign: true,
                    action: {
                        _ = store.exportCurrentResult(
                            displayTitle: displayTitle
                        )
                    }
                )
            }
            .disabled(!store.canUseCurrentResult)
            .accessibilityIdentifier("playback-collage-preview-actions")
        }
        .padding(PlaybackSubtitleFocusMetrics.contentInset)
    }
}

struct PlaybackCollagePreviewImageScrollView: NSViewRepresentable {
    let image: CGImage?
    let uiProbeScope: String?

    func makeNSView(context: Context) -> PlaybackCollagePreviewScrollContainerView {
        UIInvalidationProbe.count(
            "playback.collage_preview.native_make",
            scope: uiProbeScope
        )
        let view = PlaybackCollagePreviewScrollContainerView()
        view.updateImage(image)
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
        nsView.updateImage(image)
    }
}

final class PlaybackCollagePreviewScrollContainerView: NSView {
    private let scrollView = NSScrollView()
    private let imageDocumentView = PlaybackCollagePreviewImageDocumentView()
    private let imageView = NSImageView()
    private let scrollbarView = PlaybackCollagePreviewScrollbarView()
    private var image: CGImage?

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
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        scrollbarView.frame = bounds
        updateImageLayout()
    }

    func updateImage(_ image: CGImage?) {
        if let currentImage = self.image,
           let image,
           currentImage === image {
            return
        }
        if self.image == nil, image == nil {
            return
        }

        self.image = image
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
