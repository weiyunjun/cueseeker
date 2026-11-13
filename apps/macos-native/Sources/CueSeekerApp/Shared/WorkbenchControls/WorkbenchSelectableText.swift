import AppKit
import SwiftUI

/// Reusable static text component supporting mouse drag selection, double-click word
/// selection, triple-click select-all, `Cmd + C` copy, `.iBeam` / `.grab` pointer shape,
/// and optional single-click action disambiguated from drag selection.
struct WorkbenchSelectableText: View {
    let text: String
    var fullCopyText: String? = nil
    var fontSize: CGFloat = WorkbenchControlMetrics.redesignFontSizeBody
    var weight: Font.Weight = .regular
    var monospacedDigits: Bool = false
    var color: Color = WorkbenchRedesignColors.textPrimary
    var lineLimit: Int? = nil
    var lineHeight: CGFloat? = nil
    var truncationMode: Text.TruncationMode = .tail
    var alignment: TextAlignment = .leading
    var isSelectable: Bool = true
    var preferredPointerShape: PointerShape = .iBeam
    var showsUnderline: Bool = false
    var allowsMenuModalInteraction: Bool = false
    var onTap: (() -> Void)? = nil

    @Environment(\.interfaceLayerContext) private var interfaceLayerContext
    @Environment(\.workbenchDialogID) private var dialogID
    @Environment(\.isWorkbenchDialogCovered) private var isDialogCovered

    init(
        _ text: String,
        fullCopyText: String? = nil,
        fontSize: CGFloat = WorkbenchControlMetrics.redesignFontSizeBody,
        weight: Font.Weight = .regular,
        monospacedDigits: Bool = false,
        color: Color = WorkbenchRedesignColors.textPrimary,
        lineLimit: Int? = nil,
        lineHeight: CGFloat? = nil,
        truncationMode: Text.TruncationMode = .tail,
        alignment: TextAlignment = .leading,
        isSelectable: Bool = true,
        preferredPointerShape: PointerShape = .iBeam,
        showsUnderline: Bool = false,
        allowsMenuModalInteraction: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.text = text
        self.fullCopyText = fullCopyText
        self.fontSize = fontSize
        self.weight = weight
        self.monospacedDigits = monospacedDigits
        self.color = color
        self.lineLimit = lineLimit
        self.lineHeight = lineHeight
        self.truncationMode = truncationMode
        self.alignment = alignment
        self.isSelectable = isSelectable
        self.preferredPointerShape = preferredPointerShape
        self.showsUnderline = showsUnderline
        self.allowsMenuModalInteraction = allowsMenuModalInteraction
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
        let resolvedLineHeight: CGFloat? = (lineHeight ?? 0) > 0 ? lineHeight : nil
        WorkbenchSelectableTextSizingLayout(
            text: text,
            font: nsFont,
            lineLimit: lineLimit,
            lineHeight: resolvedLineHeight,
            truncatesTail: truncationMode == .tail
        ) {
            Text(text)
                .font(swiftUIFont)
                .foregroundStyle(color)
                .lineLimit(lineLimit)
                .truncationMode(truncationMode)
                .multilineTextAlignment(alignment)
                .opacity(isEffectivelySelectable ? 0 : 1)
        }
        .overlay {
            if isEffectivelySelectable {
                WorkbenchSelectableTextRepresentable(
                    text: text,
                    fullCopyText: fullCopyText,
                    font: nsFont,
                    textColor: NSColor(color),
                    alignment: nsAlignment,
                    lineLimit: lineLimit,
                    lineHeight: resolvedLineHeight,
                    truncatesTail: truncationMode == .tail,
                    truncationMode: truncationMode,
                    isSelectable: isEffectivelySelectable,
                    preferredPointerShape: preferredPointerShape,
                    showsUnderline: showsUnderline,
                    allowsMenuModalInteraction: allowsMenuModalInteraction,
                    onTap: onTap,
                    interfaceLayerContext: interfaceLayerContext,
                    dialogID: dialogID,
                    isDialogCovered: isDialogCovered
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

private struct WorkbenchSelectableTextSizingLayout: Layout {
    let text: String
    let font: NSFont
    let lineLimit: Int?
    let lineHeight: CGFloat?
    let truncatesTail: Bool

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let baseSize = subview.sizeThatFits(proposal)
        guard let lineHeight, lineHeight > 0 else {
            return baseSize
        }
        if lineLimit == 1 {
            return CGSize(width: baseSize.width, height: lineHeight)
        }
        let targetWidth: CGFloat
        if let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth > 0 {
            targetWidth = proposedWidth
        } else {
            targetWidth = baseSize.width
        }
        let measuredHeight = WorkbenchSelectableTextNSView.measuredMultilineHeight(
            for: text,
            font: font,
            lineHeight: lineHeight,
            lineLimit: lineLimit,
            truncatesTail: truncatesTail,
            width: targetWidth
        )
        return CGSize(
            width: targetWidth,
            height: max(baseSize.height, measuredHeight)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for subview in subviews {
            subview.place(
                at: bounds.origin,
                proposal: ProposedViewSize(bounds.size)
            )
        }
    }

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGFloat? {
        guard lineHeight == nil, let subview = subviews.first else {
            return nil
        }
        let dimensions = subview.dimensions(in: ProposedViewSize(bounds.size))
        if let explicit = dimensions[explicit: guide] {
            return bounds.minY + explicit
        }
        if guide == .firstTextBaseline || guide == .lastTextBaseline {
            return bounds.minY + dimensions[guide]
        }
        return nil
    }
}

private struct WorkbenchSelectableTextRepresentable: NSViewRepresentable {
    let text: String
    let fullCopyText: String?
    let font: NSFont
    let textColor: NSColor
    let alignment: NSTextAlignment
    let lineLimit: Int?
    let lineHeight: CGFloat?
    let truncatesTail: Bool
    let truncationMode: Text.TruncationMode?
    let isSelectable: Bool
    let preferredPointerShape: PointerShape
    let showsUnderline: Bool
    let allowsMenuModalInteraction: Bool
    let onTap: (() -> Void)?
    let interfaceLayerContext: InterfaceLayerContext
    let dialogID: WorkbenchDialogAccessibilityID?
    let isDialogCovered: Bool

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
            fullCopyText: fullCopyText,
            font: font,
            textColor: textColor,
            alignment: alignment,
            lineLimit: lineLimit,
            lineHeight: lineHeight,
            truncatesTail: truncatesTail,
            truncationMode: truncationMode,
            isSelectable: isSelectable,
            preferredPointerShape: preferredPointerShape,
            showsUnderline: showsUnderline,
            allowsMenuModalInteraction: allowsMenuModalInteraction,
            onTap: onTap,
            interfaceLayerContext: interfaceLayerContext,
            dialogID: dialogID,
            isDialogCovered: isDialogCovered
        )
    }
}

@MainActor
final class WorkbenchSelectableTextNSView:
    NSView,
    PointerShapeProviding,
    SubtitleTableTextSelectionInteractiveView,
    NSMenuItemValidation
{
    static let dragThreshold: CGFloat = 2.0

    private struct LineFragmentLayout {
        let usedRect: CGRect
        let glyphRange: NSRange
        let charRange: NSRange
        let truncatedGlyphRange: NSRange?
    }

    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    private(set) var text: String = ""
    private(set) var fullCopyText: String? = nil
    private(set) var font: NSFont = .systemFont(
        ofSize: WorkbenchControlMetrics.redesignFontSizeBody,
        weight: .regular
    )
    private(set) var textColor: NSColor = WorkbenchRedesignColors.NS.textPrimary
    private(set) var alignment: NSTextAlignment = .left
    private(set) var lineLimit: Int? = nil
    private(set) var lineHeight: CGFloat? = nil
    private(set) var truncatesTail: Bool = true
    private(set) var truncationMode: Text.TruncationMode? = nil
    private(set) var isSelectable: Bool = true
    private(set) var preferredPointerShape: PointerShape = .iBeam
    private(set) var showsUnderline: Bool = false
    private(set) var allowsMenuModalInteraction: Bool = false
    var onTap: (() -> Void)?
    private(set) var interfaceLayerContext = InterfaceLayerContext()
    private(set) var dialogID: WorkbenchDialogAccessibilityID? = nil
    private(set) var isDialogCovered: Bool = false

    private(set) var selectedRange: NSRange?
    private(set) var isTrackingMouse = false
    private var anchorRange = NSRange(location: 0, length: 0)
    private var startWindowPoint: CGPoint = .zero
    private var activeClickCount = 1
    private var didDrag = false
    private var needsTextLayout = true

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    override var acceptsFirstResponder: Bool {
        canInteract
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    var textLengthUTF16: Int {
        (text as NSString).length
    }

    var flowScope: StaticTextFlowScope? {
        guard let window else { return nil }
        let wn = window.windowNumber
        if allowsMenuModalInteraction {
            return .menuModalPopover(windowNumber: wn)
        }
        if interfaceLayerContext.layer == .dialog {
            return .dialog(windowNumber: wn, dialogID: dialogID)
        }
        return .surface(windowNumber: wn, layer: interfaceLayerContext.layer)
    }

    var hasSelection: Bool {
        guard let selectedRange else { return false }
        return selectedRange.length > 0
    }

    private var hasSyntheticEllipsisSuffix: Bool {
        guard let fullCopyText, !fullCopyText.isEmpty, fullCopyText != text else {
            return false
        }
        return text.hasSuffix("...") && textLengthUTF16 >= 3
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
        if NSMaxRange(safeRange) >= nsText.length,
           let fullCopyText,
           !fullCopyText.isEmpty,
           fullCopyText != text
        {
            if safeRange.location == 0 {
                return fullCopyText
            }
            if text.hasSuffix("..."), nsText.length >= 3 {
                let stemLength = nsText.length - 3
                let stem = nsText.substring(to: stemLength)
                if fullCopyText.hasPrefix(stem) {
                    let start = min(safeRange.location, stemLength)
                    return (fullCopyText as NSString).substring(from: start)
                }
            }
            let normalizedFull = fullCopyText.replacingOccurrences(of: "\r\n", with: "\n")
            let nsFull = normalizedFull as NSString
            if nsFull.length == nsText.length, safeRange.location < nsFull.length {
                return nsFull.substring(from: safeRange.location)
            }
            if safeRange.location < nsFull.length,
               nsText.substring(to: safeRange.location) == nsFull.substring(to: safeRange.location)
            {
                return nsFull.substring(from: safeRange.location)
            }
        }
        return nsText.substring(with: safeRange)
    }

    var isFrozenOrCovered: Bool {
        if isDialogCovered {
            return true
        }
        if allowsMenuModalInteraction {
            return interfaceLayerContext.isCovered
        }
        return interfaceLayerContext.isFrozen || interfaceLayerContext.isCovered
    }

    var canInteract: Bool {
        guard isSelectable, !text.isEmpty, !isFrozenOrCovered, !isHiddenOrHasHiddenAncestor else {
            return false
        }
        if let mainWindow = window as? CueSeekerMainWindow {
            if mainWindow.isBehindDialog(self) {
                return false
            }
            if mainWindow.isFocusLocked(), !allowsMenuModalInteraction {
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
        fullCopyText: String? = nil,
        font: NSFont,
        textColor: NSColor,
        alignment: NSTextAlignment,
        lineLimit: Int?,
        lineHeight: CGFloat? = nil,
        truncatesTail: Bool,
        truncationMode: Text.TruncationMode? = nil,
        isSelectable: Bool,
        preferredPointerShape: PointerShape,
        showsUnderline: Bool,
        allowsMenuModalInteraction: Bool = false,
        onTap: (() -> Void)?,
        interfaceLayerContext: InterfaceLayerContext,
        dialogID: WorkbenchDialogAccessibilityID? = nil,
        isDialogCovered: Bool = false
    ) {
        let textChanged = self.text != text || self.fullCopyText != fullCopyText
        let styleChanged = self.font != font
            || self.textColor != textColor
            || self.alignment != alignment
            || self.lineLimit != lineLimit
            || self.lineHeight != lineHeight
            || self.truncatesTail != truncatesTail
            || self.truncationMode != truncationMode
            || self.isSelectable != isSelectable
            || self.preferredPointerShape != preferredPointerShape
            || self.showsUnderline != showsUnderline
            || self.allowsMenuModalInteraction != allowsMenuModalInteraction
        let layerChanged = self.interfaceLayerContext.layer != interfaceLayerContext.layer
            || self.interfaceLayerContext.isCovered != interfaceLayerContext.isCovered
            || self.interfaceLayerContext.isFrozen != interfaceLayerContext.isFrozen
            || self.dialogID != dialogID
            || self.isDialogCovered != isDialogCovered

        self.text = text
        self.fullCopyText = fullCopyText
        self.font = font
        self.textColor = textColor
        self.alignment = alignment
        self.lineLimit = lineLimit
        self.lineHeight = lineHeight
        self.truncatesTail = truncatesTail
        self.truncationMode = truncationMode
        self.isSelectable = isSelectable
        self.preferredPointerShape = preferredPointerShape
        self.showsUnderline = showsUnderline
        self.allowsMenuModalInteraction = allowsMenuModalInteraction
        self.onTap = onTap
        self.interfaceLayerContext = interfaceLayerContext
        self.dialogID = dialogID
        self.isDialogCovered = isDialogCovered

        if textChanged || !canInteract {
            clearSelection(notifyCoordinator: true)
        }

        if textChanged || styleChanged || layerChanged {
            needsTextLayout = true
            updateTextLayout()
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        let oldSize = frame.size
        super.setFrameSize(newSize)
        if oldSize != newSize {
            needsTextLayout = true
            updateTextLayout()
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }

    func prepareLayoutForFlow() {
        if needsTextLayout || textStorage.length != textLengthUTF16 {
            updateTextLayout()
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
            if allowsMenuModalInteraction {
                Task { @MainActor [weak self] in
                    guard let self,
                          self.allowsMenuModalInteraction,
                          self.canInteract,
                          let window = self.window,
                          window.firstResponder == nil || window.firstResponder === window
                    else {
                        return
                    }
                    _ = window.makeFirstResponder(self)
                }
            }
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
        guard canInteract,
              let clipRect = visibleWindowClipRect(),
              clipRect.contains(windowPoint)
        else {
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

    func visibleWindowClipRect() -> CGRect? {
        clippedVisibleWindowRect(for: convert(bounds, to: nil).standardized)
    }

    func windowSelectionHitRect() -> CGRect? {
        guard visibleWindowClipRect() != nil else {
            return nil
        }
        return clippedVisibleWindowRect(
            for: convert(bounds.insetBy(dx: -4, dy: -2), to: nil).standardized
        )
    }

    private func clippedVisibleWindowRect(for candidateWindowRect: CGRect) -> CGRect? {
        guard let window,
              !isHiddenOrHasHiddenAncestor,
              bounds.width > 0,
              bounds.height > 0,
              !candidateWindowRect.isNull,
              !candidateWindowRect.isEmpty
        else {
            return nil
        }

        // Pass 1: intersect with window content bounds and all outer scroll/viewport clip containers first.
        var viewportRect = window.contentView.map {
            $0.convert($0.bounds, to: nil).standardized
        } ?? candidateWindowRect
        var pageChromeChildren: [(viewport: SubtitleTablePageChromeViewportView, child: NSView)] = []
        var current = superview
        while !viewportRect.isNull, !viewportRect.isEmpty, let ancestor = current {
            guard !ancestor.isHidden, ancestor.alphaValue > 0 else {
                return nil
            }
            if ancestor is NSClipView
                || ancestor is NSScrollView
                || ancestor is SubtitleTablePageChromeViewportView
            {
                let ancestorRect = ancestor.convert(ancestor.bounds, to: nil).standardized
                viewportRect = viewportRect.intersection(ancestorRect)
            }
            if let pageViewport = ancestor.superview as? SubtitleTablePageChromeViewportView {
                pageChromeChildren.append((pageViewport, ancestor))
            }
            current = ancestor.superview
        }

        let rect = candidateWindowRect.intersection(viewportRect)
        guard !rect.isNull, !rect.isEmpty else {
            return nil
        }

        // Pass 2: subtract upper intersecting opaque sibling sticky toolbar hosts and fixed table headers.
        var yBands: [(minY: CGFloat, maxY: CGFloat)] = [(rect.minY, rect.maxY)]
        for (pageViewport, child) in pageChromeChildren {
            guard let myIndex = pageViewport.subviews.firstIndex(of: child) else {
                continue
            }
            for sibling in pageViewport.subviews[(myIndex + 1)...] {
                guard sibling is SubtitleTablePageChromeHostingView
                        || sibling is SubtitleVirtualTableHeaderView,
                      !sibling.isHidden,
                      sibling.alphaValue > 0
                else {
                    continue
                }
                let occluder = sibling.convert(sibling.bounds, to: nil)
                    .standardized
                    .intersection(viewportRect)
                guard !occluder.isNull, !occluder.isEmpty else {
                    continue
                }
                let horizontalOverlap = min(rect.maxX, occluder.maxX) - max(rect.minX, occluder.minX)
                guard horizontalOverlap > 0.5 else {
                    continue
                }
                var nextBands: [(minY: CGFloat, maxY: CGFloat)] = []
                for band in yBands {
                    if occluder.maxY <= band.minY || occluder.minY >= band.maxY {
                        nextBands.append(band)
                    } else {
                        if occluder.minY > band.minY + 0.01 {
                            nextBands.append((band.minY, occluder.minY))
                        }
                        if occluder.maxY + 0.01 < band.maxY {
                            nextBands.append((occluder.maxY, band.maxY))
                        }
                    }
                }
                yBands = nextBands
                if yBands.isEmpty {
                    return nil
                }
            }
        }

        guard let bestBand = yBands.max(by: { ($0.maxY - $0.minY) < ($1.maxY - $1.minY) }),
              bestBand.maxY - bestBand.minY > 0.01
        else {
            return nil
        }
        return CGRect(
            x: rect.minX,
            y: bestBand.minY,
            width: rect.width,
            height: bestBand.maxY - bestBand.minY
        )
    }

    func setFlowSelectedRange(_ range: NSRange?) {
        let normalized: NSRange? = {
            guard let range, range.length > 0 else { return nil }
            let safe = NSIntersectionRange(range, NSRange(location: 0, length: textLengthUTF16))
            return safe.length > 0 ? safe : nil
        }()
        if selectedRange != normalized {
            selectedRange = normalized
            needsDisplay = true
        }
    }

    // MARK: - Mouse & Keyboard Handling

    override func rightMouseDown(with event: NSEvent) {
        if canInteract {
            clearSelection(notifyCoordinator: true)
            WorkbenchStaticTextSelectionCoordinator.shared.clearSelection()
        }
        super.rightMouseDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        guard canInteract else {
            super.mouseDown(with: event)
            return
        }
        (window as? CueSeekerWindow)?.cancelFocusedTextInputIfOutside(at: event.locationInWindow)
        prepareLayoutForFlow()
        let point = convert(event.locationInWindow, from: nil)
        let offset = utf16Offset(at: point)
        let clickCount = max(1, event.clickCount)

        startWindowPoint = event.locationInWindow
        activeClickCount = clickCount
        isTrackingMouse = true

        let initialSelection: NSRange?
        if onTap != nil {
            anchorRange = NSRange(location: offset, length: 0)
            initialSelection = nil
            didDrag = false
        } else if clickCount >= 3 {
            let fullRange = NSRange(location: 0, length: textStorage.length)
            anchorRange = fullRange
            initialSelection = fullRange.length > 0 ? fullRange : nil
            didDrag = true
        } else if clickCount == 2 {
            let word = wordRange(at: offset)
            anchorRange = word
            initialSelection = word.length > 0 ? word : nil
            didDrag = true
        } else {
            anchorRange = NSRange(location: offset, length: 0)
            initialSelection = nil
            didDrag = false
        }

        selectedRange = initialSelection
        WorkbenchStaticTextSelectionCoordinator.shared.prepareDirectMouseDown(
            in: self,
            startWindowPoint: event.locationInWindow,
            clickCount: clickCount,
            initialAnchorRange: initialSelection
        )
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

        WorkbenchStaticTextSelectionCoordinator.shared.updateDirectDrag(
            from: self,
            startWindowPoint: startWindowPoint,
            currentWindowPoint: windowPoint,
            clickCount: activeClickCount,
            initialAnchorRange: anchorRange
        )
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
                WorkbenchStaticTextSelectionCoordinator.shared.updateDirectDrag(
                    from: self,
                    startWindowPoint: startWindowPoint,
                    currentWindowPoint: windowPoint,
                    clickCount: activeClickCount,
                    initialAnchorRange: anchorRange
                )
            }
        }

        if didDrag {
            WorkbenchStaticTextSelectionCoordinator.shared.endDirectDrag(
                from: self,
                currentWindowPoint: windowPoint
            )
            return
        }

        let point = convert(windowPoint, from: nil)
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
               WorkbenchStaticTextSelectionCoordinator.shared.canCopySelection(in: window)
            {
                return WorkbenchStaticTextSelectionCoordinator.shared.copySelection(in: window)
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    @IBAction func copy(_ sender: Any?) {
        _ = CueSeekerWindow.copyActiveSelection(in: window)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(NSText.copy(_:)) {
            return CueSeekerWindow.canCopyActiveSelection(in: window)
        }
        return true
    }

    func selectAllText() {
        guard canInteract else { return }
        WorkbenchStaticTextSelectionCoordinator.shared.beginSingleNodeInteraction(in: self)
        _ = window?.makeFirstResponder(self)
        updateTextLayout()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        anchorRange = fullRange
        selectedRange = fullRange.length > 0 ? fullRange : nil
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
        let availableWidth = max(0, bounds.width)
        let effectiveAlignment: NSTextAlignment
        let paragraphLineBreak: NSLineBreakMode
        if lineLimit == 1 {
            let naturalWidth = Self.measuredSingleLineWidth(for: text, font: font)
            let wantsTruncation: Bool
            let truncatingBreakMode: NSLineBreakMode
            switch truncationMode {
            case .middle:
                wantsTruncation = true
                truncatingBreakMode = .byTruncatingMiddle
            case .head:
                wantsTruncation = true
                truncatingBreakMode = .byTruncatingHead
            case .tail, .none:
                wantsTruncation = truncatesTail
                truncatingBreakMode = .byTruncatingTail
            @unknown default:
                wantsTruncation = truncatesTail
                truncatingBreakMode = .byTruncatingTail
            }
            let isTruncated = wantsTruncation && availableWidth > 0 && availableWidth < naturalWidth - 1.5
            effectiveAlignment = isTruncated ? alignment : .left
            paragraphLineBreak = isTruncated ? truncatingBreakMode : .byClipping
            textContainer.maximumNumberOfLines = 1
            textContainer.lineBreakMode = paragraphLineBreak
            textContainer.size = CGSize(
                width: isTruncated ? availableWidth : max(availableWidth, naturalWidth + 8),
                height: .greatestFiniteMagnitude
            )
        } else {
            let maxLines = lineLimit ?? 0
            effectiveAlignment = alignment
            paragraphLineBreak = .byWordWrapping
            textContainer.maximumNumberOfLines = maxLines
            textContainer.lineBreakMode = (maxLines > 0 && truncatesTail) ? .byTruncatingTail : .byWordWrapping
            textContainer.size = CGSize(
                width: max(0, availableWidth + 1.5),
                height: .greatestFiniteMagnitude
            )
        }

        let attributes = Self.makeTextAttributes(
            font: font,
            textColor: textColor,
            alignment: effectiveAlignment,
            lineBreakMode: paragraphLineBreak,
            lineHeight: lineHeight
        )
        textStorage.setAttributedString(
            NSAttributedString(string: text, attributes: attributes)
        )
        layoutManager.ensureLayout(for: textContainer)
        needsTextLayout = false
    }

    nonisolated private static func makeTextAttributes(
        font: NSFont,
        textColor: NSColor? = nil,
        alignment: NSTextAlignment,
        lineBreakMode: NSLineBreakMode,
        lineHeight: CGFloat?
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = lineBreakMode
        paragraphStyle.tighteningFactorForTruncation = 0
        if let lineHeight, lineHeight > 0 {
            paragraphStyle.minimumLineHeight = lineHeight
            paragraphStyle.maximumLineHeight = lineHeight
        }
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]
        if let textColor {
            attributes[.foregroundColor] = textColor
        }
        let baselineOffset = resolvedBaselineOffset(for: font, lineHeight: lineHeight)
        if baselineOffset > 0 {
            attributes[.baselineOffset] = baselineOffset
        }
        return attributes
    }

    nonisolated static func resolvedBaselineOffset(
        for font: NSFont,
        lineHeight: CGFloat?
    ) -> CGFloat {
        guard let lineHeight, lineHeight > 0 else { return 0 }
        let naturalLineHeight = ceil(font.ascender - font.descender + font.leading)
        return max(0, (lineHeight - naturalLineHeight) / 2)
    }

    nonisolated static func measuredSingleLineWidth(for text: String, font: NSFont) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    nonisolated static func measuredMultilineHeight(
        for text: String,
        font: NSFont,
        lineHeight: CGFloat? = nil,
        lineLimit: Int? = nil,
        truncatesTail: Bool = true,
        width: CGFloat
    ) -> CGFloat {
        let resolvedLineHeight = (lineHeight ?? 0) > 0 ? lineHeight : nil
        let defaultHeight = resolvedLineHeight ?? ceil(NSLayoutManager().defaultLineHeight(for: font))
        guard !text.isEmpty, width > 0 else {
            return defaultHeight
        }
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: max(0, width + 1.5), height: .greatestFiniteMagnitude)
        )
        let maxLines = max(0, lineLimit ?? 0)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = maxLines
        textContainer.lineBreakMode = (maxLines > 0 && truncatesTail) ? .byTruncatingTail : .byWordWrapping
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        textStorage.setAttributedString(
            NSAttributedString(
                string: text,
                attributes: makeTextAttributes(
                    font: font,
                    alignment: .left,
                    lineBreakMode: .byWordWrapping,
                    lineHeight: resolvedLineHeight
                )
            )
        )
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = ceil(layoutManager.usedRect(for: textContainer).height)
        return max(defaultHeight, usedHeight)
    }

    private func textOrigin() -> CGPoint {
        let usedRect = layoutManager.usedRect(for: textContainer)
        let originY = lineLimit == 1
            ? max(0, (bounds.height - usedRect.height) / 2)
            : (lineHeight != nil ? 0 : max(0, (bounds.height - usedRect.height) / 2))
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

    func utf16Offset(at point: CGPoint) -> Int {
        prepareLayoutForFlow()
        guard textStorage.length > 0 else { return 0 }
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return 0 }
        let origin = textOrigin()
        let lines = lineFragmentLayouts(at: origin)
        guard let firstLine = lines.first, let lastLine = lines.last else {
            return 0
        }

        // Strict reading-flow vertical clamping: zero horizontal tolerance band outside [firstLine.minY, lastLine.maxY].
        if point.y < firstLine.usedRect.minY {
            return 0
        }
        if point.y > lastLine.usedRect.maxY {
            return textStorage.length
        }

        var targetIndex = 0
        for index in lines.indices {
            if point.y < lines[index].usedRect.minY {
                return min(max(0, lines[index].charRange.location), textStorage.length)
            }
            if point.y <= lines[index].usedRect.maxY {
                targetIndex = index
                break
            }
            targetIndex = index
        }

        let targetLine = lines[targetIndex]
        if point.x <= targetLine.usedRect.minX {
            return min(max(0, targetLine.charRange.location), textStorage.length)
        }
        if point.x >= targetLine.usedRect.maxX {
            if targetLine.truncatedGlyphRange != nil || targetIndex == lines.count - 1 {
                return textStorage.length
            }
            return lineSelectionEndOffset(for: targetLine)
        }

        let localPoint = CGPoint(
            x: point.x - origin.x,
            y: targetLine.usedRect.midY - origin.y
        )
        var fraction: CGFloat = 0
        let rawGlyphIndex = layoutManager.glyphIndex(
            for: localPoint,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        let glyphIndex = min(
            max(rawGlyphIndex, targetLine.glyphRange.location),
            NSMaxRange(targetLine.glyphRange) - 1
        )
        if let truncated = targetLine.truncatedGlyphRange {
            if NSMaxRange(truncated) >= NSMaxRange(targetLine.glyphRange) {
                let lastVisibleGlyph = truncated.location
                if glyphIndex > lastVisibleGlyph
                    || (glyphIndex == lastVisibleGlyph && fraction >= 0.5)
                {
                    return textStorage.length
                }
                let ellipsisMinX: CGFloat
                if lastVisibleGlyph > targetLine.glyphRange.location {
                    let prefixRange = NSRange(
                        location: targetLine.glyphRange.location,
                        length: lastVisibleGlyph - targetLine.glyphRange.location
                    )
                    let prefixRect = layoutManager.boundingRect(
                        forGlyphRange: prefixRange,
                        in: textContainer
                    )
                    ellipsisMinX = max(targetLine.usedRect.minX, origin.x + prefixRect.maxX)
                } else {
                    ellipsisMinX = targetLine.usedRect.minX
                }
                if ellipsisMinX < targetLine.usedRect.maxX,
                   point.x >= (ellipsisMinX + targetLine.usedRect.maxX) * 0.5
                {
                    return textStorage.length
                }
            } else if NSLocationInRange(glyphIndex, truncated) {
                let truncatedCharRange = layoutManager.characterRange(
                    forGlyphRange: truncated,
                    actualGlyphRange: nil
                )
                return fraction >= 0.5
                    ? NSMaxRange(truncatedCharRange)
                    : truncatedCharRange.location
            }
        }
        let characterRange = layoutManager.characterRange(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            actualGlyphRange: nil
        )
        let characterIndex = fraction >= 0.5
            ? NSMaxRange(characterRange)
            : characterRange.location
        if targetIndex == lines.count - 1,
           hasSyntheticEllipsisSuffix,
           characterIndex >= textStorage.length - 1
        {
            return textStorage.length
        }
        return min(max(0, characterIndex), textStorage.length)
    }

    private func lineSelectionEndOffset(for line: LineFragmentLayout) -> Int {
        let nsText = textStorage.string as NSString
        var end = min(NSMaxRange(line.charRange), nsText.length)
        while end > line.charRange.location {
            let scalar = nsText.character(at: end - 1)
            if scalar == 0x0A || scalar == 0x0D {
                end -= 1
            } else {
                break
            }
        }
        return min(max(0, end), nsText.length)
    }

    func wordRange(at utf16Offset: Int) -> NSRange {
        prepareLayoutForFlow()
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

    func selectionRects(forUTF16Range range: NSRange, at origin: CGPoint? = nil) -> [CGRect] {
        prepareLayoutForFlow()
        let resolvedOrigin = origin ?? textOrigin()
        let safeRange = NSIntersectionRange(
            range,
            NSRange(location: 0, length: textStorage.length)
        )
        guard safeRange.length > 0 else { return [] }
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return [] }

        var glyphRange = layoutManager.glyphRange(
            forCharacterRange: safeRange,
            actualCharacterRange: nil
        )
        glyphRange = NSIntersectionRange(glyphRange, validGlyphRange)
        if NSMaxRange(safeRange) >= textStorage.length {
            let lastGlyph = NSMaxRange(validGlyphRange) - 1
            let truncated = layoutManager.truncatedGlyphRange(inLineFragmentForGlyphAt: lastGlyph)
            if truncated.location != NSNotFound,
               NSMaxRange(truncated) >= NSMaxRange(validGlyphRange)
            {
                let startGlyph = glyphRange.length > 0
                    ? glyphRange.location
                    : lastGlyph
                glyphRange = NSRange(
                    location: min(startGlyph, lastGlyph),
                    length: NSMaxRange(validGlyphRange) - min(startGlyph, lastGlyph)
                )
            }
        }
        guard glyphRange.length > 0 else { return [] }

        var rects: [CGRect] = []
        layoutManager.enumerateEnclosingRects(
            forGlyphRange: glyphRange,
            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
            in: textContainer
        ) { rect, _ in
            rects.append(rect.offsetBy(dx: resolvedOrigin.x, dy: resolvedOrigin.y))
        }
        return rects
    }

    private func lineFragmentLayouts(at origin: CGPoint? = nil) -> [LineFragmentLayout] {
        prepareLayoutForFlow()
        let resolvedOrigin = origin ?? textOrigin()
        let validGlyphRange = layoutManager.glyphRange(for: textContainer)
        guard validGlyphRange.length > 0 else { return [] }
        var fragments: [LineFragmentLayout] = []
        var glyphIndex = validGlyphRange.location
        while glyphIndex < NSMaxRange(validGlyphRange) {
            var lineRange = NSRange(location: 0, length: 0)
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange
            )
            let visibleLineGlyphs = NSIntersectionRange(lineRange, validGlyphRange)
            if usedRect.width > 0, usedRect.height > 0, visibleLineGlyphs.length > 0 {
                let charRange = layoutManager.characterRange(
                    forGlyphRange: visibleLineGlyphs,
                    actualGlyphRange: nil
                )
                let truncated = layoutManager.truncatedGlyphRange(
                    inLineFragmentForGlyphAt: visibleLineGlyphs.location
                )
                let truncatedRange = (truncated.location != NSNotFound && truncated.length > 0)
                    ? truncated
                    : nil
                fragments.append(
                    LineFragmentLayout(
                        usedRect: usedRect.offsetBy(dx: resolvedOrigin.x, dy: resolvedOrigin.y),
                        glyphRange: visibleLineGlyphs,
                        charRange: charRange,
                        truncatedGlyphRange: truncatedRange
                    )
                )
            }
            guard lineRange.length > 0 else { break }
            glyphIndex = NSMaxRange(lineRange)
        }
        return fragments
    }

    func lineUsedRects(at origin: CGPoint? = nil) -> [CGRect] {
        lineFragmentLayouts(at: origin).map(\.usedRect)
    }

    func underlineRects(
        at origin: CGPoint? = nil,
        thickness: CGFloat = WorkbenchControlMetrics.redesignInteractiveTextUnderlineThickness,
        offset: CGFloat = WorkbenchControlMetrics.redesignInteractiveTextUnderlineOffset,
        backingScaleFactor: CGFloat
    ) -> [CGRect] {
        let resolvedOrigin = origin ?? textOrigin()
        let scale = max(1, backingScaleFactor)
        let lineThickness = max(1 / scale, thickness)
        let baselineOffset = Self.resolvedBaselineOffset(for: font, lineHeight: lineHeight)

        return lineFragmentLayouts(at: resolvedOrigin).compactMap { fragment in
            let baseline = fragment.usedRect.minY
                + layoutManager.location(forGlyphAt: fragment.glyphRange.location).y
                - baselineOffset
            let y = ((baseline + offset) * scale).rounded() / scale
            let minX = floor(fragment.usedRect.minX * scale) / scale
            let maxX = ceil(fragment.usedRect.maxX * scale) / scale
            let width = max(0, maxX - minX)
            return width > 0 ? CGRect(x: minX, y: y, width: width, height: lineThickness) : nil
        }
    }

    private func drawUnderline(
        at origin: CGPoint,
        color: NSColor,
        thickness: CGFloat,
        offset: CGFloat,
        backingScaleFactor: CGFloat
    ) {
        color.setFill()
        for rect in underlineRects(
            at: origin,
            thickness: thickness,
            offset: offset,
            backingScaleFactor: backingScaleFactor
        ) {
            rect.fill()
        }
    }
}
