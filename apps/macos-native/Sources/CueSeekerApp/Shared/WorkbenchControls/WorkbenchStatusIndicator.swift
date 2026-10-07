import SwiftUI

/// Unified status indicator and metric label used across Workbench pages:
/// Search result count, Library folder count, File last updated status, and Excerpt overview count.
///
/// See `docs/human/requirements/20261007-UI-Workbench Status Label And Table Header Refinements.md`.
struct WorkbenchStatusIndicator: View {
    var text: String
    var icon: AppIcon? = nil
    var textColor: Color = WorkbenchRedesignColors.textSecondary
    var iconColor: Color = WorkbenchRedesignColors.textSecondary
    var iconCustomView: AnyView? = nil

    init(
        _ text: String,
        icon: AppIcon? = nil,
        textColor: Color = WorkbenchRedesignColors.textSecondary,
        iconColor: Color = WorkbenchRedesignColors.textSecondary
    ) {
        self.text = text
        self.icon = icon
        self.textColor = textColor
        self.iconColor = iconColor
        self.iconCustomView = nil
    }

    init(
        _ text: String,
        iconCustomView: AnyView,
        textColor: Color = WorkbenchRedesignColors.textSecondary
    ) {
        self.text = text
        self.icon = nil
        self.textColor = textColor
        self.iconColor = textColor
        self.iconCustomView = iconCustomView
    }

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            if let iconCustomView {
                iconCustomView
            } else if let icon {
                AppIconImage(icon, size: WorkbenchControlMetrics.redesignButtonIconSize)
                    .foregroundStyle(iconColor)
            }

            Text(text)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }
}
