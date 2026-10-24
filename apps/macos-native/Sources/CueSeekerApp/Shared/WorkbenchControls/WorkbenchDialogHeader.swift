import SwiftUI

/// The title row every dialog opens with. The close button is not part of it:
/// it hangs off the dialog's own top-right corner instead, so its box can no
/// longer stretch this row and push the title down.
struct WorkbenchDialogHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(
                size: WorkbenchControlMetrics.redesignDialogTitleFontSize,
                weight: .semibold
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Hangs a dialog's close button off the container's top-right corner.
    /// The offsets are measured from the glyph's ink rather than the button's
    /// box, so the X lands on the same inset as the title, the body text and
    /// the buttons below it.
    /// A dialog with no Cancel button lets Escape press this one instead.
    func workbenchDialogCloseButton(
        closesOnEscape: Bool = false,
        onClose: @escaping () -> Void
    ) -> some View {
        overlay(alignment: .topTrailing) {
            WorkbenchIconButton(
                icon: .x,
                iconSize: WorkbenchControlMetrics.redesignDialogCloseIconSize,
                boxSize: WorkbenchControlMetrics.redesignDialogCloseButtonSize,
                action: onClose
            )
            .workbenchTooltip(
                scenarioID: "dialog.header.close",
                label: L("common.close"),
                shortcut: .fixed("Esc")
            )
            .keyboardShortcut(closesOnEscape ? .cancelAction : nil)
            .accessibilityLabel(L("common.close"))
            .padding(.top, WorkbenchControlMetrics.redesignDialogCloseAnchorInset)
            .padding(.trailing, WorkbenchControlMetrics.redesignDialogCloseAnchorInset)
        }
    }
}

/// Shared detail dialog shell (`L-06.8 File Detail Dialog Layout`, `L-06.11 Task Detail Dialog Layout`).
struct WorkbenchDetailDialogContainer<Content: View>: View {
    let dialogTitle: String
    let icon: AppIcon
    let headerTitle: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.workbenchDialogAvailableSize) private var availableSize
    @State private var languageRevision = 0

    var body: some View {
        let _ = languageRevision
        WorkbenchDialogColumn(
            spacing: WorkbenchControlMetrics.redesignSpacing4,
            maxHeight: availableSize.height - WorkbenchControlMetrics.redesignDialogTopPadding
        ) {
            WorkbenchDialogHeader(title: dialogTitle)
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

            WorkbenchScrollView {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                    WorkbenchDetailHeaderRow(icon: icon, title: headerTitle)
                    content()
                }
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
                .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
            }
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(closesOnEscape: true, onClose: onClose)
        .subtitleTableTextSelectionNonInteractiveRegion()
        .onReceive(NotificationCenter.default.publisher(for: .cueSeekerAppLanguageChanged)) { _ in
            languageRevision &+= 1
        }
    }
}

/// Shared 40×40 icon + title header row for detail dialogs (`--spacing-4` gap).
struct WorkbenchDetailHeaderRow: View {
    let icon: AppIcon
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchCardIcon(
                icon: icon,
                size: WorkbenchControlMetrics.redesignDetailFileIconContainerSize
            )

            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: 2 * WorkbenchControlMetrics.redesignDetailFileTitleLineHeight,
                    alignment: .leading
                )
        }
    }
}

/// Shared key-value / custom-trailing row for detail dialogs.
struct WorkbenchDetailRow<Trailing: View>: View {
    let label: String
    let isIndex: Bool
    let alignment: VerticalAlignment
    @ViewBuilder let trailing: () -> Trailing

    init(
        label: String,
        isIndex: Bool = false,
        alignment: VerticalAlignment = .top,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.label = label
        self.isIndex = isIndex
        self.alignment = alignment
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: alignment, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            Text(label)
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                .frame(
                    minWidth: isIndex
                        ? WorkbenchControlMetrics.redesignDetailIndexLabelMinWidth
                        : WorkbenchControlMetrics.redesignDetailLabelMinWidth,
                    alignment: .leading
                )

            Spacer(minLength: WorkbenchControlMetrics.redesignSpacing4)

            trailing()
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
        .padding(.vertical, WorkbenchControlMetrics.redesignSettingsRowVerticalPadding)
        .frame(minHeight: WorkbenchControlMetrics.redesignSettingsRowMinHeight)
    }
}

struct WorkbenchDetailValueText: View {
    let value: String
    let valueColor: Color

    var body: some View {
        Text(value)
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeBody))
            .monospacedDigit()
            .foregroundStyle(valueColor)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension WorkbenchDetailRow where Trailing == WorkbenchDetailValueText {
    init(
        label: String,
        value: String,
        isIndex: Bool = false,
        valueColor: Color = WorkbenchRedesignColors.textPrimary
    ) {
        self.init(label: label, isIndex: isIndex, alignment: .top) {
            WorkbenchDetailValueText(value: value, valueColor: valueColor)
        }
    }
}

typealias FileDetailRow = WorkbenchDetailRow<WorkbenchDetailValueText>

/// Shared `#1, #2...` indexed list rows for detail dialogs, showing `#1  None` when empty.
struct WorkbenchDetailIndexedRows: View {
    let values: [String]

    var body: some View {
        if values.isEmpty {
            WorkbenchDetailRow(label: "#1", value: L("file_detail.none"), isIndex: true)
        } else {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                if index > 0 {
                    SettingsRowDivider()
                }
                WorkbenchDetailRow(
                    label: "#\(index + 1)",
                    value: value,
                    isIndex: true
                )
            }
        }
    }
}

/// Shared capsule progress bar (`C-09.3 Progress Indicator / Bar`).
struct WorkbenchProgressBar: View {
    let fraction: Double

    private var clampedFraction: Double {
        max(0, min(1, fraction))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WorkbenchRedesignColors.libraryProgressTrack)

                Capsule()
                    .fill(WorkbenchRedesignColors.libraryProgressFill)
                    .frame(width: max(0, min(proxy.size.width, proxy.size.width * clampedFraction)))
            }
            .frame(height: WorkbenchControlMetrics.redesignTaskProgressBarHeight)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: WorkbenchControlMetrics.redesignTaskProgressBarHeight)
    }
}
