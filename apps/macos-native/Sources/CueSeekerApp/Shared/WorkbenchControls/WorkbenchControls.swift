import SwiftUI

enum WorkbenchControlMetrics {
    static let searchFieldHeight: CGFloat = 46
    static let controlHeight: CGFloat = 40
    static let cornerRadius: CGFloat = 8
    static let hairlineWidth: CGFloat = 0.5
    static let iconSize: CGFloat = 16
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
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
                .font(.system(size: 11, weight: .bold))
                .frame(width: 20, height: 20)
                .foregroundStyle(isEnabled ? Color(hex: "#667085") : Color(hex: "#98A2B3"))
                .frame(width: 32, height: 32)
                .background(
                    Group {
                        if isEnabled && isHovered {
                            RoundedRectangle(cornerRadius: 9999, style: .continuous)
                                .fill(isActiveContext ? Color(hex: "#D8E8FD") : Color(hex: "#F3F4F6"))
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
                    RoundedRectangle(cornerRadius: 9999, style: .continuous)
                        .stroke(Color(red: 59/255, green: 130/255, blue: 246/255, opacity: 0.22), lineWidth: 3)
                        .padding(-3)
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
                .foregroundStyle(isRedesign ? (isEnabled ? Color(hex: "#667085") : Color(hex: "#98A2B3")) : WorkbenchControlColors.mutedText)

            TextField(
                "",
                text: $text,
                prompt: Text(placeholder)
                    .foregroundColor(isRedesign ? Color(hex: "#98A2B3") : WorkbenchControlColors.mutedText)
            )
            .textFieldStyle(.plain)
            .font(.system(size: isRedesign ? 16 : 15, weight: .regular))
            .foregroundStyle(isRedesign ? (isEnabled ? Color(hex: "#0F172A") : Color(hex: "#98A2B3")) : WorkbenchControlColors.primaryText)
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
        .padding(.horizontal, isRedesign ? 16 : 18)
        .frame(height: isRedesign ? 48 : WorkbenchControlMetrics.searchFieldHeight)
        .background(
            RoundedRectangle(cornerRadius: isRedesign ? 9999 : WorkbenchControlMetrics.cornerRadius, style: .continuous)
                .fill(isRedesign ? (isEnabled ? Color(hex: "#FFFFFF") : Color(hex: "#F3F4F6")) : WorkbenchControlColors.surfaceFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isRedesign ? 9999 : WorkbenchControlMetrics.cornerRadius, style: .continuous)
                .strokeBorder(
                    isRedesign ? (isFocused ? Color(hex: "#3B82F6") : Color(hex: "#E5E7EB")) : WorkbenchControlColors.border,
                    lineWidth: isRedesign ? 1.0 : WorkbenchControlMetrics.hairlineWidth
                )
        )
        .overlay(
            Group {
                if isRedesign && isFocused {
                    RoundedRectangle(cornerRadius: 9999 + 3, style: .continuous)
                        .stroke(Color(red: 59/255, green: 130/255, blue: 246/255, opacity: 0.22), lineWidth: 3)
                        .padding(-3)
                }
            }
        )
    }
}

struct WorkbenchToolbarButton: View {
    let title: String
    let systemImage: String
    var showsChevron = false
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
                .font(.system(size: WorkbenchControlMetrics.iconSize, weight: .medium))

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            if showsChevron {
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WorkbenchControlColors.mutedText)
            }
        }
        .foregroundStyle(WorkbenchControlColors.primaryText)
        .padding(.horizontal, 14)
        .frame(height: WorkbenchControlMetrics.controlHeight)
        .background(WorkbenchControlBackground())
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct WorkbenchButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: WorkbenchControlMetrics.iconSize, weight: .regular))
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(WorkbenchControlColors.primaryText)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(WorkbenchControlBackground())
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WorkbenchPlainActionButton: View {
    let title: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: WorkbenchControlMetrics.iconSize, weight: .regular))

                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(WorkbenchControlColors.primaryText)
            .frame(height: WorkbenchControlMetrics.controlHeight)
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct WorkbenchFilterPanelTriggerButton: View {
    let title: String
    var detail: String? = nil
    var isEnabled: Bool = true
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
                .foregroundStyle(isEnabled ? Color(hex: "#0040FF") : Color(hex: "#98A2B3"))
                .padding(.leading, 16)
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
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isEnabled ? (isHovered ? Color(hex: "#E1EBFF") : Color(hex: "#EBF5FF")) : Color(hex: "#F3F4F6"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isEnabled ? Color(hex: "#0040FF") : Color(hex: "#E5E7EB"), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .overlay(
            Group {
                if isMainButtonFocused {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color(red: 59/255, green: 130/255, blue: 246/255, opacity: 0.22), lineWidth: 3)
                        .padding(-3)
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

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WorkbenchControlColors.mutedText)
        }
        .foregroundStyle(WorkbenchControlColors.primaryText)
        .padding(.horizontal, 12)
        .frame(height: WorkbenchControlMetrics.controlHeight)
        .background(WorkbenchControlBackground())
    }
}

struct WorkbenchTextInputField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(WorkbenchControlColors.primaryText)
            .padding(.horizontal, 12)
            .frame(height: WorkbenchControlMetrics.controlHeight)
            .background(WorkbenchControlBackground())
    }
}

struct WorkbenchReadonlyField: View {
    let title: String

    var body: some View {
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

struct WorkbenchDropdownChoice: Identifiable, Equatable {
    let id: String
    let title: String
}

struct WorkbenchInlineDropdown: View {
    let title: String
    var isOpen = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            WorkbenchSelectFieldLabel(title: title)
        }
        .buttonStyle(.plain)
        .frame(height: WorkbenchControlMetrics.controlHeight, alignment: .topLeading)
        .zIndex(isOpen ? 100 : 0)
    }
}

struct WorkbenchDropdownPanel: View {
    let choices: [WorkbenchDropdownChoice]
    let selectedID: String?
    var onSelect: (WorkbenchDropdownChoice) -> Void

    var body: some View {
        WorkbenchPopoverPanel {
            VStack(spacing: 0) {
                ForEach(choices) { choice in
                    WorkbenchPopoverRow(
                        title: choice.title,
                        isSelected: choice.id == selectedID,
                        isHighlighted: choice.id == selectedID,
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
        HStack(spacing: 12) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
            } else {
                Color.clear
                    .frame(width: 13, height: 13)
            }

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
            }

            Text(title)
                .font(.system(size: 15, weight: .regular))

            Spacer(minLength: 0)
        }
        .foregroundStyle(WorkbenchControlColors.primaryText)
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isHighlighted || isHovered {
            return WorkbenchControlColors.hoverFill
        }

        return .clear
    }
}

struct WorkbenchIconButton: View {
    let systemImage: String
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
        Image(systemName: systemImage)
            .font(.system(size: WorkbenchControlMetrics.iconSize, weight: .medium))
            .foregroundStyle(WorkbenchControlColors.primaryText)
            .frame(
                width: WorkbenchControlMetrics.controlHeight,
                height: WorkbenchControlMetrics.controlHeight
            )
            .background(WorkbenchControlBackground())
    }
}

struct WorkbenchPopoverPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(WorkbenchControlColors.surfaceFill)
                    .shadow(
                        color: Color.black.opacity(0.14),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(WorkbenchControlColors.border.opacity(0.75), lineWidth: 0.5)
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
