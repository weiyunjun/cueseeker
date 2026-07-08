import SwiftUI

struct WorkbenchConfirmationDialog: View {
    let title: String
    let message: String
    let destructiveTitle: String
    let cancelTitle: String
    var onDestructive: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(message)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .regular))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Spacer(minLength: 0)

                    WorkbenchButton(
                        title: cancelTitle,
                        isRedesign: true,
                        action: onCancel
                    )
                    .keyboardShortcut(.defaultAction)
                    .keyboardShortcut(.cancelAction)

                    WorkbenchDestructiveButton(
                        title: destructiveTitle,
                        action: onDestructive
                    )
                }
                .padding(.top, WorkbenchControlMetrics.redesignSpacing1)
            }
            .padding(24)
            .frame(width: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(WorkbenchRedesignColors.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(WorkbenchRedesignColors.borderControl, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
        }
    }
}
