import SwiftUI

/// The Task panel's entry, in the top bar's trailing function region.
///
/// It is the filter button's component and states — the same Icon Button, the
/// same accent Open look while its surface is up — because both are a control
/// that opens one thing and stays lit while it is open.
struct TaskEntryButton: View {
    @ObservedObject var tasks: TaskQueueStore
    /// The colors of the surface the button is drawn on; the Workbench's by
    /// default.
    var iconColor: Color? = nil
    var hoverBackground: Color = WorkbenchRedesignColors.bgHover
    let onOpen: () -> Void

    var body: some View {
        WorkbenchIconButton(
            icon: .listChecks,
            isRedesign: true,
            isOpen: tasks.isPanelOpen,
            hoverBackground: hoverBackground,
            iconColor: iconColor,
            action: onOpen
        )
        .overlay(alignment: .bottomTrailing) {
            TaskCountBadge(count: tasks.remainingTaskCount)
        }
        .help(L("task.entry"))
        .accessibilityLabel(L("task.entry"))
        .accessibilityIdentifier("task-entry-button")
    }
}

/// How much is left to do: running plus queued. A circle at one digit, a
/// capsule once the number needs the width, and nothing at all when there is
/// nothing left — an empty queue should not leave a mark on the top bar.
struct TaskCountBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeTaskCountBadge,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.taskCountBadgeText)
                .monospacedDigit()
                .padding(
                    .horizontal,
                    WorkbenchControlMetrics.redesignTaskCountBadgeHorizontalPadding
                )
                .frame(
                    minWidth: WorkbenchControlMetrics.redesignTaskCountBadgeHeight,
                    minHeight: WorkbenchControlMetrics.redesignTaskCountBadgeHeight
                )
                .background(
                    Capsule(style: .continuous)
                        .fill(WorkbenchRedesignColors.taskCountBadgeBg)
                )
                .allowsHitTesting(false)
                .accessibilityIdentifier("task-count-badge")
        }
    }
}
