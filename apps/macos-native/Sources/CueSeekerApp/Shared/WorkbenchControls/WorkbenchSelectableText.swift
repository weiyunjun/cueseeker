import AppKit
import SwiftUI

/// Global coordinator ensuring at most one static text selection exists across the App
/// and coordinating mutual exclusion with `SubtitleTable`, `PlaybackSubtitleFocusReel`,
/// focused text inputs, menus, and modal dialogs.
@MainActor
final class WorkbenchStaticTextSelectionCoordinator {
    static let shared = WorkbenchStaticTextSelectionCoordinator()

    private final class WeakWindowRef {
        weak var window: CueSeekerWindow?
        init(_ window: CueSeekerWindow) {
            self.window = window
        }
    }

    private enum ExternalDragState {
        case idle
        case armed(
            window: WeakWindowRef,
            startWindowPoint: CGPoint,
            lastWindowPoint: CGPoint
        )
        case selecting(view: WorkbenchSelectableTextNSView)
    }

    private(set) weak var activeView: WorkbenchSelectableTextNSView?
    private var externalDragState: ExternalDragState = .idle

    var hasSelection: Bool {
        activeView?.hasSelection == true
    }

    var selectedText: String? {
        activeView?.selectedText
    }

    var isDraggingSelection: Bool {
        if case .selecting = externalDragState {
            return true
        }
        return activeView?.isTrackingMouse == true
    }

    var activeDraggingPointerShape: PointerShape? {
        guard isDraggingSelection, let activeView, activeView.canInteract else {
            return nil
        }
        return activeView.preferredPointerShape
    }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClearTextSelectionNotification(_:)),
            name: .cueSeekerClearTextSelection,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWindowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }

    func beginInteraction(in view: WorkbenchSelectableTextNSView) {
        if let activeView, activeView !== view {
            activeView.clearSelection(notifyCoordinator: false)
        }
        activeView = view
        NotificationCenter.default.post(
            name: .cueSeekerClearTextSelection,
            object: view
        )
    }

    func clearSelection() {
        externalDragState = .idle
        guard let view = activeView else {
            return
        }
        activeView = nil
        view.clearSelection(notifyCoordinator: false)
    }

    func clearSelectionIfOutside(window: NSWindow, windowPoint: CGPoint) {
        guard let activeView else {
            return
        }
        guard activeView.window === window,
              activeView.containsWindowPoint(windowPoint)
        else {
            clearSelection()
            return
        }
    }

    func unregister(_ view: WorkbenchSelectableTextNSView) {
        if case .selecting(let draggingView) = externalDragState, draggingView === view {
            externalDragState = .idle
        }
        if activeView === view {
            activeView = nil
        }
    }

    func handleWindowLeftMouseDown(window: CueSeekerWindow, event: NSEvent) {
        let windowPoint = event.locationInWindow
        clearSelectionIfOutside(window: window, windowPoint: windowPoint)
        externalDragState = .idle

        guard let contentView = window.contentView else {
            return
        }
        if let mainWindow = window as? CueSeekerMainWindow, mainWindow.isFocusLocked() {
            return
        }
        let hitView = contentView.superview?.hitTest(windowPoint)
            ?? contentView.hitTest(contentView.convert(windowPoint, from: nil))
        if hitView is WorkbenchSelectableTextNSView {
            return
        }
        if Self.isInsideDedicatedTextSelectionSurface(hitView) {
            return
        }
        if SubtitleTableTextSelectionHitTesting.isInteractive(
            hitView,
            atWindowPoint: windowPoint,
            in: contentView
        ) {
            return
        }
        if AppPointerShape.manages(window), AppPointerShape.model.shape == .grab {
            return
        }

        externalDragState = .armed(
            window: WeakWindowRef(window),
            startWindowPoint: windowPoint,
            lastWindowPoint: windowPoint
        )
    }

    func handleWindowLeftMouseDragged(window: CueSeekerWindow, event: NSEvent) {
        let currentWindowPoint = event.locationInWindow
        switch externalDragState {
        case .idle:
            return

        case .armed(let weakWindow, let startWindowPoint, let lastWindowPoint):
            guard weakWindow.window === window,
                  let contentView = window.contentView
            else {
                externalDragState = .idle
                return
            }
            externalDragState = .armed(
                window: weakWindow,
                startWindowPoint: startWindowPoint,
                lastWindowPoint: currentWindowPoint
            )
            guard hypot(
                currentWindowPoint.x - startWindowPoint.x,
                currentWindowPoint.y - startWindowPoint.y
            ) >= WorkbenchSelectableTextNSView.dragThreshold else {
                return
            }
            guard let targetView = Self.findHitSelectableTextView(
                in: contentView,
                from: lastWindowPoint,
                to: currentWindowPoint
            ) ?? Self.findHitSelectableTextView(
                in: contentView,
                from: startWindowPoint,
                to: currentWindowPoint
            ) else {
                return
            }
            externalDragState = .selecting(view: targetView)
            targetView.beginExternalDragSelection(
                startWindowPoint: startWindowPoint,
                currentWindowPoint: currentWindowPoint
            )

        case .selecting(let view):
            guard view.window === window, view.canInteract else {
                clearSelection()
                return
            }
            view.updateExternalDragSelection(currentWindowPoint: currentWindowPoint)
        }
    }

    func handleWindowLeftMouseUp(window: CueSeekerWindow, event: NSEvent) {
        switch externalDragState {
        case .idle:
            return
        case .armed:
            externalDragState = .idle
        case .selecting(let view):
            externalDragState = .idle
            guard view.window === window else {
                clearSelection()
                return
            }
            view.endExternalDragSelection(currentWindowPoint: event.locationInWindow)
        }
    }

    private static func isInsideDedicatedTextSelectionSurface(_ hitView: NSView?) -> Bool {
        var current = hitView
        while let view = current {
            if view is SubtitleVirtualTableDocumentView
                || view is SubtitleTableHeaderTextOverlayView
                || view is PlaybackSubtitleFocusReelDocumentView
            {
                return true
            }
            current = view.superview
        }
        return false
    }

    private static func findHitSelectableTextView(
        in rootView: NSView,
        from startPoint: CGPoint,
        to endPoint: CGPoint
    ) -> WorkbenchSelectableTextNSView? {
        var bestMatch: (view: WorkbenchSelectableTextNSView, entryT: CGFloat, distanceSq: CGFloat)?

        func visit(_ view: NSView) {
            guard view.window != nil,
                  !view.isHidden,
                  view.alphaValue > 0
            else {
                return
            }
            if let selectable = view as? WorkbenchSelectableTextNSView {
                guard selectable.canInteract,
                      let hitRect = selectable.windowSelectionHitRect(),
                      let entryT = segmentRectIntersectionParameter(
                          from: startPoint,
                          to: endPoint,
                          rect: hitRect
                      )
                else {
                    return
                }
                let distanceSq = squaredDistance(from: endPoint, to: hitRect)
                if let currentBest = bestMatch {
                    if entryT < currentBest.entryT - 0.0001
                        || (abs(entryT - currentBest.entryT) <= 0.0001 && distanceSq < currentBest.distanceSq)
                    {
                        bestMatch = (selectable, entryT, distanceSq)
                    }
                } else {
                    bestMatch = (selectable, entryT, distanceSq)
                }
                return
            }
            for subview in view.subviews.reversed() {
                visit(subview)
            }
        }

        visit(rootView)
        return bestMatch?.view
    }

    static func segmentRectIntersectionParameter(
        from p0: CGPoint,
        to p1: CGPoint,
        rect: CGRect
    ) -> CGFloat? {
        guard !rect.isNull, !rect.isEmpty else {
            return nil
        }
        if rect.contains(p0) {
            return 0
        }
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        var tMin: CGFloat = 0
        var tMax: CGFloat = 1

        let checks: [(p: CGFloat, q: CGFloat)] = [
            (-dx, p0.x - rect.minX),
            (dx, rect.maxX - p0.x),
            (-dy, p0.y - rect.minY),
            (dy, rect.maxY - p0.y),
        ]

        for check in checks {
            if abs(check.p) < 1e-6 {
                if check.q < 0 {
                    return nil
                }
            } else {
                let t = check.q / check.p
                if check.p < 0 {
                    if t > tMax { return nil }
                    if t > tMin { tMin = t }
                } else {
                    if t < tMin { return nil }
                    if t < tMax { tMax = t }
                }
            }
        }
        return tMin <= tMax ? max(0, tMin) : nil
    }

    private static func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    @discardableResult
    func copyActiveSelection(to pasteboard: NSPasteboard = .general) -> Bool {
        guard let activeView,
              activeView.canInteract,
              let text = activeView.selectedText,
              !text.isEmpty
        else {
            return false
        }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    @objc private func handleClearTextSelectionNotification(_ notification: Notification) {
        if let sender = notification.object as? WorkbenchSelectableTextNSView,
           sender === activeView {
            return
        }
        clearSelection()
    }

    @objc private func handleAppDidResignActive(_ notification: Notification) {
        clearSelection()
    }

    @objc private func handleWindowDidResignKey(_ notification: Notification) {
        guard let resignedWindow = notification.object as? NSWindow,
              activeView?.window === resignedWindow
        else {
            return
        }
        clearSelection()
    }
}

/// Reusable static text component supporting mouse drag selection, double-click word
/// selection, triple-click select-all, `Cmd + C` copy, `.iBeam` / `.grab` pointer shape,
/// and optional single-click action disambiguated from drag selection.
struct WorkbenchSelectableText: View {
    let text: String
    var fontSize: CGFloat = WorkbenchControlMetrics.redesignFontSizeBody
    var weight: Font.Weight = .regular
    var monospacedDigits: Bool = false
    var color: Color = WorkbenchRedesignColors.textPrimary
    var lineLimit: Int? = nil
    var truncationMode: Text.TruncationMode = .tail
    var alignment: TextAlignment = .leading
    var isSelectable: Bool = true
    var preferredPointerShape: PointerShape = .iBeam
    var showsUnderline: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.interfaceLayerContext) private var interfaceLayerContext

    init(
        _ text: String,
        fontSize: CGFloat = WorkbenchControlMetrics.redesignFontSizeBody,
        weight: Font.Weight = .regular,
        monospacedDigits: Bool = false,
        color: Color = WorkbenchRedesignColors.textPrimary,
        lineLimit: Int? = nil,
        truncationMode: Text.TruncationMode = .tail,
        alignment: TextAlignment = .leading,
        isSelectable: Bool = true,
        preferredPointerShape: PointerShape = .iBeam,
        showsUnderline: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.fontSize = fontSize
        self.weight = weight
        self.monospacedDigits = monospacedDigits
        self.color = color
        self.lineLimit = lineLimit
        self.truncationMode = truncationMode
        self.alignment = alignment
        self.isSelectable = isSelectable
        self.preferredPointerShape = preferredPointerShape
        self.showsUnderline = showsUnderline
        self.onTap = onTap
    }

    private var swiftUIFont: Font {
        let base = Font.system(size: fontSize, weight: weight)
        return monospacedDigits ? base.monospacedDigit() : base
    }

    private var nsFont: NSFont {
        let nsWeight = Self.nsFontWeight(for: weight)
        if monospacedDigits {
            return .monospacedDigitSystemFont(ofSize: fontSize, weight: nsWeight)
        }
        return .systemFont(ofSize: fontSize, weight: nsWeight)
    }

    private var nsAlignment: NSTextAlignment {
        switch alignment {
        case .leading:
            return .left
        case .center:
            return .center
        case .trailing:
            return .right
        }
    }

    private var isEffectivelySelectable: Bool {
        isSelectable && !text.isEmpty
    }

    var body: some View {
        Text(text)
            .font(swiftUIFont)
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .truncationMode(truncationMode)
            .multilineTextAlignment(alignment)
            .opacity(isEffectivelySelectable ? 0 : 1)
            .overlay {
                if isEffectivelySelectable {
                    WorkbenchSelectableTextRepresentable(
                        text: text,
                        font: nsFont,
                        textColor: NSColor(color),
                        alignment: nsAlignment,
                        lineLimit: lineLimit,
                        truncatesTail: truncationMode == .tail,
                        isSelectable: isEffectivelySelectable,
                        preferredPointerShape: preferredPointerShape,
                        showsUnderline: showsUnderline,
                        onTap: onTap,
                        interfaceLayerContext: interfaceLayerContext
                    )
                }
            }
    }

    private static func nsFontWeight(for weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight:
            return .ultraLight
        case .thin:
            return .thin
        case .light:
            return .light
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .black:
            return .black
        default:
            return .regular
        }
    }
}

private struct WorkbenchSelectableTextRepresentable: NSViewRepresentable {
    let text: String
    let font: NSFont
    let textColor: NSColor
    let alignment: NSTextAlignment
    let lineLimit: Int?
    let truncatesTail: Bool
    let isSelectable: Bool
    let preferredPointerShape: PointerShape
    let showsUnderline: Bool
    let onTap: (() -> Void)?
    let interfaceLayerContext: InterfaceLayerContext

    func makeNSView(context _: Context) -> WorkbenchSelectableTextNSView {
        let view = WorkbenchSelectableTextNSView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: WorkbenchSelectableTextNSView, context _: Context) {
        update(nsView)
    }

    static func dismantleNSView(_ nsView: WorkbenchSelectableTextNSView, coordinator _: ()) {
        MainActor.assumeIsolated {
            nsView.clearSelection(notifyCoordinator: true)
            WorkbenchStaticTextSelectionCoordinator.shared.unregister(nsView)
        }
    }

    private func update(_ view: WorkbenchSelectableTextNSView) {
        view.configure(
            text: text,
            font: font,
            textColor: textColor,
            alignment: alignment,
            lineLimit: lineLimit,
            truncatesTail: truncatesTail,
            isSelectable: isSelectable,
            preferredPointerShape: preferredPointerShape,
            showsUnderline: showsUnderline,
            onTap: onTap,
            interfaceLayerContext: interfaceLayerContext
        )
    }
}

@MainActor
final class WorkbenchSelectableTextNSView: NSView, PointerShapeProviding, SubtitleTableTextSelectionInteractiveView {
    static let dragThreshold: CGFloat = 2.0

    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    private(set) var text: String = ""
    private(set) var font: NSFont = .systemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeBody,
        weight: .regular
    )
    private(set) var textColor: NSColor = WorkbenchRedesignColors.NS.textPrimary
    private(set) var alignment: NSTextAlignment = .left
    private(set) var lineLimit: Int? = nil
    private(set) var truncatesTail: Bool = true
    private(set) var isSelectable: Bool = true
    private(set) var preferredPointerShape: PointerShape = .iBeam
    private(set) var showsUnderline: Bool = false
    var onTap: (() -> Void)?
    private(set) var interfaceLayerContext = InterfaceLayerContext()

    private(set) var selectedRange: NSRange?
    private(set) var isTrackingMouse = false
    private var anchorRange = NSRange(location: 0, length: 0)
    private var startWindowPoint: CGPoint = .zero
    private var activeClickCount = 1
    private var didDrag = false

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override var acceptsFirstResponder: Bool {
        canInteract
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    var hasSelection: Bool {
        guard let selectedRange else { return false }
        return selectedRange.length > 0
    }

    var selectedText: String? {
        guard let selectedRange, selectedRange.length > 0 else {
            return nil
        }
        let nsText = text as NSString
        let safeRange = NSIntersectionRange(
            selectedRange,
            NSRange(location: 0, length: nsText.length)
        )
        guard safeRange.length > 0 else {
            return nil
        }
        return nsText.substring(with: safeRange)
    }

    var isFrozenOrCovered: Bool {
        interfaceLayerContext.isFrozen || interfaceLayerContext.isCovered
    }

    var canInteract: Bool {
        guard isSelectable, !text.isEmpty, !isFrozenOrCovered, !isHiddenOrHasHiddenAncestor else {
            return false
        }
        if let mainWindow = window as? CueSeekerMainWindow {
            if mainWindow.isFocusLocked() || mainWindow.isBehindDialog(self) {
                return false
            }
            if mainWindow.isWorkbenchCovered(), interfaceLayerContext.layer == .workbenchPage {
                return false
            }
        }
        return true
    }

    var subtitleTableTextSelectionInteraction: SubtitleTableTextSelectionInteraction {
        canInteract ? .interactive : .nonInteractive
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textContainer.lineFragmentPadding = 0
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        text: String,
        font: NSFont,
        textColor: NSColor,
        alignment: NSTextAlignment,
        lineLimit: Int?,
        truncatesTail: Bool,
        isSelectable: Bool,
        preferredPointerShape: PointerShape,
        showsUnderline: Bool,
        onTap: (() -> Void)?,
        interfaceLayerContext: InterfaceLayerContext
    ) {
        let textChanged = self.text != text
        let styleChanged = self.font != font
            || self.textColor != textColor
            || self.alignment != alignment
            || self.lineLimit != lineLimit
            || self.truncatesTail != truncatesTail
            || self.isSelectable != isSelectable
            || self.preferredPointerShape != preferredPointerShape
            || self.showsUnderline != showsUnderline
        let layerChanged = self.interfaceLayerContext.layer != interfaceLayerContext.layer
            || self.interfaceLayerContext.isCovered != interfaceLayerContext.isCovered
            || self.interfaceLayerContext.isFrozen != interfaceLayerContext.isFrozen

        self.text = text
        self.font = font
        self.textColor = textColor
        self.alignment = alignment
        self.lineLimit = lineLimit
        self.truncatesTail = truncatesTail
        self.isSelectable = isSelectable
        self.preferredPointerShape = preferredPointerShape
        self.showsUnderline = showsUnderline
        self.onTap = onTap
        self.interfaceLayerContext = interfaceLayerContext

        if textChanged || !canInteract {
            clearSelection(notifyCoordinator: true)
        }

        if textChanged || styleChanged || layerChanged {
            updateTextLayout()
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        super.setFrameSize(newSize)
        if oldSize != newSize {
            updateTextLayout()
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            clearSelection(notifyCoordinator: true)
            WorkbenchStaticTextSelectionCoordinator.shared.unregister(self)
        } else {
            updateTextLayout()
            window?.invalidateCursorRects(for: self)
        }
    }

    override func viewDidHide() {
        super.viewDidHide()
        clearSelection(notifyCoordinator: true)
    }

    override func resetCursorRects() {
        if AppPointerShape.manages(window) {
            addCursorRect(visibleRect, cursor: AppPointerShape.rectCursor)
        } else if canInteract {
            updateTextLayout()
            let origin = textOrigin()
            for rect in lineUsedRects(at: origin) {
                let clipped = rect.intersection(bounds)
                if !clipped.isNull, clipped.width > 0, clipped.height > 0 {
                    addCursorRect(clipped, cursor: preferredPointerShape.cursor)
                }
            }
        } else {
            super.resetCursorRects()
        }
    }

    func pointerShape(atWindowPoint windowPoint: CGPoint) -> PointerShape {
        guard canInteract else {
            return .arrow
        }
        let point = convert(windowPoint, from: nil)
        guard bounds.contains(point) else {
            return .arrow
        }
        if onTap != nil || lineLimit == 1 || containsText(at: point) {
            return preferredPointerShape
        }
        return .arrow
    }

    func containsWindowPoint(_ windowPoint: CGPoint) -> Bool {
        guard window != nil else { return false }
        let point = convert(windowPoint, from: nil)
        return bounds.contains(point)
    }

    func windowSelectionHitRect() -> CGRect? {
        guard window != nil,
              !isHiddenOrHasHiddenAncestor,
              bounds.width > 0,
              bounds.height > 0
        else {
            return nil
        }
        var rect = convert(bounds.insetBy(dx: -4, dy: -2), to: nil).standardized
        var current = superview
        while !rect.isNull, !rect.isEmpty, let ancestor = current {
            guard !ancestor.isHidden, ancestor.alphaValue > 0 else {
                return nil
            }
            if ancestor is NSClipView || ancestor is NSScrollView {
                let clipRect = ancestor.convert(ancestor.bounds, to: nil).standardized
                rect = rect.intersection(clipRect)
            }
            current = ancestor.superview
        }
        return (rect.isNull || rect.isEmpty) ? nil : rect
    }

    func beginExternalDragSelection(
        startWindowPoint: CGPoint,
        currentWindowPoint: CGPoint
    ) {
        guard canInteract else { return }
        WorkbenchStaticTextSelectionCoordinator.shared.beginInteraction(in: self)
        _ = window?.makeFirstResponder(self)

        updateTextLayout()
        let startPoint = convert(startWindowPoint, from: nil)
        let currentPoint = convert(currentWindowPoint, from: nil)
        let anchorOffset = utf16Offset(at: startPoint)

        self.startWindowPoint = startWindowPoint
        self.activeClickCount = 1
        self.anchorRange = NSRange(location: anchorOffset, length: 0)
        self.didDrag = true
        self.isTrackingMouse = true
        updateSelectionForDrag(at: currentPoint)
        needsDisplay = true
    }

    func updateExternalDragSelection(currentWindowPoint: CGPoint) {
        guard isTrackingMouse, canInteract else {
            clearSelection(notifyCoordinator: true)
            return
        }
        let point = convert(currentWindowPoint, from: nil)
        updateSelectionForDrag(at: point)
    }

    func endExternalDragSelection(currentWindowPoint: CGPoint) {
        guard isTrackingMouse else { return }
        isTrackingMouse = false
        guard canInteract else {
            clearSelection(notifyCoordinator: true)
            return
        }
        let point = convert(currentWindowPoint, from: nil)
        updateSelectionForDrag(at: point)
        if !hasSelection {
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        }
    }

    // MARK: - Mouse & Keyboard Handling

    override func mouseDown(with event: NSEvent) {
        guard canInteract else {
            super.mouseDown(with: event)
            return
        }
        WorkbenchStaticTextSelectionCoordinator.shared.beginInteraction(in: self)
        _ = window?.makeFirstResponder(self)

        updateTextLayout()
        let point = convert(event.locationInWindow, from: nil)
        let offset = utf16Offset(at: point)
        let clickCount = max(1, event.clickCount)

        startWindowPoint = event.locationInWindow
        activeClickCount = clickCount
        isTrackingMouse = true

        if onTap != nil {
            anchorRange = NSRange(location: offset, length: 0)
            selectedRange = nil
            didDrag = false
        } else if clickCount >= 3 {
            let fullRange = NSRange(location: 0, length: textStorage.length)
            anchorRange = fullRange
            selectedRange = fullRange.length > 0 ? fullRange : nil
            didDrag = true
        } else if clickCount == 2 {
            let word = wordRange(at: offset)
            anchorRange = word
            selectedRange = word.length > 0 ? word : nil
            didDrag = true
        } else {
            anchorRange = NSRange(location: offset, length: 0)
            selectedRange = nil
            didDrag = false
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isTrackingMouse else {
            super.mouseDragged(with: event)
            return
        }
        guard canInteract else {
            clearSelection(notifyCoordinator: true)
            return
        }
        let windowPoint = event.locationInWindow
        if !didDrag {
            let distance = hypot(
                windowPoint.x - startWindowPoint.x,
                windowPoint.y - startWindowPoint.y
            )
            guard distance >= Self.dragThreshold else {
                return
            }
            didDrag = true
        }
        updateSelectionForDrag(at: convert(windowPoint, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        guard isTrackingMouse else {
            super.mouseUp(with: event)
            return
        }
        isTrackingMouse = false
        guard canInteract else {
            clearSelection(notifyCoordinator: true)
            return
        }

        let windowPoint = event.locationInWindow
        if !didDrag {
            let distance = hypot(
                windowPoint.x - startWindowPoint.x,
                windowPoint.y - startWindowPoint.y
            )
            if distance >= Self.dragThreshold {
                didDrag = true
            }
        }

        let point = convert(windowPoint, from: nil)
        if didDrag {
            if activeClickCount == 1 || onTap != nil {
                updateSelectionForDrag(at: point)
            }
            if !hasSelection {
                WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
            }
            return
        }

        WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        if let onTap, bounds.insetBy(dx: -2, dy: -2).contains(point) {
            onTap()
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown {
            let flags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function])
            if flags == .command,
               event.charactersIgnoringModifiers?.lowercased() == "c" || event.keyCode == 8,
               hasSelection,
               WorkbenchStaticTextSelectionCoordinator.shared.activeView === self
            {
                return WorkbenchStaticTextSelectionCoordinator.shared.copyActiveSelection()
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    @IBAction func copy(_ sender: Any?) {
        _ = WorkbenchStaticTextSelectionCoordinator.shared.copyActiveSelection()
    }

    @IBAction override func selectAll(_ sender: Any?) {
        selectAllText()
    }

    func selectAllText() {
        guard canInteract else { return }
        WorkbenchStaticTextSelectionCoordinator.shared.beginInteraction(in: self)
        _ = window?.makeFirstResponder(self)
        updateTextLayout()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        anchorRange = fullRange
        selectedRange = fullRange.length > 0 ? fullRange : nil
        needsDisplay = true
    }

    func selectRangeForTesting(_ range: NSRange) {
        guard canInteract else { return }
        WorkbenchStaticTextSelectionCoordinator.shared.beginInteraction(in: self)
        _ = window?.makeFirstResponder(self)
        updateTextLayout()
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        anchorRange = safeRange
        selectedRange = safeRange.length > 0 ? safeRange : nil
        needsDisplay = true
    }

    func clearSelection(notifyCoordinator: Bool) {
        isTrackingMouse = false
        didDrag = false
        let hadSelection = selectedRange != nil
        selectedRange = nil
        if notifyCoordinator {
            WorkbenchStaticTextSelectionCoordinator.shared.unregister(self)
        }
        if hadSelection {
            needsDisplay = true
        }
    }

    // MARK: - Drawing & TextKit Layout

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty else { return }
        updateTextLayout()
        let origin = textOrigin()
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }

        if let selectedRange, selectedRange.length > 0 {
            NSColor.selectedTextBackgroundColor.setFill()
            for rect in selectionRects(forUTF16Range: selectedRange, at: origin) {
                rect.intersection(bounds).fill()
            }
        }

        if showsUnderline {
            drawUnderline(
                at: origin,
                color: textColor,
                thickness: WorkbenchControlMetrics.redesignInteractiveTextUnderlineThickness,
                offset: WorkbenchControlMetrics.redesignInteractiveTextUnderlineOffset,
                backingScaleFactor: window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
            )
        }

        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    private func updateTextLayout() {
        let paragraphStyle = NSMutableParagraphStyle()
        let availableWidth = max(0, bounds.width)

        if lineLimit == 1 {
            let naturalWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
            let isTruncated = truncatesTail && availableWidth > 0 && availableWidth < naturalWidth - 1.5
            paragraphStyle.alignment = isTruncated ? alignment : .left
            paragraphStyle.lineBreakMode = isTruncated ? .byTruncatingTail : .byClipping
            paragraphStyle.tighteningFactorForTruncation = 0

            textContainer.maximumNumberOfLines = 1
            textContainer.lineBreakMode = isTruncated ? .byTruncatingTail : .byClipping
            textContainer.size = CGSize(
                width: isTruncated ? availableWidth : max(availableWidth, naturalWidth + 8),
                height: .greatestFiniteMagnitude
            )
        } else {
            paragraphStyle.alignment = alignment
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.tighteningFactorForTruncation = 0

            let maxLines = lineLimit ?? 0
            textContainer.maximumNumberOfLines = maxLines
            textContainer.lineBreakMode = (maxLines > 0 && truncatesTail) ? .byTruncatingTail : .byWordWrapping
            textContainer.size = CGSize(
                width: max(0, availableWidth + 1.5),
                height: .greatestFiniteMagnitude
            )
        }

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle,
            ]
        )
        textStorage.setAttributedString(attributed)
        layoutManager.ensureLayout(for: textContainer)
    }

    private func textOrigin() -> CGPoint {
        let usedRect = layoutManager.usedRect(for: textContainer)
        let originY = max(0, (bounds.height - usedRect.height) / 2)
        if lineLimit == 1, textContainer.lineBreakMode == .byClipping {
            switch alignment {
            case .center:
                return CGPoint(
                    x: (bounds.width - usedRect.width) / 2 - usedRect.minX,
                    y: originY
                )
            case .right:
                return CGPoint(
                    x: bounds.width - usedRect.maxX,
                    y: originY
                )
            default:
                return CGPoint(x: 0, y: originY)
            }
        }
        return CGPoint(x: 0, y: originY)
    }

    private func updateSelectionForDrag(at point: CGPoint) {
        let offset = utf16Offset(at: point)
        let nextRange: NSRange?
        if activeClickCount >= 3, onTap == nil {
            let full = NSRange(location: 0, length: textStorage.length)
            nextRange = full.length > 0 ? full : nil
        } else if activeClickCount == 2, onTap == nil {
            let targetWord = wordRange(at: offset)
            let lower = min(anchorRange.location, targetWord.location)
            let upper = max(NSMaxRange(anchorRange), NSMaxRange(targetWord))
            nextRange = upper > lower ? NSRange(location: lower, length: upper - lower) : nil
        } else {
            let lower = min(anchorRange.location, offset)
            let upper = max(NSMaxRange(anchorRange), offset)
            nextRange = upper > lower ? NSRange(location: lower, length: upper - lower) : nil
        }
        if selectedRange != nextRange {
            selectedRange = nextRange
            needsDisplay = true
        }
    }

    func utf16Offset(at point: CGPoint) -> Int {
        guard textStorage.length > 0 else { return 0 }
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return 0 }
        let origin = textOrigin()
        let lines = lineUsedRects(at: origin)
        guard let firstLine = lines.first, let lastLine = lines.last else {
            return 0
        }

        let topSnapThreshold = firstLine.minY - max(12, firstLine.height)
        let bottomSnapThreshold = lastLine.maxY + max(12, lastLine.height)
        if point.y < topSnapThreshold {
            return 0
        }
        if point.y > bottomSnapThreshold {
            return textStorage.length
        }

        let targetLine = lines.min { lhs, rhs in
            Self.verticalDistance(from: point.y, to: lhs)
                < Self.verticalDistance(from: point.y, to: rhs)
        } ?? firstLine

        let localPoint = CGPoint(
            x: point.x - origin.x,
            y: targetLine.midY - origin.y
        )
        var fraction: CGFloat = 0
        let rawGlyphIndex = layoutManager.glyphIndex(
            for: localPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        let glyphIndex = min(
            max(rawGlyphIndex, validGlyphRange.location),
            NSMaxRange(validGlyphRange) - 1
        )
        let characterRange = layoutManager.characterRange(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            actualGlyphRange: nil
        )
        let characterIndex = fraction >= 0.5
            ? NSMaxRange(characterRange)
            : characterRange.location
        return min(max(0, characterIndex), textStorage.length)
    }

    private static func verticalDistance(from y: CGFloat, to rect: CGRect) -> CGFloat {
        if y < rect.minY {
            return rect.minY - y
        }
        if y > rect.maxY {
            return y - rect.maxY
        }
        return 0
    }

    func wordRange(at utf16Offset: Int) -> NSRange {
        guard textStorage.length > 0 else {
            return NSRange(location: 0, length: 0)
        }
        let clampedIndex = min(max(0, utf16Offset), textStorage.length - 1)
        return textStorage.doubleClick(at: clampedIndex)
    }

    private func containsText(at point: CGPoint) -> Bool {
        let origin = textOrigin()
        return lineUsedRects(at: origin).contains {
            $0.insetBy(dx: -2, dy: -2).contains(point)
        }
    }

    private func selectionRects(forUTF16Range range: NSRange, at origin: CGPoint) -> [CGRect] {
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        guard safeRange.length > 0 else { return [] }
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: safeRange,
            actualCharacterRange: nil
        )
        var rects: [CGRect] = []
        layoutManager.enumerateEnclosingRects(
            forGlyphRange: glyphRange,
            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
            in: textContainer
        ) { rect, _ in
            rects.append(rect.offsetBy(dx: origin.x, dy: origin.y))
        }
        return rects
    }

    private func lineUsedRects(at origin: CGPoint) -> [CGRect] {
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return [] }
        var rects: [CGRect] = []
        var glyphIndex = validGlyphRange.location
        while glyphIndex < NSMaxRange(validGlyphRange) {
            var lineRange = NSRange(location: 0, length: 0)
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange
            )
            if usedRect.width > 0, usedRect.height > 0 {
                rects.append(usedRect.offsetBy(dx: origin.x, dy: origin.y))
            }
            guard lineRange.length > 0 else { break }
            glyphIndex = NSMaxRange(lineRange)
        }
        return rects
    }

    private func drawUnderline(
        at origin: CGPoint,
        color: NSColor,
        thickness: CGFloat,
        offset: CGFloat,
        backingScaleFactor: CGFloat
    ) {
        let scale = max(1, backingScaleFactor)
        let lineThickness = max(1 / scale, thickness)
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return }

        color.setFill()
        var glyphIndex = validGlyphRange.location
        while glyphIndex < NSMaxRange(validGlyphRange) {
            var lineRange = NSRange(location: 0, length: 0)
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange
            )
            if usedRect.width > 0 {
                let baseline = origin.y
                    + usedRect.minY
                    + layoutManager.location(forGlyphAt: glyphIndex).y
                let y = (baseline + offset * scale).rounded() / scale
                let minX = floor((origin.x + usedRect.minX) * scale) / scale
                let maxX = ceil((origin.x + usedRect.maxX) * scale) / scale
                let rect = CGRect(
                    x: minX,
                    y: y,
                    width: max(0, maxX - minX),
                    height: lineThickness
                )
                if rect.width > 0 {
                    rect.fill()
                }
            }
            guard lineRange.length > 0 else { break }
            glyphIndex = NSMaxRange(lineRange)
        }
    }
}
