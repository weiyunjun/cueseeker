import SwiftUI

struct WorkbenchEmptyHint: View {
    let icon: AppEmptyStateIcon
    let message: String
    var actionTitle: String? = nil
    var actionIcon: AppIcon? = nil
    var isActionFocused: Bool = false
    var action: (() -> Void)? = nil

    init(
        icon: AppEmptyStateIcon,
        message: String,
        actionTitle: String? = nil,
        actionIcon: AppIcon? = nil,
        isActionFocused: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.message = message
        self.actionTitle = actionTitle
        self.actionIcon = actionIcon
        self.isActionFocused = isActionFocused
        self.action = action
    }

    var body: some View {
        let hasAction = actionTitle != nil && action != nil
        VStack(spacing: WorkbenchControlMetrics.redesignEmptyStateIconToTextGap) {
            VStack(spacing: WorkbenchControlMetrics.redesignEmptyStateIconToTextGap) {
                AppEmptyStateIconView(
                    icon: icon,
                    size: WorkbenchControlMetrics.redesignEmptyStateIconSize
                )

                Text(message)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .multilineTextAlignment(.center)
            }
            .allowsHitTesting(false)

            if let actionTitle, let action {
                WorkbenchButton(
                    title: actionTitle,
                    icon: actionIcon,
                    isFocused: isActionFocused,
                    action: action
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(hasAction)
    }
}
