import AppKit
import SwiftUI
import CueSeekerCore

/// The Task panel.
///
/// Presented by the dialog layer at the window root, beside Edit Cover, the
/// Shiori List Editor and Confirmation, so the dimming and the input barrier
/// come from the App's one modal presentation rather than from a second one
/// written here.
///
/// Its confirmations go to the app-level holder like every page's: the dialog
/// layer stacks them on the panel.
struct TaskPanel: View {

    @ObservedObject var tasks: TaskQueueStore
    /// Observed because a confirmation open above the panel takes its Escape.
    @ObservedObject var confirmation: ConfirmationCenter
    // Observed so the labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore

    var body: some View {
        VStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: L("task.title"))
                .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)

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

            // The list reaches the dialog's sides and bottom: the scrollbar
            // runs in the inset, and the last card ends one inset above the
            // bottom edge.
            WorkbenchScrollView {
                tabContent
                    .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
                    .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
            }
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .frame(height: WorkbenchControlMetrics.redesignTaskPanelHeight)
        .background(WorkbenchRedesignColors.bgSurface)
        // Escape closes the panel through its close button, unless a
        // confirmation stands above the panel, which owns it.
        .workbenchDialogCloseButton(
            closesOnEscape: confirmation.session == nil,
            onClose: tasks.closePanel
        )
        .subtitleTableTextSelectionNonInteractiveRegion()
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

                // A running rename has no point at which stopping leaves the
                // disk and the database agreeing, so it cannot be removed.
                if !(entry.isRename && entry.record.state == .running) {
                    WorkbenchIconButton(
                        icon: .x,
                        isRedesign: true,
                        action: onRemove
                    )
                    .help(L("task.confirm.remove.title"))
                    .accessibilityLabel(L("task.confirm.remove.title"))
                    .accessibilityIdentifier("task-remove-\(entry.id)")
                }
            }

            TaskCardPathLines(record: entry.record)

            switch entry.record.kind {
            case .ankiExport:
                if entry.record.state == .running {
                    TaskProgressRow(
                        progress: entry.progress,
                        itemCount: entry.record.itemCount
                    )
                } else {
                    TaskCardDetailText(L("task.card_count", entry.record.itemCount))
                }
            case .renameFolder, .renameFiles:
                if entry.record.state == .running {
                    TaskRenameProgressRow(progress: entry.progress)
                }
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
        TaskProgressBarRow(
            text: L("task.progress.exported", progress.exportedCount, itemCount),
            fraction: fraction
        )
    }

    private var fraction: Double {
        guard itemCount > 0 else {
            return 0
        }
        return min(1, Double(progress.exportedCount) / Double(itemCount))
    }
}

/// The stage and the bar for the running rename: each stage is half.
private struct TaskRenameProgressRow: View {
    @ObservedObject var progress: TaskProgressModel

    var body: some View {
        TaskProgressBarRow(
            text: progress.renameStage.label,
            fraction: progress.renameStage.fraction
        )
    }
}

private struct TaskProgressBarRow: View {
    let text: String
    let fraction: Double

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: WorkbenchControlMetrics.redesignSpacing1
        ) {
            TaskCardDetailText(text)

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
                    icon: .trash,
                    isRedesign: true,
                    action: onDelete
                )
                .help(L("task.confirm.delete.title"))
                .accessibilityLabel(L("task.confirm.delete.title"))
                .accessibilityIdentifier("task-delete-\(record.id)")
            }

            TaskCardPathLines(record: record)

            HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                if record.kind == .ankiExport {
                    TaskCardDetailText(L("task.card_count", record.itemCount))
                }

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

/// What the task wrote or moved: the package and its folder for an export;
/// the old and the new name for a folder rename; every file's old path and
/// then every file's new path for a group rename, one per line.
private struct TaskCardPathLines: View {
    let record: TaskRecord

    var body: some View {
        switch record.kind {
        case .ankiExport:
            TaskCardDetailText(record.fileName)
            TaskCardDetailText(record.folderPath)
        case .renameFolder, .renameFiles:
            ForEach(Array(renameLines.enumerated()), id: \.offset) {
                TaskCardDetailText($0.element)
            }
        }
    }

    private var renameLines: [String] {
        let paths = record.oldPaths + record.newPaths
        guard record.kind == .renameFolder else {
            return paths
        }
        return paths.map { URL(fileURLWithPath: $0).lastPathComponent }
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
        case .renameFolder:
            L("rename.folder")
        case .renameFiles:
            L("rename.files")
        }
    }
}
