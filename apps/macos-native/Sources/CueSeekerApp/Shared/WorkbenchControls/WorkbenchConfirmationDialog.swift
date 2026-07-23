import SwiftUI

enum WorkbenchConfirmationActionStyle {
    case neutral
    case primary
    case destructive
}

struct WorkbenchConfirmationAction: Identifiable {
    let id: String
    let title: String
    let style: WorkbenchConfirmationActionStyle
    var isDefault = false
    var isCancel = false
    let action: () -> Void
}

struct WorkbenchConfirmationDialog: View {
    let title: String
    let message: String
    let actions: [WorkbenchConfirmationAction]

    init(
        title: String,
        message: String,
        actions: [WorkbenchConfirmationAction]
    ) {
        self.title = title
        self.message = message
        self.actions = actions
    }

    init(
        title: String,
        message: String,
        destructiveTitle: String,
        cancelTitle: String,
        onDestructive: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            title: title,
            message: message,
            actions: [
                WorkbenchConfirmationAction(
                    id: "cancel",
                    title: cancelTitle,
                    style: .neutral,
                    isDefault: true,
                    isCancel: true,
                    action: onCancel
                ),
                WorkbenchConfirmationAction(
                    id: "destructive",
                    title: destructiveTitle,
                    style: .destructive,
                    action: onDestructive
                ),
            ]
        )
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(message)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .regular))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Spacer(minLength: 0)

                    ForEach(actions) { action in
                        actionButton(action)
                    }
                }
                .padding(.top, WorkbenchControlMetrics.redesignSpacing1)
            }
            .padding(24)
            .frame(width: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .fill(WorkbenchRedesignColors.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .strokeBorder(WorkbenchRedesignColors.borderControl, lineWidth: 1)
            )
        }
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    @ViewBuilder
    private func actionButton(_ action: WorkbenchConfirmationAction) -> some View {
        Group {
            switch action.style {
            case .neutral:
                WorkbenchButton(
                    title: action.title,
                    isRedesign: true,
                    action: action.action
                )
            case .primary:
                WorkbenchPrimaryButton(
                    title: action.title,
                    action: action.action
                )
            case .destructive:
                WorkbenchDestructiveButton(
                    title: action.title,
                    action: action.action
                )
            }
        }
        .confirmationKeyboardShortcut(
            isDefault: action.isDefault,
            isCancel: action.isCancel
        )
    }
}

private extension View {
    @ViewBuilder
    func confirmationKeyboardShortcut(
        isDefault: Bool,
        isCancel: Bool
    ) -> some View {
        if isDefault && isCancel {
            self
                .keyboardShortcut(.defaultAction)
                .keyboardShortcut(.cancelAction)
        } else if isDefault {
            self.keyboardShortcut(.defaultAction)
        } else if isCancel {
            self.keyboardShortcut(.cancelAction)
        } else {
            self
        }
    }
}
