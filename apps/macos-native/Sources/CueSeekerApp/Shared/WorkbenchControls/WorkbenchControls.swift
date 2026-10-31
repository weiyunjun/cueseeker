import SwiftUI
import AppKit

struct WorkbenchInlineClearButton: View {
    var isEnabled: Bool = true
    var isFocused: Bool = false
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            AppIconImage(.x, size: WorkbenchControlMetrics.inlineClearSymbolFontSizeMacOS) // --size-inline-clear-symbol-font-size-macos: 11pt
                .frame(width: WorkbenchControlMetrics.inlineClearIconSize, height: WorkbenchControlMetrics.inlineClearIconSize) // --size-inline-clear-icon: 16px
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textSecondary : WorkbenchRedesignColors.textDisabled)
                .frame(width: WorkbenchControlMetrics.redesignInlineClearButtonSize, height: WorkbenchControlMetrics.redesignInlineClearButtonSize)
                .background(
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignInlineClearButtonRadius, style: .continuous)
                        .fill(backgroundColor)
                )
                .workbenchAccessibilityFocusRing(
                    isFocused: isFocused,
                    cornerRadius: WorkbenchControlMetrics.redesignInlineClearButtonRadius
                )
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .disabled(!isEnabled)
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return WorkbenchRedesignColors.bgPressed
        }
        if isHovered {
            return WorkbenchRedesignColors.bgHover
        }
        return Color.clear
    }
}

struct WorkbenchSearchField: View {
    private final class WeakTextFieldBox {
        weak var field: WorkbenchNativeSingleLineTextField?
    }

    let placeholder: String
    @Binding var text: String
    var autofocus: Bool
    var trailingStatusText: String?
    var isSearchAccessibilityFocused: Bool
    var isClearAccessibilityFocused: Bool
    var onBindAccessibilityTextField: ((WorkbenchNativeSingleLineTextField?) -> Void)?
    var onSubmit: (() -> Void)?
    var onMoveUp: (() -> Bool)?
    var onMoveDown: (() -> Bool)?
    var onCancel: (() -> Bool)?

    @State private var isNativeFocused = false
    @State private var textFieldBox = WeakTextFieldBox()
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.workbenchAccessibility) private var workbenchAccessibility

    init(
        placeholder: String,
        text: Binding<String>,
        autofocus: Bool = false,
        trailingStatusText: String? = nil,
        isSearchAccessibilityFocused: Bool = false,
        isClearAccessibilityFocused: Bool = false,
        onSubmit: (() -> Void)? = nil,
        onMoveUp: (() -> Bool)? = nil,
        onMoveDown: (() -> Bool)? = nil,
        onCancel: (() -> Bool)? = nil,
        onBindAccessibilityTextField: ((WorkbenchNativeSingleLineTextField?) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        _text = text
        self.autofocus = autofocus
        self.trailingStatusText = trailingStatusText
        self.isSearchAccessibilityFocused = isSearchAccessibilityFocused
        self.isClearAccessibilityFocused = isClearAccessibilityFocused
        self.onBindAccessibilityTextField = onBindAccessibilityTextField
        self.onSubmit = onSubmit
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onCancel = onCancel
    }

    static func placeInsertionPointAtEnd(in editor: NSTextView) {
        editor.setSelectedRange(NSRange(
            location: editor.string.utf16.count,
            length: 0
        ))
    }

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            AppIconImage(.magnifyingGlass, size: WorkbenchControlMetrics.redesignControlIconSize)
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textSecondary : WorkbenchRedesignColors.textDisabled)

            WorkbenchSingleLineTextInput(
                placeholder: placeholder,
                text: Binding(
                    get: { text },
                    set: {
                        text = SearchInputNormalizer.singleLine($0)
                    }
                ),
                placeholderColor: WorkbenchRedesignColors.textPlaceholder,
                textColor: isEnabled
                    ? WorkbenchRedesignColors.textPrimary
                    : WorkbenchRedesignColors.textPlaceholder,
                fontSize: WorkbenchControlMetrics.redesignFontSizeControl,
                autofocus: autofocus,
                focus: nil,
                accessibilityLabel: placeholder,
                onFocusChange: { isNativeFocused = $0 },
                onBindTextField: { field in
                    textFieldBox.field = field
                    WorkbenchAccessibilityDebugLog.log(
                        "WorkbenchSearchField.onBindTextField field=\(ObjectIdentifier(field)) isSearchAccessibilityFocused=\(isSearchAccessibilityFocused)"
                    )
                    onBindAccessibilityTextField?(field)
                    if isSearchAccessibilityFocused {
                        field.focusFromAccessibility()
                    }
                },
                onSubmit: onSubmit,
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onCancel: {
                    if let onCancel, onCancel() {
                        return true
                    }
                    if !isSearchAccessibilityFocused, let field = textFieldBox.field, field.isCurrentlyFocused {
                        _ = field.window?.makeFirstResponder(nil)
                        return true
                    }
                    return false
                }
            )

            if let trailingStatusText,
               !trailingStatusText.isEmpty {
                Text(trailingStatusText)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: .regular
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if !text.isEmpty {
                WorkbenchInlineClearButton(
                    isEnabled: isEnabled,
                    isFocused: isClearAccessibilityFocused
                ) {
                    textFieldBox.field?.clearTextAndFocus()
                    text = ""
                }
                .workbenchTooltip(
                    scenarioID: "input.search.clear",
                    isActive: isEnabled,
                    label: L("tooltip.input.search.clear")
                )
            }
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
        .frame(height: WorkbenchControlMetrics.redesignSearchHeight)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignSearchRadius, style: .continuous)
                .fill(isEnabled ? WorkbenchRedesignColors.bgControl : WorkbenchRedesignColors.bgDisabled)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignSearchRadius, style: .continuous)
                .strokeBorder(
                    isNativeFocused ? WorkbenchRedesignColors.borderFocus : (isEnabled ? WorkbenchRedesignColors.borderControl : WorkbenchRedesignColors.borderDisabled),
                    lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
                )
                .allowsHitTesting(false)
        )
        .workbenchAccessibilityFocusRing(
            isFocused: isSearchAccessibilityFocused,
            cornerRadius: WorkbenchControlMetrics.redesignSearchRadius
        )
        .overlay(
            WorkbenchSingleLineContainerOverlay(
                isEnabled: isEnabled,
                trailingExclusionSize: !text.isEmpty
                    ? NSSize(
                        width: WorkbenchControlMetrics.redesignInlineClearButtonSize,
                        height: WorkbenchControlMetrics.redesignInlineClearButtonSize
                    )
                    : nil,
                trailingExclusionRightInset: WorkbenchControlMetrics.redesignControlPaddingX
            )
        )
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .onChange(of: isSearchAccessibilityFocused) { focused in
            WorkbenchAccessibilityDebugLog.log(
                "WorkbenchSearchField.onChange(isSearchAccessibilityFocused) -> \(focused) hasField=\(textFieldBox.field != nil)"
            )
            if focused {
                textFieldBox.field?.focusFromAccessibility()
            }
        }
        .onDisappear {
            WorkbenchAccessibilityDebugLog.log(
                "WorkbenchSearchField.onDisappear hasField=\(textFieldBox.field != nil) isCurrentActiveField=\(workbenchAccessibility?.activeSearchTextField === textFieldBox.field)"
            )
            if let field = textFieldBox.field,
               let workbenchAccessibility,
               workbenchAccessibility.activeSearchTextField !== field,
               workbenchAccessibility.activeCommandPanelSearchTextField !== field
            {
                return
            }
            onBindAccessibilityTextField?(nil)
        }
    }
}

struct WorkbenchButton: View {
    static var lastFocusedButtonTitleForTesting: String?

    var title: String? = nil
    var icon: AppIcon? = nil
    var count: Int = 0
    var countBackground: Color = WorkbenchRedesignColors.badgeNeutralBg
    var countTextColor: Color = WorkbenchRedesignColors.textSecondary
    var isOpen: Bool = false
    /// Buttons never take the keyboard focus, so the one that opens focused -
    /// Confirmation's Cancel - is told to draw its Focused state.
    var isFocused: Bool = false
    var height: CGFloat? = nil
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let _ = {
            if isFocused {
                Self.lastFocusedButtonTitleForTesting = title
                WorkbenchAccessibilityDebugLog.log(
                    "WorkbenchButton.body isFocused=true title=\(title ?? "nil") isEnabled=\(isEnabled)"
                )
            }
        }()
        Button(action: action) {
            content
                .padding(.horizontal, horizontalPadding)
                .frame(width: boxWidth, height: boxHeight)
                .background(
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
                .workbenchAccessibilityFocusRing(
                    isFocused: isFocused,
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
                )
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var content: some View {
        HStack(spacing: contentSpacing) {
            if let icon {
                AppIconImage(icon, size: iconSize)
                    .foregroundStyle(iconForegroundColor)
            }

            if let title, !title.isEmpty {
                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .foregroundStyle(textForegroundColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if count > 0 {
                TaskCountBadge(
                    count: count,
                    background: isEnabled ? countBackground : countBackground.opacity(0.35),
                    textColor: countTextColor
                )
            }
        }
    }

    private var hasTitle: Bool {
        guard let title else { return false }
        return !title.isEmpty
    }

    private var boxHeight: CGFloat {
        height ?? WorkbenchControlMetrics.redesignHeight
    }

    private var boxWidth: CGFloat? {
        if !hasTitle && count == 0 {
            return boxHeight
        }
        return nil
    }

    private var horizontalPadding: CGFloat {
        if !hasTitle && count == 0 {
            return 0
        }
        if !hasTitle && count > 0 {
            return (boxHeight - WorkbenchControlMetrics.redesignControlIconSize) / 2
        }
        return WorkbenchControlMetrics.redesignControlPaddingX
    }

    private var contentSpacing: CGFloat {
        if !hasTitle && count > 0 {
            return WorkbenchControlMetrics.redesignTaskCountBadgeGap
        }
        return WorkbenchControlMetrics.redesignSpacing2
    }

    private var iconSize: CGFloat {
        hasTitle ? WorkbenchControlMetrics.redesignButtonIconSize : WorkbenchControlMetrics.redesignControlIconSize
    }

    private var iconForegroundColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.textDisabled
        }
        return WorkbenchRedesignColors.textSecondary
    }

    private var textForegroundColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.textDisabled
        }
        return WorkbenchRedesignColors.textSecondary
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.bgDisabled
        }
        if isPressed {
            return WorkbenchRedesignColors.bgPressed
        }
        if isOpen || isHovered {
            return WorkbenchRedesignColors.bgHover
        }
        return WorkbenchRedesignColors.bgControl
    }

    private var borderColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.borderDisabled
        }
        if isPressed || isOpen || isHovered {
            return WorkbenchRedesignColors.borderControlHover
        }
        return WorkbenchRedesignColors.borderControl
    }
}

struct WorkbenchPrimaryButton: View {
    let title: String
    var icon: AppIcon? = nil
    var iconWeight: AppIconWeight? = nil
    /// A spinner in the icon's place, while the button waits for what its
    /// title needs.
    var showsSpinner: Bool = false
    var isFocused: Bool = false
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                if showsSpinner {
                    WorkbenchSpinner()
                } else if let icon {
                    AppIconImage(
                        icon,
                        size: WorkbenchControlMetrics.redesignButtonIconSize,
                        weight: iconWeight
                    )
                }

                Text(title)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeControl,
                        weight: WorkbenchControlMetrics.redesignFontWeightControl
                    ))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(
                isEnabled
                    ? WorkbenchRedesignColors.primaryButtonText
                    : WorkbenchRedesignColors.textDisabled
            )
            .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignHeight)
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                    style: .continuous
                )
                .fill(backgroundColor)
            )
            .workbenchAccessibilityFocusRing(
                isFocused: isFocused,
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
            )
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.bgDisabled
        }
        if isPressed {
            return WorkbenchRedesignColors.primaryButtonBgPressed
        }
        if isHovered {
            return WorkbenchRedesignColors.primaryButtonBgHover
        }
        return WorkbenchRedesignColors.primaryButtonBg
    }
}

struct WorkbenchDestructiveButton: View {
    let title: String
    var icon: AppIcon? = nil
    var isFocused: Bool = false
    var action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                if let icon {
                    AppIconImage(icon, size: WorkbenchControlMetrics.redesignButtonIconSize)
                        .foregroundStyle(isEnabled ? WorkbenchRedesignColors.dangerText : WorkbenchRedesignColors.textDisabled)
                }

                Text(title)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: WorkbenchControlMetrics.redesignFontWeightControl))
                    .foregroundStyle(isEnabled ? WorkbenchRedesignColors.dangerText : WorkbenchRedesignColors.textDisabled)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignControlPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignHeight)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .workbenchAccessibilityFocusRing(
                isFocused: isFocused,
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius
            )
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
        .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
        .focusable(false)
        .onPointerHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.bgDisabled
        }
        if isPressed {
            return WorkbenchRedesignColors.dangerBgPressed
        }
        if isHovered {
            return WorkbenchRedesignColors.dangerBgHover
        }
        return WorkbenchRedesignColors.bgControl
    }

    private var borderColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.borderDisabled
        }
        return (isPressed || isHovered)
            ? WorkbenchRedesignColors.borderControlHover
            : WorkbenchRedesignColors.borderControl
    }
}

struct WorkbenchBadge: View {
    let title: String
    let foregroundColor: Color
    let fillColor: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fillColor)
            )
    }
}

struct WorkbenchIconButton: View {
    static var lastFocusedIconForTesting: AppIcon?

    let icon: AppIcon
    var iconWeight: AppIconWeight? = nil
    /// The button stays lit for as long as the menu or panel it hangs off is
    /// open, and for as long as the mode it switches on is on. Lit looks the
    /// same as hover, the way a shortcut button does.
    var isOpen: Bool = false
    var isFocused: Bool = false
    var isPlayerChrome: Bool = false
    /// Default resting background when not hovered, pressed, or open.
    var defaultBackground: Color = Color.clear
    /// Hover is read against the surface the button sits on, so a button drawn
    /// on another surface passes that surface's own step; the Workbench
    /// surface's is the default.
    var hoverBackground: Color = WorkbenchRedesignColors.bgHover
    /// Pressed advances one step beyond hover on the surface the button sits on.
    var pressedBackground: Color = WorkbenchRedesignColors.bgPressed
    /// Open uses a translucent accent tint background by default, distinguishing
    /// the active state from hover. Surfaces like the player top bar pass their
    /// own open background step.
    var openBackground: Color? = nil
    /// The icon is read against the surface too: on the video page it takes
    /// the player's text color, because the Workbench's secondary text is dark
    /// on a dark video in Light appearance.
    var iconColor: Color? = nil
    /// Open uses the dynamic accent icon color by default, distinguishing
    /// the active state from hover. Surfaces like the player top bar can pass
    /// their own open icon color step if needed.
    var openIconColor: Color? = nil
    /// Input is blocked while a window or video size transition runs. The
    /// freeze is not a disabled state, so the button keeps the look it had
    /// before the transition started and nothing about it changes on screen.
    var isFrozen: Bool = false
    /// Dialog close buttons carry a smaller glyph than the rest of the icon
    /// buttons; everything else keeps the shared control icon size.
    var iconSize: CGFloat? = nil
    /// Dialog close buttons also carry a smaller box, so their hover block stays
    /// in proportion to the smaller glyph; everything else keeps the shared one.
    var boxSize: CGFloat? = nil
    /// The Task entry's or the Filter trigger's count, drawn beside the glyph
    /// inside the button, so hover and Open cover it and a click on it is a
    /// click on the button. At zero nothing is drawn and the box stays square.
    var count: Int = 0
    /// The count badge is filled with the accent color with white text for clear
    /// contrast across surfaces. A disabled button greys the count with its glyph.
    var countBackground: Color = WorkbenchRedesignColors.badgeNeutralBg
    var countTextColor: Color = WorkbenchRedesignColors.textSecondary
    var onHoverChange: ((Bool) -> Void)? = nil
    var action: (() -> Void)? = nil

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        let _ = {
            if isFocused {
                Self.lastFocusedIconForTesting = icon
            }
        }()
        Group {
            if let action {
                Button(action: action) {
                    label
                }
                .buttonStyle(PressableButtonStyle(isPressed: $isPressed, isHovered: $isHovered))
                .disabled(isFrozen)
                .focusable(false)
                .subtitleTableTextSelectionInteractiveRegion(isActive: isEnabled)
                .onPointerHover { hovered in
                    isHovered = hovered
                    onHoverChange?(hovered)
                }
            } else {
                label
            }
        }
    }

    private var label: some View {
        Group {
            if count > 0 {
                HStack(spacing: WorkbenchControlMetrics.redesignTaskCountBadgeGap) {
                    glyph
                    TaskCountBadge(
                        count: count,
                        background: isEnabled ? countBackground : countBackground.opacity(0.35),
                        textColor: countTextColor
                    )
                }
                // The count ends as far from the button's edge as the glyph
                // sits from its top.
                .padding(.horizontal, (boxLength - glyphLength) / 2)
                .frame(height: boxLength)
            } else {
                glyph
                    .frame(width: boxLength, height: boxLength)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                .fill(redesignBackgroundColor)
        )
        .workbenchAccessibilityFocusRing(
            isFocused: isFocused,
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            isPlayerChrome: isPlayerChrome
        )
        .contentShape(Rectangle())
    }

    private var glyph: some View {
        AppIconImage(icon, size: glyphLength, weight: iconWeight)
            .foregroundStyle(redesignIconColor)
    }

    private var glyphLength: CGFloat {
        iconSize ?? WorkbenchControlMetrics.redesignControlIconSize
    }

    private var boxLength: CGFloat {
        boxSize ?? WorkbenchControlMetrics.redesignIconButtonSize
    }

    var redesignIconColor: Color {
        guard isEnabled else {
            return WorkbenchRedesignColors.textDisabled
        }
        if isOpen {
            return openIconColor ?? iconColor ?? WorkbenchRedesignColors.textSecondary
        }
        return iconColor ?? WorkbenchRedesignColors.textSecondary
    }

    private var redesignBackgroundColor: Color {
        guard isEnabled else {
            return Color.clear
        }
        if isPressed {
            return pressedBackground
        }
        if isOpen {
            return openBackground ?? hoverBackground
        }
        if isHovered {
            return hoverBackground
        }
        return defaultBackground
    }
}

/// Toast and Playback Feedback both put the icon in its own column and wrap the
/// message beside it. The icon belongs to the first line, not to the block: on
/// the block's centre it would float into the gap between lines as soon as a
/// message wraps.
extension VerticalAlignment {
    private enum FeedbackFirstLineCenter: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
            dimensions[VerticalAlignment.center]
        }
    }

    static let feedbackFirstLineCenter = VerticalAlignment(FeedbackFirstLineCenter.self)
}

struct WorkbenchCardIcon: View {
    let icon: AppIcon
    var size: CGFloat = WorkbenchControlMetrics.redesignCardIconContainerSize

    var body: some View {
        AppAccentDuotoneIconView(icon: icon, size: size)
            .frame(width: size, height: size)
    }
}
