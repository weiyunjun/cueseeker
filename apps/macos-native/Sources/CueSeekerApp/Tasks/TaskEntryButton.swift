import SwiftUI

/// The Task panel's entry, in the top bar's trailing function region.
///
/// It is the filter button's component and states — the same Icon Button, the
/// same Open look while its surface is up — because both are a control that
/// opens one thing and stays lit while it is open. What it adds is the count
/// beside its glyph.
struct TaskEntryButton: View {
    @ObservedObject var tasks: TaskQueueStore
    /// The colors of the surface the button is drawn on; the Workbench's by
    /// default.
    var iconColor: Color? = nil
    var hoverBackground: Color = WorkbenchRedesignColors.bgHover
    var countBackground: Color = WorkbenchRedesignColors.popoverSurfaceKeycapBg
    var countHoverBackground: Color = WorkbenchRedesignColors.popoverSurfaceKeycapHoverBg
    let onOpen: () -> Void

    var body: some View {
        WorkbenchIconButton(
            icon: .listChecks,
            isRedesign: true,
            isOpen: tasks.isPanelOpen,
            hoverBackground: hoverBackground,
            iconColor: iconColor,
            count: tasks.remainingTaskCount,
            countBackground: countBackground,
            countHoverBackground: countHoverBackground,
            action: onOpen
        )
        .help(L("task.entry"))
        .accessibilityLabel(L("task.entry"))
        .accessibilityIdentifier("task-entry-button")
    }
}

/// How much is left to do: running plus queued. As tall as the glyph beside
/// it, a circle at one digit and a capsule once the number needs the width.
/// The number takes the glyph's color; the button holding it picks the
/// circle's, from its surface and whether it is lit.
struct TaskCountBadge: View {
    let count: Int
    let background: Color
    let textColor: Color

    var body: some View {
        Text("\(count)")
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeTaskCountBadge,
                weight: WorkbenchControlMetrics.redesignFontWeightTaskCountBadge
            ))
            .foregroundStyle(textColor)
            .monospacedDigit()
            .padding(
                .horizontal,
                WorkbenchControlMetrics.redesignTaskCountBadgeHorizontalPadding
            )
            .frame(
                minWidth: WorkbenchControlMetrics.redesignControlIconSize,
                minHeight: WorkbenchControlMetrics.redesignControlIconSize
            )
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
            .accessibilityIdentifier("task-count-badge")
    }
}
