import SwiftUI

/// The shared Dialog header: the title on the leading side and the close
/// button on the trailing side. Closing is the dialog's own action; it does not
/// depend on whether the dialog also offers Cancel.
struct WorkbenchDialogHeader: View {
    let title: String
    let onClose: () -> Void
    var isCloseDisabled = false

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            WorkbenchIconButton(
                systemImage: "xmark",
                isRedesign: true,
                action: onClose
            )
            .disabled(isCloseDisabled)
            .accessibilityLabel(L("common.close"))
        }
    }
}
