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

struct WorkbenchSearchField: View {
    let placeholder: String
    @Binding var text: String

    init(placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        _text = text
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(WorkbenchControlColors.mutedText)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(WorkbenchControlColors.primaryText)
        }
        .padding(.horizontal, 18)
        .frame(height: WorkbenchControlMetrics.searchFieldHeight)
        .background(WorkbenchControlBackground())
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
