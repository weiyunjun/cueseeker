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
    var autofocus: Bool = false
    let focus: FocusState<Bool>.Binding
    let accessibilityLabel: String
    var normalizeDraft: ((String) -> String)? = nil
    var onFocusChange: ((Bool) -> Void)? = nil
    var onAutofocusCompleted: (() -> Void)? = nil
    var onBindTextField: ((WorkbenchNativeSingleLineTextField) -> Void)? = nil
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
        onBindTextField?(field)
        return field
    }

    func updateNSView(_ nsView: WorkbenchNativeSingleLineTextField, context: Context) {
        context.coordinator.parent = self
        nsView.configure(with: self, isEnabled: isEnabled)
        onBindTextField?(nsView)
        let normalizedText = nsView.normalizeFullString(text)
        if let editor = nsView.currentEditor() as? NSTextView {
            if editor.string != normalizedText, !editor.hasMarkedText() {
                let selection = editor.selectedRange()
                nsView.isApplyingProgrammaticText = true
                editor.string = normalizedText
                nsView.applyTextStyle(to: editor)
                let length = (normalizedText as NSString).length
                if nsView.hasPerformedInitialAutofocus && !nsView.didUserInteractSinceAutofocus && nsView.isCurrentlyFocused {
                    editor.setSelectedRange(NSRange(location: 0, length: length))
                } else {
                    editor.setSelectedRange(NSRange(
                        location: min(selection.location, length),
                        length: 0
                    ))
                }
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
        if nsView.autofocus, !nsView.hasPerformedInitialAutofocus {
            nsView.performInitialAutofocusIfPossible()
        } else if nsView.wantsFocusFromSwiftUI, !nsView.isCurrentlyFocused {
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
            DispatchQueue.main.async { [weak self] in
                guard let self, let field = self.textField else { return }
                let actualFocus = field.isCurrentlyFocused
                guard actualFocus == focused else { return }
                self.lastObservedSwiftUIFocus = actualFocus
                self.parent.onFocusChange?(actualFocus)
                if self.parent.focus.wrappedValue != actualFocus {
                    self.parent.focus.wrappedValue = actualFocus
                }
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
                    isFocused: isFocused
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

    static func filterIntegerDraft(_ raw: String) -> String {
        let prefix = raw.prefix { scalar in
            scalar != "." && !scalar.unicodeScalars.contains(where: { CharacterSet.newlines.contains($0) })
        }
        return String(prefix.filter { $0.isASCII && ("0"..."9").contains($0) })
    }

    static func normalizeIntegerDraft(_ raw: String, maximum: Int) -> String {
        let digitsOnly = filterIntegerDraft(raw)
        guard !digitsOnly.isEmpty else {
            return ""
        }
        if let parsed = Int(digitsOnly), parsed > maximum {
            return String(maximum)
        }
        if Int(digitsOnly) == nil {
            return String(maximum)
        }
        return digitsOnly
    }

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
                    ? (isFocused
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
    var showsErrorBorder: Bool = true
    var autofocus: Bool = false
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
                    autofocus: autofocus,
                    focus: focus,
                    accessibilityLabel: label,
                    normalizeDraft: normalizeDraft,
                    onFocusChange: { isFocused = $0 },
                    onSubmit: onSubmit
                )
                .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
                .workbenchDialogFormFieldChrome(
                    hasError: showsErrorBorder && validationMessage != nil,
                    isFocused: isFocused,
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
                    isFocused: isFocused,
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
