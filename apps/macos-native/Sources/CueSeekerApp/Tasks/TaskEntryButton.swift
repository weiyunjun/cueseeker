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
    var openIconColor: Color? = nil
    var hoverBackground: Color = WorkbenchRedesignColors.bgHover
    var openBackground: Color? = nil
    var countBackground: Color = Color.accentColor
    var countTextColor: Color = WorkbenchRedesignColors.iconOnDark
    let onOpen: () -> Void

    var body: some View {
        WorkbenchIconButton(
            icon: .tray,
            isRedesign: true,
            isOpen: tasks.isPanelOpen,
            hoverBackground: hoverBackground,
            openBackground: openBackground,
            iconColor: iconColor,
            openIconColor: openIconColor,
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

/// A count beside an icon or a group name. A circle as wide as it is tall at
/// one digit, and a capsule with padding on either side once there are more,
/// with half-circle ends either way. The holder picks the fill and the
/// number's color.
struct TaskCountBadge: View {
    let count: Int
    let background: Color
    let textColor: Color
    /// Inside a button the count is as tall as the glyph beside it. Beside a
    /// Filter dialog group name it sits next to 14px text rather than in a
    /// button box, and the full size reads larger than the name, so it is
    /// drawn smaller.
    var isCompact: Bool = false

    var body: some View {
        let metrics = WorkbenchControlMetrics.self
        let height = isCompact
            ? metrics.redesignTaskCountBadgeCompactHeight
            : metrics.redesignControlIconSize
        let padding = isCompact
            ? metrics.redesignTaskCountBadgeCompactHorizontalPadding
            : metrics.redesignTaskCountBadgeHorizontalPadding
        Text("\(count)")
            .font(.system(
                size: isCompact ? metrics.redesignFontSizeCaption : metrics.redesignFontSizeTaskCountBadge,
                weight: metrics.redesignFontWeightTaskCountBadge
            ))
            .foregroundStyle(textColor)
            .padding(.horizontal, count < 10 ? 0 : padding)
            .frame(minWidth: height)
            .frame(height: height)
            .background(Capsule().fill(background))
            .accessibilityIdentifier("task-count-badge")
    }
}
