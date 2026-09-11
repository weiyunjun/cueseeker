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
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(placeholderColor)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }

            TextField("", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(textColor)
                .focused(focus)
                .accessibilityLabel(accessibilityLabel)
                .onSubmit {
                    onSubmit?()
                }
        }
        .font(.system(size: fontSize, weight: .regular))
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
                    ? WorkbenchRedesignColors.bgSurface
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
            .fill(WorkbenchRedesignColors.bgSurface)
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
}
