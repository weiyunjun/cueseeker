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
        VStack(spacing: WorkbenchControlMetrics.redesignEmptyStateIconToTextGap) {
            VStack(spacing: WorkbenchControlMetrics.redesignEmptyStateIconToTextGap) {
                AppEmptyStateIconView(
                    icon: icon,
                    size: WorkbenchControlMetrics.redesignEmptyStateIconSize
                )
                .allowsHitTesting(false)

                WorkbenchSelectableText(
                    message,
                    fontSize: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular,
                    color: WorkbenchRedesignColors.textMuted,
                    lineLimit: nil,
                    alignment: .center
                )
                .fixedSize(horizontal: false, vertical: true)
            }

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
    }
}
