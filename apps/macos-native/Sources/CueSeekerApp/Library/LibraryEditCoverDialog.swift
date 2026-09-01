import SwiftUI

struct LibraryEditCoverDialog: View {
    @ObservedObject var session: LibraryCoverEditingSession
    let onChooseImage: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WorkbenchDialogHeader(title: LibraryCoverEditingCopy.dialogTitle)

            coverEditor

            Text(LibraryCoverEditingCopy.hint)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Spacer(minLength: 0)

                WorkbenchButton(
                    title: LibraryCoverEditingCopy.cancelButtonTitle,
                    isRedesign: true,
                    action: onCancel
                )
                .disabled(session.isSaving)
                .keyboardShortcut(.cancelAction)

                WorkbenchPrimaryButton(
                    title: LibraryCoverEditingCopy.saveButtonTitle,
                    action: onSave
                )
                .disabled(!session.canSave)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .frame(width: 760, height: 600, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
        .workbenchDialogCloseButton(isDisabled: session.isSaving, onClose: onCancel)
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    @ViewBuilder
    private var coverEditor: some View {
        if let source = session.selectedSource {
            LibraryCoverCropEditor(
                source: source,
                cropRect: $session.cropRect
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LibraryCoverChooser(
                title: LibraryCoverEditingCopy.chooseImageActionTitle,
                systemImage: LibraryCoverEditingCopy.editSystemImage,
                isEnabled: !session.isSaving,
                action: onChooseImage
            ) {
                LibraryCachedCoverImage(
                    coverPath: session.currentCoverPath,
                    coverRevision: session.currentCoverRevision
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
