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
    var countBackground: Color = WorkbenchRedesignColors.textMuted
    var countTextColor: Color = WorkbenchRedesignColors.bgSurface
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
            countTextColor: countTextColor,
            action: onOpen
        )
        .help(L("task.entry"))
        .accessibilityLabel(L("task.entry"))
        .accessibilityIdentifier("task-entry-button")
    }
}

/// A count beside an icon or a group name. As tall as the glyph beside it: a
/// circle as wide as it is tall at one digit, and a capsule with padding on
/// either side once there are more, with half-circle ends either way. The
/// holder picks the fill and the number's color.
struct TaskCountBadge: View {
    let count: Int
    let background: Color
    let textColor: Color

    var body: some View {
        let height = WorkbenchControlMetrics.redesignControlIconSize
        Text("\(count)")
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeTaskCountBadge,
                weight: WorkbenchControlMetrics.redesignFontWeightTaskCountBadge
            ))
            .foregroundStyle(textColor)
            .padding(
                .horizontal,
                count < 10 ? 0 : WorkbenchControlMetrics.redesignTaskCountBadgeHorizontalPadding
            )
            .frame(minWidth: height)
            .frame(height: height)
            .background(Capsule().fill(background))
            .accessibilityIdentifier("task-count-badge")
    }
}
