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

/// One open Confirmation. It is a session like the Edit Cover and Shiori List
/// Editor sessions so all three dialogs are presented the same way: the layer
/// that raises the confirmation writes the session, and the layer that
/// presents it owns the dimming and the input barrier.
struct WorkbenchConfirmationSession: Identifiable {
    let id = UUID()
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
}

/// The main window's open Confirmation. A confirmation raised from a page goes
/// here and the window presents it, so it dims and blocks the whole window the
/// way the other dialogs do. A confirmation raised from inside another dialog
/// is presented by that dialog instead, which is how one modal stacks over
/// another; the layer registry already reads as open in that case.
@MainActor
final class ConfirmationCenter: ObservableObject {
    @Published var session: WorkbenchConfirmationSession?
}

/// The Confirmation dialog body. It draws no scrim of its own: dimming and the
/// input barrier come from the modal presentation it is placed in.
struct WorkbenchConfirmationDialog: View {
    let session: WorkbenchConfirmationSession
    /// Closing dismisses the confirmation itself. It does not run the caller's
    /// cancel action, so a confirmation without one still closes.
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            WorkbenchDialogHeader(title: session.title, onClose: onClose)

            Text(session.message)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .regular))
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Spacer(minLength: 0)

                ForEach(session.actions) { action in
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
