import SwiftUI

struct WorkbenchSingleLineTextInput: View {
    let placeholder: String
    @Binding var text: String
    let placeholderColor: Color
    let textColor: Color
    let fontSize: CGFloat
    let focus: FocusState<Bool>.Binding
    let accessibilityLabel: String
    var onSubmit: (() -> Void)?

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder)
                .foregroundColor(placeholderColor)
        )
        .textFieldStyle(.plain)
        .foregroundStyle(textColor)
        .font(.system(size: fontSize, weight: .regular))
        .focused(focus)
        .accessibilityLabel(accessibilityLabel)
        .onSubmit {
            onSubmit?()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WorkbenchFormTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let validationMessage: String?
    let focus: FocusState<Bool>.Binding

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
                accessibilityLabel: label
            )
                .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
                .workbenchFormFieldChrome(
                    hasError: validationMessage != nil,
                    isFocused: focus.wrappedValue
                )
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

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(WorkbenchRedesignColors.textPlaceholder)
            )
            .textFieldStyle(.plain)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeControl,
                weight: .regular
            ))
            .foregroundStyle(
                isEnabled
                    ? WorkbenchRedesignColors.textPrimary
                    : WorkbenchRedesignColors.textDisabled
            )
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .focused(focus)

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
                    ? (focus.wrappedValue
                        ? WorkbenchRedesignColors.borderFocus
                        : WorkbenchRedesignColors.borderControl)
                    : WorkbenchRedesignColors.borderDisabled,
                lineWidth: 1
            )
        )
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
                    ? (isFocused
                        ? WorkbenchRedesignColors.borderFocus
                        : WorkbenchRedesignColors.borderControl)
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
    let focus: FocusState<Bool>.Binding
    var onSubmit: (() -> Void)?

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchFormLabel(text: label)

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
                onSubmit: onSubmit
            )
            .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
            .workbenchDialogFormFieldChrome(
                isFocused: focus.wrappedValue,
                isEnabled: isEnabled
            )
        }
    }
}

struct WorkbenchDialogFormPasswordField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let focus: FocusState<Bool>.Binding
    var onSubmit: (() -> Void)?

    @State private var isFocused = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchFormLabel(text: label)

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
                isFocused: isFocused || focus.wrappedValue,
                isEnabled: isEnabled
            )
        }
    }
}

import AppKit

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
        field.stringValue = text
        return field
    }

    func updateNSView(_ nsView: WorkbenchNativeSecureTextField, context: Context) {
        context.coordinator.parent = self
        nsView.configure(
            placeholder: placeholder,
            accessibilityLabel: accessibilityLabel,
            isEnabled: isEnabled
        )
        if nsView.stringValue != text {
            nsView.stringValue = text
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
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            setFocus(false)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit?()
                return true
            }
            return false
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

    var isCurrentlyFocused: Bool {
        guard let window, let responder = window.firstResponder else {
            return false
        }
        return responder === self || responder === currentEditor()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let customCell = WorkbenchSecureTextFieldCell(textCell: "")
        customCell.isEditable = true
        customCell.isSelectable = true
        customCell.isBordered = false
        customCell.drawsBackground = false
        customCell.focusRingType = .none
        customCell.usesSingleLineMode = true
        customCell.wraps = false
        customCell.isScrollable = true
        customCell.lineBreakMode = .byTruncatingTail
        self.cell = customCell

        isBordered = false
        drawsBackground = false
        focusRingType = .none
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingTail
        font = .systemFont(
            ofSize: WorkbenchControlMetrics.redesignFontSizeControl,
            weight: .regular
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            applyBulletKerningToCurrentEditor()
            onFocusChange?(true)
        }
        return accepted
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
        var typingAttrs = editor.typingAttributes
        typingAttrs[.kern] = WorkbenchSecureTextFieldCell.bulletKern
        if let font {
            typingAttrs[.font] = font
        }
        if let textColor {
            typingAttrs[.foregroundColor] = textColor
        }
        editor.typingAttributes = typingAttrs
        if let storage = editor.textStorage, storage.length > 0 {
            storage.addAttribute(
                .kern,
                value: WorkbenchSecureTextFieldCell.bulletKern,
                range: NSRange(location: 0, length: storage.length)
            )
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
