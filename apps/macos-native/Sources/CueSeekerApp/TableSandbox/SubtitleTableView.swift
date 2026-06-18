import AppKit
import SwiftUI

// MARK: - Metrics

enum SubtitleTableMetrics {
    static let indexColumnWidth: CGFloat = 50
    static let nameColumnWidth: CGFloat = 240
    static let speakerColumnWidth: CGFloat = 180
    static let languageColumnWidth: CGFloat = 160
    static let cellLeading: CGFloat = 12
    static let trailingInset: CGFloat = 14
    static let indexTrailingInset: CGFloat = 6
    static let rowVerticalInset: CGFloat = 9
    static let headerHeight: CGFloat = 44
    static let headerHorizontalInset: CGFloat = 12
    static let indexHeaderHorizontalInset: CGFloat = 16
    static let cornerRadius: CGFloat = 10
    static let estimatedRowHeight: CGFloat = 56
    static let maximumBodyLineCount = 6
    static let tagHeight: CGFloat = 22
    static let tagHorizontalInset: CGFloat = 8
    static let tagCornerRadius: CGFloat = 6
    static let tagHorizontalSpacing: CGFloat = 6
    static let tagVerticalSpacing: CGFloat = 4
    static let checkboxSize: CGFloat = 16
    static let checkboxCornerRadius: CGFloat = 4
    static let checkboxHitSlop: CGFloat = 8
    static let scrollbarSize: CGFloat = 8
    static let scrollbarInset: CGFloat = 4
    static let scrollbarMinThumbLength: CGFloat = 24
    static let scrollbarHitSlop: CGFloat = 6
    static let interactiveTextUnderlineThickness: CGFloat = 1
    static let interactiveTextUnderlineOffset: CGFloat = 2
}

// MARK: - Typography

@MainActor
enum SubtitleTableText {
    static let bodyFont = NSFont.systemFont(ofSize: 13.5, weight: .semibold)
    static let indexFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let headerFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let tagFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    static let lineSpacing: CGFloat = 4

    static func bodyParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        return style
    }

    static func body(_ text: String, isRedesign: Bool = false) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: bodyFont,
            .paragraphStyle: bodyParagraphStyle(),
            .foregroundColor: isRedesign ? WorkbenchRedesignColors.NS.textPrimary : NSColor.labelColor,
        ])
    }

    static func index(_ number: Int, isRedesign: Bool = false) -> NSAttributedString {
        NSAttributedString(string: "\(number)", attributes: [
            .font: indexFont,
            .foregroundColor: isRedesign ? WorkbenchRedesignColors.NS.textMuted : NSColor.secondaryLabelColor,
        ])
    }

    static func header(_ text: String, isRedesign: Bool = false) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: headerFont,
            .foregroundColor: isRedesign ? WorkbenchRedesignColors.NS.textPrimary : NSColor.labelColor,
        ])
    }

    static func tag(_ tag: WorkbenchTag, isRedesign: Bool = false) -> NSAttributedString {
        NSAttributedString(string: tag.label, attributes: [
            .font: tagFont,
            .foregroundColor: isRedesign ? tag.colorID.redesignForegroundColor() : tag.colorID.appKitForegroundColor,
        ])
    }
}

// MARK: - TextKit layout

@MainActor
final class SubtitleTextLayout {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer()

    init(maximumNumberOfLines: Int = SubtitleTableMetrics.maximumBodyLineCount) {
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = maximumNumberOfLines
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func update(attributedString: NSAttributedString, width: CGFloat) {
        textStorage.setAttributedString(attributedString)
        textContainer.size = CGSize(width: max(0, width), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
    }

    var usedHeight: CGFloat {
        ceil(layoutManager.usedRect(for: textContainer).height)
    }

    func draw(at origin: CGPoint) {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return }
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    func containsText(at point: CGPoint, origin: CGPoint) -> Bool {
        lineUsedRects(at: origin).contains { $0.contains(point) }
    }

    func underlineRects(
        at origin: CGPoint,
        thickness: CGFloat,
        offset: CGFloat,
        backingScaleFactor: CGFloat
    ) -> [CGRect] {
        let scale = max(1, backingScaleFactor)
        let lineThickness = max(1 / scale, thickness)
        return lineGlyphRanges().compactMap { glyphRange in
            guard glyphRange.length > 0 else { return nil }
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            guard usedRect.width > 0 else { return nil }
            let baseline = origin.y + usedRect.minY + layoutManager.location(forGlyphAt: glyphRange.location).y
            let y = pixelAligned(baseline + offset, scale: scale)
            let minX = pixelFloored(origin.x + usedRect.minX, scale: scale)
            let maxX = pixelCeiled(origin.x + usedRect.maxX, scale: scale)
            return CGRect(
                x: minX,
                y: y,
                width: max(0, maxX - minX),
                height: lineThickness
            )
        }
    }

    func drawUnderline(
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
        ) where rect.width > 0 {
            rect.fill()
        }
    }

    private func lineUsedRects(at origin: CGPoint) -> [CGRect] {
        lineGlyphRanges().compactMap { glyphRange in
            guard glyphRange.length > 0 else { return nil }
            let usedRect = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil
            )
            guard usedRect.width > 0, usedRect.height > 0 else { return nil }
            return usedRect.offsetBy(dx: origin.x, dy: origin.y)
        }
    }

    private func lineGlyphRanges() -> [NSRange] {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        guard glyphRange.length > 0 else { return [] }

        var lineRanges: [NSRange] = []
        var glyphIndex = glyphRange.location
        let glyphUpperBound = NSMaxRange(glyphRange)
        while glyphIndex < glyphUpperBound {
            var effectiveRange = NSRange(location: 0, length: 0)
            _ = layoutManager.lineFragmentUsedRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &effectiveRange
            )
            let lineRange = NSIntersectionRange(effectiveRange, glyphRange)
            if lineRange.length > 0 {
                lineRanges.append(lineRange)
            }
            let nextIndex = NSMaxRange(effectiveRange)
            guard nextIndex > glyphIndex else { break }
            glyphIndex = nextIndex
        }
        return lineRanges
    }

    private func pixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded() / scale
    }

    private func pixelFloored(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        floor(value * scale) / scale
    }

    private func pixelCeiled(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        ceil(value * scale) / scale
    }
}

// MARK: - Hover Play/Copy buttons

private struct CueHoverButtons: View {
    var isRedesign: Bool = false
    var isEnabled: Bool = true
    var isMenuOpen: Bool = false
    var onPlay: () -> Void
    var onCopy: () -> Void
    var onTriggerMenu: () -> Void
    var onDismissMenu: () -> Void

    @State private var isHovered = false
    @State private var hasPushedCursor = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isRedesign {
            Button(action: {
                if isMenuOpen {
                    onDismissMenu()
                } else {
                    onTriggerMenu()
                }
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconDisabled)
                    .frame(width: 36, height: 36)
                    .background((isHovered || isMenuOpen) && isEnabled ? WorkbenchRedesignColors.bgHover : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .focused($isFocused)
            .disableFocusEffect()
            .overlay(
                Group {
                    if isFocused && isEnabled {
                        RoundedRectangle(
                            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth,
                            style: .continuous
                        )
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                    }
                }
            )
            .contentShape(Rectangle())
            .onHover { inside in
                isHovered = inside
                updateCursor(inside: inside)
            }
            .onChange(of: isEnabled) { newValue in
                if isHovered {
                    if hasPushedCursor {
                        NSCursor.pop()
                        hasPushedCursor = false
                    }
                    if newValue {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.operationNotAllowed.push()
                    }
                    hasPushedCursor = true
                }
            }
            .onDisappear {
                if hasPushedCursor {
                    NSCursor.pop()
                    hasPushedCursor = false
                }
            }
        } else {
            HStack(spacing: 2) {
                button(title: "Play", systemImage: "play.fill", action: onPlay)
                button(title: "Copy", systemImage: "doc.on.doc", action: onCopy)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }

    private func updateCursor(inside: Bool) {
        if inside {
            if !hasPushedCursor {
                if isEnabled {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.operationNotAllowed.push()
                }
                hasPushedCursor = true
            }
        } else {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }

    private func button(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarButtonStyle())
    }
}

private struct RowActionMenu: View {
    var onCopy: () -> Void
    var onContext: () -> Void
    var onFavorite: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(spacing: 0) {
                WorkbenchPopoverRow(
                    title: "Copy Cue Text",
                    systemImage: "doc.on.doc", // Mapped from "copy" to "doc.on.doc" for macOS copy semantics
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: true,
                    action: onCopy
                )
                WorkbenchPopoverRow(
                    title: "Open Context",
                    systemImage: "magnifyingglass", // Mapped from "search" to "magnifyingglass"
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: false, // Disabled and not integrated yet
                    action: onContext
                )
                WorkbenchPopoverRow(
                    title: "Favorite",
                    systemImage: "star", // Mapped from "star" to "star"
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: false, // Disabled and not integrated yet
                    action: onFavorite
                )
            }
        }
    }
}

final class SubtitleTableMenuOverlayView: NSView {
    var onClick: (() -> Void)?
    override var isFlipped: Bool { true }
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

private enum WorkbenchCheckboxDrawing {
    static func draw(state: WorkbenchCheckboxState, in rect: CGRect, isFocused: Bool = false) {
        let path = NSBezierPath(
            roundedRect: rect,
            xRadius: SubtitleTableMetrics.checkboxCornerRadius,
            yRadius: SubtitleTableMetrics.checkboxCornerRadius
        )
        switch state {
        case .unchecked:
            WorkbenchRedesignColors.NS.bgCheckboxUnchecked.setFill()
        case .checked, .indeterminate:
            WorkbenchRedesignColors.NS.bgCheckboxChecked.setFill()
        }
        path.fill()

        let borderColor: NSColor? = isFocused
            ? WorkbenchRedesignColors.NS.borderFocus
            : (state == .unchecked ? WorkbenchRedesignColors.NS.borderCheckbox : nil)
        if let borderColor {
            borderColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        switch state {
        case .unchecked:
            break
        case .checked:
            drawCheckmark(in: rect)
        case .indeterminate:
            drawIndeterminate(in: rect)
        }

        if isFocused {
            let focusRect = rect.insetBy(
                dx: -WorkbenchControlMetrics.redesignFocusRingWidth,
                dy: -WorkbenchControlMetrics.redesignFocusRingWidth
            )
            let focusPath = NSBezierPath(
                roundedRect: focusRect,
                xRadius: SubtitleTableMetrics.checkboxCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth,
                yRadius: SubtitleTableMetrics.checkboxCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth
            )
            WorkbenchRedesignColors.NS.focusRing.setStroke()
            focusPath.lineWidth = WorkbenchControlMetrics.redesignFocusRingWidth
            focusPath.stroke()
        }
    }

    private static func drawCheckmark(in rect: CGRect) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + 8.5))
        path.line(to: CGPoint(x: rect.minX + 7, y: rect.minY + 11.5))
        path.line(to: CGPoint(x: rect.minX + 12.5, y: rect.minY + 5))
        WorkbenchRedesignColors.NS.checkboxIcon.setStroke()
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    private static func drawIndeterminate(in rect: CGRect) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX + 4, y: rect.midY))
        path.line(to: CGPoint(x: rect.maxX - 4, y: rect.midY))
        WorkbenchRedesignColors.NS.checkboxIcon.setStroke()
        path.lineWidth = 2.5
        path.lineCapStyle = .round
        path.stroke()
    }
}

private struct WorkbenchCheckboxButton: View {
    let state: WorkbenchCheckboxState
    var isEnabled: Bool = true
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var suppressFocusRingUntilBlur = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: SubtitleTableMetrics.checkboxCornerRadius, style: .continuous)
                    .fill(backgroundColor)
                if let borderColor {
                    RoundedRectangle(cornerRadius: SubtitleTableMetrics.checkboxCornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1.5)
                }
                if state != .unchecked {
                    Image(systemName: state == .checked ? "checkmark" : "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WorkbenchRedesignColors.checkboxIcon)
                }
            }
            .frame(width: SubtitleTableMetrics.checkboxSize, height: SubtitleTableMetrics.checkboxSize)
            .overlay(
                Group {
                    if showsKeyboardFocus {
                        RoundedRectangle(
                            cornerRadius: SubtitleTableMetrics.checkboxCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth,
                            style: .continuous
                        )
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in suppressFocusRingUntilBlur = true }
        )
        .onChange(of: isFocused) { focused in
            if !focused {
                suppressFocusRingUntilBlur = false
            }
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .unchecked:
            return WorkbenchRedesignColors.bgCheckboxUnchecked
        case .checked, .indeterminate:
            return WorkbenchRedesignColors.bgCheckboxChecked
        }
    }

    private var borderColor: Color? {
        if showsKeyboardFocus {
            return WorkbenchRedesignColors.borderFocus
        }
        return state == .unchecked ? WorkbenchRedesignColors.borderCheckbox : nil
    }

    private var showsKeyboardFocus: Bool {
        isFocused && isEnabled && !suppressFocusRingUntilBlur
    }
}

// MARK: - Container and header

final class SubtitleTableContainerView: NSView {
    var onLayout: (() -> Void)?
    var isRedesign: Bool = false { didSet { applyAppearanceColors() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = SubtitleTableMetrics.cornerRadius
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        applyAppearanceColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        onLayout?()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearanceColors()
    }

    private func applyAppearanceColors() {
        guard let layer else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if isRedesign {
                layer.backgroundColor = WorkbenchRedesignColors.NS.bgSurface.cgColor
                layer.borderColor = WorkbenchRedesignColors.NS.borderControl.cgColor
            } else {
                layer.backgroundColor = NSColor.textBackgroundColor.cgColor
                layer.borderColor = NSColor.separatorColor.cgColor
            }
        }
    }
}

struct SubtitleTableScrollbarMetrics {
    enum Axis {
        case vertical
        case horizontal
    }

    var viewportSize: CGSize
    var contentSize: CGSize
    var contentOffset: CGPoint

    private var size: CGFloat { SubtitleTableMetrics.scrollbarSize }
    private var inset: CGFloat { SubtitleTableMetrics.scrollbarInset }
    private var minThumbLength: CGFloat { SubtitleTableMetrics.scrollbarMinThumbLength }
    private var hitSlop: CGFloat { SubtitleTableMetrics.scrollbarHitSlop }

    func isVisible(_ axis: Axis) -> Bool {
        switch axis {
        case .vertical:
            contentSize.height > viewportSize.height + 0.5
        case .horizontal:
            contentSize.width > viewportSize.width + 0.5
        }
    }

    func trackRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        guard isVisible(axis) else { return nil }
        let verticalReserve = isVisible(.vertical) ? size + inset : 0
        let horizontalReserve = isVisible(.horizontal) ? size + inset : 0

        switch axis {
        case .vertical:
            let height = bounds.height - 2 * inset - horizontalReserve
            guard height > 0 else { return nil }
            return CGRect(
                x: bounds.maxX - inset - size,
                y: bounds.minY + inset,
                width: size,
                height: height
            )
        case .horizontal:
            let width = bounds.width - 2 * inset - verticalReserve
            guard width > 0 else { return nil }
            return CGRect(
                x: bounds.minX + inset,
                y: bounds.maxY - inset - size,
                width: width,
                height: size
            )
        }
    }

    func thumbRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        guard let track = trackRect(for: axis, in: bounds) else { return nil }
        let viewportLength: CGFloat
        let contentLength: CGFloat
        let contentOffsetLength: CGFloat
        let trackLength: CGFloat

        switch axis {
        case .vertical:
            viewportLength = viewportSize.height
            contentLength = contentSize.height
            contentOffsetLength = contentOffset.y
            trackLength = track.height
        case .horizontal:
            viewportLength = viewportSize.width
            contentLength = contentSize.width
            contentOffsetLength = contentOffset.x
            trackLength = track.width
        }

        let maxScroll = max(0, contentLength - viewportLength)
        guard maxScroll > 0, trackLength > 0 else { return nil }

        let proportionalLength = trackLength * min(1, max(0, viewportLength / contentLength))
        let thumbLength = min(trackLength, max(minThumbLength, proportionalLength))
        let travelLength = max(0, trackLength - thumbLength)
        let scrollFraction = maxScroll > 0 ? min(1, max(0, contentOffsetLength / maxScroll)) : 0
        let thumbOffset = travelLength * scrollFraction

        switch axis {
        case .vertical:
            return CGRect(
                x: track.minX,
                y: track.minY + thumbOffset,
                width: track.width,
                height: thumbLength
            )
        case .horizontal:
            return CGRect(
                x: track.minX + thumbOffset,
                y: track.minY,
                width: thumbLength,
                height: track.height
            )
        }
    }

    func interactiveThumbRect(for axis: Axis, in bounds: CGRect) -> CGRect? {
        guard let thumb = thumbRect(for: axis, in: bounds) else { return nil }
        switch axis {
        case .vertical:
            return thumb.insetBy(dx: -hitSlop, dy: -2)
        case .horizontal:
            return thumb.insetBy(dx: -2, dy: -hitSlop)
        }
    }

    func scrollOffset(for axis: Axis, thumbPosition: CGFloat, in bounds: CGRect) -> CGFloat {
        guard let track = trackRect(for: axis, in: bounds),
              let thumb = thumbRect(for: axis, in: bounds)
        else {
            return 0
        }

        let trackStart: CGFloat
        let trackLength: CGFloat
        let thumbLength: CGFloat
        let maxScroll: CGFloat

        switch axis {
        case .vertical:
            trackStart = track.minY
            trackLength = track.height
            thumbLength = thumb.height
            maxScroll = max(0, contentSize.height - viewportSize.height)
        case .horizontal:
            trackStart = track.minX
            trackLength = track.width
            thumbLength = thumb.width
            maxScroll = max(0, contentSize.width - viewportSize.width)
        }

        let travelLength = max(0, trackLength - thumbLength)
        guard travelLength > 0, maxScroll > 0 else { return 0 }
        let thumbTravel = min(travelLength, max(0, thumbPosition - trackStart))
        return maxScroll * thumbTravel / travelLength
    }

    func scrollOffset(
        for axis: Axis,
        dragStartThumbOrigin: CGFloat,
        dragDelta: CGFloat,
        in bounds: CGRect
    ) -> CGFloat {
        scrollOffset(for: axis, thumbPosition: dragStartThumbOrigin + dragDelta, in: bounds)
    }
}

final class SubtitleTableScrollbarOverlayView: NSView {
    weak var scrollView: NSScrollView? {
        didSet {
            lastMetrics = nil
            needsDisplay = true
        }
    }

    var onDragStateChanged: ((Bool) -> Void)?

    var isRedesign: Bool = false {
        didSet {
            isHidden = !isRedesign
            lastMetrics = nil
            needsDisplay = true
        }
    }

    private var trackingArea: NSTrackingArea?
    private var hoveredAxis: SubtitleTableScrollbarMetrics.Axis? {
        didSet {
            guard hoveredAxis != oldValue else { return }
            invalidateInteractiveStateChange(from: oldValue, to: hoveredAxis)
        }
    }
    private var draggingAxis: SubtitleTableScrollbarMetrics.Axis? {
        didSet {
            guard draggingAxis != oldValue else { return }
            invalidateInteractiveStateChange(from: oldValue, to: draggingAxis)
            if (oldValue == nil) != (draggingAxis == nil) {
                onDragStateChanged?(draggingAxis != nil)
            }
        }
    }
    private var dragStartPoint: CGPoint = .zero
    private var dragStartThumbOrigin: CGFloat = 0
    private var lastMetrics: SubtitleTableScrollbarMetrics?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isHidden = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = superview.map { convert(point, from: $0) } ?? point
        guard isRedesign,
              !isHidden,
              axis(at: localPoint) != nil
        else {
            return nil
        }
        return self
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isRedesign, let currentMetrics = metrics() else {
            lastMetrics = nil
            return
        }
        lastMetrics = currentMetrics
        effectiveAppearance.performAsCurrentDrawingAppearance {
            drawThumb(axis: .vertical, metrics: currentMetrics)
            drawThumb(axis: .horizontal, metrics: currentMetrics)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        hoveredAxis = axis(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard draggingAxis == nil else { return }
        hoveredAxis = nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let axis = axis(at: point),
              let metrics = metrics(),
              let thumb = metrics.thumbRect(for: axis, in: bounds)
        else {
            return
        }
        draggingAxis = axis
        hoveredAxis = axis
        dragStartPoint = point
        dragStartThumbOrigin = axis == .vertical ? thumb.minY : thumb.minX
    }

    override func mouseDragged(with event: NSEvent) {
        guard let draggingAxis,
              let metrics = metrics(),
              let scrollView
        else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let dragDelta = draggingAxis == .vertical
            ? point.y - dragStartPoint.y
            : point.x - dragStartPoint.x
        let nextOffset = metrics.scrollOffset(
            for: draggingAxis,
            dragStartThumbOrigin: dragStartThumbOrigin,
            dragDelta: dragDelta,
            in: bounds
        )
        var origin = scrollView.contentView.bounds.origin
        switch draggingAxis {
        case .vertical:
            origin.y = nextOffset
        case .horizontal:
            origin.x = nextOffset
        }
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        let newMetrics = self.metrics()
        invalidateThumbs(oldMetrics: metrics, newMetrics: newMetrics, axes: [draggingAxis])
        lastMetrics = newMetrics
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        draggingAxis = nil
        hoveredAxis = axis(at: convert(event.locationInWindow, from: nil))
    }

    override func scrollWheel(with event: NSEvent) {
        if let scrollView {
            scrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    func scrollMetricsDidChange() {
        guard isRedesign else { return }
        let newMetrics = metrics()
        invalidateThumbs(oldMetrics: lastMetrics, newMetrics: newMetrics)
        lastMetrics = newMetrics
    }

    private func metrics() -> SubtitleTableScrollbarMetrics? {
        guard let scrollView,
              let documentView = scrollView.documentView
        else {
            return nil
        }
        return SubtitleTableScrollbarMetrics(
            viewportSize: scrollView.contentView.bounds.size,
            contentSize: documentView.frame.size,
            contentOffset: scrollView.contentView.bounds.origin
        )
    }

    private func axis(at point: CGPoint) -> SubtitleTableScrollbarMetrics.Axis? {
        guard let metrics = metrics() else { return nil }
        if let verticalThumb = metrics.interactiveThumbRect(for: .vertical, in: bounds),
           verticalThumb.contains(point) {
            return .vertical
        }
        if let horizontalThumb = metrics.interactiveThumbRect(for: .horizontal, in: bounds),
           horizontalThumb.contains(point) {
            return .horizontal
        }
        return nil
    }

    private func invalidateInteractiveStateChange(
        from oldAxis: SubtitleTableScrollbarMetrics.Axis?,
        to newAxis: SubtitleTableScrollbarMetrics.Axis?
    ) {
        guard isRedesign else { return }
        var axes = [SubtitleTableScrollbarMetrics.Axis]()
        if let oldAxis {
            axes.append(oldAxis)
        }
        if let newAxis, newAxis != oldAxis {
            axes.append(newAxis)
        }
        guard !axes.isEmpty else { return }
        let currentMetrics = metrics()
        invalidateThumbs(oldMetrics: currentMetrics, newMetrics: currentMetrics, axes: axes)
    }

    private func invalidateThumbs(
        oldMetrics: SubtitleTableScrollbarMetrics?,
        newMetrics: SubtitleTableScrollbarMetrics?,
        axes: [SubtitleTableScrollbarMetrics.Axis] = [.vertical, .horizontal]
    ) {
        var dirtyRect = CGRect.null
        for axis in axes {
            if let oldRect = oldMetrics?.thumbRect(for: axis, in: bounds) {
                dirtyRect = dirtyRect.union(oldRect)
            }
            if let newRect = newMetrics?.thumbRect(for: axis, in: bounds) {
                dirtyRect = dirtyRect.union(newRect)
            }
        }
        guard !dirtyRect.isNull else { return }
        setNeedsDisplay(dirtyRect.insetBy(dx: -2, dy: -2))
    }

    private func drawThumb(axis: SubtitleTableScrollbarMetrics.Axis, metrics: SubtitleTableScrollbarMetrics) {
        guard let rect = metrics.thumbRect(for: axis, in: bounds)
        else {
            return
        }
        let isInteractive = hoveredAxis == axis || draggingAxis == axis
        let color = isInteractive
            ? WorkbenchRedesignColors.NS.scrollbarThumbInteractive
            : WorkbenchRedesignColors.NS.scrollbarThumbDefault
        color.setFill()
        NSBezierPath(
            roundedRect: rect,
            xRadius: SubtitleTableMetrics.scrollbarSize / 2,
            yRadius: SubtitleTableMetrics.scrollbarSize / 2
        ).fill()
    }
}

final class SubtitleVirtualTableHeaderView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?
    var isRedesign: Bool = false {
        didSet {
            refreshHeaderHosts()
            needsDisplay = true
        }
    }

    private var indexHeaderHost: NSHostingView<AnyView>?
    private var nameHeaderHost: NSHostingView<AnyView>?
    private var cuesHeaderHost: NSHostingView<AnyView>?
    private var speakerHeaderHost: NSHostingView<AnyView>?
    private var languageHeaderHost: NSHostingView<AnyView>?

    private var hoverTracking: NSTrackingArea?
    private var isHeaderHovered = false {
        didSet {
            guard isHeaderHovered != oldValue else { return }
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking {
            removeTrackingArea(hoverTracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTracking = area
        updateHoverState()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHoverState()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateHoverState()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHoverState()
    }

    private func updateHoverState() {
        guard isRedesign, let window = window else {
            isHeaderHovered = false
            return
        }
        if let coordinator = coordinator, (coordinator.isMenuOpen || coordinator.isExternalPopupLayerOpen) {
            isHeaderHovered = false
            return
        }
        let mouseLoc = window.mouseLocationOutsideOfEventStream
        let localLoc = convert(mouseLoc, from: nil)
        isHeaderHovered = bounds.contains(localLoc)
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            super.draw(dirtyRect)
            
            if isRedesign {
                if isHeaderHovered {
                    WorkbenchRedesignColors.NS.rowHover.setFill()
                    bounds.fill()
                }
                WorkbenchRedesignColors.NS.borderDivider.setStroke()
                let path = NSBezierPath()
                path.move(to: NSPoint(x: bounds.minX, y: bounds.maxY - 0.5))
                path.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 0.5))
                path.lineWidth = 0.5
                path.stroke()
                return
            }

            let M = SubtitleTableMetrics.self
            let showsLanguageColumn = coordinator?.showsLanguageColumnForRendering() ?? false
            let showsSpeakerColumn = coordinator?.showsSpeakerColumnForRendering() ?? false
            let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
            let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0
            drawHeader(
                "#",
                rect: CGRect(x: 0, y: 0, width: M.indexColumnWidth, height: bounds.height),
                leading: M.indexHeaderHorizontalInset,
                trailing: M.indexTrailingInset
            )
            drawHeader(
                coordinator?.displayTitleHeaderForRendering() ?? "Name",
                rect: CGRect(x: M.indexColumnWidth, y: 0, width: M.nameColumnWidth, height: bounds.height),
                leading: M.headerHorizontalInset,
                trailing: M.trailingInset
            )
            drawHeader(
                "Cues",
                rect: CGRect(
                    x: M.indexColumnWidth + M.nameColumnWidth,
                    y: 0,
                    width: max(0, bounds.width - M.indexColumnWidth - M.nameColumnWidth - speakerWidth - languageWidth),
                    height: bounds.height
                ),
                leading: M.headerHorizontalInset,
                trailing: M.trailingInset
            )
            if showsSpeakerColumn {
                drawHeader(
                    "Speaker",
                    rect: CGRect(
                        x: max(M.indexColumnWidth + M.nameColumnWidth, bounds.width - languageWidth - M.speakerColumnWidth),
                        y: 0,
                        width: M.speakerColumnWidth,
                        height: bounds.height
                    ),
                    leading: M.headerHorizontalInset,
                    trailing: M.trailingInset
                )
            }
            if showsLanguageColumn {
                drawHeader(
                    "Language",
                    rect: CGRect(
                        x: max(M.indexColumnWidth + M.nameColumnWidth, bounds.width - M.languageColumnWidth),
                        y: 0,
                        width: M.languageColumnWidth,
                        height: bounds.height
                    ),
                    leading: M.headerHorizontalInset,
                    trailing: M.trailingInset
                )
            }

            NSColor.separatorColor.setStroke()
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bounds.minX, y: bounds.maxY - 0.5))
            path.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY - 0.5))
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    private func drawHeader(_ text: String, rect: CGRect, leading: CGFloat, trailing: CGFloat) {
        let attributed = SubtitleTableText.header(text, isRedesign: isRedesign)
        let size = attributed.size()
        let origin = CGPoint(
            x: rect.minX + leading,
            y: rect.minY + max(0, (rect.height - size.height) / 2)
        )
        let clipped = CGRect(
            x: origin.x,
            y: origin.y,
            width: max(0, rect.width - leading - trailing),
            height: size.height
        )
        attributed.draw(in: clipped)
    }

    override func layout() {
        super.layout()
        refreshHeaderHosts()
    }

    func refreshHeaderHosts() {
        updateHoverState()
        guard isRedesign else {
            indexHeaderHost?.isHidden = true
            nameHeaderHost?.isHidden = true
            cuesHeaderHost?.isHidden = true
            speakerHeaderHost?.isHidden = true
            languageHeaderHost?.isHidden = true
            return
        }

        let M = SubtitleTableMetrics.self
        let showsLanguageColumn = coordinator?.showsLanguageColumnForRendering() ?? false
        let showsSpeakerColumn = coordinator?.showsSpeakerColumnForRendering() ?? false
        let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
        let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0

        let indexRect = CGRect(x: 0, y: 0, width: M.indexColumnWidth, height: bounds.height)
        let nameRect = CGRect(x: M.indexColumnWidth, y: 0, width: M.nameColumnWidth, height: bounds.height)
        let cuesRect = CGRect(
            x: M.indexColumnWidth + M.nameColumnWidth,
            y: 0,
            width: max(0, bounds.width - M.indexColumnWidth - M.nameColumnWidth - speakerWidth - languageWidth),
            height: bounds.height
        )
        let speakerRect = showsSpeakerColumn ? CGRect(
            x: max(M.indexColumnWidth + M.nameColumnWidth, bounds.width - languageWidth - M.speakerColumnWidth),
            y: 0,
            width: M.speakerColumnWidth,
            height: bounds.height
        ) : .zero
        let languageRect = showsLanguageColumn ? CGRect(
            x: max(M.indexColumnWidth + M.nameColumnWidth, bounds.width - M.languageColumnWidth),
            y: 0,
            width: M.languageColumnWidth,
            height: bounds.height
        ) : .zero

        updateSelectionHeaderHost(&indexHeaderHost, frame: indexRect)
        updateHeaderHost(&nameHeaderHost, title: coordinator?.displayTitleHeaderForRendering() ?? "Name", columnID: "name", isSortable: true, frame: nameRect)
        updateHeaderHost(&cuesHeaderHost, title: "Cues", columnID: "cues", isSortable: true, frame: cuesRect)

        if showsSpeakerColumn {
            updateHeaderHost(&speakerHeaderHost, title: "Speaker", columnID: "speaker", isSortable: true, frame: speakerRect)
        } else {
            speakerHeaderHost?.isHidden = true
        }

        if showsLanguageColumn {
            updateHeaderHost(&languageHeaderHost, title: "Language", columnID: "language", isSortable: true, frame: languageRect)
        } else {
            languageHeaderHost?.isHidden = true
        }
        updateHeaderKeyViewBridge()
    }

    private func updateSelectionHeaderHost(
        _ hostVar: inout NSHostingView<AnyView>?,
        frame: CGRect
    ) {
        guard let coordinator else { return }
        let checkboxView = WorkbenchCheckboxButton(
            state: coordinator.selectionHeaderStateForRendering(),
            isEnabled: coordinator.canToggleSelectionForRendering(),
            action: { [weak self] in
                self?.coordinator?.toggleAllRowSelection()
            }
        )
        let anyView = AnyView(checkboxView)

        if let host = hostVar {
            host.rootView = anyView
            host.frame = frame
            host.isHidden = false
        } else {
            let host = NSHostingView(rootView: anyView)
            host.wantsLayer = true
            host.layer?.masksToBounds = false
            addSubview(host)
            hostVar = host
            host.frame = frame
            host.isHidden = false
        }
    }

    private func updateHeaderHost(
        _ hostVar: inout NSHostingView<AnyView>?,
        title: String,
        columnID: String,
        isSortable: Bool,
        frame: CGRect
    ) {
        guard let coordinator else { return }
        let sortDirection = coordinator.sortedColumnID == columnID ? coordinator.sortDirection : nil
        let isMenuOpen = coordinator.isMenuOpen && coordinator.activeHeaderMenuColumnID == columnID
        let isEnabled = coordinator.isEnabled

        let cellView = SubtitleTableHeaderCellView(
            title: title,
            columnID: columnID,
            isSortable: isSortable,
            isEnabled: isEnabled,
            sortDirection: sortDirection,
            isMenuOpen: isMenuOpen,
            columnRect: frame
        ) { [weak self] rect in
            self?.coordinator?.showHeaderMenu(for: columnID, triggerFrame: rect)
        }

        let anyView = AnyView(cellView)

        if let host = hostVar {
            host.rootView = anyView
            host.frame = frame
            host.isHidden = false
        } else {
            let host = NSHostingView(rootView: anyView)
            host.wantsLayer = true
            host.layer?.masksToBounds = false
            addSubview(host)
            hostVar = host
            host.frame = frame
            host.isHidden = false
        }
    }

    func isLastInteractiveHeaderResponder(_ responder: NSResponder?) -> Bool {
        guard let host = lastInteractiveHeaderHost(), let responderView = responder as? NSView else {
            return false
        }
        return responderView === host || responderView.isDescendant(of: host)
    }

    private func updateHeaderKeyViewBridge() {
        guard let lastHost = lastInteractiveHeaderHost(), let documentView = coordinator?.documentViewForKeyboardFocusBridge() else {
            return
        }
        lastHost.nextKeyView = documentView
    }

    private func lastInteractiveHeaderHost() -> NSView? {
        if let languageHeaderHost, !languageHeaderHost.isHidden {
            return languageHeaderHost
        }
        if let speakerHeaderHost, !speakerHeaderHost.isHidden {
            return speakerHeaderHost
        }
        if let cuesHeaderHost, !cuesHeaderHost.isHidden {
            return cuesHeaderHost
        }
        if let nameHeaderHost, !nameHeaderHost.isHidden {
            return nameHeaderHost
        }
        return nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Virtual document view

final class SubtitleVirtualTableDocumentView: NSView {
    weak var coordinator: SubtitleTableView.Coordinator?
    private var hoverTracking: NSTrackingArea?
    var isRedesign: Bool = false { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        coordinator?.clearFocusedCheckbox()
        return super.resignFirstResponder()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking {
            removeTrackingArea(hoverTracking)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        coordinator?.handleMouseHover(windowPoint: event.locationInWindow)
    }

    override func mouseEntered(with event: NSEvent) {
        coordinator?.handleMouseHover(windowPoint: event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        coordinator?.clearHover()
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if coordinator?.handleMouseDown(windowPoint: event.locationInWindow) == true {
            return
        }
        coordinator?.clearFocusedCheckbox()
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if coordinator?.handleKeyDown(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        coordinator?.drawRows(in: dirtyRect)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Height cache

struct SubtitleVirtualRowHeightCache {
    private var heights: [Int: CGFloat] = [:]

    var count: Int {
        heights.count
    }

    mutating func removeAll() {
        heights.removeAll()
    }

    mutating func prune(rowCount: Int, isLoaded: (Int) -> Bool) {
        heights = heights.filter { row, _ in
            row >= 0 && row < rowCount && isLoaded(row)
        }
    }

    func height(for row: Int, defaultHeight: CGFloat) -> CGFloat {
        defaultHeight
    }

    mutating func setHeight(_ height: CGFloat, for row: Int, defaultHeight: CGFloat) -> Bool {
        _ = height
        _ = row
        _ = defaultHeight
        return false
    }

    func yOffset(for row: Int, defaultHeight: CGFloat) -> CGFloat {
        CGFloat(max(0, row)) * defaultHeight
    }

    func totalHeight(rowCount: Int, defaultHeight: CGFloat) -> CGFloat {
        CGFloat(max(0, rowCount)) * defaultHeight
    }

    func rowIndex(atY y: CGFloat, rowCount: Int, defaultHeight: CGFloat) -> Int {
        guard rowCount > 0 else { return 0 }
        let row = Int((max(0, y) / max(1, defaultHeight)).rounded(.down))
        return min(max(0, row), rowCount - 1)
    }
}

// MARK: - SwiftUI bridge

struct IsWorkbenchPopupLayerOpenKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isWorkbenchPopupLayerOpen: Bool {
        get { self[IsWorkbenchPopupLayerOpenKey.self] }
        set { self[IsWorkbenchPopupLayerOpenKey.self] = newValue }
    }
}

struct SubtitleTableView: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isWorkbenchPopupLayerOpen) var isWorkbenchPopupLayerOpen
    var tableName: String
    var rowCount: Int
    var rowProvider: (Int) -> SubtitleTableRow?
    var rowsVersion: Int
    var rowsUpdate: TableSandboxRowsUpdate
    var displayTitleHeader = "Name"
    var showsLanguageColumn = false
    var showsSpeakerColumn = false
    var scrollResetToken = 0
    var onVisibleRowsChange: (Range<Int>) -> Void = { _ in }
    var isRowSelected: (Int) -> Bool = { _ in false }
    var selectionHeaderState: WorkbenchCheckboxState = .unchecked
    var onToggleRowSelection: (Int) -> Void = { _ in }
    var onToggleAllSelection: () -> Void = {}
    var onPlay: (SubtitleTableRow) -> Void
    var isRedesign: Bool = false

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            tableName: tableName,
            rowCount: rowCount,
            rowProvider: rowProvider,
            rowsVersion: rowsVersion,
            displayTitleHeader: displayTitleHeader,
            showsLanguageColumn: showsLanguageColumn,
            showsSpeakerColumn: showsSpeakerColumn,
            scrollResetToken: scrollResetToken,
            onVisibleRowsChange: onVisibleRowsChange,
            isRowSelected: isRowSelected,
            selectionHeaderState: selectionHeaderState,
            onToggleRowSelection: onToggleRowSelection,
            onToggleAllSelection: onToggleAllSelection,
            onPlay: onPlay
        )
        coordinator.isRedesign = isRedesign
        return coordinator
    }

    func makeNSView(context: Context) -> SubtitleTableContainerView {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isExternalPopupLayerOpen = isWorkbenchPopupLayerOpen
        let container = SubtitleTableContainerView()

        let header = SubtitleVirtualTableHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.coordinator = context.coordinator

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        let scrollbarOverlayView = SubtitleTableScrollbarOverlayView()
        scrollbarOverlayView.translatesAutoresizingMaskIntoConstraints = false
        scrollbarOverlayView.scrollView = scrollView

        let documentView = SubtitleVirtualTableDocumentView()
        documentView.coordinator = context.coordinator
        documentView.frame = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        scrollView.documentView = documentView
        scrollView.contentView.postsBoundsChangedNotifications = true

        context.coordinator.attach(
            container: container,
            headerView: header,
            scrollView: scrollView,
            scrollbarOverlayView: scrollbarOverlayView,
            documentView: documentView
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollContentDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        container.addSubview(header)
        container.addSubview(scrollView)
        container.addSubview(scrollbarOverlayView)

        let headerHeightConstraint = header.heightAnchor.constraint(equalToConstant: context.coordinator.currentHeaderHeight)
        context.coordinator.headerHeightConstraint = headerHeightConstraint

        container.isRedesign = context.coordinator.isRedesign
        header.isRedesign = context.coordinator.isRedesign
        documentView.isRedesign = context.coordinator.isRedesign

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headerHeightConstraint,

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            scrollbarOverlayView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollbarOverlayView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollbarOverlayView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollbarOverlayView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])

        context.coordinator.resizeDocument()
        context.coordinator.notifyVisibleRowsChanged()
        return container
    }

    func updateNSView(_ nsView: SubtitleTableContainerView, context: Context) {
        context.coordinator.isRedesign = isRedesign
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isExternalPopupLayerOpen = isWorkbenchPopupLayerOpen
        context.coordinator.update(
            tableName: tableName,
            rowCount: rowCount,
            rowProvider: rowProvider,
            rowsVersion: rowsVersion,
            rowsUpdate: rowsUpdate,
            displayTitleHeader: displayTitleHeader,
            showsLanguageColumn: showsLanguageColumn,
            showsSpeakerColumn: showsSpeakerColumn,
            scrollResetToken: scrollResetToken,
            onVisibleRowsChange: onVisibleRowsChange,
            isRowSelected: isRowSelected,
            selectionHeaderState: selectionHeaderState,
            onToggleRowSelection: onToggleRowSelection,
            onToggleAllSelection: onToggleAllSelection,
            onPlay: onPlay
        )
    }

    // MARK: Coordinator

    @MainActor
    final class Coordinator: NSObject {
        private var tableName: String
        private var rowCount: Int
        private var rowProvider: (Int) -> SubtitleTableRow?
        private var rowsVersion: Int
        private var displayTitleHeader: String
        private var showsLanguageColumn: Bool
        private var showsSpeakerColumn: Bool
        private var scrollResetToken: Int
        private var onVisibleRowsChange: (Range<Int>) -> Void
        private var isRowSelected: (Int) -> Bool
        private var selectionHeaderState: WorkbenchCheckboxState
        private var onToggleRowSelection: (Int) -> Void
        private var onToggleAllSelection: () -> Void
        private var onPlay: (SubtitleTableRow) -> Void

        var isRedesign: Bool = false {
            didSet {
                guard oldValue != isRedesign else { return }
                container?.isRedesign = isRedesign
                headerView?.isRedesign = isRedesign
                documentView?.isRedesign = isRedesign
                scrollbarOverlayView?.isRedesign = isRedesign
                configureScrollbars()

                headerHeightConstraint?.constant = currentHeaderHeight
                container?.layoutSubtreeIfNeeded()
                rowHeightCache.removeAll()
                lastNotifiedVisibleRows = nil
                resizeDocument()
                notifyVisibleRowsChanged(force: true)
                updateHoveredCueTextRow(nil)
                layoutHoverButtons()
                headerView?.refreshHeaderHosts()
                headerView?.needsDisplay = true
                documentView?.needsDisplay = true
            }
        }

        var isEnabled: Bool = true {
            didSet {
                guard oldValue != isEnabled else { return }
                if !isEnabled {
                    clearFocusedCheckbox()
                    updateHoveredCueTextRow(nil)
                }
                layoutHoverButtons()
                headerView?.refreshHeaderHosts()
            }
        }

        var headerHeightConstraint: NSLayoutConstraint?

        var currentHeaderHeight: CGFloat {
            isRedesign ? WorkbenchControlMetrics.redesignTableHeaderHeight : SubtitleTableMetrics.headerHeight
        }

        var currentRowHeight: CGFloat {
            isRedesign ? 64.0 : SubtitleTableMetrics.estimatedRowHeight
        }

        private weak var container: SubtitleTableContainerView?
        private weak var headerView: SubtitleVirtualTableHeaderView?
        private weak var scrollView: NSScrollView?
        private weak var scrollbarOverlayView: SubtitleTableScrollbarOverlayView?
        private weak var documentView: SubtitleVirtualTableDocumentView?
        private var buttonsHost: NSHostingView<CueHoverButtons>?
        fileprivate var isMenuOpen = false
        private var menuHost: NSHostingView<AnyView>?
        private var menuOverlayView: SubtitleTableMenuOverlayView?
        private var activeMenuAnchor: ActiveMenuAnchor?
        nonisolated(unsafe) private var menuEventMonitor: Any?
        nonisolated(unsafe) private var keyboardFocusEventMonitor: Any?

        private enum ActiveMenuAnchor {
            case row(buttonFrame: CGRect)
            case header(triggerFrame: CGRect)
        }

        enum TableSortDirection: Equatable {
            case asc
            case desc
        }

        var sortedColumnID: String?
        var sortDirection: TableSortDirection?
        var activeHeaderMenuColumnID: String?
        var isExternalPopupLayerOpen = false {
            didSet {
                guard isExternalPopupLayerOpen != oldValue else { return }
                if isExternalPopupLayerOpen {
                    if isMenuOpen {
                        dismissMenu(recalculateHover: false)
                    }
                    hoveredRow = nil
                    hoveredCueTextRow = nil
                    updateCueTextCursor(isActive: false)
                    buttonsHost?.isHidden = true
                    documentView?.needsDisplay = true
                    headerView?.refreshHeaderHosts()
                } else {
                    if let window = documentView?.window {
                        handleMouseHover(windowPoint: window.mouseLocationOutsideOfEventStream)
                    }
                    headerView?.refreshHeaderHosts()
                }
            }
        }

        private let textLayout = SubtitleTextLayout()
        private var rowHeightCache = SubtitleVirtualRowHeightCache()
        private var hoveredRow: Int?
        private var hoveredCueTextRow: Int?
        private var hasPushedCueTextCursor = false
        private var focusedCheckboxRow: Int?
        private var lastNotifiedVisibleRows: Range<Int>?
        private var isScrollbarDragging = false

        init(
            tableName: String,
            rowCount: Int,
            rowProvider: @escaping (Int) -> SubtitleTableRow?,
            rowsVersion: Int,
            displayTitleHeader: String = "Name",
            showsLanguageColumn: Bool = false,
            showsSpeakerColumn: Bool = false,
            scrollResetToken: Int = 0,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            isRowSelected: @escaping (Int) -> Bool = { _ in false },
            selectionHeaderState: WorkbenchCheckboxState = .unchecked,
            onToggleRowSelection: @escaping (Int) -> Void = { _ in },
            onToggleAllSelection: @escaping () -> Void = {},
            onPlay: @escaping (SubtitleTableRow) -> Void
        ) {
            self.tableName = tableName
            self.rowCount = max(0, rowCount)
            self.rowProvider = rowProvider
            self.rowsVersion = rowsVersion
            self.displayTitleHeader = displayTitleHeader
            self.showsLanguageColumn = showsLanguageColumn
            self.showsSpeakerColumn = showsSpeakerColumn
            self.scrollResetToken = scrollResetToken
            self.onVisibleRowsChange = onVisibleRowsChange
            self.isRowSelected = isRowSelected
            self.selectionHeaderState = selectionHeaderState
            self.onToggleRowSelection = onToggleRowSelection
            self.onToggleAllSelection = onToggleAllSelection
            self.onPlay = onPlay
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            if let monitor = menuEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = keyboardFocusEventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func attach(
            container: SubtitleTableContainerView,
            headerView: SubtitleVirtualTableHeaderView,
            scrollView: NSScrollView,
            scrollbarOverlayView: SubtitleTableScrollbarOverlayView,
            documentView: SubtitleVirtualTableDocumentView
        ) {
            self.container = container
            self.headerView = headerView
            self.scrollView = scrollView
            self.scrollbarOverlayView = scrollbarOverlayView
            self.documentView = documentView
            scrollbarOverlayView.onDragStateChanged = { [weak self] isDragging in
                self?.setScrollbarDragging(isDragging)
            }
            configureScrollbars()

            let buttonsHost = NSHostingView(rootView: CueHoverButtons(
                isRedesign: isRedesign,
                isEnabled: isEnabled,
                onPlay: {},
                onCopy: {},
                onTriggerMenu: {},
                onDismissMenu: {}
            ))
            buttonsHost.isHidden = true
            buttonsHost.translatesAutoresizingMaskIntoConstraints = true
            documentView.addSubview(buttonsHost)
            self.buttonsHost = buttonsHost

            container.onLayout = { [weak self] in
                self?.resizeDocument()
                self?.repositionOpenMenu()
            }
            installKeyboardFocusEventMonitor()
        }

        func update(
            tableName: String,
            rowCount: Int,
            rowProvider: @escaping (Int) -> SubtitleTableRow?,
            rowsVersion: Int,
            rowsUpdate: TableSandboxRowsUpdate,
            displayTitleHeader: String,
            showsLanguageColumn: Bool,
            showsSpeakerColumn: Bool,
            scrollResetToken: Int,
            onVisibleRowsChange: @escaping (Range<Int>) -> Void,
            isRowSelected: @escaping (Int) -> Bool,
            selectionHeaderState: WorkbenchCheckboxState,
            onToggleRowSelection: @escaping (Int) -> Void,
            onToggleAllSelection: @escaping () -> Void,
            onPlay: @escaping (SubtitleTableRow) -> Void
        ) {
            self.tableName = tableName
            self.rowProvider = rowProvider
            let displayTitleChanged = displayTitleHeader != self.displayTitleHeader
            self.displayTitleHeader = displayTitleHeader
            let languageColumnChanged = showsLanguageColumn != self.showsLanguageColumn
            self.showsLanguageColumn = showsLanguageColumn
            let speakerColumnChanged = showsSpeakerColumn != self.showsSpeakerColumn
            self.showsSpeakerColumn = showsSpeakerColumn
            let shouldScrollToTop = scrollResetToken != self.scrollResetToken
            self.scrollResetToken = scrollResetToken
            self.onVisibleRowsChange = onVisibleRowsChange
            self.isRowSelected = isRowSelected
            let selectionHeaderChanged = selectionHeaderState != self.selectionHeaderState
            self.selectionHeaderState = selectionHeaderState
            self.onToggleRowSelection = onToggleRowSelection
            self.onToggleAllSelection = onToggleAllSelection
            self.onPlay = onPlay

            let nextRowCount = max(0, rowCount)
            let changed = nextRowCount != self.rowCount || rowsVersion != self.rowsVersion
            self.rowCount = nextRowCount
            self.rowsVersion = rowsVersion
            if changed || shouldScrollToTop {
                lastNotifiedVisibleRows = nil
            }
            if let focusedCheckboxRow, focusedCheckboxRow >= nextRowCount {
                updateFocusedCheckbox(nil)
            }

            rowHeightCache.prune(rowCount: nextRowCount) { [rowProvider] row in
                rowProvider(row) != nil
            }

            resizeDocument()
            if changed || languageColumnChanged || speakerColumnChanged {
                if isMenuOpen {
                    repositionOpenMenu()
                }
            }
            if shouldScrollToTop {
                scrollToTop()
            } else if changed || languageColumnChanged || speakerColumnChanged {
                notifyVisibleRowsChanged(force: changed)
            }
            if changed || languageColumnChanged || speakerColumnChanged || displayTitleChanged || selectionHeaderChanged {
                headerView?.refreshHeaderHosts()
            }
            headerView?.needsDisplay = true
            documentView?.needsDisplay = true
            layoutHoverButtons()
        }

        func displayTitleHeaderForRendering() -> String {
            displayTitleHeader
        }

        func showsLanguageColumnForRendering() -> Bool {
            showsLanguageColumn
        }

        func showsSpeakerColumnForRendering() -> Bool {
            showsSpeakerColumn
        }

        func textForLanguageColumn(row: Int) -> String {
            if let model = rowProvider(row) {
                return model.tags.map(\.label).joined(separator: ", ")
            }
            return ""
        }

        func numberOfRowsForTesting() -> Int {
            rowCount
        }

        func rowSelectionStateForTesting(row: Int) -> Bool {
            isRowSelected(row)
        }

        func focusedCheckboxRowForTesting() -> Int? {
            focusedCheckboxRow
        }

        func isMenuOpenForTesting() -> Bool {
            isMenuOpen && menuHost?.isHidden == false && menuOverlayView?.isHidden == false
        }

        func setFocusedCheckboxRowForTesting(_ row: Int?) {
            updateFocusedCheckbox(row)
        }

        func cueTextHitTestForTesting(row: Int, point: CGPoint) -> Bool {
            isPointInCueText(row: row, point: point)
        }

        @discardableResult
        func toggleRowCheckboxFromMouseForTesting(row: Int) -> Bool {
            toggleRowCheckboxFromMouse(row: row)
        }

        func selectionHeaderStateForRendering() -> WorkbenchCheckboxState {
            selectionHeaderState
        }

        func canToggleSelectionForRendering() -> Bool {
            isEnabled && rowCount > 0
        }

        func usesOverlayScrollbarsForTesting() -> Bool {
            scrollbarOverlayView?.isRedesign == true &&
                scrollView?.hasVerticalScroller == false &&
                scrollView?.hasHorizontalScroller == false
        }

        func documentViewForKeyboardFocusBridge() -> NSView? {
            documentView
        }

        private func configureScrollbars() {
            guard let scrollView else { return }
            if isRedesign {
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
                scrollView.autohidesScrollers = true
            } else {
                scrollView.hasVerticalScroller = true
                scrollView.hasHorizontalScroller = false
                scrollView.autohidesScrollers = true
            }
            scrollbarOverlayView?.isRedesign = isRedesign
            scrollbarOverlayView?.isHidden = !isRedesign
            scrollbarOverlayView?.needsDisplay = true
            if !isRedesign {
                setScrollbarDragging(false)
            }
        }

        func toggleAllRowSelection() {
            guard rowCount > 0 else { return }
            onToggleAllSelection()
            headerView?.refreshHeaderHosts()
            documentView?.needsDisplay = true
        }

        func cellFullText(row: Int, column: Int) -> String {
            if row == -1 {
                var headers = ["#", displayTitleHeader, "Cues"]
                if showsSpeakerColumn {
                    headers.append("Speaker")
                }
                if showsLanguageColumn {
                    headers.append("Language")
                }
                return headers.indices.contains(column) ? headers[column] : ""
            }
            guard row >= 0, row < rowCount else { return "" }
            guard column != 0 else { return "\(row + 1)" }
            guard let model = rowProvider(row) else { return "" }
            if column == 1 {
                return model.displayTitle
            }
            if column == 2 {
                return model.cues
            }
            var nextColumn = 3
            if showsSpeakerColumn {
                if column == nextColumn {
                    return model.speakerTags.map(\.label).joined(separator: ", ")
                }
                nextColumn += 1
            }
            if showsLanguageColumn, column == nextColumn {
                return model.tags.map(\.label).joined(separator: ", ")
            }
            return ""
        }

        func resizeDocument() {
            guard let scrollView, let documentView else { return }
            let width = max(scrollView.contentSize.width, scrollView.bounds.width)
            let height = max(
                scrollView.contentSize.height,
                CGFloat(rowCount) * currentRowHeight
            )
            let nextSize = CGSize(width: width, height: max(1, height))
            scrollbarOverlayView?.needsDisplay = true
            guard documentView.frame.size != nextSize else { return }
            documentView.setFrameSize(nextSize)
        }

        func notifyVisibleRowsChanged(force: Bool = false) {
            guard let range = visibleRowRange() else { return }
            guard force || range != lastNotifiedVisibleRows else { return }
            lastNotifiedVisibleRows = range
            onVisibleRowsChange(range)
        }

        func scrollToTop() {
            guard let scrollView else {
                return
            }

            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            documentView?.needsDisplay = true
            scrollbarOverlayView?.needsDisplay = true
            notifyVisibleRowsChanged(force: true)
        }

        @objc func scrollContentDidChange() {
            notifyVisibleRowsChanged()
            scrollbarOverlayView?.scrollMetricsDidChange()
            if isMenuOpen {
                repositionOpenMenu()
            } else if !isScrollbarDragging {
                layoutHoverButtons()
            }
        }

        func drawRows(in dirtyRect: CGRect) {
            guard let documentView else { return }
            documentView.effectiveAppearance.performAsCurrentDrawingAppearance {
                NSGraphicsContext.saveGraphicsState()
                drawRowsNow(in: dirtyRect)
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        private func drawRowsNow(in dirtyRect: CGRect) {
            guard rowCount > 0,
                  let documentView,
                  let range = visibleRowRange(in: dirtyRect)
            else {
                return
            }

            for row in range {
                let rowRect = rectForRow(row, width: documentView.bounds.width)
                drawRowBackground(row: row, rect: rowRect)
                drawCellTexts(row: row, rowRect: rowRect)
            }
        }

        private func drawRowBackground(row: Int, rect: CGRect) {
            let rowIsSelected = isRedesign && isRowSelected(row)
            if rowIsSelected {
                WorkbenchRedesignColors.NS.rowSelected.setFill()
                rect.fill()
            } else if hoveredRow == row {
                if isRedesign {
                    WorkbenchRedesignColors.NS.rowHover.setFill()
                } else {
                    NSColor.secondaryLabelColor.withAlphaComponent(0.06).setFill()
                }
                rect.fill()
            }

            if isRedesign {
                WorkbenchRedesignColors.NS.borderDivider.setStroke()
            } else {
                NSColor.separatorColor.setStroke()
            }
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.minX, y: rect.maxY - 0.5))
            path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 0.5))
            path.lineWidth = 0.5
            path.stroke()
        }

        private func drawCellTexts(row: Int, rowRect: CGRect) {
            let M = SubtitleTableMetrics.self
            let model = rowProvider(row)
            let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
            let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0
            let cuesWidth = max(0, rowRect.width - M.indexColumnWidth - M.nameColumnWidth - speakerWidth - languageWidth)

            if isRedesign {
                let checkboxState: WorkbenchCheckboxState = isRowSelected(row) ? .checked : .unchecked
                WorkbenchCheckboxDrawing.draw(
                    state: checkboxState,
                    in: checkboxRect(forRowRect: rowRect),
                    isFocused: isEnabled && focusedCheckboxRow == row && documentView?.window?.firstResponder === documentView
                )
            } else {
                drawIndex(row + 1, in: CGRect(x: 0, y: rowRect.minY, width: M.indexColumnWidth, height: rowRect.height))
            }
            drawBody(
                model?.displayTitle ?? "",
                in: CGRect(x: M.indexColumnWidth, y: rowRect.minY, width: M.nameColumnWidth, height: rowRect.height),
                trailing: M.trailingInset
            )
            drawBody(
                model?.cues ?? "",
                in: CGRect(
                    x: M.indexColumnWidth + M.nameColumnWidth,
                    y: rowRect.minY,
                    width: cuesWidth,
                    height: rowRect.height
                ),
                trailing: M.trailingInset,
                underline: isRedesign && hoveredCueTextRow == row
            )
            if showsSpeakerColumn {
                drawTags(
                    model?.speakerTags ?? [],
                    in: CGRect(
                        x: max(M.indexColumnWidth + M.nameColumnWidth, rowRect.width - languageWidth - M.speakerColumnWidth),
                        y: rowRect.minY,
                        width: M.speakerColumnWidth,
                        height: rowRect.height
                    ),
                    trailing: M.trailingInset
                )
            }
            if showsLanguageColumn {
                drawTags(
                    model?.tags ?? [],
                    in: CGRect(
                        x: max(M.indexColumnWidth + M.nameColumnWidth, rowRect.width - M.languageColumnWidth),
                        y: rowRect.minY,
                        width: M.languageColumnWidth,
                        height: rowRect.height
                    ),
                    trailing: M.trailingInset
                )
            }
        }

        private func drawIndex(_ number: Int, in rect: CGRect) {
            let M = SubtitleTableMetrics.self
            textLayout.update(
                attributedString: SubtitleTableText.index(number, isRedesign: isRedesign),
                width: max(0, rect.width - M.cellLeading - M.indexTrailingInset)
            )
            let yOffset = isRedesign ? rect.minY + (rect.height - textLayout.usedHeight) / 2 : rect.minY + M.rowVerticalInset
            textLayout.draw(at: CGPoint(x: rect.minX + M.cellLeading, y: yOffset))
        }

        private func drawBody(_ text: String, in rect: CGRect, trailing: CGFloat, underline: Bool = false) {
            let M = SubtitleTableMetrics.self
            guard !text.isEmpty else { return }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(rect)
            textLayout.update(
                attributedString: SubtitleTableText.body(text, isRedesign: isRedesign),
                width: max(0, rect.width - M.cellLeading - trailing)
            )
            let origin = bodyTextOrigin(in: rect)
            if underline {
                textLayout.drawUnderline(
                    at: origin,
                    color: WorkbenchRedesignColors.NS.textPrimary,
                    thickness: M.interactiveTextUnderlineThickness,
                    offset: M.interactiveTextUnderlineOffset,
                    backingScaleFactor: backingScaleFactor()
                )
            }
            textLayout.draw(at: origin)
            NSGraphicsContext.restoreGraphicsState()
        }

        private func drawTags(_ tags: [WorkbenchTag], in rect: CGRect, trailing: CGFloat) {
            let M = SubtitleTableMetrics.self
            guard !tags.isEmpty else { return }

            NSGraphicsContext.saveGraphicsState()
            NSBezierPath.clip(rect)

            var x = rect.minX + M.cellLeading
            let startY = isRedesign ? rect.minY + (rect.height - M.tagHeight) / 2 : rect.minY + M.rowVerticalInset - 1
            var y = startY
            let maxX = rect.maxX - trailing
            let maxY = isRedesign ? rect.maxY : rect.maxY - M.rowVerticalInset

            for tag in tags {
                let attributed = SubtitleTableText.tag(tag, isRedesign: isRedesign)
                let textSize = attributed.size()
                let tagWidth = ceil(textSize.width) + 2 * M.tagHorizontalInset
                if x > rect.minX + M.cellLeading, x + tagWidth > maxX {
                    x = rect.minX + M.cellLeading
                    y += M.tagHeight + M.tagVerticalSpacing
                }
                guard y + M.tagHeight <= maxY else {
                    break
                }

                let tagRect = CGRect(x: x, y: y, width: min(tagWidth, max(0, maxX - x)), height: M.tagHeight)
                let path = NSBezierPath(
                    roundedRect: tagRect,
                    xRadius: M.tagCornerRadius,
                    yRadius: M.tagCornerRadius
                )
                if isRedesign {
                    tag.colorID.redesignFillColor().setFill()
                } else {
                    tag.colorID.appKitFillColor.setFill()
                }
                path.fill()

                let textRect = CGRect(
                    x: tagRect.minX + M.tagHorizontalInset,
                    y: tagRect.minY + max(0, (tagRect.height - textSize.height) / 2),
                    width: max(0, tagRect.width - 2 * M.tagHorizontalInset),
                    height: textSize.height
                )
                attributed.draw(in: textRect)
                x += tagRect.width + M.tagHorizontalSpacing
            }

            NSGraphicsContext.restoreGraphicsState()
        }

        private func heightForRow(_ row: Int, width: CGFloat) -> CGFloat {
            _ = row
            _ = width
            return currentRowHeight
        }

        private func rectForRow(_ row: Int, width: CGFloat) -> CGRect {
            let y = rowHeightCache.yOffset(for: row, defaultHeight: currentRowHeight)
            let height = heightForRow(row, width: width)
            return CGRect(x: 0, y: y, width: width, height: height)
        }

        private func checkboxRect(forRowRect rowRect: CGRect) -> CGRect {
            let size = SubtitleTableMetrics.checkboxSize
            return CGRect(
                x: (SubtitleTableMetrics.indexColumnWidth - size) / 2,
                y: rowRect.minY + (rowRect.height - size) / 2,
                width: size,
                height: size
            )
        }

        private func checkboxHitRect(forRowRect rowRect: CGRect) -> CGRect {
            checkboxRect(forRowRect: rowRect).insetBy(
                dx: -SubtitleTableMetrics.checkboxHitSlop,
                dy: -SubtitleTableMetrics.checkboxHitSlop
            )
        }

        private func visibleRowRange() -> Range<Int>? {
            guard let scrollView else { return nil }
            return visibleRowRange(in: scrollView.contentView.bounds)
        }

        private func visibleRowRange(in rect: CGRect) -> Range<Int>? {
            guard rowCount > 0 else { return nil }
            let lower = rowHeightCache.rowIndex(
                atY: rect.minY,
                rowCount: rowCount,
                defaultHeight: currentRowHeight
            )
            let upper = rowHeightCache.rowIndex(
                atY: max(rect.minY, rect.maxY),
                rowCount: rowCount,
                defaultHeight: currentRowHeight
            )
            let overscan = 4
            let lowerBound = max(0, lower - overscan)
            let upperBound = min(rowCount, upper + overscan + 1)
            return lowerBound < upperBound ? lowerBound..<upperBound : nil
        }

        private func rowAtDocumentPoint(_ point: CGPoint) -> Int? {
            guard rowCount > 0 else { return nil }
            let row = rowHeightCache.rowIndex(
                atY: point.y,
                rowCount: rowCount,
                defaultHeight: currentRowHeight
            )
            let rect = rectForRow(row, width: documentView?.bounds.width ?? 0)
            return rect.contains(point) ? row : nil
        }

        private func cuesCellRect(forRowRect rowRect: CGRect) -> CGRect {
            let M = SubtitleTableMetrics.self
            let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
            let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0
            let cuesWidth = max(0, rowRect.width - M.indexColumnWidth - M.nameColumnWidth - speakerWidth - languageWidth)
            return CGRect(
                x: M.indexColumnWidth + M.nameColumnWidth,
                y: rowRect.minY,
                width: cuesWidth,
                height: rowRect.height
            )
        }

        private func bodyTextOrigin(in rect: CGRect) -> CGPoint {
            let M = SubtitleTableMetrics.self
            let yOffset = isRedesign ? rect.minY + (rect.height - textLayout.usedHeight) / 2 : rect.minY + M.rowVerticalInset
            return CGPoint(x: rect.minX + M.cellLeading, y: yOffset)
        }

        private func isPointInCueText(row: Int, point: CGPoint) -> Bool {
            guard row >= 0,
                  row < rowCount,
                  let documentView,
                  let model = rowProvider(row),
                  !model.cues.isEmpty
            else {
                return false
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            let cuesRect = cuesCellRect(forRowRect: rowRect)
            guard cuesRect.contains(point) else { return false }

            let M = SubtitleTableMetrics.self
            textLayout.update(
                attributedString: SubtitleTableText.body(model.cues, isRedesign: isRedesign),
                width: max(0, cuesRect.width - M.cellLeading - M.trailingInset)
            )
            return textLayout.containsText(at: point, origin: bodyTextOrigin(in: cuesRect))
        }

        func handleMouseHover(windowPoint: CGPoint) {
            if isMenuOpen || isExternalPopupLayerOpen {
                return
            }
            guard let documentView else { return }
            let point = documentView.convert(windowPoint, from: nil)
            guard documentView.visibleRect.contains(point) else {
                clearHover()
                return
            }
            let row = rowAtDocumentPoint(point)
            updateHoveredRow(row)
            let cueTextRow = row.flatMap { isPointInCueText(row: $0, point: point) ? $0 : nil }
            updateHoveredCueTextRow(cueTextRow)
        }

        func handleMouseDown(windowPoint: CGPoint) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let documentView
            else {
                return false
            }
            let point = documentView.convert(windowPoint, from: nil)
            guard documentView.visibleRect.contains(point),
                  let row = rowAtDocumentPoint(point)
            else {
                return false
            }
            if isPointInCueText(row: row, point: point) {
                playRow(row)
                return true
            }
            let rowRect = rectForRow(row, width: documentView.bounds.width)
            guard checkboxHitRect(forRowRect: rowRect).contains(point) else {
                return false
            }
            return toggleRowCheckboxFromMouse(row: row)
        }

        private func toggleRowCheckboxFromMouse(row: Int) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  row >= 0,
                  row < rowCount
            else {
                return false
            }
            clearFocusedCheckbox()
            onToggleRowSelection(row)
            invalidateRows([row])
            headerView?.refreshHeaderHosts()
            return true
        }

        func handleKeyDown(_ event: NSEvent) -> Bool {
            guard isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen
            else {
                return false
            }

            switch event.keyCode {
            case 48:
                guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
                    return false
                }
                if moveFocusedCheckboxByTab(isShiftPressed: event.modifierFlags.contains(.shift)) {
                    return true
                }
                exitFocusedCheckboxByTab(isShiftPressed: event.modifierFlags.contains(.shift))
                return true
            case 49:
                guard let focusedCheckboxRow,
                      focusedCheckboxRow >= 0,
                      focusedCheckboxRow < rowCount
                else {
                    return false
                }
                onToggleRowSelection(focusedCheckboxRow)
                invalidateRows([focusedCheckboxRow])
                headerView?.refreshHeaderHosts()
                return true
            case 125:
                guard focusedCheckboxRow != nil else { return false }
                moveFocusedCheckbox(by: 1)
                return true
            case 126:
                guard focusedCheckboxRow != nil else { return false }
                moveFocusedCheckbox(by: -1)
                return true
            default:
                return false
            }
        }

        func clearFocusedCheckbox() {
            updateFocusedCheckbox(nil)
        }

        private func moveFocusedCheckbox(by delta: Int) {
            guard rowCount > 0 else {
                updateFocusedCheckbox(nil)
                return
            }
            let current = focusedCheckboxRow ?? hoveredRow ?? visibleRowRange()?.lowerBound ?? 0
            let next = min(max(0, current + delta), rowCount - 1)
            updateFocusedCheckbox(next)
            scrollFocusedCheckboxIntoVisible()
        }

        private func moveFocusedCheckboxByTab(isShiftPressed: Bool) -> Bool {
            guard let focusedCheckboxRow, rowCount > 0 else {
                return false
            }
            let next = focusedCheckboxRow + (isShiftPressed ? -1 : 1)
            guard next >= 0, next < rowCount else {
                return false
            }
            updateFocusedCheckbox(next)
            scrollFocusedCheckboxIntoVisible()
            return true
        }

        private func exitFocusedCheckboxByTab(isShiftPressed: Bool) {
            clearFocusedCheckbox()
            if isShiftPressed {
                documentView?.window?.selectPreviousKeyView(documentView)
            } else {
                documentView?.window?.selectNextKeyView(documentView)
            }
        }

        private func updateFocusedCheckbox(_ row: Int?) {
            let nextRow = row.flatMap { $0 >= 0 && $0 < rowCount ? $0 : nil }
            guard nextRow != focusedCheckboxRow else { return }
            let oldRow = focusedCheckboxRow
            focusedCheckboxRow = nextRow
            invalidateRows([oldRow, nextRow])
        }

        private func scrollFocusedCheckboxIntoVisible() {
            guard let focusedCheckboxRow, let documentView else { return }
            documentView.scrollToVisible(rectForRow(focusedCheckboxRow, width: documentView.bounds.width))
            notifyVisibleRowsChanged()
        }

        @discardableResult
        func focusFirstVisibleCheckboxFromKeyboard() -> Bool {
            guard isRedesign,
                  isEnabled,
                  rowCount > 0,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  let documentView
            else {
                return false
            }
            guard let row = firstFocusableCheckboxRow(visibleRows: visibleRowRange()) else {
                return false
            }
            documentView.window?.makeFirstResponder(documentView)
            updateFocusedCheckbox(row)
            scrollFocusedCheckboxIntoVisible()
            return true
        }

        func firstFocusableCheckboxRowForTesting(visibleRows: Range<Int>?) -> Int? {
            firstFocusableCheckboxRow(visibleRows: visibleRows)
        }

        private func firstFocusableCheckboxRow(visibleRows: Range<Int>?) -> Int? {
            guard rowCount > 0 else { return nil }
            guard let visibleRows, visibleRows.lowerBound < visibleRows.upperBound else {
                return 0
            }
            return min(max(0, visibleRows.lowerBound), rowCount - 1)
        }

        private func installKeyboardFocusEventMonitor() {
            guard keyboardFocusEventMonitor == nil else { return }
            keyboardFocusEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyboardFocusEvent(event)
            }
        }

        private func handleKeyboardFocusEvent(_ event: NSEvent) -> NSEvent? {
            guard event.keyCode == 48,
                  let container,
                  event.window === container.window,
                  isRedesign,
                  isEnabled,
                  !isMenuOpen,
                  !isExternalPopupLayerOpen,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  let firstResponder = event.window?.firstResponder,
                  headerView?.isLastInteractiveHeaderResponder(firstResponder) == true
            else {
                return event
            }
            return focusFirstVisibleCheckboxFromKeyboard() ? nil : event
        }

        func clearHover() {
            updateHoveredRow(nil)
            updateHoveredCueTextRow(nil)
        }

        private func updateHoveredRow(_ newRow: Int?) {
            if isMenuOpen || isExternalPopupLayerOpen {
                return
            }
            guard newRow != hoveredRow else { return }
            let oldRow = hoveredRow
            hoveredRow = newRow
            invalidateRows([oldRow, newRow])
            layoutHoverButtons()
        }

        private func updateHoveredCueTextRow(_ newRow: Int?) {
            guard newRow != hoveredCueTextRow else {
                updateCueTextCursor(isActive: newRow != nil)
                return
            }
            let oldRow = hoveredCueTextRow
            hoveredCueTextRow = newRow
            invalidateRows([oldRow, newRow])
            updateCueTextCursor(isActive: newRow != nil)
        }

        private func updateCueTextCursor(isActive: Bool) {
            if isActive {
                guard !hasPushedCueTextCursor else { return }
                NSCursor.pointingHand.push()
                hasPushedCueTextCursor = true
                return
            }

            if hasPushedCueTextCursor {
                NSCursor.pop()
                hasPushedCueTextCursor = false
            }
        }

        private func invalidateRows(_ rows: [Int?]) {
            guard let documentView else { return }
            for row in rows.compactMap({ $0 }) where row >= 0 && row < rowCount {
                documentView.setNeedsDisplay(rectForRow(row, width: documentView.bounds.width))
            }
        }

        private func setScrollbarDragging(_ isDragging: Bool) {
            guard isScrollbarDragging != isDragging else { return }
            isScrollbarDragging = isDragging
            if isDragging {
                buttonsHost?.isHidden = true
                updateHoveredCueTextRow(nil)
            } else {
                layoutHoverButtons()
            }
        }

        private func backingScaleFactor() -> CGFloat {
            documentView?.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        }

        private func layoutHoverButtons() {
            guard !isScrollbarDragging,
                  let buttonsHost,
                  let documentView,
                  let hoveredRow,
                  hoveredRow >= 0,
                  hoveredRow < rowCount,
                  let model = rowProvider(hoveredRow)
            else {
                buttonsHost?.isHidden = true
                return
            }

            let buttonFrame: CGRect
            let M = SubtitleTableMetrics.self
            let rowRect = rectForRow(hoveredRow, width: documentView.bounds.width)
            if isRedesign {
                let languageWidth = showsLanguageColumn ? M.languageColumnWidth : 0
                let speakerWidth = showsSpeakerColumn ? M.speakerColumnWidth : 0
                let cuesWidth = max(0, rowRect.width - M.indexColumnWidth - M.nameColumnWidth - speakerWidth - languageWidth)
                let x = M.indexColumnWidth + M.nameColumnWidth + cuesWidth - 36 - M.trailingInset
                let y = rowRect.minY + (rowRect.height - 36) / 2
                buttonFrame = CGRect(x: x, y: y, width: 36, height: 36)
            } else {
                let x = M.indexColumnWidth + M.nameColumnWidth + M.cellLeading
                let y = rowRect.minY + M.rowVerticalInset - 4
                buttonFrame = CGRect(x: x, y: y, width: 120, height: 28)
            }

            buttonsHost.rootView = CueHoverButtons(
                isRedesign: isRedesign,
                isEnabled: isEnabled,
                isMenuOpen: isMenuOpen,
                onPlay: { [weak self] in self?.playRow(hoveredRow) },
                onCopy: { [weak self] in self?.copyRow(hoveredRow) },
                onTriggerMenu: { [weak self] in self?.showMenu(for: hoveredRow, buttonFrame: buttonFrame) },
                onDismissMenu: { [weak self] in self?.dismissMenu() }
            )

            buttonsHost.frame = buttonFrame
            buttonsHost.isHidden = model.cues.isEmpty
        }

        private func setMenuHost<Content: View>(_ content: Content, in container: NSView) {
            let wrapped = AnyView(content)
            if let menuHost {
                menuHost.rootView = wrapped
            } else {
                let host = NSHostingView(rootView: wrapped)
                host.wantsLayer = true
                host.layer?.masksToBounds = false
                container.addSubview(host)
                menuHost = host
            }
        }

        private func positionMenu(triggerFrameInContainer: CGRect, menuSize: CGSize) -> CGRect {
            let visibleRect = container?.bounds ?? .zero
            let M = SubtitleTableMetrics.self
            let menuWidth = menuSize.width
            let menuHeight = menuSize.height

            var menuX = triggerFrameInContainer.minX
            if menuX + menuWidth > visibleRect.maxX - M.trailingInset {
                menuX = max(visibleRect.minX, visibleRect.maxX - menuWidth - M.trailingInset)
            }

            var menuY = triggerFrameInContainer.minY - menuHeight - WorkbenchControlMetrics.redesignSpacing1
            if menuY < visibleRect.minY {
                menuY = triggerFrameInContainer.maxY + WorkbenchControlMetrics.redesignSpacing1
                if menuY + menuHeight > visibleRect.maxY {
                    menuY = max(visibleRect.minY, visibleRect.maxY - menuHeight)
                }
            }

            return CGRect(x: menuX, y: menuY, width: menuWidth, height: menuHeight)
        }

        func showMenu(for row: Int, buttonFrame: CGRect) {
            isMenuOpen = true
            activeMenuAnchor = .row(buttonFrame: buttonFrame)
            layoutHoverButtons()

            guard let documentView, let container = self.container else {
                isMenuOpen = false
                activeMenuAnchor = nil
                return
            }

            if menuOverlayView == nil {
                let overlay = SubtitleTableMenuOverlayView()
                overlay.onClick = { [weak self] in
                    self?.dismissMenu()
                }
                container.addSubview(overlay)
                menuOverlayView = overlay
            }
            menuOverlayView?.frame = container.bounds
            menuOverlayView?.isHidden = false

            let menuView = RowActionMenu(
                onCopy: { [weak self] in
                    self?.copyRow(row)
                    self?.dismissMenu()
                },
                onContext: { [weak self] in
                    self?.dismissMenu()
                },
                onFavorite: { [weak self] in
                    self?.dismissMenu()
                }
            )

            setMenuHost(menuView, in: container)

            if let menuOverlayView {
                container.addSubview(menuOverlayView)
            }
            if let menuHost {
                container.addSubview(menuHost)
            }

            menuHost?.layout()
            let menuSize = menuHost?.fittingSize ?? CGSize(width: 172, height: 128)

            let triggerFrameInContainer = container.convert(buttonFrame, from: documentView)
            let finalMenuFrame = positionMenu(triggerFrameInContainer: triggerFrameInContainer, menuSize: menuSize)

            menuHost?.frame = finalMenuFrame
            menuHost?.isHidden = false

            installMenuDismissMonitor()
        }

        func showHeaderMenu(for columnID: String, triggerFrame: CGRect) {
            isMenuOpen = true
            activeHeaderMenuColumnID = columnID
            activeMenuAnchor = .header(triggerFrame: triggerFrame)
            layoutHoverButtons()
            headerView?.refreshHeaderHosts()

            guard let container = self.container, let headerView = self.headerView else {
                isMenuOpen = false
                activeHeaderMenuColumnID = nil
                activeMenuAnchor = nil
                return
            }

            if menuOverlayView == nil {
                let overlay = SubtitleTableMenuOverlayView()
                overlay.onClick = { [weak self] in
                    self?.dismissMenu()
                }
                container.addSubview(overlay)
                menuOverlayView = overlay
            }
            menuOverlayView?.frame = container.bounds
            menuOverlayView?.isHidden = false

            let sortDirection = (sortedColumnID == columnID) ? self.sortDirection : nil
            let menuView = ColumnHeaderMenu(
                sortDirection: sortDirection,
                onSortAscending: { [weak self] in
                    self?.sortedColumnID = columnID
                    self?.sortDirection = .asc
                    self?.dismissMenu()
                },
                onSortDescending: { [weak self] in
                    self?.sortedColumnID = columnID
                    self?.sortDirection = .desc
                    self?.dismissMenu()
                }
            )

            setMenuHost(menuView, in: container)

            if let menuOverlayView {
                container.addSubview(menuOverlayView)
            }
            if let menuHost {
                container.addSubview(menuHost)
            }

            menuHost?.layout()
            let menuSize = menuHost?.fittingSize ?? CGSize(width: 172, height: 128)

            let triggerFrameInContainer = container.convert(triggerFrame, from: headerView)
            let finalMenuFrame = positionMenu(triggerFrameInContainer: triggerFrameInContainer, menuSize: menuSize)

            menuHost?.frame = finalMenuFrame
            menuHost?.isHidden = false

            installMenuDismissMonitor()
        }

        func dismissMenu(recalculateHover: Bool = true) {
            isMenuOpen = false
            activeHeaderMenuColumnID = nil
            activeMenuAnchor = nil
            menuHost?.isHidden = true
            menuOverlayView?.isHidden = true
            removeMenuDismissMonitor()
            headerView?.refreshHeaderHosts()

            guard recalculateHover else { return }

            if let window = documentView?.window {
                handleMouseHover(windowPoint: window.mouseLocationOutsideOfEventStream)
            } else {
                layoutHoverButtons()
            }
        }

        private func installMenuDismissMonitor() {
            removeMenuDismissMonitor()
            menuEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self else { return event }
                if self.isMenuOpen {
                    guard let container = self.container, event.window === container.window else {
                        DispatchQueue.main.async { self.dismissMenu() }
                        return event
                    }
                    if let menuHost = self.menuHost, !menuHost.isHidden {
                        let clickPoint = container.convert(event.locationInWindow, from: nil)
                        if menuHost.frame.contains(clickPoint) {
                            return event
                        }
                    }
                    DispatchQueue.main.async {
                        self.dismissMenu()
                    }
                }
                return event
            }
        }

        private func repositionOpenMenu() {
            guard isMenuOpen,
                  let container,
                  let menuHost,
                  !menuHost.isHidden,
                  let activeMenuAnchor
            else {
                return
            }

            menuOverlayView?.frame = container.bounds
            menuOverlayView?.isHidden = false

            let menuSize = menuHost.fittingSize
            let resolvedMenuSize = CGSize(
                width: menuSize.width > 0 ? menuSize.width : menuHost.frame.width,
                height: menuSize.height > 0 ? menuSize.height : menuHost.frame.height
            )

            let triggerFrameInContainer: CGRect
            switch activeMenuAnchor {
            case .row(let buttonFrame):
                guard let documentView else { return }
                triggerFrameInContainer = container.convert(buttonFrame, from: documentView)
            case .header(let triggerFrame):
                guard let headerView else { return }
                triggerFrameInContainer = container.convert(triggerFrame, from: headerView)
            }

            menuHost.frame = positionMenu(
                triggerFrameInContainer: triggerFrameInContainer,
                menuSize: resolvedMenuSize
            )
        }

        private func removeMenuDismissMonitor() {
            if let monitor = menuEventMonitor {
                NSEvent.removeMonitor(monitor)
                menuEventMonitor = nil
            }
        }

        private func playRow(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            onPlay(model)
        }

        private func copyRow(_ row: Int) {
            guard let model = rowProvider(row) else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(model.cues, forType: .string)
        }

        private func scheduleResizeAfterDrawing() {
            resizeDocument()
        }
    }
}

// MARK: - Header Cell and Header Menu Views

struct SubtitleTableHeaderCellView: View {
    let title: String
    let columnID: String
    let isSortable: Bool
    let isEnabled: Bool
    let sortDirection: SubtitleTableView.Coordinator.TableSortDirection?
    let isMenuOpen: Bool
    let columnRect: CGRect
    let onTrigger: (CGRect) -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @State private var hasPushedCursor = false
    @State private var triggerWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            if isSortable {
                Button(action: {
                    let triggerRect = CGRect(
                        x: columnRect.minX,
                        y: columnRect.minY,
                        width: triggerWidth,
                        height: columnRect.height
                    )
                    onTrigger(triggerRect)
                }) {
                    buttonContent
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { triggerWidth = geo.size.width }
                                    .onChange(of: geo.size.width) { newValue in triggerWidth = newValue }
                            }
                        )
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .focused($isFocused)
                .disableFocusEffect()
                .overlay(
                    Group {
                        if isFocused && isEnabled {
                            RoundedRectangle(
                                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius + WorkbenchControlMetrics.redesignFocusRingWidth,
                                style: .continuous
                            )
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                        }
                    }
                )
                .contentShape(Rectangle())
                .onHover { inside in
                    if isEnabled {
                        isHovered = inside
                        updateCursor(inside: inside)
                    } else {
                        isHovered = false
                    }
                }
                .onChange(of: isEnabled) { newValue in
                    if isHovered {
                        if hasPushedCursor {
                            NSCursor.pop()
                            hasPushedCursor = false
                        }
                        if newValue {
                            NSCursor.pointingHand.push()
                        }
                        hasPushedCursor = newValue
                    }
                }
                .onDisappear {
                    if hasPushedCursor {
                        NSCursor.pop()
                        hasPushedCursor = false
                    }
                }
            } else {
                staticContent
            }
            Spacer(minLength: 0)
        }
        .frame(width: columnRect.width, height: columnRect.height, alignment: .leading)
    }

    private var buttonContent: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Text(title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTable, weight: .semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
            
            Image(systemName: sortIconName)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS,
                    weight: WorkbenchControlMetrics.redesignSelectIndicatorWeightMacOS
                ))
                .foregroundStyle(iconColor)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignPaddingHeaderTriggerX)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius, style: .continuous)
                .fill((isHovered || isMenuOpen) && isEnabled ? WorkbenchRedesignColors.bgHover : Color.clear)
        )
    }

    private var staticContent: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeTable, weight: .semibold))
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled)
                .lineLimit(1)
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignPaddingX)
        .frame(maxHeight: .infinity)
    }

    private var textColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.textDisabled }
        return WorkbenchRedesignColors.textPrimary
    }

    private var iconColor: Color {
        guard isEnabled else { return WorkbenchRedesignColors.iconDisabled }
        if isHovered || isMenuOpen {
            return WorkbenchRedesignColors.textPrimary
        }
        return WorkbenchRedesignColors.iconDefault
    }

    private var sortIconName: String {
        switch sortDirection {
        case .asc:
            return "arrow.up"
        case .desc:
            return "arrow.down"
        case nil:
            return "chevron.up.chevron.down"
        }
    }

    private func updateCursor(inside: Bool) {
        if inside {
            if !hasPushedCursor {
                if isEnabled {
                    NSCursor.pointingHand.push()
                }
                hasPushedCursor = isEnabled
            }
        } else {
            if hasPushedCursor {
                NSCursor.pop()
                hasPushedCursor = false
            }
        }
    }
}

struct ColumnHeaderMenu: View {
    let sortDirection: SubtitleTableView.Coordinator.TableSortDirection?
    let onSortAscending: () -> Void
    let onSortDescending: () -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: true) {
            VStack(spacing: 0) {
                WorkbenchPopoverRow(
                    title: "Sort Ascending",
                    isSelected: false,
                    isHighlighted: sortDirection == .asc,
                    systemImage: "arrow.up",
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: true,
                    action: onSortAscending
                )
                WorkbenchPopoverRow(
                    title: "Sort Descending",
                    isSelected: false,
                    isHighlighted: sortDirection == .desc,
                    systemImage: "arrow.down",
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: true,
                    action: onSortDescending
                )
                Rectangle()
                    .fill(WorkbenchRedesignColors.borderDivider)
                    .frame(height: WorkbenchControlMetrics.hairlineWidth)
                    .padding(.vertical, WorkbenchControlMetrics.redesignSpacing1)
                WorkbenchPopoverRow(
                    title: "Hide Column",
                    isSelected: false,
                    isHighlighted: false,
                    systemImage: "eye.slash",
                    isRedesign: true,
                    showsCheckmarkSlot: false,
                    isEnabled: false,
                    action: nil
                )
            }
        }
    }
}
