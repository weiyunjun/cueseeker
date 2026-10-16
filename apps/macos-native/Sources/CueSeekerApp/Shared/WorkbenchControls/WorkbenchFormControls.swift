import AppKit
import SwiftUI

struct WorkbenchSingleLineTextInput: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let placeholderColor: Color
    let textColor: Color
    let fontSize: CGFloat
    var alignment: NSTextAlignment = .left
    var usesMonospacedDigits: Bool = false
    let focus: FocusState<Bool>.Binding
    let accessibilityLabel: String
    var normalizeDraft: ((String) -> String)? = nil
    var onFocusChange: ((Bool) -> Void)? = nil
    var onEditingEnded: (() -> Void)? = nil
    var onSubmit: (() -> Void)? = nil
    var onMoveUp: (() -> Bool)? = nil
    var onMoveDown: (() -> Bool)? = nil
    var onCancel: (() -> Bool)? = nil

    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WorkbenchNativeSingleLineTextField {
        let field = WorkbenchNativeSingleLineTextField()
        context.coordinator.textField = field
        context.coordinator.lastObservedSwiftUIFocus = focus.wrappedValue
        field.delegate = context.coordinator
        field.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.setFocus(focused)
        }
        field.configure(with: self, isEnabled: isEnabled)
        field.stringValue = field.normalizeFullString(text)
        field.wantsFocusFromSwiftUI = focus.wrappedValue
        return field
    }

    func updateNSView(_ nsView: WorkbenchNativeSingleLineTextField, context: Context) {
        context.coordinator.parent = self
        nsView.configure(with: self, isEnabled: isEnabled)
        let normalizedText = nsView.normalizeFullString(text)
        if let editor = nsView.currentEditor() as? NSTextView {
            if editor.string != normalizedText, !editor.hasMarkedText() {
                let selection = editor.selectedRange()
                nsView.isApplyingProgrammaticText = true
                editor.string = normalizedText
                nsView.applyTextStyle(to: editor)
                let length = (normalizedText as NSString).length
                editor.setSelectedRange(NSRange(
                    location: min(selection.location, length),
                    length: 0
                ))
                nsView.isApplyingProgrammaticText = false
            }
        } else if nsView.stringValue != normalizedText {
            nsView.stringValue = normalizedText
        }

        let swiftUIFocus = focus.wrappedValue
        if swiftUIFocus != context.coordinator.lastObservedSwiftUIFocus {
            context.coordinator.lastObservedSwiftUIFocus = swiftUIFocus
            nsView.wantsFocusFromSwiftUI = swiftUIFocus
        } else if !swiftUIFocus {
            nsView.wantsFocusFromSwiftUI = false
        }
        if nsView.wantsFocusFromSwiftUI, !nsView.isCurrentlyFocused {
            nsView.requestFocusIfPossible()
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: WorkbenchNativeSingleLineTextField,
        context: Context
    ) -> CGSize? {
        let height = nsView.intrinsicContentSize.height
        let width = proposal
            .replacingUnspecifiedDimensions(by: CGSize(width: 120, height: height))
            .width
        return CGSize(width: max(0, width), height: height)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: WorkbenchSingleLineTextInput
        weak var textField: WorkbenchNativeSingleLineTextField?
        var lastObservedSwiftUIFocus = false

        init(parent: WorkbenchSingleLineTextInput) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            if let field = obj.object as? WorkbenchNativeSingleLineTextField,
               let editor = field.currentEditor() as? NSTextView {
                field.applyTextStyle(to: editor)
            }
            setFocus(true)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? WorkbenchNativeSingleLineTextField,
                  !field.isApplyingProgrammaticText
            else {
                return
            }
            let current = (field.currentEditor() as? NSTextView)?.string ?? field.stringValue
            let normalized = field.normalizeFullString(current)
            if let editor = field.currentEditor() as? NSTextView,
               !editor.hasMarkedText(),
               editor.string != normalized {
                let selection = editor.selectedRange()
                field.isApplyingProgrammaticText = true
                editor.string = normalized
                field.applyTextStyle(to: editor)
                let length = (normalized as NSString).length
                editor.setSelectedRange(NSRange(
                    location: min(selection.location, length),
                    length: 0
                ))
                field.isApplyingProgrammaticText = false
            }
            if parent.text != normalized {
                parent.text = normalized
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            setFocus(false)
            parent.onEditingEnded?()
            if let field = obj.object as? WorkbenchNativeSingleLineTextField {
                let normalized = field.normalizeFullString(parent.text)
                if field.stringValue != normalized {
                    field.stringValue = normalized
                    field.needsDisplay = true
                }
                field.updateEffectiveAlignment(for: field.stringValue)
            }
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
                    if let field = control as? WorkbenchNativeSingleLineTextField {
                        let normalized = field.normalizeFullString(parent.text)
                        if textView.string != normalized {
                            let selection = textView.selectedRange()
                            field.isApplyingProgrammaticText = true
                            textView.string = normalized
                            field.applyTextStyle(to: textView)
                            let length = (normalized as NSString).length
                            let targetLocation = selection.location == 0 ? length : min(selection.location, length)
                            textView.setSelectedRange(NSRange(location: targetLocation, length: 0))
                            field.isApplyingProgrammaticText = false
                        }
                    }
                }
                return true
            case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
                 #selector(NSResponder.insertLineBreak(_:)),
                 #selector(NSResponder.insertParagraphSeparator(_:)):
                return true
            case #selector(NSResponder.moveUp(_:)):
                if !textView.hasMarkedText(),
                   let onMoveUp = parent.onMoveUp {
                    return onMoveUp()
                }
                return false
            case #selector(NSResponder.moveDown(_:)):
                if !textView.hasMarkedText(),
                   let onMoveDown = parent.onMoveDown {
                    return onMoveDown()
                }
                return false
            case #selector(NSResponder.cancelOperation(_:)):
                if !textView.hasMarkedText(),
                   let onCancel = parent.onCancel {
                    return onCancel()
                }
                return false
            default:
                return false
            }
        }

        func setFocus(_ focused: Bool) {
            textField?.wantsFocusFromSwiftUI = focused
            lastObservedSwiftUIFocus = focused
            parent.onFocusChange?(focused)
            if parent.focus.wrappedValue != focused {
                parent.focus.wrappedValue = focused
            }
        }
    }
}

struct WorkbenchFormTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let validationMessage: String?
    let focus: FocusState<Bool>.Binding

    @State private var isFocused = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        WorkbenchFormFieldContainer(
            label: label,
            validationMessage: validationMessage
        ) {
            WorkbenchSingleLineTextInput(
                placeholder: placeholder,
                text: $text,
                placeholderColor: WorkbenchRedesignColors.textPlaceholder,
                textColor: WorkbenchRedesignColors.textPrimary,
                fontSize: WorkbenchControlMetrics.redesignFontSizeControl,
                focus: focus,
                accessibilityLabel: label,
                onFocusChange: { isFocused = $0 }
            )
                .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
                .workbenchFormFieldChrome(
                    hasError: validationMessage != nil,
                    isFocused: isFocused || focus.wrappedValue
                )
                .overlay(WorkbenchSingleLineContainerOverlay(isEnabled: isEnabled))
        }
    }
}

struct WorkbenchFormTextArea: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let validationMessage: String?
    let focus: FocusState<Bool>.Binding
    /// The box's height comes from the layout it sits in.
    let height: CGFloat

    @State private var isFocused = false

    var body: some View {
        WorkbenchFormFieldContainer(
            label: label,
            validationMessage: validationMessage
        ) {
            WorkbenchTextAreaInput(
                text: $text,
                placeholder: placeholder,
                focus: focus,
                onFocusChange: { isFocused = $0 }
            )
            .frame(height: height)
            .workbenchFormFieldChrome(
                hasError: validationMessage != nil,
                isFocused: isFocused
            )
        }
    }
}

struct WorkbenchNumberField: View {
    let placeholder: String
    @Binding var text: String
    let unit: String?
    let focus: FocusState<Bool>.Binding
    var normalizeDraft: ((String) -> String)? = nil
    var onEditingEnded: (() -> Void)? = nil
    var onSubmit: (() -> Void)? = nil

    @State private var isFocused = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchSingleLineTextInput(
                placeholder: placeholder,
                text: $text,
                placeholderColor: WorkbenchRedesignColors.textPlaceholder,
                textColor: isEnabled
                    ? WorkbenchRedesignColors.textPrimary
                    : WorkbenchRedesignColors.textDisabled,
                fontSize: WorkbenchControlMetrics.redesignFontSizeControl,
                alignment: .right,
                usesMonospacedDigits: true,
                focus: focus,
                accessibilityLabel: placeholder,
                normalizeDraft: normalizeDraft,
                onFocusChange: { isFocused = $0 },
                onEditingEnded: onEditingEnded,
                onSubmit: onSubmit
            )

            if let unit {
                Text(unit)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .regular
                    ))
                    .foregroundStyle(
                        isEnabled
                            ? WorkbenchRedesignColors.textMuted
                            : WorkbenchRedesignColors.textDisabled
                    )
                    .fixedSize()
            }
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
        .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                style: .continuous
            )
            .fill(
                isEnabled
                    ? WorkbenchRedesignColors.bgControl
                    : WorkbenchRedesignColors.bgDisabled
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                style: .continuous
            )
            .strokeBorder(
                isEnabled
                    ? ((isFocused || focus.wrappedValue)
                        ? WorkbenchRedesignColors.borderFocus
                        : WorkbenchRedesignColors.borderControl)
                    : WorkbenchRedesignColors.borderDisabled,
                lineWidth: 1
            )
        )
        .overlay(WorkbenchSingleLineContainerOverlay(isEnabled: isEnabled))
    }
}

/// The label above a form field, and above the rename dialog's current name.
struct WorkbenchFormLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeControl,
                weight: .medium
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
    }
}

private struct WorkbenchFormFieldContainer<Content: View>: View {
    let label: String
    let validationMessage: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchFormLabel(text: label)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                content

                WorkbenchValidationMessage(text: validationMessage)
            }
        }
    }
}

/// Text Field's Validation Message: one line below the field, kept even while
/// there is nothing to say so the field never moves when a message comes.
struct WorkbenchValidationMessage: View {
    let text: String?

    var body: some View {
        Text(text ?? "\u{00A0}")
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeCaption,
                weight: .regular
            ))
            .foregroundStyle(WorkbenchRedesignColors.dangerText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(text == nil)
    }
}

extension View {
    /// Text Field's container: surface fill and the border for its Default,
    /// Focused and Error states.
    func workbenchFormFieldChrome(
        hasError: Bool,
        isFocused: Bool
    ) -> some View {
        background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgControl)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                style: .continuous
            )
            .strokeBorder(
                hasError
                    ? WorkbenchRedesignColors.dangerText
                    : (isFocused
                        ? WorkbenchRedesignColors.borderFocus
                        : WorkbenchRedesignColors.borderControl),
                lineWidth: 1
            )
        )
    }

    func workbenchDialogFormFieldChrome(
        hasError: Bool = false,
        isFocused: Bool,
        isEnabled: Bool
    ) -> some View {
        background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                style: .continuous
            )
            .fill(
                isEnabled
                    ? WorkbenchRedesignColors.bgControl
                    : WorkbenchRedesignColors.bgDisabled
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignFieldRadius,
                style: .continuous
            )
            .strokeBorder(
                isEnabled
                    ? (hasError
                        ? WorkbenchRedesignColors.dangerText
                        : (isFocused
                            ? WorkbenchRedesignColors.borderFocus
                            : WorkbenchRedesignColors.borderControl))
                    : WorkbenchRedesignColors.borderDisabled,
                lineWidth: 1
            )
        )
    }
}

struct WorkbenchDialogFormTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var validationMessage: String? = nil
    var reservesValidationLine: Bool = false
    let focus: FocusState<Bool>.Binding
    var normalizeDraft: ((String) -> String)? = nil
    var onSubmit: (() -> Void)?

    @State private var isFocused = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            WorkbenchFormLabel(text: label)
                .frame(
                    width: WorkbenchControlMetrics.redesignFormLabelWidth,
                    height: WorkbenchControlMetrics.redesignFieldHeight,
                    alignment: .leading
                )

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                WorkbenchSingleLineTextInput(
                    placeholder: placeholder,
                    text: $text,
                    placeholderColor: WorkbenchRedesignColors.textPlaceholder,
                    textColor: isEnabled
                        ? WorkbenchRedesignColors.textPrimary
                        : WorkbenchRedesignColors.textDisabled,
                    fontSize: WorkbenchControlMetrics.redesignFontSizeControl,
                    focus: focus,
                    accessibilityLabel: label,
                    normalizeDraft: normalizeDraft,
                    onFocusChange: { isFocused = $0 },
                    onSubmit: onSubmit
                )
                .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
                .workbenchDialogFormFieldChrome(
                    hasError: validationMessage != nil,
                    isFocused: isFocused || focus.wrappedValue,
                    isEnabled: isEnabled
                )
                .overlay(WorkbenchSingleLineContainerOverlay(isEnabled: isEnabled))

                if reservesValidationLine {
                    WorkbenchValidationMessage(text: validationMessage)
                }
            }
        }
    }
}

struct WorkbenchDialogFormPasswordField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var validationMessage: String? = nil
    var reservesValidationLine: Bool = false
    var showsErrorBorder: Bool = false
    let focus: FocusState<Bool>.Binding
    var onSubmit: (() -> Void)?

    @State private var isFocused = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            WorkbenchFormLabel(text: label)
                .frame(
                    width: WorkbenchControlMetrics.redesignFormLabelWidth,
                    height: WorkbenchControlMetrics.redesignFieldHeight,
                    alignment: .leading
                )

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                WorkbenchSecureSingleLineInput(
                    text: $text,
                    placeholder: placeholder,
                    focus: focus,
                    accessibilityLabel: label,
                    onFocusChange: { isFocused = $0 },
                    onSubmit: onSubmit
                )
                .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
                .workbenchDialogFormFieldChrome(
                    hasError: showsErrorBorder && validationMessage != nil,
                    isFocused: isFocused || focus.wrappedValue,
                    isEnabled: isEnabled
                )
                .overlay(WorkbenchSingleLineContainerOverlay(isEnabled: isEnabled))

                if reservesValidationLine {
                    WorkbenchValidationMessage(text: validationMessage)
                }
            }
        }
    }
}

@MainActor
final class WorkbenchNativeSingleLineTextField: NSTextField {
    var onFocusChange: ((Bool) -> Void)?
    var normalizeDraft: ((String) -> String)?
    var wantsFocusFromSwiftUI = false
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

    func requestFocusIfPossible() {
        guard let window, bounds.width > 0, !isCurrentlyFocused else {
            return
        }
        _ = window.makeFirstResponder(self)
    }

    override func layout() {
        super.layout()
        let activeText = (currentEditor() as? NSTextView)?.string ?? super.stringValue
        updateEffectiveAlignment(for: activeText)
        if let editor = currentEditor() as? NSTextView {
            applyTextStyle(to: editor)
        }
        if wantsFocusFromSwiftUI, !isCurrentlyFocused, bounds.width > 0 {
            requestFocusIfPossible()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        ensureFieldEditorUsesTextKit1()
        if wantsFocusFromSwiftUI, !isCurrentlyFocused {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.wantsFocusFromSwiftUI, !self.isCurrentlyFocused else {
                    return
                }
                self.requestFocusIfPossible()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        ensureFieldEditorUsesTextKit1()
        updateEffectiveAlignment(for: super.stringValue)
        super.mouseDown(with: event)
        if let editor = currentEditor() as? NSTextView {
            applyTextStyle(to: editor)
        }
    }

    override func becomeFirstResponder() -> Bool {
        ensureFieldEditorUsesTextKit1()
        updateEffectiveAlignment(for: super.stringValue)
        let accepted = super.becomeFirstResponder()
        if accepted {
            if let editor = currentEditor() as? NSTextView {
                applyTextStyle(to: editor)
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
        super.textDidChange(notification)
        if let editor = currentEditor() as? NSTextView {
            applyTextStyle(to: editor)
        }
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        updateEffectiveAlignment(for: super.stringValue)
        onFocusChange?(false)
    }
}

struct WorkbenchSingleLineContainerOverlay: NSViewRepresentable {
    let isEnabled: Bool
    var trailingExclusionSize: NSSize? = nil
    var trailingExclusionRightInset: CGFloat = 0

    func makeNSView(context: Context) -> WorkbenchSingleLineContainerOverlayView {
        let view = WorkbenchSingleLineContainerOverlayView()
        view.isEnabled = isEnabled
        view.trailingExclusionSize = trailingExclusionSize
        view.trailingExclusionRightInset = trailingExclusionRightInset
        return view
    }

    func updateNSView(_ nsView: WorkbenchSingleLineContainerOverlayView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.trailingExclusionSize = trailingExclusionSize
        nsView.trailingExclusionRightInset = trailingExclusionRightInset
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

@MainActor
final class WorkbenchSingleLineContainerOverlayView: NSView, PointerShapeProviding {
    var isEnabled = true
    var trailingExclusionSize: NSSize?
    var trailingExclusionRightInset: CGFloat = 0

    func pointerShape(atWindowPoint point: CGPoint) -> PointerShape {
        isEnabled ? .iBeam : .arrow
    }

    override func resetCursorRects() {
        guard isEnabled else { return }
        addCursorRect(bounds, cursor: .iBeam)
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
        guard isEnabled,
              let field = findEnclosedTextField(),
              field.isEnabled && field.isEditable
        else {
            super.mouseDown(with: event)
            return
        }
        let wasFocused = window?.firstResponder === field
            || window?.firstResponder === field.currentEditor()
        if !wasFocused {
            _ = window?.makeFirstResponder(field)
        }
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

    private func findEnclosedTextField() -> NSTextField? {
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

private struct WorkbenchSecureSingleLineInput: NSViewRepresentable {
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
private final class WorkbenchNativeSecureTextField: NSSecureTextField {
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
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        ensureFieldEditorUsesTextKit1()
        let accepted = super.becomeFirstResponder()
        if accepted {
            applyBulletKerningToCurrentEditor()
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

private final class WorkbenchSecureTextFieldCell: NSSecureTextFieldCell {
    static let bulletKern: CGFloat = 2.0

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
