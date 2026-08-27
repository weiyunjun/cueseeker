import AppKit
import SwiftUI
import CueSeekerCore

enum TaskPanelMotion {
    /// The curve the Design System already uses for a surface arriving and
    /// leaving. The close is a shrink back into the entry button, so the panel
    /// reads as going back to where it came from rather than blinking out.
    static let collapse = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.20)
    /// How small the panel gets before it disappears. Not zero: a hair of the
    /// surface is still on screen when the opacity finishes, which is what
    /// makes the movement read as travel rather than a scale to nothing.
    static let collapsedScale: CGFloat = 0.02
}

/// The Task panel and the dim behind it.
///
/// It is drawn in the window rather than presented as a sheet, which the three
/// other dialogs are. A sheet is animated by macOS and always leaves the same
/// way, and this panel has to collapse back into the button that opened it. So
/// it paints the dim the sheet would have given it, and swallows the input the
/// sheet would have blocked; both cover the whole window because the host is
/// mounted at the window root, which is the part the old page-level
/// confirmation scrim got wrong.
struct TaskPanelHost: View {
    @ObservedObject var tasks: TaskQueueStore
    let confirmation: ConfirmationCenter
    /// The entry button, so the panel knows what to collapse into.
    let entryAnchor: MenuAnchorHandle

    @State private var hostAnchor = MenuAnchorHandle()
    @State private var collapseAnchor = UnitPoint.center

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if tasks.isPanelOpen {
                    TaskPanelScrim()
                        .ignoresSafeArea()
                        .transition(.opacity)

                    TaskPanel(
                        tasks: tasks,
                        confirmation: confirmation
                    )
                    .transition(
                        .scale(
                            scale: TaskPanelMotion.collapsedScale,
                            anchor: collapseAnchor
                        )
                        .combined(with: .opacity)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(TaskPanelMotion.collapse, value: tasks.isPanelOpen)
            .background(MenuAnchorProbe(handle: hostAnchor))
            .onChange(of: geometry.size) { _ in
                updateCollapseAnchor(hostSize: geometry.size)
            }
            .onChange(of: tasks.isPanelOpen) { isOpen in
                guard isOpen else {
                    return
                }
                updateCollapseAnchor(hostSize: geometry.size)
            }
        }
        .allowsHitTesting(tasks.isPanelOpen)
        .interfaceLayer(.taskPanel)
    }

    /// Turns the entry button's position into the point the panel keeps still
    /// while it scales. Scaling toward a point outside the panel is what walks
    /// it across the window, so the unit point is deliberately not clamped.
    private func updateCollapseAnchor(hostSize: CGSize) {
        guard let buttonFrame = entryAnchor.frame(in: hostAnchor) else {
            collapseAnchor = .center
            return
        }

        let panelWidth = WorkbenchControlMetrics.redesignTaskPanelWidth
        let panelHeight = WorkbenchControlMetrics.redesignTaskPanelHeight
        let panelOrigin = CGPoint(
            x: (hostSize.width - panelWidth) / 2,
            y: (hostSize.height - panelHeight) / 2
        )
        collapseAnchor = UnitPoint(
            x: (buttonFrame.midX - panelOrigin.x) / panelWidth,
            y: (buttonFrame.midY - panelOrigin.y) / panelHeight
        )
    }
}

private struct TaskPanel: View {
    @ObservedObject var tasks: TaskQueueStore
    let confirmation: ConfirmationCenter
    // Observed so the labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    var body: some View {
        VStack(spacing: 0) {
            header

            WorkbenchScrollView {
                tabContent
                    .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
                    .padding(.bottom, WorkbenchControlMetrics.redesignSpacing4)
            }
        }
        .frame(
            width: WorkbenchControlMetrics.redesignTaskPanelWidth,
            height: WorkbenchControlMetrics.redesignTaskPanelHeight
        )
        // The shadow belongs to the panel's shape, not to the panel. Applied
        // to the whole surface it would be cast by every leaf inside it —
        // haloed text — and would rasterize the scroll view's AppKit layer out
        // of the background it is supposed to sit on.
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgPopover)
            .shadowToken(WorkbenchRedesignColors.shadowPopover)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchRedesignColors.borderMuted, lineWidth: 1)
        )
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    private var header: some View {
        ZStack {
            TaskPanelTabBar(
                selectedTab: $tasks.selectedTab
            )

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                WorkbenchIconButton(
                    systemImage: "minus",
                    isRedesign: true,
                    action: tasks.closePanel
                )
                .help(L("task.minimize"))
                .accessibilityLabel(L("task.minimize"))
                .accessibilityIdentifier("task-panel-minimize")
            }
        }
        .padding(.horizontal, WorkbenchControlMetrics.redesignSpacing4)
        .frame(height: PlaybackOverlayMetrics.tabBarHeight)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tasks.selectedTab {
        case .current:
            cardList(isEmpty: tasks.current.isEmpty, emptyMessage: L("task.empty.current")) {
                ForEach(tasks.current) { entry in
                    TaskCurrentCard(
                        entry: entry,
                        onRemove: { confirmRemove(entry.record) }
                    )
                }
            }
        case .completed:
            cardList(isEmpty: tasks.completed.isEmpty, emptyMessage: L("task.empty.completed")) {
                ForEach(tasks.completed) { record in
                    TaskHistoryCard(
                        record: record,
                        onDelete: { confirmDelete(record) }
                    )
                }
            }
        case .incomplete:
            cardList(isEmpty: tasks.incomplete.isEmpty, emptyMessage: L("task.empty.incomplete")) {
                ForEach(tasks.incomplete) { record in
                    TaskHistoryCard(
                        record: record,
                        onDelete: { confirmDelete(record) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func cardList<Content: View>(
        isEmpty: Bool,
        emptyMessage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isEmpty {
            WorkbenchEmptyHint(message: emptyMessage)
                .frame(minHeight: WorkbenchControlMetrics.redesignTaskPanelHeight / 2)
        } else {
            LazyVStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
                content()
            }
        }
    }

    private func confirmRemove(_ record: TaskRecord) {
        confirmation.session = WorkbenchConfirmationSession(
            title: L("task.confirm.remove.title"),
            message: L("task.confirm.remove.message", record.fileName),
            destructiveTitle: L("common.remove"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                tasks.removeCurrentTask(id: record.id)
                confirmation.session = nil
            },
            onCancel: {
                confirmation.session = nil
            }
        )
    }

    private func confirmDelete(_ record: TaskRecord) {
        confirmation.session = WorkbenchConfirmationSession(
            title: L("task.confirm.delete.title"),
            message: L("task.confirm.delete.message", record.fileName),
            destructiveTitle: L("shiori.delete"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                tasks.deleteRecord(id: record.id)
                confirmation.session = nil
            },
            onCancel: {
                confirmation.session = nil
            }
        )
    }
}

/// The panel's three tabs. Same shape as the Playback Overlay's Current /
/// Playlist tabs — label over a selection indicator — in the workbench's own
/// text and accent colours.
private struct TaskPanelTabBar: View {
    @Binding var selectedTab: TaskQueueTab

    var body: some View {
        HStack(spacing: PlaybackOverlayMetrics.tabGap) {
            ForEach(TaskQueueTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: PlaybackOverlayMetrics.tabIndicatorGap) {
                        Text(tab.label)
                            .font(.system(
                                size: PlaybackOverlayMetrics.tabFontSize,
                                weight: selectedTab == tab ? .semibold : .regular
                            ))
                            .lineLimit(1)

                        Capsule()
                            .fill(WorkbenchRedesignColors.accent)
                            .frame(
                                width: PlaybackOverlayMetrics.tabIndicatorWidth,
                                height: PlaybackOverlayMetrics.tabIndicatorHeight
                            )
                            .opacity(selectedTab == tab ? 1 : 0)
                    }
                    .foregroundStyle(
                        selectedTab == tab
                            ? WorkbenchRedesignColors.textPrimary
                            : WorkbenchRedesignColors.textMuted
                    )
                    .padding(.horizontal, PlaybackOverlayMetrics.tabHorizontalPadding)
                    .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
                .accessibilityLabel(tab.label)
                .accessibilityIdentifier("task-tab-\(tab.rawValue)")
            }
        }
    }
}

private struct TaskCurrentCard: View {
    let entry: TaskQueueEntry
    let onRemove: () -> Void

    var body: some View {
        TaskCardContainer {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                WorkbenchBadge(
                    title: statusTitle,
                    foregroundColor: statusForeground,
                    fillColor: statusFill
                )

                Text(entry.record.kind.taskName)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .semibold
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                WorkbenchIconButton(
                    systemImage: "xmark",
                    isRedesign: true,
                    action: onRemove
                )
                .help(L("task.confirm.remove.title"))
                .accessibilityLabel(L("task.confirm.remove.title"))
                .accessibilityIdentifier("task-remove-\(entry.id)")
            }

            TaskCardDetailText(entry.record.fileName)
            TaskCardDetailText(entry.record.folderPath)

            if entry.record.state == .running {
                TaskProgressRow(
                    progress: entry.progress,
                    itemCount: entry.record.itemCount
                )
            } else {
                TaskCardDetailText(L("task.card_count", entry.record.itemCount))
            }
        }
    }

    private var statusTitle: String {
        entry.record.state == .running
            ? L("task.status.in_progress")
            : L("task.status.queued")
    }

    private var statusForeground: Color {
        entry.record.state == .running
            ? WorkbenchRedesignColors.watchStatusWatchingText
            : WorkbenchRedesignColors.watchStatusUnwatchedText
    }

    private var statusFill: Color {
        entry.record.state == .running
            ? WorkbenchRedesignColors.watchStatusWatchingBg
            : WorkbenchRedesignColors.watchStatusUnwatchedBg
    }
}

/// The count and the bar for the running task.
///
/// It is the only thing that observes the progress object, so a card moving
/// from its ninth cue to its tenth re-reads these two lines and nothing else —
/// not the card around it, not the other cards, not the tabs.
private struct TaskProgressRow: View {
    @ObservedObject var progress: TaskProgressModel
    let itemCount: Int

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing1
        ) {
            TaskCardDetailText(
                L("task.progress.exported", progress.exportedCount, itemCount)
            )

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WorkbenchRedesignColors.libraryProgressTrack)

                    Capsule()
                        .fill(WorkbenchRedesignColors.libraryProgressFill)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: WorkbenchControlMetrics.redesignTaskProgressBarHeight)
            .accessibilityIdentifier("task-progress-bar")
        }
    }

    private var fraction: Double {
        guard itemCount > 0 else {
            return 0
        }
        return min(1, Double(progress.exportedCount) / Double(itemCount))
    }
}

private struct TaskHistoryCard: View {
    let record: TaskRecord
    let onDelete: () -> Void

    var body: some View {
        TaskCardContainer {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                Text(record.kind.taskName)
                    .font(.system(
                        size: WorkbenchControlMetrics.redesignFontSizeBody,
                        weight: .semibold
                    ))
                    .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                WorkbenchIconButton(
                    systemImage: "trash",
                    isRedesign: true,
                    action: onDelete
                )
                .help(L("task.confirm.delete.title"))
                .accessibilityLabel(L("task.confirm.delete.title"))
                .accessibilityIdentifier("task-delete-\(record.id)")
            }

            TaskCardDetailText(record.fileName)
            TaskCardDetailText(record.folderPath)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                TaskCardDetailText(L("task.card_count", record.itemCount))

                Spacer(minLength: 0)

                TaskCardDetailText(
                    tableSandboxShioriDateAddedDisplayText(for: record.stateChangedAt)
                )
            }

            if let errorMessage = record.errorMessage {
                Text(errorMessage)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption))
                    .foregroundStyle(WorkbenchRedesignColors.dangerText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct TaskCardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing1
        ) {
            content()
        }
        .padding(WorkbenchControlMetrics.redesignSpacing3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgSurface)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchRedesignColors.borderControl, lineWidth: 1)
        )
    }
}

/// A card's secondary line. It sizes to its own text and does not claim the
/// row: a detail that decided to fill would take half the width from the
/// detail beside it and leave the spacer between them nothing to push with,
/// which is what kept the completion time off the card's trailing edge.
private struct TaskCardDetailText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

extension TaskRecordKind {
    var taskName: String {
        switch self {
        case .ankiExport:
            L("task.name.anki_export")
        }
    }
}

/// The dim behind the panel, and the barrier the panel needs because it is not
/// a sheet. Every button, wheel and click that lands outside the panel stops
/// here, so nothing underneath lights up or acts while the panel is open.
private struct TaskPanelScrim: NSViewRepresentable {
    func makeNSView(context _: Context) -> ScrimView {
        let view = ScrimView()
        view.wantsLayer = true
        view.updateBackgroundColor()
        return view
    }

    func updateNSView(_ nsView: ScrimView, context _: Context) {
        nsView.updateBackgroundColor()
    }

    final class ScrimView: NSView {
        override var isOpaque: Bool { false }
        override var acceptsFirstResponder: Bool { false }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            updateBackgroundColor()
        }

        func updateBackgroundColor() {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = WorkbenchRedesignColors.NS.dialogScrim
                    .usingColorSpace(.sRGB)?
                    .cgColor
            }
        }

        override func mouseDown(with event: NSEvent) {}
        override func rightMouseDown(with event: NSEvent) {}
        override func otherMouseDown(with event: NSEvent) {}
        override func mouseUp(with event: NSEvent) {}
        override func rightMouseUp(with event: NSEvent) {}
        override func otherMouseUp(with event: NSEvent) {}
        override func mouseDragged(with event: NSEvent) {}
        override func scrollWheel(with event: NSEvent) {}
    }
}
