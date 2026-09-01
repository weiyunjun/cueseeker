import AppKit
import SwiftUI
import CueSeekerCore

/// The Task panel.
///
/// Presented as a sheet from the window root, beside Edit Cover, the Shiori
/// List Editor and Confirmation, so the dimming and the input barrier come from
/// the App's one modal presentation rather than from a second one written here.
///
/// It raises its own confirmations rather than writing to the app-level holder,
/// because a sheet is presented by the surface it belongs to: a confirmation
/// asked for from inside this panel has to stack on the panel, and the window
/// root is already presenting the panel itself.
struct TaskPanel: View {

    @ObservedObject var tasks: TaskQueueStore
    // Observed so the labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @State private var pendingConfirmation: WorkbenchConfirmationSession?

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
        .sheet(item: $pendingConfirmation) { session in
            WorkbenchConfirmationDialog(
                session: session,
                onClose: { pendingConfirmation = nil }
            )
            .interfaceLayer(.dialog)
        }
    }

    private var header: some View {
        ZStack {
            WorkbenchTabs(
                items: TaskQueueTab.allCases.map {
                    .init(
                        value: $0,
                        label: $0.label,
                        accessibilityIdentifier: "task-tab-\($0.rawValue)"
                    )
                },
                selection: tasks.selectedTab
            ) { tab in
                tasks.selectedTab = tab
            }

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                WorkbenchIconButton(
                    systemImage: "xmark",
                    isRedesign: true,
                    iconSize: WorkbenchControlMetrics.redesignDialogCloseIconSize,
                    action: tasks.closePanel
                )
                // Escape closes the panel the way it closes the other dialogs,
                // through the control that closes it.
                .keyboardShortcut(.cancelAction)
                .help(L("common.close"))
                .accessibilityLabel(L("common.close"))
                .accessibilityIdentifier("task-panel-close")
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
        pendingConfirmation = WorkbenchConfirmationSession(
            title: L("task.confirm.remove.title"),
            message: L("task.confirm.remove.message", record.fileName),
            destructiveTitle: L("common.remove"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                tasks.removeCurrentTask(id: record.id)
                pendingConfirmation = nil
            },
            onCancel: {
                pendingConfirmation = nil
            }
        )
    }

    private func confirmDelete(_ record: TaskRecord) {
        pendingConfirmation = WorkbenchConfirmationSession(
            title: L("task.confirm.delete.title"),
            message: L("task.confirm.delete.message", record.fileName),
            destructiveTitle: L("shiori.delete"),
            cancelTitle: L("common.cancel"),
            onDestructive: {
                tasks.deleteRecord(id: record.id)
                pendingConfirmation = nil
            },
            onCancel: {
                pendingConfirmation = nil
            }
        )
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
