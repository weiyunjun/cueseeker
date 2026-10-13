import SwiftUI
import CueSeekerCore

@MainActor
final class WebDAVFolderDialogSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String = ""
    @Published var address: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isSubmitting: Bool = false
    var validationTask: Task<Void, Never>?

    func cancelValidation() {
        validationTask?.cancel()
        validationTask = nil
        isSubmitting = false
    }
}

struct WebDAVFolderDialog: View {
    @ObservedObject var session: WebDAVFolderDialogSession
    let onConfirm: () -> Void
    let onClose: () -> Void

    @FocusState private var isNameFocused: Bool
    @FocusState private var isAddressFocused: Bool
    @FocusState private var isUsernameFocused: Bool
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L("webdav.dialog.title"))

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                WorkbenchDialogFormTextField(
                    label: L("webdav.field.name"),
                    placeholder: "",
                    text: $session.name,
                    focus: $isNameFocused,
                    onSubmit: submitIfIdle
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("webdav-name")

                WorkbenchDialogFormTextField(
                    label: L("webdav.field.address"),
                    placeholder: "",
                    text: $session.address,
                    focus: $isAddressFocused,
                    onSubmit: submitIfIdle
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("webdav-address")

                WorkbenchDialogFormTextField(
                    label: L("webdav.field.username"),
                    placeholder: "",
                    text: $session.username,
                    focus: $isUsernameFocused,
                    onSubmit: submitIfIdle
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("webdav-username")

                WorkbenchDialogFormPasswordField(
                    label: L("webdav.field.password"),
                    placeholder: "",
                    text: $session.password,
                    focus: $isPasswordFocused,
                    onSubmit: submitIfIdle
                )
                .disabled(session.isSubmitting)
                .accessibilityIdentifier("webdav-password")
            }

            actions
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthMedium)
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: onClose)
        .onAppear {
            isNameFocused = true
        }
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    private var actions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isRedesign: true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L("webdav.add"),
                showsSpinner: session.isSubmitting,
                action: submitIfIdle
            )
            .keyboardShortcut(.defaultAction)
            .disabled(session.isSubmitting)
            .accessibilityIdentifier("webdav-add")
        }
    }

    private func submitIfIdle() {
        guard !session.isSubmitting else {
            return
        }
        onConfirm()
    }
}
