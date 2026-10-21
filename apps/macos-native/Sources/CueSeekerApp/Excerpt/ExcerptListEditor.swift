import CoreGraphics
import SwiftUI
import CueSeekerCore

enum ExcerptListEditorMode {
    case newList
    case edit(ExcerptList)

    var title: String {
        switch self {
        case .newList:
            L("excerpt.new_list")
        case .edit:
            L("excerpt.edit_list")
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .newList:
            L("excerpt.create")
        case .edit:
            L("excerpt.save")
        }
    }

    var editedList: ExcerptList? {
        guard case .edit(let list) = self else {
            return nil
        }
        return list
    }
}

/// A Save to, Move to or Duplicate to that the destination submenu's New List
/// item interrupted. It runs against the list this session creates.
struct ExcerptListEditorPendingTransfer {
    let action: SubtitleTableRowAction
    let target: Target
    /// The surface that asked, so the result lands where that surface can show
    /// it once the editor closes.
    var report: ExcerptSaveReport = .toast

    /// Move and Duplicate carry an existing Excerpt; Save from the Search table
    /// has only the Cue.
    enum Target {
        case excerpt(Excerpt)
        case cue(Int64)
    }
}

@MainActor
final class ExcerptListEditorSession: ObservableObject, Identifiable {
    let id = UUID()
    let mode: ExcerptListEditorMode
    let pendingTransfer: ExcerptListEditorPendingTransfer?
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
        mode: ExcerptListEditorMode,
        pendingTransfer: ExcerptListEditorPendingTransfer? = nil
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

    func apply(validation: ExcerptListValidation) {
        hasAttemptedValidation = true
        nameValidationMessage = Self.message(for: validation.nameError)
        descriptionValidationMessage = Self.message(for: validation.descriptionError)
    }

    private static func message(for error: ExcerptListValidationError?) -> String? {
        switch error {
        case nil:
            nil
        case .emptyName:
            L("excerpt.validation.name_required")
        case .nameTooLong:
            L("excerpt.validation.name_too_long")
        case .descriptionTooLong:
            L("excerpt.validation.description_too_long")
        case .duplicateName:
            L("excerpt.validation.name_taken")
        }
    }
}

struct ExcerptListEditorDialog: View {
    @ObservedObject var session: ExcerptListEditorSession
    let onChooseImage: () -> Void
    let onValidate: () -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    @FocusState private var isNameFocused: Bool
    @FocusState private var isDescriptionFocused: Bool
    @Environment(\.workbenchDialogAvailableSize) private var availableSize

    var body: some View {
        WorkbenchDialogColumn(
            spacing: WorkbenchControlMetrics.redesignCoverDialogRegionGap,
            maxHeight: availableSize.height
                - WorkbenchControlMetrics.redesignDialogTopPadding
                - WorkbenchControlMetrics.redesignDialogInset
        ) {
            WorkbenchDialogHeader(title: session.mode.title)
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            // The scroll view reaches the dialog's sides, so its scrollbar runs
            // in the inset rather than over the cover or the fields.
            WorkbenchScrollView {
                mainLayout {
                    coverRegion
                        .frame(width: WorkbenchControlMetrics.redesignExcerptListEditorCoverWidth)

                    formRegion
                        .frame(
                            width: isWide
                                ? WorkbenchControlMetrics.redesignExcerptListEditorWideFormWidth
                                : WorkbenchControlMetrics.redesignExcerptListEditorCoverWidth
                        )
                }
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
            }

            actions
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(
            isWide
                ? WorkbenchControlMetrics.redesignDialogWidthXLarge
                : WorkbenchControlMetrics.redesignDialogWidthSmall
        )
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: onClose)
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

    /// Two columns while the window leaves room for the x-large dialog; below
    /// that, the small dialog with the cover above the form.
    private var isWide: Bool {
        availableSize.width >= WorkbenchControlMetrics.redesignDialogWidthXLarge
    }

    /// One layout switched in place, so the fields keep their state and focus
    /// when the window crosses the width.
    private var mainLayout: AnyLayout {
        isWide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing6))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6))
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
                    icon: LibraryCoverEditingCopy.editIcon,
                    isEnabled: !session.isSaving,
                    action: onChooseImage
                ) {
                    ExcerptListCoverView(coverPath: session.originalCoverPath)
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
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing2) {
            WorkbenchFormTextField(
                label: L("excerpt.list_name"),
                placeholder: L("excerpt.list_name.placeholder"),
                text: $session.name,
                validationMessage: session.nameValidationMessage,
                focus: $isNameFocused
            )

            WorkbenchFormTextArea(
                label: L("excerpt.description"),
                placeholder: L("excerpt.description.placeholder"),
                text: $session.listDescription,
                validationMessage: session.descriptionValidationMessage,
                focus: $isDescriptionFocused,
                height: WorkbenchControlMetrics.redesignExcerptListEditorDescriptionHeight
            )
        }
    }

    private var actions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
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
