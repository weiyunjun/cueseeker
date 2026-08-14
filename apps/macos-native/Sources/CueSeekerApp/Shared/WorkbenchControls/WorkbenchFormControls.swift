import SwiftUI

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
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
                .focused(focus)
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
            .frame(height: WorkbenchControlMetrics.redesignFormTextAreaHeight)
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

private struct WorkbenchFormFieldContainer<Content: View>: View {
    let label: String
    let validationMessage: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
            Text(label)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                    weight: .medium
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)

            Text(validationMessage ?? "\u{00A0}")
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeCaption,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.dangerText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(validationMessage == nil)

            content
        }
    }
}

private extension View {
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
