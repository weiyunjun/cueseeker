import SwiftUI

struct LibraryEditCoverDialog: View {
    @ObservedObject var session: LibraryCoverEditingSession
    let onChooseImage: () -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    @Environment(\.workbenchDialogID) private var dialogID

    var body: some View {
        WorkbenchAccessibilityReader { accessibility in
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignCoverDialogRegionGap) {
                WorkbenchDialogHeader(title: LibraryCoverEditingCopy.dialogTitle)

                coverEditor(accessibility: accessibility)

                Text(LibraryCoverEditingCopy.hint)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    Spacer(minLength: 0)

                    WorkbenchButton(
                        title: LibraryCoverEditingCopy.cancelButtonTitle,
                        isFocused: accessibility?.isDialogFocused(.editCoverCancel, dialogID: dialogID) == true,
                        action: onCancel
                    )
                    .disabled(session.isSaving)
                    .keyboardShortcut(.cancelAction)

                    WorkbenchPrimaryButton(
                        title: LibraryCoverEditingCopy.saveButtonTitle,
                        isFocused: accessibility?.isDialogFocused(.editCoverSave, dialogID: dialogID) == true,
                        action: onSave
                    )
                    .disabled(!session.canSave)
                    .workbenchTooltip(
                        scenarioID: "disabled.edit_cover.save",
                        isActive: !session.canSave,
                        label: L("tooltip.disabled.edit_cover.save")
                    )
                }
            }
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthSmall)
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: onCancel)
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    /// The cover across the content width; a chosen image is cropped in the
    /// same frame, as in the Excerpt List Editor.
    @ViewBuilder
    private func coverEditor(accessibility: WorkbenchAccessibilityCoordinator?) -> some View {
        if let source = session.selectedSource {
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
                isFocused: accessibility?.isDialogFocused(.editCoverChooseImage, dialogID: dialogID) == true,
                action: onChooseImage
            ) {
                LibraryCachedCoverImage(
                    coverPath: session.currentCoverPath,
                    coverRevision: session.currentCoverRevision
                )
            }
        }
    }
}
