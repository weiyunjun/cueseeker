import SwiftUI

struct WorkbenchConfirmationDialog: View {
    let systemImage: String
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(WorkbenchRedesignColors.iconDefault)
                    .frame(width: 56, height: 56)
                    .background(WorkbenchRedesignColors.bgHover)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody, weight: .regular))
                        .foregroundStyle(WorkbenchRedesignColors.textMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                    WorkbenchButton(
                        title: confirmTitle,
                        isRedesign: true,
                        action: onConfirm
                    )

                    WorkbenchButton(
                        title: cancelTitle,
                        isRedesign: true,
                        action: onCancel
                    )
                    .keyboardShortcut(.defaultAction)
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.top, WorkbenchControlMetrics.redesignSpacing1)
            }
            .padding(24)
            .frame(width: 360)
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
