import CoreGraphics
import SwiftUI
import CueSeekerCore

enum ShioriListEditorMode {
    case newList
    case edit(ShioriList)

    var title: String {
        switch self {
        case .newList:
            "New List"
        case .edit:
            "Edit List"
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .newList:
            "Create"
        case .edit:
            "Save"
        }
    }

    var editedList: ShioriList? {
        guard case .edit(let list) = self else {
            return nil
        }
        return list
    }
}

@MainActor
final class ShioriListEditorSession: ObservableObject, Identifiable {
    let id = UUID()
    let mode: ShioriListEditorMode
    let originalName: String
    let originalDescription: String
    let originalCoverPath: String?

    @Published var name: String
    @Published var listDescription: String
    @Published var selectedCoverSource: LibraryUserCoverSource?
    @Published var cropRect = CGRect.zero
    @Published var nameValidationMessage: String?
    @Published var descriptionValidationMessage: String?
    @Published var hasAttemptedValidation = false
    @Published var isSaving = false

    init(mode: ShioriListEditorMode) {
        self.mode = mode
        let list = mode.editedList
        originalName = list?.name ?? ""
        originalDescription = list?.description ?? ""
        originalCoverPath = list?.coverPath
        name = originalName
        listDescription = originalDescription
    }

    var hasUnsavedChanges: Bool {
        name != originalName
            || listDescription != originalDescription
            || selectedCoverSource != nil
    }

    var displaysCustomCover: Bool {
        selectedCoverSource != nil || originalCoverPath != nil
    }

    func selectCoverSource(_ source: LibraryUserCoverSource) {
        selectedCoverSource = source
        cropRect = LibraryCoverCropGeometry.initialCropRect(
            imageSize: source.pixelSize
        )
    }

    func apply(validation: ShioriListValidation) {
        hasAttemptedValidation = true
        nameValidationMessage = Self.message(for: validation.nameError)
        descriptionValidationMessage = Self.message(for: validation.descriptionError)
    }

    private static func message(for error: ShioriListValidationError?) -> String? {
        switch error {
        case nil:
            nil
        case .emptyName:
            "Enter a list name"
        case .nameTooLong(_, let currentCharacters):
            "List name must be 30 characters or fewer. You entered \(currentCharacters)."
        case .descriptionTooLong(_, let currentCharacters):
            "Description must be 100 characters or fewer. You entered \(currentCharacters)."
        case .duplicateName:
            "A list with this name already exists. Choose a different name."
        }
    }
}

struct ShioriListEditorDialog: View {
    @ObservedObject var session: ShioriListEditorSession
    let onChooseImage: () -> Void
    let onValidate: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    @FocusState private var isNameFocused: Bool
    @FocusState private var isDescriptionFocused: Bool
    @State private var showsSaveChangesConfirmation = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(session.mode.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)

                HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing6) {
                    coverRegion
                        .frame(width: 380)

                    formRegion
                        .frame(width: 340)
                }

                actions
            }
            .padding(24)
            .frame(width: 792, alignment: .topLeading)
            .background(WorkbenchRedesignColors.bgSurface)

            if showsSaveChangesConfirmation {
                WorkbenchConfirmationDialog(
                    title: "Save Changes?",
                    message: "You have unsaved changes. Do you want to save them before closing?",
                    actions: [
                        WorkbenchConfirmationAction(
                            id: "discard",
                            title: "Don’t Save",
                            style: .destructive,
                            action: onClose
                        ),
                        WorkbenchConfirmationAction(
                            id: "cancel",
                            title: "Cancel",
                            style: .neutral,
                            isCancel: true,
                            action: {
                                showsSaveChangesConfirmation = false
                            }
                        ),
                        WorkbenchConfirmationAction(
                            id: "save",
                            title: "Save",
                            style: .primary,
                            isDefault: true,
                            action: {
                                showsSaveChangesConfirmation = false
                                save()
                            }
                        ),
                    ]
                )
                .zIndex(20)
            }
        }
        .onChange(of: session.name) { _ in
            revalidateIfNeeded()
        }
        .onChange(of: session.listDescription) { _ in
            revalidateIfNeeded()
        }
        .onChange(of: session.nameValidationMessage) { _ in
            focusFirstErrorIfNeeded()
        }
        .onChange(of: session.descriptionValidationMessage) { _ in
            focusFirstErrorIfNeeded()
        }
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    @ViewBuilder
    private var coverRegion: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
            if let source = session.selectedCoverSource {
                LibraryCoverCropEditor(
                    source: source,
                    cropRect: $session.cropRect
                )
                .frame(height: 250)
            } else {
                LibraryCoverFrame {
                    ShioriListCoverView(coverPath: session.originalCoverPath)
                }
            }

            WorkbenchButton(
                title: session.displaysCustomCover ? "Change Image" : "Choose Image",
                isRedesign: true,
                action: onChooseImage
            )
            .disabled(session.isSaving)

            Text(LibraryCoverEditingCopy.hint)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formRegion: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchFormTextField(
                label: "List Name",
                placeholder: "Enter a list name",
                text: $session.name,
                validationMessage: session.nameValidationMessage,
                focus: $isNameFocused
            )

            WorkbenchFormTextArea(
                label: "Description (optional)",
                placeholder: "Add a description (optional)",
                text: $session.listDescription,
                validationMessage: session.descriptionValidationMessage,
                focus: $isDescriptionFocused
            )
        }
    }

    private var actions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: "Cancel",
                isRedesign: true,
                action: cancel
            )
            .disabled(session.isSaving)
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: session.mode.primaryActionTitle,
                action: save
            )
            .disabled(session.isSaving)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func cancel() {
        if session.hasUnsavedChanges {
            showsSaveChangesConfirmation = true
        } else {
            onClose()
        }
    }

    private func save() {
        onValidate()
        guard session.nameValidationMessage == nil,
              session.descriptionValidationMessage == nil
        else {
            focusFirstErrorIfNeeded()
            return
        }
        onSave()
    }

    private func revalidateIfNeeded() {
        guard session.hasAttemptedValidation else {
            return
        }
        onValidate()
    }

    private func focusFirstErrorIfNeeded() {
        if session.nameValidationMessage != nil {
            isNameFocused = true
        } else if session.descriptionValidationMessage != nil {
            isDescriptionFocused = true
        }
    }
}
