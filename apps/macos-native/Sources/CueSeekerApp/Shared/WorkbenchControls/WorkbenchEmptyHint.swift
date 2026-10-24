import SwiftUI

struct WorkbenchEmptyHint: View {
    let icon: AppEmptyStateIcon
    var title: String? = nil
    let message: String

    init(
        icon: AppEmptyStateIcon,
        title: String? = nil,
        message: String
    ) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: WorkbenchControlMetrics.redesignEmptyStateIconToTextGap) {
            AppEmptyStateIconView(
                icon: icon,
                size: WorkbenchControlMetrics.redesignEmptyStateIconSize
            )

            VStack(spacing: WorkbenchControlMetrics.redesignEmptyStateTitleToMessageGap) {
                if let title, !title.isEmpty {
                    Text(title)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignEmptyStateTitleFontSize,
                            weight: .semibold
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .multilineTextAlignment(.center)
                }

                Text(message)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: WorkbenchControlMetrics.redesignEmptyStateMessageMaxWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing3 * 2)
        .allowsHitTesting(false)
    }
}
