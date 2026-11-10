import AppKit
import SwiftUI

enum WorkbenchConfirmationActionStyle {
    case neutral
    case primary
    case destructive
}

struct WorkbenchConfirmationAction: Identifiable {
    let id: String
    private let titleProvider: () -> String
    let style: WorkbenchConfirmationActionStyle
    var isDefault = false
    var isCancel = false
    let action: () -> Void

    var title: String {
        titleProvider()
    }

    init(
        id: String,
        title: @autoclosure @escaping () -> String,
        style: WorkbenchConfirmationActionStyle,
        isDefault: Bool = false,
        isCancel: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.titleProvider = title
        self.style = style
        self.isDefault = isDefault
        self.isCancel = isCancel
        self.action = action
    }
}

/// One open Confirmation. It is a session like the Edit Cover and Excerpt List
/// Editor sessions so all three dialogs are presented the same way: the layer
/// that raises the confirmation writes the session, and the layer that
/// presents it owns the dimming and the input barrier.
struct WorkbenchConfirmationSession: Identifiable {
    let id = UUID()
    private let titleProvider: () -> String
    private let messageProvider: () -> String
    let actions: [WorkbenchConfirmationAction]

    var title: String {
        titleProvider()
    }

    var message: String {
        messageProvider()
    }

    init(
        title: @autoclosure @escaping () -> String,
        message: @autoclosure @escaping () -> String,
        actions: [WorkbenchConfirmationAction]
    ) {
        self.titleProvider = title
        self.messageProvider = message
        self.actions = actions
    }

    init(
        title: @autoclosure @escaping () -> String,
        message: @autoclosure @escaping () -> String,
        destructiveTitle: @autoclosure @escaping () -> String,
        cancelTitle: @autoclosure @escaping () -> String,
        onDestructive: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.init(
            title: title(),
            message: message(),
            actions: [
                WorkbenchConfirmationAction(
                    id: "cancel",
                    title: cancelTitle(),
                    style: .neutral,
                    isDefault: true,
                    isCancel: true,
                    action: onCancel
                ),
                WorkbenchConfirmationAction(
                    id: "destructive",
                    title: destructiveTitle(),
                    style: .destructive,
                    action: onDestructive
                ),
            ]
        )
    }
}

/// The main window's open Confirmation. Every confirmation goes here, raised
/// from a page or from inside the Task panel, and the dialog layer presents it
/// above whatever dialog is open, so it dims and blocks the whole window the
/// way the other dialogs do. While one is open the App does not close; see
/// `AppDelegate.applicationShouldTerminate(_:)`.
@MainActor
final class ConfirmationCenter: ObservableObject {
    @Published var session: WorkbenchConfirmationSession?
}

/// The Confirmation dialog body. It draws no scrim of its own: dimming and the
/// input barrier come from the dialog layer it is placed in.
struct WorkbenchConfirmationDialog: View {
    let session: WorkbenchConfirmationSession
    /// Closing dismisses the confirmation itself. It does not run the caller's
    /// cancel action, so a confirmation without one still closes.
    let onClose: () -> Void

    @Environment(\.workbenchAccessibility) private var workbenchAccessibility
    @Environment(\.workbenchDialogID) private var workbenchDialogID
    @State private var languageRevision = 0

    var body: some View {
        let _ = languageRevision
        WorkbenchAccessibilityReader { accessibility in
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                WorkbenchDialogHeader(title: session.title)

                WorkbenchSelectableText(
                    session.message,
                    fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular,
                    color: WorkbenchRedesignColors.textMuted,
                    lineLimit: nil,
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    Spacer(minLength: 0)

                    ForEach(session.actions) { action in
                        actionButton(
                            action,
                            isFocused: accessibility?.isDialogFocused(
                                .confirmationAction(action.id),
                                dialogID: workbenchDialogID ?? .confirmation
                            ) == true
                        )
                    }
                }
                .padding(.top, WorkbenchControlMetrics.redesignSpacing1)
            }
            .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
            .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
            .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthSmall)
            .background(WorkbenchRedesignColors.bgDialog)
            .workbenchDialogCloseButton(onClose: onClose)
            .onReceive(NotificationCenter.default.publisher(for: .cueSeekerAppLanguageChanged)) { _ in
                languageRevision &+= 1
            }
            .subtitleTableTextSelectionNonInteractiveRegion()
            .background(WindowKeyDownMonitor(handle: handleKey))
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard workbenchAccessibility == nil else {
            return false
        }
        guard event.modifierFlags
            .intersection([.command, .control, .option, .shift])
            .isEmpty
        else {
            return false
        }
        switch event.keyCode {
        case 53:
            if !event.isARepeat {
                onClose()
            }
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private func actionButton(_ action: WorkbenchConfirmationAction, isFocused: Bool) -> some View {
        switch action.style {
        case .neutral:
            WorkbenchButton(
                title: action.title,
                isFocused: isFocused,
                action: action.action
            )
        case .primary:
            WorkbenchPrimaryButton(
                title: action.title,
                isFocused: isFocused,
                action: action.action
            )
        case .destructive:
            WorkbenchDestructiveButton(
                title: action.title,
                isFocused: isFocused,
                action: action.action
            )
        }
    }
}
