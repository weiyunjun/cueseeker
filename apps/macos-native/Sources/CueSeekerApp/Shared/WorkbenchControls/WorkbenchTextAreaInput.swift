import AppKit
import SwiftUI

enum WorkbenchTextAreaScrollbarVisibility {
    static func isVisible(
        hasOverflow: Bool,
        isHovered: Bool,
        isScrolling: Bool,
        isDragging: Bool
    ) -> Bool {
        hasOverflow && (isHovered || isScrolling || isDragging)
    }
}

struct WorkbenchTextAreaInput: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focus: FocusState<Bool>.Binding
    let onFocusChange: (Bool) -> Void

    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WorkbenchTextAreaContainerView {
        let view = WorkbenchTextAreaContainerView()
        context.coordinator.containerView = view
        view.textView.delegate = context.coordinator
        view.textView.onFirstResponderChange = { [weak coordinator = context.coordinator] in
            coordinator?.setFocus($0)
        }
        view.configure(
            placeholder: placeholder,
            isEnabled: isEnabled
        )
        context.coordinator.applyExternalText(text, to: view)
        return view
    }

    func updateNSView(
        _ nsView: WorkbenchTextAreaContainerView,
        context: Context
    ) {
        context.coordinator.parent = self
        nsView.configure(
            placeholder: placeholder,
            isEnabled: isEnabled
        )
        if nsView.shouldApplyExternalText(text) {
            context.coordinator.applyExternalText(text, to: nsView)
        }

        if focus.wrappedValue {
            nsView.focusTextViewIfPossible()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: WorkbenchTextAreaInput
        weak var containerView: WorkbenchTextAreaContainerView?
        private var isApplyingExternalText = false

        init(parent: WorkbenchTextAreaInput) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingExternalText,
                  let textView = notification.object as? NSTextView
            else {
                return
            }
            parent.text = textView.string
            containerView?.textDidChange()
        }

        func setFocus(_ isFocused: Bool) {
            parent.onFocusChange(isFocused)
            guard parent.focus.wrappedValue != isFocused else { return }
            parent.focus.wrappedValue = isFocused
        }

        func applyExternalText(
            _ text: String,
            to containerView: WorkbenchTextAreaContainerView
        ) {
            isApplyingExternalText = true
            containerView.setText(text)
            isApplyingExternalText = false
        }
    }
}

@MainActor
final class WorkbenchTextAreaContainerView: NSView {
    static let contentInset = NSSize(
        width: WorkbenchControlMetrics.redesignFieldPaddingX,
        height: 10
    )

    let textView = WorkbenchTextAreaNativeTextView()

    private let scrollView = NSScrollView()
    private let scrollbarView = WorkbenchTextAreaScrollbarView()
    private var trackingArea: NSTrackingArea?
    private var isScrollAreaHovered = false
    private var isScrolling = false
    private var isScrollbarDragging = false
    private var lastScrollOrigin = CGPoint.zero
    private var scrollIdleTask: Task<Void, Never>?
    private var isUpdatingDocumentSize = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureViews()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        scrollIdleTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        scrollbarView.frame = bounds
        updateDocumentSize()
        updateScrollbarVisibility()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseEnteredAndExited,
                .activeInActiveApp,
                .inVisibleRect,
            ],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        setScrollAreaHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        setScrollAreaHovered(false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors(isEnabled: textView.isEditable)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window == nil else { return }
        scrollIdleTask?.cancel()
        isScrolling = false
        isScrollAreaHovered = false
        updateScrollbarVisibility()
    }

    func configure(placeholder: String, isEnabled: Bool) {
        textView.placeholder = placeholder
        textView.isEditable = isEnabled
        textView.isSelectable = isEnabled
        applyColors(isEnabled: isEnabled)
    }

    func shouldApplyExternalText(_ text: String) -> Bool {
        textView.string != text
            && (!isTextViewFirstResponder || !textView.hasMarkedText())
    }

    func setText(_ text: String) {
        let selection = textView.selectedRange()
        textView.string = text
        let textLength = (text as NSString).length
        textView.setSelectedRange(NSRange(
            location: min(selection.location, textLength),
            length: 0
        ))
        textDidChange()
    }

    func textDidChange() {
        textView.needsDisplay = true
        updateDocumentSize()
        scrollbarView.scrollbarMetricsDidChange()
        updateScrollbarVisibility()
    }

    func focusTextViewIfPossible() {
        guard let window,
              window.firstResponder !== textView
        else {
            return
        }
        window.makeFirstResponder(textView)
    }

    var isTextViewFirstResponder: Bool {
        window?.firstResponder === textView
    }

    var contentInsetForTesting: NSSize {
        textView.textContainerInset
    }

    var lineFragmentPaddingForTesting: CGFloat {
        textView.textContainer?.lineFragmentPadding ?? -1
    }

    var usesNativeScrollbarsForTesting: Bool {
        scrollView.hasVerticalScroller || scrollView.hasHorizontalScroller
    }

    var hasVerticalOverflowForTesting: Bool {
        scrollbarView.hasVerticalOverflow
    }

    var isScrollbarVisibleForTesting: Bool {
        scrollbarView.isPresented
    }

    func setScrollAreaHoveredForTesting(_ isHovered: Bool) {
        setScrollAreaHovered(isHovered)
    }

    private func configureViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true

        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = Self.contentInset
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.font = NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )

        scrollView.documentView = textView
        addSubview(scrollView)

        scrollbarView.scrollView = scrollView
        scrollbarView.onDraggingChanged = { [weak self] isDragging in
            self?.isScrollbarDragging = isDragging
            self?.updateScrollbarVisibility()
        }
        addSubview(scrollbarView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    private func applyColors(isEnabled: Bool) {
        let textColor = isEnabled
            ? WorkbenchRedesignColors.NS.textPrimary
            : WorkbenchRedesignColors.NS.textDisabled
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.placeholderColor = isEnabled
            ? WorkbenchRedesignColors.NS.textPlaceholder
            : WorkbenchRedesignColors.NS.textDisabled
        textView.typingAttributes = [
            .font: textView.font as Any,
            .foregroundColor: textColor,
        ]
        textView.needsDisplay = true
    }

    private func updateDocumentSize() {
        guard !isUpdatingDocumentSize else { return }
        let viewportSize = scrollView.contentSize
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }

        isUpdatingDocumentSize = true
        defer { isUpdatingDocumentSize = false }

        let initialHeight = max(viewportSize.height, textView.frame.height)
        textView.setFrameSize(NSSize(
            width: viewportSize.width,
            height: initialHeight
        ))
        if let textContainer = textView.textContainer,
           let layoutManager = textView.layoutManager {
            textContainer.containerSize = NSSize(
                width: max(1, viewportSize.width - 2 * Self.contentInset.width),
                height: CGFloat.greatestFiniteMagnitude
            )
            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
            let targetHeight = max(
                viewportSize.height,
                ceil(usedHeight + 2 * Self.contentInset.height)
            )
            textView.setFrameSize(NSSize(
                width: viewportSize.width,
                height: targetHeight
            ))

            let maximumOffset = max(0, targetHeight - viewportSize.height)
            var origin = scrollView.contentView.bounds.origin
            origin.x = 0
            origin.y = min(maximumOffset, max(0, origin.y))
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            lastScrollOrigin = origin
        }
        scrollbarView.scrollbarMetricsDidChange()
    }

    private func setScrollAreaHovered(_ isHovered: Bool) {
        guard isScrollAreaHovered != isHovered else { return }
        isScrollAreaHovered = isHovered
        updateScrollbarVisibility()
    }

    @objc
    private func scrollBoundsDidChange() {
        let origin = scrollView.contentView.bounds.origin
        scrollbarView.scrollbarMetricsDidChange()
        guard origin != lastScrollOrigin else {
            updateScrollbarVisibility()
            return
        }
        lastScrollOrigin = origin
        isScrolling = true
        updateScrollbarVisibility()
        scheduleScrollIdle()
    }

    private func scheduleScrollIdle() {
        scrollIdleTask?.cancel()
        scrollIdleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled,
                  let self
            else {
                return
            }
            self.isScrolling = false
            self.updateScrollbarVisibility()
        }
    }

    private func updateScrollbarVisibility() {
        let shouldShow = WorkbenchTextAreaScrollbarVisibility.isVisible(
            hasOverflow: scrollbarView.hasVerticalOverflow,
            isHovered: isScrollAreaHovered,
            isScrolling: isScrolling,
            isDragging: isScrollbarDragging
        )
        scrollbarView.showsInteractiveThumb =
            isScrollAreaHovered || isScrollbarDragging
        scrollbarView.isPresented = shouldShow
        if shouldShow {
            scrollbarView.scrollbarMetricsDidChange()
        }
    }
}

@MainActor
final class WorkbenchTextAreaNativeTextView: NSTextView {
    var onFirstResponderChange: (Bool) -> Void = { _ in }

    var placeholder = "" {
        didSet {
            guard placeholder != oldValue else { return }
            needsDisplay = true
        }
    }

    var placeholderColor = NSColor.placeholderTextColor {
        didSet {
            needsDisplay = true
        }
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            onFirstResponderChange(true)
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            onFirstResponderChange(false)
        }
        return didResignFirstResponder
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty,
              let font
        else {
            return
        }

        let origin = textContainerOrigin
        let availableWidth = max(
            0,
            bounds.width - origin.x - textContainerInset.width
        )
        (placeholder as NSString).draw(
            in: CGRect(
                x: origin.x,
                y: origin.y,
                width: availableWidth,
                height: max(0, bounds.height - origin.y)
            ),
            withAttributes: [
                .font: font,
                .foregroundColor: placeholderColor,
            ]
        )
    }
}

@MainActor
private final class WorkbenchTextAreaScrollbarView: TableScrollbarOverlayView {
    weak var scrollView: NSScrollView? {
        didSet {
            scrollbarMetricsDidChange()
        }
    }

    var onDraggingChanged: (Bool) -> Void = { _ in }

    var hasVerticalOverflow: Bool {
        presentation()?.vertical != nil
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        presentationProvider = { [weak self] in
            self?.presentation()
        }
        onDrag = { [weak self] event in
            self?.handleDrag(event)
        }
        onDragStateChanged = { [weak self] isDragging in
            self?.onDraggingChanged(isDragging)
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
        origin.x = 0
        origin.y = maximumOffset * event.positionFraction
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        scrollbarMetricsDidChange()
    }
}
