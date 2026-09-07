import CoreGraphics
import SwiftUI
import CueSeekerCore

enum ShioriListEditorMode {
    case newList
    case edit(ShioriList)

    var title: String {
        switch self {
        case .newList:
            L("shiori.new_list")
        case .edit:
            L("shiori.edit_list")
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .newList:
            L("shiori.create")
        case .edit:
            L("shiori.save")
        }
    }

    var editedList: ShioriList? {
        guard case .edit(let list) = self else {
            return nil
        }
        return list
    }
}

/// A Save to, Move to or Duplicate to that the destination submenu's New List
/// item interrupted. It runs against the list this session creates.
struct ShioriListEditorPendingTransfer {
    let action: SubtitleTableRowAction
    let target: Target
    /// The surface that asked, so the result lands where that surface can show
    /// it once the editor closes.
    var report: ShioriSaveReport = .toast

    /// Move and Duplicate carry an existing Shiori; Save from the Search table
    /// has only the Cue.
    enum Target {
        case shiori(Shiori)
        case cue(Int64)
    }
}

@MainActor
final class ShioriListEditorSession: ObservableObject, Identifiable {
    let id = UUID()
    let mode: ShioriListEditorMode
    let pendingTransfer: ShioriListEditorPendingTransfer?
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

    init(
        mode: ShioriListEditorMode,
        pendingTransfer: ShioriListEditorPendingTransfer? = nil
    ) {
        self.mode = mode
        self.pendingTransfer = pendingTransfer
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
            L("shiori.validation.name_required")
        case .nameTooLong:
            L("shiori.validation.name_too_long")
        case .descriptionTooLong:
            L("shiori.validation.description_too_long")
        case .duplicateName:
            L("shiori.validation.name_taken")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WorkbenchDialogHeader(title: session.mode.title)

            HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing6) {
                coverRegion
                    .frame(width: 380)

                formRegion
                    .frame(width: WorkbenchControlMetrics.redesignDialogFormRegionWidth)
            }

            actions
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .frame(width: 792, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
        .workbenchDialogCloseButton(isDisabled: session.isSaving, onClose: onClose)
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
                LibraryCoverFrame {
                    ZStack {
                        WorkbenchRedesignColors.libraryCoverPlaceholderBg

                        LibraryCoverCropEditor(
                            source: source,
                            cropRect: $session.cropRect
                        )
                    }
                }
            } else {
                LibraryCoverChooser(
                    title: LibraryCoverEditingCopy.chooseImageActionTitle,
                    systemImage: LibraryCoverEditingCopy.editSystemImage,
                    isEnabled: !session.isSaving,
                    action: onChooseImage
                ) {
                    ShioriListCoverView(coverPath: session.originalCoverPath)
                }
            }

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
                label: L("shiori.list_name"),
                placeholder: L("shiori.list_name.placeholder"),
                text: $session.name,
                validationMessage: session.nameValidationMessage,
                focus: $isNameFocused
            )

            WorkbenchFormTextArea(
                label: L("shiori.description"),
                placeholder: L("shiori.description.placeholder"),
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
                title: L("common.cancel"),
                isRedesign: true,
                action: onClose
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
