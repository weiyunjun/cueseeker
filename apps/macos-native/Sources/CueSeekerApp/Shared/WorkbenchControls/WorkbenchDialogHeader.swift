import SwiftUI

/// The title row every dialog opens with. The close button is not part of it:
/// it hangs off the dialog's own top-right corner instead, so its box can no
/// longer stretch this row and push the title down.
struct WorkbenchDialogHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(
                size: WorkbenchControlMetrics.redesignDialogTitleFontSize,
                weight: .semibold
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Hangs a dialog's close button off the container's top-right corner.
    /// The offsets are measured from the glyph's ink rather than the button's
    /// box, so the X lands on the same inset as the title, the body text and
    /// the buttons below it.
    /// A dialog with no Cancel button lets Escape press this one instead.
    func workbenchDialogCloseButton(
        closesOnEscape: Bool = false,
        onClose: @escaping () -> Void
    ) -> some View {
        overlay(alignment: .topTrailing) {
            WorkbenchIconButton(
                icon: .x,
                isRedesign: true,
                iconSize: WorkbenchControlMetrics.redesignDialogCloseIconSize,
                boxSize: WorkbenchControlMetrics.redesignDialogCloseButtonSize,
                action: onClose
            )
            .workbenchTooltip(
                scenarioID: "dialog.header.close",
                label: L("common.close"),
                shortcut: .fixed("Esc")
            )
            .keyboardShortcut(closesOnEscape ? .cancelAction : nil)
            .accessibilityLabel(L("common.close"))
            .padding(.top, WorkbenchControlMetrics.redesignDialogCloseAnchorInset)
            .padding(.trailing, WorkbenchControlMetrics.redesignDialogCloseAnchorInset)
        }
    }
}
