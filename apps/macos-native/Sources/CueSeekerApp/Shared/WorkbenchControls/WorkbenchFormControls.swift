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

    var body: some View {
        WorkbenchFormFieldContainer(
            label: label,
            validationMessage: validationMessage
        ) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeControl,
                            weight: .regular
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPlaceholder)
                        .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .padding(.horizontal, WorkbenchControlMetrics.redesignFieldPaddingX - 5)
                    .padding(.vertical, 2)
                    .focused(focus)
            }
            .frame(height: WorkbenchControlMetrics.redesignFormTextAreaHeight)
            .workbenchFormFieldChrome(
                hasError: validationMessage != nil,
                isFocused: focus.wrappedValue
            )
        }
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

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeCaption,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
                    : WorkbenchRedesignColors.borderControl,
                lineWidth: 1
            )
        )
        .overlay {
            if isFocused {
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignFieldRadius
                        + WorkbenchControlMetrics.redesignFocusRingPathExpansion,
                    style: .continuous
                )
                .stroke(
                    WorkbenchRedesignColors.focusRing,
                    lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth
                )
                .padding(-WorkbenchControlMetrics.redesignFocusRingPathExpansion)
            }
        }
    }
}
