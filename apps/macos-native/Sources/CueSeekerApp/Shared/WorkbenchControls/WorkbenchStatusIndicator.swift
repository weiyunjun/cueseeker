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
    var isTextFocused: Bool = false
    var onTapText: (() -> Void)? = nil
    @State private var isTextHovered = false

    init(
        _ text: String,
        icon: AppIcon? = nil,
        textColor: Color = WorkbenchRedesignColors.textSecondary,
        iconColor: Color = WorkbenchRedesignColors.textSecondary,
        isTextFocused: Bool = false,
        onTapText: (() -> Void)? = nil
    ) {
        self.text = text
        self.icon = icon
        self.textColor = textColor
        self.iconColor = iconColor
        self.iconCustomView = nil
        self.isTextFocused = isTextFocused
        self.onTapText = onTapText
    }

    init(
        _ text: String,
        iconCustomView: AnyView,
        textColor: Color = WorkbenchRedesignColors.textSecondary,
        isTextFocused: Bool = false,
        onTapText: (() -> Void)? = nil
    ) {
        self.text = text
        self.icon = nil
        self.textColor = textColor
        self.iconColor = textColor
        self.iconCustomView = iconCustomView
        self.isTextFocused = isTextFocused
        self.onTapText = onTapText
    }

    init(
        text: String,
        icon: AppIcon? = nil,
        textColor: Color = WorkbenchRedesignColors.textSecondary,
        iconColor: Color = WorkbenchRedesignColors.textSecondary,
        iconCustomView: AnyView? = nil,
        isTextFocused: Bool = false,
        onTapText: (() -> Void)? = nil
    ) {
        self.text = text
        self.icon = icon
        self.textColor = textColor
        self.iconColor = iconColor
        self.iconCustomView = iconCustomView
        self.isTextFocused = isTextFocused
        self.onTapText = onTapText
    }

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            if let iconCustomView {
                iconCustomView
            } else if let icon {
                AppIconImage(icon, size: WorkbenchControlMetrics.redesignButtonIconSize)
                    .foregroundStyle(iconColor)
            }

            if let onTapText {
                Button(action: onTapText) {
                    textLabel(showsUnderline: isTextHovered)
                        .workbenchAccessibilityFocusRing(
                            isFocused: isTextFocused,
                            cornerRadius: WorkbenchControlMetrics.redesignFieldRadius
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
                .onPointerHover(showsHand: true) { isHovered in
                    isTextHovered = isHovered
                }
                .onDisappear {
                    isTextHovered = false
                }
            } else {
                textLabel(showsUnderline: false)
                    .workbenchAccessibilityFocusRing(
                        isFocused: isTextFocused,
                        cornerRadius: WorkbenchControlMetrics.redesignFieldRadius
                    )
                    .onAppear {
                        isTextHovered = false
                    }
            }
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
    }

    private func textLabel(showsUnderline: Bool) -> some View {
        Text(text)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeBody,
                weight: WorkbenchControlMetrics.redesignFontWeightControl
            ))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .overlay(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
                if showsUnderline {
                    Rectangle()
                        .fill(textColor)
                        .frame(height: WorkbenchControlMetrics.redesignInteractiveTextUnderlineThickness)
                        .alignmentGuide(.firstTextBaseline) { _ in
                            -WorkbenchControlMetrics.redesignInteractiveTextUnderlineOffset
                        }
                        .allowsHitTesting(false)
                }
            }
    }
}
