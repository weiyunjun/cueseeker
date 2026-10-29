import AppKit
import SwiftUI

@MainActor
final class WorkbenchNativeSingleLineTextField: NSTextField {
    override class var cellClass: AnyClass? {
        get { WorkbenchSingleLineTextFieldCell.self }
        set {}
    }

    var onFocusChange: ((Bool) -> Void)?
    var onAutofocusCompleted: (() -> Void)?
    var normalizeDraft: ((String) -> String)?
    var autofocus = false
    private(set) var hasPerformedInitialAutofocus = false
    var didUserInteractSinceAutofocus = false
    private var isRetryingAutofocus = false
    private var autofocusRetryCount = 0
    var wantsFocusFromSwiftUI = false
    private var isRetryingSwiftUIFocus = false
    var isApplyingProgrammaticText = false
    private var configuredAlignment: NSTextAlignment = .left
    private var isUpdatingEffectiveAlignment = false

    override var alignment: NSTextAlignment {
        get { super.alignment }
        set {
            if !isUpdatingEffectiveAlignment {
                configuredAlignment = newValue
            }
            super.alignment = newValue
        }
    }

    override var intrinsicContentSize: NSSize {
        let resolvedFont = font ?? .systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: resolvedFont))
        return NSSize(width: NSView.noIntrinsicMetric, height: lineHeight)
    }

    override var stringValue: String {
        get { super.stringValue }
        set {
            let normalized = normalizeFullString(newValue)
            super.stringValue = normalized
            updateEffectiveAlignment(for: normalized)
        }
    }

    var isCurrentlyFocused: Bool {
        guard let window, let responder = window.firstResponder else {
            return false
        }
        return responder === self || responder === currentEditor()
    }

    override var focusRingMaskBounds: NSRect { .zero }

    override func drawFocusRingMask() {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let customCell = WorkbenchSingleLineTextFieldCell(textCell: "")
        customCell.isEditable = true
        customCell.isSelectable = true
        customCell.isBordered = false
        customCell.drawsBackground = false
        customCell.usesSingleLineMode = true
        customCell.wraps = false
        customCell.isScrollable = true
        self.cell = customCell

        isEditable = true
        isSelectable = true
        isBordered = false
        drawsBackground = false
        usesSingleLineMode = true
        cell?.wraps = false
        cell?.isScrollable = true
        font = .systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func ensureFieldEditorUsesTextKit1() {
        _ = (window?.fieldEditor(true, for: self) as? NSTextView)?.layoutManager
    }

    func resolvedAlignment(for text: String) -> NSTextAlignment {
        guard configuredAlignment == .right, bounds.width > 0 else {
            return configuredAlignment
        }
        let resolvedFont = font ?? .systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        let textWidth = ceil((text as NSString).size(withAttributes: [.font: resolvedFont]).width) + 4.0
        return textWidth > bounds.width ? .left : .right
    }

    func updateEffectiveAlignment(for text: String) {
        let effective = resolvedAlignment(for: text)
        if super.alignment != effective {
            isUpdatingEffectiveAlignment = true
            super.alignment = effective
            isUpdatingEffectiveAlignment = false
        }
    }

    func normalizeFullString(_ raw: String) -> String {
        if let normalizeDraft {
            return SearchInputNormalizer.singleLine(normalizeDraft(raw))
        }
        return SearchInputNormalizer.singleLine(raw)
    }

    func configure(with input: WorkbenchSingleLineTextInput, isEnabled: Bool) {
        self.isEnabled = isEnabled
        self.isEditable = isEnabled
        self.isSelectable = isEnabled
        self.configuredAlignment = input.alignment
        self.normalizeDraft = input.normalizeDraft
        self.autofocus = input.autofocus
        self.onAutofocusCompleted = input.onAutofocusCompleted
        self.setAccessibilityLabel(input.accessibilityLabel)

        let resolvedFont: NSFont = input.usesMonospacedDigits
            ? .monospacedDigitSystemFont(ofSize: input.fontSize, weight: .regular)
            : .systemFont(ofSize: input.fontSize, weight: .regular)
        self.font = resolvedFont
        self.textColor = NSColor(input.textColor)
        let activeText = (currentEditor() as? NSTextView)?.string ?? super.stringValue
        updateEffectiveAlignment(for: activeText)

        if input.placeholder.isEmpty {
            self.placeholderAttributedString = nil
            self.placeholderString = nil
        } else {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = input.alignment
            paragraphStyle.lineBreakMode = .byTruncatingTail
            self.placeholderAttributedString = NSAttributedString(
                string: input.placeholder,
                attributes: [
                    .font: resolvedFont,
                    .foregroundColor: NSColor(input.placeholderColor),
                    .paragraphStyle: paragraphStyle
                ]
            )
        }
        cell?.usesSingleLineMode = true
        cell?.wraps = false
        cell?.isScrollable = true
        if let editor = currentEditor() as? NSTextView {
            applyTextStyle(to: editor)
        }
        needsDisplay = true
    }

    func applyTextStyle(to editor: NSTextView) {
        _ = editor.layoutManager
        let resolvedFont = font ?? .systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        let resolvedColor = textColor ?? .labelColor
        let effectiveAlignment = resolvedAlignment(for: editor.string)
        updateEffectiveAlignment(for: editor.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = effectiveAlignment
        paragraphStyle.lineBreakMode = .byClipping
        paragraphStyle.tighteningFactorForTruncation = 0
        let attributes: [NSAttributedString.Key: Any] = [
            .font: resolvedFont,
            .foregroundColor: resolvedColor,
            .paragraphStyle: paragraphStyle
        ]
        editor.font = resolvedFont
        editor.textColor = resolvedColor
        editor.alignment = effectiveAlignment
        editor.typingAttributes = attributes
        if let storage = editor.textStorage, storage.length > 0 {
            storage.addAttributes(
                attributes,
                range: NSRange(location: 0, length: storage.length)
            )
        }
        if let layoutManager = editor.layoutManager,
           let textContainer = editor.textContainer {
            layoutManager.ensureLayout(for: textContainer)
        }
    }

    func selectAllInCurrentEditor() {
        guard let editor = currentEditor() as? NSTextView else {
            return
        }
        applyTextStyle(to: editor)
        let length = (editor.string as NSString).length
        editor.setSelectedRange(NSRange(location: 0, length: length))
    }

    func clearTextAndFocus() {
        guard isEnabled && isEditable else {
            return
        }
        didUserInteractSinceAutofocus = true
        if !isCurrentlyFocused {
            _ = window?.makeFirstResponder(self)
        }
        if let editor = currentEditor() as? NSTextView {
            if editor.hasMarkedText() {
                editor.unmarkText()
            }
            editor.string = ""
            applyTextStyle(to: editor)
            editor.setSelectedRange(NSRange(location: 0, length: 0))
            (editor.superview as? NSClipView)?.scroll(to: .zero)
            editor.didChangeText()
        } else {
            isApplyingProgrammaticText = true
            stringValue = ""
            isApplyingProgrammaticText = false
        }
        needsDisplay = true
    }

    func performInitialAutofocusIfPossible() {
        guard autofocus, !hasPerformedInitialAutofocus else {
            return
        }
        guard let window, bounds.width > 0, isEnabled, isEditable, !isHiddenOrHasHiddenAncestor else {
            scheduleAutofocusRetryIfNeeded()
            return
        }
        let customCell = cell as? WorkbenchSingleLineTextFieldCell
        customCell?.selectsAllOnEditSessionStart = true
        let focused: Bool
        if isCurrentlyFocused {
            focused = true
        } else {
            focused = window.makeFirstResponder(self)
        }
        customCell?.selectsAllOnEditSessionStart = false

        guard focused, isCurrentlyFocused else {
            scheduleAutofocusRetryIfNeeded()
            return
        }
        hasPerformedInitialAutofocus = true
        didUserInteractSinceAutofocus = false
        autofocusRetryCount = 0
        selectAllInCurrentEditor()
        onAutofocusCompleted?()
    }

    private func scheduleAutofocusRetryIfNeeded() {
        guard autofocus, !hasPerformedInitialAutofocus, !isRetryingAutofocus, autofocusRetryCount < 8 else {
            return
        }
        isRetryingAutofocus = true
        autofocusRetryCount += 1
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRetryingAutofocus = false
            self.performInitialAutofocusIfPossible()
        }
    }

    func requestFocusIfPossible() {
        guard let window, bounds.width > 0, !isCurrentlyFocused else {
            return
        }
        if window.makeFirstResponder(self) {
            isRetryingSwiftUIFocus = false
        } else if !isRetryingSwiftUIFocus {
            isRetryingSwiftUIFocus = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isRetryingSwiftUIFocus = false
                guard self.wantsFocusFromSwiftUI, !self.isCurrentlyFocused, let window = self.window else {
                    return
                }
                if !window.makeFirstResponder(self) {
                    self.wantsFocusFromSwiftUI = false
                    self.onFocusChange?(false)
                }
            }
        } else {
            wantsFocusFromSwiftUI = false
            onFocusChange?(false)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        isEnabled && isEditable
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let activeText = (currentEditor() as? NSTextView)?.string ?? super.stringValue
        updateEffectiveAlignment(for: activeText)
        if let editor = currentEditor() as? NSTextView {
            applyTextStyle(to: editor)
            if hasPerformedInitialAutofocus, !didUserInteractSinceAutofocus, isCurrentlyFocused {
                let length = (editor.string as NSString).length
                if editor.selectedRange() != NSRange(location: 0, length: length) {
                    editor.setSelectedRange(NSRange(location: 0, length: length))
                }
            }
        }
        if autofocus, !hasPerformedInitialAutofocus, bounds.width > 0 {
            performInitialAutofocusIfPossible()
        } else if wantsFocusFromSwiftUI, !isCurrentlyFocused, bounds.width > 0 {
            requestFocusIfPossible()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        ensureFieldEditorUsesTextKit1()
        if autofocus, !hasPerformedInitialAutofocus {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.autofocus, !self.hasPerformedInitialAutofocus else {
                    return
                }
                self.performInitialAutofocusIfPossible()
            }
        } else if wantsFocusFromSwiftUI, !isCurrentlyFocused {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.wantsFocusFromSwiftUI, !self.isCurrentlyFocused else {
                    return
                }
                self.requestFocusIfPossible()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        didUserInteractSinceAutofocus = true
        ensureFieldEditorUsesTextKit1()
        updateEffectiveAlignment(for: super.stringValue)
        if event.clickCount == 1,
           !event.modifierFlags.contains(.shift),
           let editor = currentEditor() as? NSTextView,
           editor.selectedRange().length > 0 {
            editor.setSelectedRange(NSRange(location: editor.selectedRange().location, length: 0))
        }
        super.mouseDown(with: event)
        if let editor = currentEditor() as? NSTextView {
            applyTextStyle(to: editor)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard isEnabled && isEditable else { return }
        didUserInteractSinceAutofocus = true
        ensureFieldEditorUsesTextKit1()
        updateEffectiveAlignment(for: super.stringValue)
        if !isCurrentlyFocused {
            _ = window?.makeFirstResponder(self)
            if let editor = currentEditor() as? NSTextView {
                applyTextStyle(to: editor)
                let pointInEditor = editor.convert(event.locationInWindow, from: nil)
                let clampedPoint = NSPoint(
                    x: min(max(pointInEditor.x, 0), editor.bounds.width),
                    y: editor.bounds.midY
                )
                let index = editor.characterIndexForInsertion(at: clampedPoint)
                editor.setSelectedRange(NSRange(location: index, length: 0))
            }
        }
    }

    override func becomeFirstResponder() -> Bool {
        ensureFieldEditorUsesTextKit1()
        updateEffectiveAlignment(for: super.stringValue)
        let shouldSelectAll = (cell as? WorkbenchSingleLineTextFieldCell)?.selectsAllOnEditSessionStart == true
        let accepted = super.becomeFirstResponder()
        if accepted {
            if let editor = currentEditor() as? NSTextView {
                applyTextStyle(to: editor)
                if shouldSelectAll {
                    let length = (editor.string as NSString).length
                    editor.setSelectedRange(NSRange(location: 0, length: length))
                } else {
                    editor.setSelectedRange(NSRange(location: 0, length: 0))
                    (editor.superview as? NSClipView)?.scroll(to: .zero)
                }
            }
            onFocusChange?(true)
        }
        return accepted
    }

    @objc(textView:shouldChangeTextInRange:replacementString:)
    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        didUserInteractSinceAutofocus = true
        guard let replacementString else {
            return true
        }
        let inserted = normalizeDraft != nil
            ? replacementString
            : SearchInputNormalizer.singleLine(replacementString)
        if !replacementString.isEmpty,
           let normalizeDraft,
           normalizeDraft(inserted).isEmpty {
            return false
        }
        let currentNSString = textView.string as NSString
        let candidate = currentNSString.replacingCharacters(
            in: affectedCharRange,
            with: inserted
        )
        let normalized = normalizeFullString(candidate)
        if inserted == replacementString && normalized == candidate {
            return true
        }

        let cursorLocation: Int
        if normalizeDraft != nil {
            let prefix = currentNSString.substring(to: affectedCharRange.location)
            let normalizedPrefix = normalizeFullString(prefix + inserted)
            cursorLocation = min(
                (normalizedPrefix as NSString).length,
                (normalized as NSString).length
            )
        } else {
            cursorLocation = affectedCharRange.location + (inserted as NSString).length
        }

        if let storage = textView.textStorage {
            storage.replaceCharacters(
                in: NSRange(location: 0, length: currentNSString.length),
                with: normalized
            )
            applyTextStyle(to: textView)
            textView.setSelectedRange(NSRange(location: cursorLocation, length: 0))
            textView.didChangeText()
        }
        return false
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        if let editor = currentEditor() as? NSTextView {
            applyTextStyle(to: editor)
        }
        onFocusChange?(true)
    }

    override func textDidChange(_ notification: Notification) {
        didUserInteractSinceAutofocus = true
        super.textDidChange(notification)
        if let editor = currentEditor() as? NSTextView {
            applyTextStyle(to: editor)
        }
    }

    override func textDidEndEditing(_ notification: Notification) {
        if let editor = currentEditor() as? NSTextView {
            editor.setSelectedRange(NSRange(location: 0, length: 0))
            (editor.superview as? NSClipView)?.scroll(to: .zero)
        }
        super.textDidEndEditing(notification)
        updateEffectiveAlignment(for: super.stringValue)
        onFocusChange?(false)
    }
}

final class WorkbenchSingleLineTextFieldCell: NSTextFieldCell {
    var selectsAllOnEditSessionStart = false

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        let effectiveStart = selectsAllOnEditSessionStart ? selStart : 0
        let effectiveLength = selectsAllOnEditSessionStart ? selLength : 0
        super.select(
            withFrame: rect,
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: effectiveStart,
            length: effectiveLength
        )
    }
}

struct WorkbenchSingleLineContainerOverlay: NSViewRepresentable {
    let isEnabled: Bool
    var trailingExclusionSize: NSSize? = nil
    var trailingExclusionRightInset: CGFloat = 0
    var onPressRelease: (() -> Void)? = nil

    func makeNSView(context: Context) -> WorkbenchSingleLineContainerOverlayView {
        let view = WorkbenchSingleLineContainerOverlayView()
        view.isEnabled = isEnabled
        view.trailingExclusionSize = trailingExclusionSize
        view.trailingExclusionRightInset = trailingExclusionRightInset
        view.onPressRelease = onPressRelease
        return view
    }

    func updateNSView(_ nsView: WorkbenchSingleLineContainerOverlayView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.trailingExclusionSize = trailingExclusionSize
        nsView.trailingExclusionRightInset = trailingExclusionRightInset
        nsView.onPressRelease = onPressRelease
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

@MainActor
final class WorkbenchSingleLineContainerOverlayView: NSView, PointerShapeProviding {
    var isEnabled = true
    var trailingExclusionSize: NSSize?
    var trailingExclusionRightInset: CGFloat = 0
    var onPressRelease: (() -> Void)?
    private var isPressingInside = false
    private var dragAnchorIndex: Int?

    func pointerShape(atWindowPoint point: CGPoint) -> PointerShape {
        isEnabled ? .iBeam : .arrow
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        isEnabled
    }

    override func resetCursorRects() {
        guard isEnabled else { return }
        addCursorRect(bounds, cursor: .iBeam)
    }

    func containsWindowPoint(_ windowPoint: NSPoint) -> Bool {
        let localPoint = convert(windowPoint, from: nil)
        return bounds.contains(localPoint)
    }

    func enclosesField(_ target: NSView) -> Bool {
        findEnclosedTextField() === target
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = superview != nil ? convert(point, from: superview) : point
        guard bounds.contains(localPoint) else {
            return nil
        }
        if let exclusionSize = trailingExclusionSize {
            let exclusionRect = NSRect(
                x: bounds.width - trailingExclusionRightInset - exclusionSize.width,
                y: (bounds.height - exclusionSize.height) / 2.0,
                width: exclusionSize.width,
                height: exclusionSize.height
            )
            if exclusionRect.contains(localPoint) {
                return nil
            }
        }
        if let field = findEnclosedTextField() {
            let pointInField = field.convert(localPoint, from: self)
            if field.bounds.contains(pointInField) {
                return nil
            }
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        if onPressRelease != nil {
            let localPoint = convert(event.locationInWindow, from: nil)
            isPressingInside = isEnabled && bounds.contains(localPoint)
            return
        }
        isPressingInside = false
        focusEnclosedTextField(
            atWindowPoint: event.locationInWindow,
            clickCount: event.clickCount,
            modifierFlags: event.modifierFlags
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard onPressRelease == nil,
              isEnabled,
              let anchor = dragAnchorIndex,
              let field = findEnclosedTextField(),
              let editor = field.currentEditor() as? NSTextView
        else {
            super.mouseDragged(with: event)
            return
        }
        let pointInEditor = editor.convert(event.locationInWindow, from: nil)
        let clampedPoint = NSPoint(
            x: min(max(pointInEditor.x, 0), editor.bounds.width),
            y: editor.bounds.midY
        )
        let current = editor.characterIndexForInsertion(at: clampedPoint)
        let start = min(anchor, current)
        let length = abs(current - anchor)
        editor.setSelectedRange(NSRange(location: start, length: length))
        editor.scrollRangeToVisible(NSRange(location: current, length: 0))
    }

    override func mouseUp(with event: NSEvent) {
        dragAnchorIndex = nil
        guard onPressRelease != nil else {
            super.mouseUp(with: event)
            return
        }
        let didStartInside = isPressingInside
        isPressingInside = false
        let localPoint = convert(event.locationInWindow, from: nil)
        guard didStartInside, isEnabled, bounds.contains(localPoint) else {
            return
        }
        focusEnclosedTextField(
            atWindowPoint: event.locationInWindow,
            clickCount: event.clickCount,
            modifierFlags: event.modifierFlags
        )
        onPressRelease?()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard isEnabled,
              let field = findEnclosedTextField(),
              field.isEnabled && field.isEditable
        else {
            return
        }
        (field as? WorkbenchNativeSingleLineTextField)?.didUserInteractSinceAutofocus = true
        let wasFocused = window?.firstResponder === field
            || window?.firstResponder === field.currentEditor()
        if !wasFocused {
            _ = window?.makeFirstResponder(field)
            if let editor = field.currentEditor() as? NSTextView {
                let pointInField = field.convert(event.locationInWindow, from: nil)
                let clampedFieldPoint = NSPoint(
                    x: min(max(pointInField.x, 0), field.bounds.width),
                    y: field.bounds.midY
                )
                let pointInEditor = editor.convert(clampedFieldPoint, from: field)
                let clampedPoint = NSPoint(x: pointInEditor.x, y: editor.bounds.midY)
                let index = editor.characterIndexForInsertion(at: clampedPoint)
                editor.setSelectedRange(NSRange(location: index, length: 0))
            }
        }
    }

    private func focusEnclosedTextField(
        atWindowPoint windowPoint: NSPoint,
        clickCount: Int = 1,
        modifierFlags: NSEvent.ModifierFlags = []
    ) {
        guard isEnabled,
              let field = findEnclosedTextField(),
              field.isEnabled && field.isEditable
        else {
            return
        }
        (field as? WorkbenchNativeSingleLineTextField)?.didUserInteractSinceAutofocus = true
        let wasFocused = window?.firstResponder === field
            || window?.firstResponder === field.currentEditor()
        if !wasFocused {
            _ = window?.makeFirstResponder(field)
        }
        if let editor = field.currentEditor() as? NSTextView {
            let pointInField = field.convert(windowPoint, from: nil)
            let clampedFieldPoint = NSPoint(
                x: min(max(pointInField.x, 0), field.bounds.width),
                y: field.bounds.midY
            )
            let pointInEditor = editor.convert(clampedFieldPoint, from: field)
            let clampedPoint = NSPoint(x: pointInEditor.x, y: editor.bounds.midY)
            let index = editor.characterIndexForInsertion(at: clampedPoint)
            let totalLength = (editor.string as NSString).length
            if clickCount >= 3 {
                dragAnchorIndex = nil
                editor.setSelectedRange(NSRange(location: 0, length: totalLength))
            } else if clickCount == 2 {
                dragAnchorIndex = nil
                let wordRange = editor.selectionRange(
                    forProposedRange: NSRange(location: min(index, max(0, totalLength - 1)), length: 0),
                    granularity: .selectByWord
                )
                editor.setSelectedRange(wordRange)
            } else if modifierFlags.contains(.shift) {
                let existing = editor.selectedRange()
                let anchor = existing.location
                dragAnchorIndex = anchor
                let start = min(anchor, index)
                let length = abs(index - anchor)
                editor.setSelectedRange(NSRange(location: start, length: length))
            } else {
                dragAnchorIndex = index
                editor.setSelectedRange(NSRange(location: index, length: 0))
            }
        }
    }

    func findEnclosedTextField() -> NSTextField? {
        guard let root = window?.contentView ?? superview else {
            return nil
        }
        let rectInWindow = convert(bounds, to: nil)
        return Self.findTextField(in: root, within: rectInWindow)
    }

    private static func findTextField(in view: NSView, within windowRect: NSRect) -> NSTextField? {
        if let field = view as? NSTextField,
           !field.isHiddenOrHasHiddenAncestor,
           field.bounds.width > 0,
           field.bounds.height > 0 {
            let centerInWindow = field.convert(
                NSPoint(x: field.bounds.midX, y: field.bounds.midY),
                to: nil
            )
            if windowRect.contains(centerInWindow) {
                return field
            }
        }
        for subview in view.subviews {
            if let found = findTextField(in: subview, within: windowRect) {
                return found
            }
        }
        return nil
    }
}

struct FocusedTextInputCompanionSurface: NSViewRepresentable {
    func makeNSView(context: Context) -> FocusedTextInputCompanionView {
        FocusedTextInputCompanionView()
    }

    func updateNSView(_ nsView: FocusedTextInputCompanionView, context: Context) {}
}

@MainActor
final class FocusedTextInputCompanionView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func containsWindowPoint(_ windowPoint: NSPoint) -> Bool {
        guard !isHiddenOrHasHiddenAncestor, bounds.width > 0, bounds.height > 0 else {
            return false
        }
        let localPoint = convert(windowPoint, from: nil)
        return bounds.contains(localPoint)
    }
}

struct WorkbenchSecureSingleLineInput: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focus: FocusState<Bool>.Binding
    let accessibilityLabel: String
    let onFocusChange: (Bool) -> Void
    var onSubmit: (() -> Void)?

    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WorkbenchNativeSecureTextField {
        let field = WorkbenchNativeSecureTextField()
        field.delegate = context.coordinator
        field.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.setFocus(focused)
        }
        field.configure(
            placeholder: placeholder,
            accessibilityLabel: accessibilityLabel,
            isEnabled: isEnabled
        )
        field.stringValue = SearchInputNormalizer.singleLine(text)
        return field
    }

    func updateNSView(_ nsView: WorkbenchNativeSecureTextField, context: Context) {
        context.coordinator.parent = self
        nsView.configure(
            placeholder: placeholder,
            accessibilityLabel: accessibilityLabel,
            isEnabled: isEnabled
        )
        let normalized = SearchInputNormalizer.singleLine(text)
        if nsView.stringValue != normalized {
            nsView.stringValue = normalized
            nsView.applyBulletKerningToCurrentEditor()
            nsView.needsDisplay = true
        }
        if focus.wrappedValue, !nsView.isCurrentlyFocused {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: WorkbenchSecureSingleLineInput

        init(parent: WorkbenchSecureSingleLineInput) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            if let field = obj.object as? WorkbenchNativeSecureTextField {
                field.applyBulletKerningToCurrentEditor()
            }
            setFocus(true)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? WorkbenchNativeSecureTextField else {
                return
            }
            field.applyBulletKerningToCurrentEditor()
            let normalized = SearchInputNormalizer.singleLine(field.stringValue)
            if parent.text != normalized {
                parent.text = normalized
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            setFocus(false)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                if !textView.hasMarkedText() {
                    parent.onSubmit?()
                }
                return true
            case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
                 #selector(NSResponder.insertLineBreak(_:)),
                 #selector(NSResponder.insertParagraphSeparator(_:)):
                return true
            default:
                return false
            }
        }

        func setFocus(_ focused: Bool) {
            parent.onFocusChange(focused)
            if parent.focus.wrappedValue != focused {
                parent.focus.wrappedValue = focused
            }
        }
    }
}

@MainActor
final class WorkbenchNativeSecureTextField: NSSecureTextField {
    override class var cellClass: AnyClass? {
        get { WorkbenchSecureTextFieldCell.self }
        set {}
    }

    var onFocusChange: ((Bool) -> Void)?

    override var stringValue: String {
        get { super.stringValue }
        set { super.stringValue = SearchInputNormalizer.singleLine(newValue) }
    }

    var isCurrentlyFocused: Bool {
        guard let window, let responder = window.firstResponder else {
            return false
        }
        return responder === self || responder === currentEditor()
    }

    override var focusRingMaskBounds: NSRect { .zero }

    override func drawFocusRingMask() {}

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let customCell = WorkbenchSecureTextFieldCell(textCell: "")
        customCell.isEditable = true
        customCell.isSelectable = true
        customCell.isBordered = false
        customCell.drawsBackground = false
        customCell.usesSingleLineMode = true
        customCell.wraps = false
        customCell.isScrollable = true
        self.cell = customCell

        isBordered = false
        drawsBackground = false
        usesSingleLineMode = true
        cell?.wraps = false
        cell?.isScrollable = true
        font = .systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func ensureFieldEditorUsesTextKit1() {
        _ = (window?.fieldEditor(true, for: self) as? NSTextView)?.layoutManager
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        ensureFieldEditorUsesTextKit1()
    }

    override func mouseDown(with event: NSEvent) {
        ensureFieldEditorUsesTextKit1()
        if event.clickCount == 1,
           !event.modifierFlags.contains(.shift),
           let editor = currentEditor() as? NSTextView,
           editor.selectedRange().length > 0 {
            editor.setSelectedRange(NSRange(location: editor.selectedRange().location, length: 0))
        }
        super.mouseDown(with: event)
        applyBulletKerningToCurrentEditor()
    }

    override func rightMouseDown(with event: NSEvent) {
        guard isEnabled && isEditable else { return }
        ensureFieldEditorUsesTextKit1()
        if !isCurrentlyFocused {
            _ = window?.makeFirstResponder(self)
            applyBulletKerningToCurrentEditor()
            if let editor = currentEditor() as? NSTextView {
                let pointInEditor = editor.convert(event.locationInWindow, from: nil)
                let clampedPoint = NSPoint(
                    x: min(max(pointInEditor.x, 0), editor.bounds.width),
                    y: editor.bounds.midY
                )
                let index = editor.characterIndexForInsertion(at: clampedPoint)
                editor.setSelectedRange(NSRange(location: index, length: 0))
            }
        }
    }

    override func becomeFirstResponder() -> Bool {
        ensureFieldEditorUsesTextKit1()
        let shouldSelectAll = (cell as? WorkbenchSecureTextFieldCell)?.selectsAllOnEditSessionStart == true
        let accepted = super.becomeFirstResponder()
        if accepted {
            applyBulletKerningToCurrentEditor()
            if let editor = currentEditor() as? NSTextView {
                if shouldSelectAll {
                    let length = (editor.string as NSString).length
                    editor.setSelectedRange(NSRange(location: 0, length: length))
                } else {
                    editor.setSelectedRange(NSRange(location: 0, length: 0))
                    (editor.superview as? NSClipView)?.scroll(to: .zero)
                }
            }
            onFocusChange?(true)
        }
        return accepted
    }

    @objc(textView:shouldChangeTextInRange:replacementString:)
    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        if let replacementString,
           replacementString.rangeOfCharacter(from: .newlines) != nil {
            let normalized = SearchInputNormalizer.singleLine(replacementString)
            if let storage = textView.textStorage {
                storage.replaceCharacters(in: affectedCharRange, with: normalized)
                let newCursor = affectedCharRange.location + (normalized as NSString).length
                textView.setSelectedRange(NSRange(location: newCursor, length: 0))
                textView.didChangeText()
                applyBulletKerningToCurrentEditor()
            }
            return false
        }
        return true
    }

    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        applyBulletKerningToCurrentEditor()
        onFocusChange?(true)
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        applyBulletKerningToCurrentEditor()
    }

    override func textDidEndEditing(_ notification: Notification) {
        if let editor = currentEditor() as? NSTextView {
            editor.setSelectedRange(NSRange(location: 0, length: 0))
            (editor.superview as? NSClipView)?.scroll(to: .zero)
        }
        super.textDidEndEditing(notification)
        onFocusChange?(false)
    }

    func configure(placeholder: String, accessibilityLabel: String, isEnabled: Bool) {
        self.isEnabled = isEnabled
        self.isEditable = isEnabled
        self.isSelectable = isEnabled
        self.setAccessibilityLabel(accessibilityLabel)
        let font = NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        self.font = font
        self.textColor = isEnabled
            ? NSColor(WorkbenchRedesignColors.textPrimary)
            : NSColor(WorkbenchRedesignColors.textDisabled)
        if placeholder.isEmpty {
            self.placeholderAttributedString = nil
        } else {
            self.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor(WorkbenchRedesignColors.textPlaceholder)
                ]
            )
        }
        applyBulletKerningToCurrentEditor()
        needsDisplay = true
    }

    func applyBulletKerningToCurrentEditor() {
        guard let editor = currentEditor() as? NSTextView else {
            return
        }
        _ = editor.layoutManager
        var typingAttrs = editor.typingAttributes
        typingAttrs[.kern] = WorkbenchSecureTextFieldCell.bulletKern
        if let font {
            typingAttrs[.font] = font
            editor.font = font
        }
        if let textColor {
            typingAttrs[.foregroundColor] = textColor
            editor.textColor = textColor
        }
        editor.typingAttributes = typingAttrs
        if let storage = editor.textStorage, storage.length > 0 {
            storage.addAttributes(
                typingAttrs,
                range: NSRange(location: 0, length: storage.length)
            )
        }
        if let layoutManager = editor.layoutManager,
           let textContainer = editor.textContainer {
            layoutManager.ensureLayout(for: textContainer)
        }
    }
}

final class WorkbenchSecureTextFieldCell: NSSecureTextFieldCell {
    static let bulletKern: CGFloat = 2.0
    var selectsAllOnEditSessionStart = false

    override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) {
        let effectiveStart = selectsAllOnEditSessionStart ? selStart : 0
        let effectiveLength = selectsAllOnEditSessionStart ? selLength : 0
        super.select(
            withFrame: rect,
            in: controlView,
            editor: textObj,
            delegate: delegate,
            start: effectiveStart,
            length: effectiveLength
        )
    }

    override func drawingRect(forBounds theRect: NSRect) -> NSRect {
        let baseRect = super.drawingRect(forBounds: theRect)
        let resolvedFont = font ?? NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        let lineHeight = NSLayoutManager().defaultLineHeight(for: resolvedFont)
        var centered = baseRect
        centered.origin.y = theRect.origin.y + floor((theRect.height - lineHeight) / 2.0)
        centered.size.height = lineHeight
        return centered
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard controlView.window?.firstResponder !== (controlView as? NSControl)?.currentEditor(),
              !stringValue.isEmpty
        else {
            super.drawInterior(withFrame: cellFrame, in: controlView)
            return
        }
        let resolvedFont = font ?? NSFont.systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
        let resolvedColor = textColor ?? NSColor.labelColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let bullets = String(repeating: "\u{2022}", count: stringValue.count)
        let attributed = NSAttributedString(
            string: bullets,
            attributes: [
                .font: resolvedFont,
                .foregroundColor: resolvedColor,
                .kern: Self.bulletKern,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributed.draw(in: drawingRect(forBounds: cellFrame))
    }
}
