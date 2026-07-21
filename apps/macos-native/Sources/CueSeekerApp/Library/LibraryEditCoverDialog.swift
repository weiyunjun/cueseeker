import SwiftUI

struct LibraryEditCoverDialog: View {
    @ObservedObject var session: LibraryCoverEditingSession
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LibraryCoverEditingCopy.dialogTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)

            LibraryCoverCropEditor(
                source: session.source,
                cropRect: $session.cropRect
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                .disabled(session.isSaving)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 760, height: 600, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
        .subtitleTableTextSelectionNonInteractiveRegion()
    }
}
