import SwiftUI

enum WorkbenchControlMetrics {
    static let searchFieldHeight: CGFloat = 46
    static let controlHeight: CGFloat = 40
    static let cornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5
    static let iconSize: CGFloat = 16

    // ==========================================
    // Redesign Tokens (对接新的 Token 规范)
    // ==========================================
    /// --height-control / --height-filter-bar-control: 40px
    static let redesignHeight: CGFloat = 40
    /// --radius-control: 8px
    static let redesignCornerRadius: CGFloat = 8
    /// --height-field: 40px
    static let redesignFieldHeight: CGFloat = 40
    /// --height-filter-bar-control (Search box): 40px
    static let redesignSearchHeight: CGFloat = 40
    /// --radius-field: 8px
    static let redesignFieldRadius: CGFloat = 8
    /// --radius-search: 9999px
    static let redesignSearchRadius: CGFloat = 9999
    /// --size-inline-clear-button: 32px
    static let redesignInlineClearButtonSize: CGFloat = 32
    /// --padding-field-x / --padding-control-x: 16px
    static let redesignPaddingX: CGFloat = 16
    /// --size-inline-clear-symbol-font-size-macos: 11pt
    static let inlineClearSymbolFontSizeMacOS: CGFloat = 11
    /// --size-inline-clear-icon: 20px
    static let inlineClearIconSize: CGFloat = 20
    /// --focus-ring-width: 3px
    static let redesignFocusRingWidth: CGFloat = 3
    /// --radius-inline-clear-button: 9999px
    static let redesignInlineClearButtonRadius: CGFloat = 9999
    /// --size-control-icon: 20px
    static let redesignControlIconSize: CGFloat = 20
    /// --size-select-indicator-symbol-font-size-macos: 10pt
    static let redesignSelectIndicatorSymbolFontSizeMacOS: CGFloat = 10
    /// --size-select-indicator-weight-macos: .medium
    static let redesignSelectIndicatorWeightMacOS: Font.Weight = .medium
    /// --font-size-control: 16px
    static let redesignFontSizeControl: CGFloat = 16
}

enum WorkbenchControlColors {
    static let surfaceFill = Color(nsColor: .textBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
    static let primaryText = Color(nsColor: .labelColor)
    static let mutedText = Color(nsColor: .secondaryLabelColor)
    static let activeBlue = Color(red: 0.035, green: 0.412, blue: 0.957)
    static let activeBlueFill = Color(red: 0.910, green: 0.952, blue: 1.0)
    static let hoverFill = Color(nsColor: .labelColor).opacity(0.06)
}


struct WorkbenchInlineClearButton: View {
    var isEnabled: Bool = true
    var isActiveContext: Bool = false
    var action: () -> Void

    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: WorkbenchControlMetrics.inlineClearSymbolFontSizeMacOS, weight: .bold)) // --size-inline-clear-symbol-font-size-macos: 11pt
                .frame(width: WorkbenchControlMetrics.inlineClearIconSize, height: WorkbenchControlMetrics.inlineClearIconSize) // --size-inline-clear-icon: 20px
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted)
                .frame(width: WorkbenchControlMetrics.redesignInlineClearButtonSize, height: WorkbenchControlMetrics.redesignInlineClearButtonSize)
                .background(
                    Group {
                        if isEnabled && isHovered {
                            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignInlineClearButtonRadius, style: .continuous)
                                .fill(isActiveContext ? WorkbenchRedesignColors.bgActiveClearHover : WorkbenchRedesignColors.bgHover)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
        .overlay(
            Group {
                if isFocused {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignInlineClearButtonRadius, style: .continuous)
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                }
            }
        )
    }
}

struct WorkbenchSearchField: View {
    let placeholder: String
    @Binding var text: String
    var isRedesign: Bool
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    init(
        placeholder: String,
        text: Binding<String>,
        isRedesign: Bool = false,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        _text = text
        self.isRedesign = isRedesign
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: isRedesign ? 12 : 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: isRedesign ? 20 : 18, weight: .regular))
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted) : WorkbenchControlColors.mutedText)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(isRedesign ? WorkbenchRedesignColors.textPlaceholder : WorkbenchControlColors.mutedText)
            )
            .textFieldStyle(.plain)
            .font(.system(size: isRedesign ? 16 : 15, weight: .regular))
            .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textPlaceholder) : WorkbenchControlColors.primaryText)
            .focused($isFocused)
            .onSubmit {
                onSubmit?()
            }

            if isRedesign && !text.isEmpty {
                WorkbenchInlineClearButton(isEnabled: isEnabled, isActiveContext: false) {
                    text = ""
                }
            }
        }
        .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignPaddingX : 18)
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignSearchHeight : WorkbenchControlMetrics.searchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: isRedesign ? WorkbenchControlMetrics.redesignSearchRadius : WorkbenchControlMetrics.cornerRadius, style: .continuous)
                .fill(isRedesign ? (isEnabled ? WorkbenchRedesignColors.bgSurface : WorkbenchRedesignColors.bgDisabled) : WorkbenchControlColors.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isRedesign ? WorkbenchControlMetrics.redesignSearchRadius : WorkbenchControlMetrics.cornerRadius, style: .continuous)
                .strokeBorder(
                    isRedesign ? (isFocused ? WorkbenchRedesignColors.borderFocus : WorkbenchRedesignColors.borderControl) : WorkbenchControlColors.border,
                    lineWidth: isRedesign ? 1.0 : WorkbenchControlMetrics.hairlineWidth
                )
        )
        .overlay(
            Group {
                if isRedesign && isFocused {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignSearchRadius + WorkbenchControlMetrics.redesignFocusRingWidth, style: .continuous)
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                }
            }
        )
    }
}

struct WorkbenchToolbarButton: View {
    let title: String
    let systemImage: String
    var showsChevron = false
    var isRedesign: Bool = false
    var isMenuOpen: Bool = false
    var action: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .disableFocusEffect()
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: isRedesign ? 8 : 10) {
            Image(systemName: systemImage)
                .font(.system(size: isRedesign ? 16 : WorkbenchControlMetrics.iconSize, weight: isRedesign ? .semibold : .medium))
                .frame(width: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil, height: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil) // 20x20 icon slot
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted) : WorkbenchControlColors.primaryText)

            Text(title)
                .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 15, weight: isRedesign ? .medium : .medium))
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textPlaceholder) : WorkbenchControlColors.primaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if showsChevron {
                if isRedesign {
                    Spacer(minLength: 0)
                        .frame(width: 4) // spacing between text and chevron
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS, weight: WorkbenchControlMetrics.redesignSelectIndicatorWeightMacOS))
                        .frame(width: WorkbenchControlMetrics.redesignControlIconSize, height: WorkbenchControlMetrics.redesignControlIconSize) // 20x20 slot
                        .foregroundStyle(WorkbenchRedesignColors.iconMuted)
                } else {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WorkbenchControlColors.mutedText)
                }
            }
        }
        .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignPaddingX : 14)
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignHeight : WorkbenchControlMetrics.controlHeight)
        .background(
            Group {
                if isRedesign {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                        .fill(isEnabled ? ((isHovered || isMenuOpen) ? WorkbenchRedesignColors.bgHover : WorkbenchRedesignColors.bgSurface) : WorkbenchRedesignColors.bgDisabled)
                } else {
                    WorkbenchControlBackground()
                }
            }
        )
        .overlay(
            Group {
                if isRedesign {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                        .strokeBorder(isEnabled ? ((isHovered || isMenuOpen) ? WorkbenchRedesignColors.borderControlHover : WorkbenchRedesignColors.borderControl) : WorkbenchRedesignColors.borderControl, lineWidth: 1)
                }
            }
        )
        .overlay(
            Group {
                if isRedesign && isFocused && isEnabled {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth, style: .continuous)
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                }
            }
        )
        .onHover { isHovered = $0 }
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(Rectangle())
    }
}

struct WorkbenchButton: View {
    let title: String
    var systemImage: String? = nil
    var isRedesign: Bool = false
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: isRedesign ? 8 : 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: isRedesign ? 16 : WorkbenchControlMetrics.iconSize, weight: isRedesign ? .semibold : .regular))
                        .frame(width: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil, height: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil)
                        .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted) : WorkbenchControlColors.primaryText)
                }

                Text(title)
                    .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 14, weight: .medium))
                    .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textPlaceholder) : WorkbenchControlColors.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignPaddingX : 14)
            .frame(height: isRedesign ? WorkbenchControlMetrics.redesignHeight : 36)
            .background(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                            .fill(isEnabled ? (isHovered ? WorkbenchRedesignColors.bgHover : WorkbenchRedesignColors.bgSurface) : WorkbenchRedesignColors.bgDisabled)
                    } else {
                        WorkbenchControlBackground()
                    }
                }
            )
            .overlay(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                            .strokeBorder(isEnabled ? (isHovered ? WorkbenchRedesignColors.borderControlHover : WorkbenchRedesignColors.borderControl) : WorkbenchRedesignColors.borderControl, lineWidth: 1)
                    }
                }
            )
            .overlay(
                Group {
                    if isRedesign && isFocused && isEnabled {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth, style: .continuous)
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                    }
                }
            )
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
    }
}

struct WorkbenchPlainActionButton: View {
    let title: String
    let systemImage: String
    var isRedesign: Bool = false
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: isRedesign ? 8 : 10) {
                Image(systemName: systemImage)
                    .font(.system(size: isRedesign ? 16 : WorkbenchControlMetrics.iconSize, weight: isRedesign ? .semibold : .regular))
                    .frame(width: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil, height: isRedesign ? WorkbenchControlMetrics.redesignControlIconSize : nil)
                    .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted) : WorkbenchControlColors.primaryText)

                Text(title)
                    .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 15, weight: isRedesign ? .medium : .regular))
                    .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textPlaceholder) : WorkbenchControlColors.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignPaddingX : 0)
            .frame(height: isRedesign ? WorkbenchControlMetrics.redesignHeight : WorkbenchControlMetrics.controlHeight)
            .background(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                            .fill(isEnabled && isHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
                    }
                }
            )
            .overlay(
                Group {
                    if isRedesign && isFocused && isEnabled {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth, style: .continuous)
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                    }
                }
            )
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
    }
}

struct WorkbenchFilterPanelTriggerButton: View {
    let title: String
    var detail: String? = nil
    var isEnabled: Bool = true
    var isMenuOpen: Bool = false
    var onTrigger: () -> Void
    var onClear: () -> Void

    @State private var isHovered = false
    @FocusState private var isMainButtonFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTrigger) {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .semibold))
                    if let detail {
                        (Text(title).font(.system(size: 15, weight: .medium))
                         + Text(" · ").font(.system(size: 15, weight: .medium))
                         + Text(detail).font(.system(size: 15, weight: .semibold)))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    } else {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .foregroundStyle(isEnabled ? WorkbenchRedesignColors.accent : WorkbenchRedesignColors.iconMuted)
                .padding(.leading, WorkbenchControlMetrics.redesignPaddingX)
                .padding(.trailing, 8)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .focused($isMainButtonFocused)
            .disableFocusEffect()

            WorkbenchInlineClearButton(
                isEnabled: isEnabled,
                isActiveContext: true,
                action: onClear
            )
            .padding(.trailing, 8)
        }
        .frame(height: WorkbenchControlMetrics.redesignHeight)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                .fill(isEnabled ? ((isHovered || isMenuOpen) ? WorkbenchRedesignColors.bgActiveHover : WorkbenchRedesignColors.bgActive) : WorkbenchRedesignColors.bgDisabled)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                .strokeBorder(isEnabled ? WorkbenchRedesignColors.accent : WorkbenchRedesignColors.borderControl, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .overlay(
            Group {
                if isMainButtonFocused {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth, style: .continuous)
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                }
            }
        )
    }
}

struct WorkbenchFilterChip: View {
    let systemImage: String
    let title: String
    let detail: String?
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: WorkbenchControlMetrics.iconSize, weight: .semibold))

            Text(title)
                .font(.system(size: 15, weight: .regular))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if let detail {
                Text(detail)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(WorkbenchControlColors.activeBlue)
        .padding(.horizontal, 14)
        .frame(height: WorkbenchControlMetrics.controlHeight)
        .fixedSize(horizontal: true, vertical: false)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.cornerRadius,
                style: .continuous
            )
            .fill(WorkbenchControlColors.activeBlueFill)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.cornerRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchControlColors.activeBlue.opacity(0.24), lineWidth: 1)
        )
    }
}

struct WorkbenchSelectFieldLabel: View {
    let title: String
    var isRedesign: Bool = false
    var isMenuOpen: Bool = false
    var isHovered: Bool = false
    var isFocused: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: isRedesign ? 8 : 8) {
            Text(title)
                .font(.system(size: isRedesign ? WorkbenchControlMetrics.redesignFontSizeControl : 14, weight: .regular))
                .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textPlaceholder) : WorkbenchControlColors.primaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            if isRedesign {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS, weight: WorkbenchControlMetrics.redesignSelectIndicatorWeightMacOS))
                    .frame(width: WorkbenchControlMetrics.redesignControlIconSize, height: WorkbenchControlMetrics.redesignControlIconSize)
                    .foregroundStyle(isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted)
            } else {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WorkbenchControlColors.mutedText)
            }
        }
        .padding(.horizontal, isRedesign ? WorkbenchControlMetrics.redesignPaddingX : 12)
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignFieldHeight : WorkbenchControlMetrics.controlHeight)
        .background(
            Group {
                if isRedesign {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius, style: .continuous)
                        .fill(isEnabled ? ((isHovered || isMenuOpen) ? WorkbenchRedesignColors.bgHover : WorkbenchRedesignColors.bgSurface) : WorkbenchRedesignColors.bgDisabled)
                } else {
                    WorkbenchControlBackground()
                }
            }
        )
        .overlay(
            Group {
                if isRedesign {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius, style: .continuous)
                        .strokeBorder(isEnabled ? (isFocused ? WorkbenchRedesignColors.borderFocus : ((isHovered || isMenuOpen) ? WorkbenchRedesignColors.borderControlHover : WorkbenchRedesignColors.borderControl)) : WorkbenchRedesignColors.borderControl, lineWidth: 1)
                }
            }
        )
        .overlay(
            Group {
                if isRedesign && isFocused && isEnabled {
                    RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius + WorkbenchControlMetrics.redesignFocusRingWidth, style: .continuous)
                        .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                        .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                }
            }
        )
    }
}

struct WorkbenchTextInputField: View {
    let placeholder: String
    @Binding var text: String
    var isRedesign: Bool = false

    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if isRedesign {
            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: .regular))
                    .foregroundColor(isEnabled ? WorkbenchRedesignColors.textPlaceholder : WorkbenchRedesignColors.textDisabled)
            )
            .textFieldStyle(.plain)
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: .regular))
            .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textPrimary : WorkbenchRedesignColors.textDisabled)
            .focused($isFocused)
            .padding(.horizontal, WorkbenchControlMetrics.redesignPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius, style: .continuous)
                    .fill(isEnabled ? WorkbenchRedesignColors.bgSurface : WorkbenchRedesignColors.bgDisabled)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius, style: .continuous)
                    .strokeBorder(
                        isEnabled ? (isFocused ? WorkbenchRedesignColors.borderFocus : WorkbenchRedesignColors.borderControl) : WorkbenchRedesignColors.borderDisabled,
                        lineWidth: 1.0
                    )
            )
            .overlay(
                Group {
                    if isFocused && isEnabled {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius + WorkbenchControlMetrics.redesignFocusRingWidth, style: .continuous)
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                    }
                }
            )
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(WorkbenchControlColors.primaryText)
                .padding(.horizontal, 12)
                .frame(height: WorkbenchControlMetrics.controlHeight)
                .background(WorkbenchControlBackground())
        }
    }
}

struct WorkbenchReadonlyField: View {
    let title: String
    var isRedesign: Bool = false

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if isRedesign {
            HStack {
                Text(title)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeControl, weight: .regular))
                    .foregroundStyle(isEnabled ? WorkbenchRedesignColors.textReadonly : WorkbenchRedesignColors.textDisabled)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, WorkbenchControlMetrics.redesignPaddingX)
            .frame(height: WorkbenchControlMetrics.redesignFieldHeight)
            .background(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius, style: .continuous)
                    .fill(isEnabled ? WorkbenchRedesignColors.bgReadonly : WorkbenchRedesignColors.bgDisabled)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignFieldRadius, style: .continuous)
                    .strokeBorder(
                        isEnabled ? WorkbenchRedesignColors.borderReadonly : WorkbenchRedesignColors.borderDisabled,
                        lineWidth: 1.0
                    )
            )
        } else {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(WorkbenchControlColors.mutedText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(height: WorkbenchControlMetrics.controlHeight)
            .background(WorkbenchControlBackground())
        }
    }
}

struct WorkbenchDropdownChoice: Identifiable, Equatable {
    let id: String
    let title: String
}

struct WorkbenchInlineDropdown: View {
    let title: String
    var isOpen = false
    var isRedesign: Bool = false
    var action: () -> Void

    @FocusState private var isFocused: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            WorkbenchSelectFieldLabel(
                title: title,
                isRedesign: isRedesign,
                isMenuOpen: isOpen,
                isHovered: isHovered,
                isFocused: isFocused
            )
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .disableFocusEffect()
        .onHover { isHovered = $0 }
        .frame(height: isRedesign ? WorkbenchControlMetrics.redesignFieldHeight : WorkbenchControlMetrics.controlHeight, alignment: .topLeading)
        .fixedSize(horizontal: isRedesign, vertical: false)
        .zIndex(isOpen ? 100 : 0)
    }
}

struct WorkbenchDropdownPanel: View {
    let choices: [WorkbenchDropdownChoice]
    let selectedID: String?
    var isRedesign: Bool = false
    var onSelect: (WorkbenchDropdownChoice) -> Void

    var body: some View {
        WorkbenchPopoverPanel(isRedesign: isRedesign) {
            VStack(spacing: 0) {
                ForEach(choices) { choice in
                    WorkbenchPopoverRow(
                        title: choice.title,
                        isSelected: choice.id == selectedID,
                        isHighlighted: choice.id == selectedID,
                        isRedesign: isRedesign,
                        action: {
                            onSelect(choice)
                        }
                    )
                }
            }
        }
    }
}

struct WorkbenchBadge: View {
    let title: String
    var foregroundColor = WorkbenchControlColors.activeBlue
    var fillColor = WorkbenchControlColors.activeBlueFill

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

struct WorkbenchPopoverRow: View {
    let title: String
    var isSelected = false
    var isHighlighted = false
    var systemImage: String?
    var isRedesign: Bool = false
    var action: (() -> Void)? = nil
    @State private var isHovered = false

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: isRedesign ? 12 : 12) {
            if isRedesign {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: WorkbenchControlMetrics.redesignControlIconSize, height: WorkbenchControlMetrics.redesignControlIconSize)
                        .foregroundStyle(WorkbenchRedesignColors.iconDefault)
                } else {
                    Color.clear
                        .frame(width: WorkbenchControlMetrics.redesignControlIconSize, height: WorkbenchControlMetrics.redesignControlIconSize)
                }
            } else {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    Color.clear
                        .frame(width: 13, height: 13)
                }
            }

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: isRedesign ? 16 : 14, weight: isRedesign ? .medium : .medium))
                    .foregroundStyle(isRedesign ? WorkbenchRedesignColors.iconDefault : WorkbenchControlColors.primaryText)
            }

            Text(title)
                .font(.system(size: isRedesign ? 14 : 15, weight: .regular))
                .foregroundStyle(isRedesign ? WorkbenchRedesignColors.textPrimary : WorkbenchControlColors.primaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)
        }
        .foregroundStyle(isRedesign ? WorkbenchRedesignColors.textPrimary : WorkbenchControlColors.primaryText)
        .padding(.horizontal, isRedesign ? 16 : 12)
        .frame(height: isRedesign ? 40 : 40)
        .background(
            RoundedRectangle(cornerRadius: isRedesign ? 8 : 8, style: .continuous)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isRedesign {
            if isHighlighted || isHovered {
                return WorkbenchRedesignColors.bgHover
            }
            return .clear
        } else {
            if isHighlighted || isHovered {
                return WorkbenchControlColors.hoverFill
            }
            return .clear
        }
    }
}

struct WorkbenchIconButton: View {
    let systemImage: String
    var isRedesign: Bool = false
    var action: (() -> Void)? = nil

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        if let action {
            Button(action: action) {
                label
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .disableFocusEffect()
            .onHover { isHovered = $0 }
        } else {
            label
        }
    }

    private var label: some View {
        Image(systemName: systemImage)
            .font(.system(size: isRedesign ? 16 : WorkbenchControlMetrics.iconSize, weight: isRedesign ? .semibold : .medium))
            .foregroundStyle(isRedesign ? (isEnabled ? WorkbenchRedesignColors.iconDefault : WorkbenchRedesignColors.iconMuted) : WorkbenchControlColors.primaryText)
            .frame(
                width: isRedesign ? 40 : WorkbenchControlMetrics.controlHeight,
                height: isRedesign ? 40 : WorkbenchControlMetrics.controlHeight
            )
            .background(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius, style: .continuous)
                            .fill(isEnabled && isHovered ? WorkbenchRedesignColors.bgHover : Color.clear)
                    } else {
                        Color.clear
                    }
                }
            )
            .overlay(
                Group {
                    if isRedesign && isFocused && isEnabled {
                        RoundedRectangle(cornerRadius: WorkbenchControlMetrics.redesignCornerRadius + WorkbenchControlMetrics.redesignFocusRingWidth, style: .continuous)
                            .stroke(WorkbenchRedesignColors.focusRing, lineWidth: WorkbenchControlMetrics.redesignFocusRingWidth)
                            .padding(-WorkbenchControlMetrics.redesignFocusRingWidth)
                    }
                }
            )
            .contentShape(Rectangle())
    }
}

struct WorkbenchPopoverPanel<Content: View>: View {
    var isRedesign: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(isRedesign ? 4 : 8)
            .background(
                Group {
                    if isRedesign {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(WorkbenchRedesignColors.bgPopover)
                            .shadowToken(WorkbenchRedesignColors.shadowPopover)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(WorkbenchControlColors.surfaceFill)
                            .shadow(
                                color: Color.black.opacity(0.14),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: isRedesign ? 16 : 10, style: .continuous)
                    .strokeBorder(isRedesign ? WorkbenchRedesignColors.borderControl : WorkbenchControlColors.border.opacity(0.75), lineWidth: isRedesign ? 1.0 : 0.5)
            )
    }
}

struct WorkbenchControlBackground: View {
    var body: some View {
        RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.cornerRadius,
            style: .continuous
        )
        .fill(WorkbenchControlColors.surfaceFill)
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.cornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchControlColors.border,
                lineWidth: WorkbenchControlMetrics.hairlineWidth
            )
        )
    }
}

extension View {
    @ViewBuilder
    func disableFocusEffect() -> some View {
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }
}

public struct WorkbenchDropdownAnchorPreferenceKey: PreferenceKey {
    public typealias Value = [String: CGRect]
    public static var defaultValue: Value { [:] }
    public static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    public func workbenchDropdownAnchor(id: String, in spaceName: String) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: WorkbenchDropdownAnchorPreferenceKey.self,
                        value: [id: geo.frame(in: .named(spaceName))]
                    )
            }
        )
    }
}
