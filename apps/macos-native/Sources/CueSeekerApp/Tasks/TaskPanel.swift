import AppKit
import SwiftUI
import CueSeekerCore

/// The Task panel.
///
/// Presented by the dialog layer at the window root, beside Edit Cover, the
/// Excerpt List Editor and Confirmation, so the dimming and the input barrier
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
        .background(WorkbenchRedesignColors.bgDialog)
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
                    TaskCurrentCard(entry: entry)
                }
            }
        case .completed:
            cardList(isEmpty: tasks.completed.isEmpty, emptyMessage: L("task.empty.completed")) {
                ForEach(tasks.completed) { record in
                    TaskHistoryCard(record: record)
                }
            }
        case .incomplete:
            cardList(isEmpty: tasks.incomplete.isEmpty, emptyMessage: L("task.empty.incomplete")) {
                ForEach(tasks.incomplete) { record in
                    TaskHistoryCard(record: record)
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
}

private struct TaskCurrentCard: View {
    let entry: TaskQueueEntry

    var body: some View {
        TaskCardContainer {
            AppIconImage(
                entry.record.icon,
                size: WorkbenchControlMetrics.redesignSizeTaskCardIcon
            )
            .foregroundStyle(WorkbenchRedesignColors.textSecondary)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                TaskCardTitleView(
                    actionPrefix: entry.record.titleActionPrefix,
                    targetName: entry.record.titleTargetName
                )

                if entry.record.state == .running {
                    TaskCurrentRunningContent(entry: entry)
                } else {
                    TaskCurrentQueuedContent(entry: entry)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TaskCurrentQueuedContent: View {
    let entry: TaskQueueEntry

    var body: some View {
        Text(queuedText)
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption, weight: .regular))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var queuedText: String {
        switch entry.record.kind {
        case .ankiExport:
            return "\(L("task.status.queued"))  \(L("task.card_count", entry.record.itemCount))"
        case .renameFolder, .renameFiles, .index, .addFolder, .removeFolder:
            return L("task.status.queued")
        }
    }
}

private struct TaskCurrentRunningContent: View {
    let entry: TaskQueueEntry

    var body: some View {
        switch entry.record.kind {
        case .ankiExport:
            TaskRunningAnkiContent(progress: entry.progress, itemCount: entry.record.itemCount)
        case .renameFolder, .renameFiles:
            TaskRunningRenameContent(progress: entry.progress)
        case .index, .addFolder:
            TaskRunningIndexContent(progress: entry.progress)
        case .removeFolder:
            Text(L("task.progress.removing"))
                .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption, weight: .regular))
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .lineLimit(1)
        }
    }
}

private struct TaskRunningAnkiContent: View {
    @ObservedObject var progress: TaskProgressModel
    let itemCount: Int

    var body: some View {
        Text(L("task.progress.exported", progress.exportedCount, itemCount))
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption, weight: .regular))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .lineLimit(1)
            .truncationMode(.middle)

        TaskProgressBarRow(fraction: fraction)
    }

    private var fraction: Double {
        guard itemCount > 0 else { return 0 }
        return min(1, Double(progress.exportedCount) / Double(itemCount))
    }
}

private struct TaskRunningRenameContent: View {
    @ObservedObject var progress: TaskProgressModel

    var body: some View {
        Text(progress.renameStage.label)
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption, weight: .regular))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .lineLimit(1)
            .truncationMode(.middle)

        TaskProgressBarRow(fraction: progress.renameStage.fraction)
    }
}

private struct TaskRunningIndexContent: View {
    @ObservedObject var progress: TaskProgressModel

    var body: some View {
        Text(progress.indexProgress.label)
            .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption, weight: .regular))
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
            .lineLimit(1)
            .truncationMode(.middle)

        TaskProgressBarRow(fraction: progress.indexProgress.fraction)
    }
}

private struct TaskProgressBarRow: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WorkbenchRedesignColors.libraryProgressTrack)

                Capsule()
                    .fill(WorkbenchRedesignColors.libraryProgressFill)
                    .frame(width: max(0, min(proxy.size.width, proxy.size.width * fraction)))
            }
            .frame(height: WorkbenchControlMetrics.redesignTaskProgressBarHeight)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: WorkbenchControlMetrics.redesignTaskCardLine3Height)
        .accessibilityIdentifier("task-progress-bar")
    }
}

private struct TaskHistoryCard: View {
    let record: TaskRecord

    var body: some View {
        TaskCardContainer {
            AppIconImage(
                record.icon,
                size: WorkbenchControlMetrics.redesignSizeTaskCardIcon
            )
            .foregroundStyle(WorkbenchRedesignColors.textSecondary)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                TaskCardTitleView(
                    actionPrefix: record.titleActionPrefix,
                    targetName: record.titleTargetName
                )

                Text(subtitleText)
                    .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption, weight: .regular))
                    .foregroundStyle(WorkbenchRedesignColors.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if record.state == .incomplete, let errorMessage = record.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: WorkbenchControlMetrics.redesignFontSizeCaption, weight: .regular))
                        .foregroundStyle(WorkbenchRedesignColors.dangerText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: WorkbenchControlMetrics.redesignTaskCardLine3Height, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var subtitleText: String {
        let time = tableSandboxExcerptDateAddedDisplayText(for: record.stateChangedAt)
        switch record.kind {
        case .ankiExport:
            return "\(L("task.card_count", record.itemCount))  \(time)"
        case .renameFolder, .index, .addFolder, .removeFolder:
            return time
        case .renameFiles:
            return "\(L("task.files_count", record.itemCount))  \(time)"
        }
    }
}

private struct TaskCardTitleView: View {
    let actionPrefix: String
    let targetName: String

    var body: some View {
        (
            Text(actionPrefix)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundColor(WorkbenchRedesignColors.textPrimary)
            +
            Text(targetName)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: .regular
                ))
                .foregroundColor(WorkbenchRedesignColors.textSecondary)
        )
        .lineLimit(1)
        .truncationMode(.middle)
    }
}

private struct TaskCardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            content()
        }
        .padding(WorkbenchControlMetrics.redesignSpacing4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgDialog)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                WorkbenchRedesignColors.borderControl,
                lineWidth: WorkbenchControlMetrics.redesignControlBorderWidth
            )
        )
    }
}

extension TaskRecord {
    var icon: AppIcon {
        switch kind {
        case .ankiExport:
            return .ankiStar
        case .renameFolder, .renameFiles:
            return .pencilSimple
        case .index:
            return .arrowClockwise
        case .addFolder:
            return .folderPlus
        case .removeFolder:
            return .minusCircle
        }
    }

    var titleActionPrefix: String {
        switch kind {
        case .ankiExport:
            return L("task.title.anki_export")
        case .renameFolder:
            return L("task.title.rename_folder")
        case .renameFiles:
            return L("task.title.rename_files")
        case .index:
            return L("task.title.index")
        case .addFolder:
            return L("task.title.add_folder")
        case .removeFolder:
            return L("task.title.remove")
        }
    }

    var titleTargetName: String {
        switch kind {
        case .ankiExport:
            return fileName
        case .renameFolder:
            if !fileName.isEmpty {
                return fileName
            }
            return URL(fileURLWithPath: newPaths.first ?? "").lastPathComponent
        case .renameFiles:
            if !fileName.isEmpty {
                return fileName
            }
            return URL(fileURLWithPath: newPaths.first ?? "").deletingPathExtension().lastPathComponent
        case .index:
            return ""
        case .addFolder, .removeFolder:
            if !fileName.isEmpty {
                return fileName
            }
            return URL(fileURLWithPath: oldPaths.first ?? "").lastPathComponent
        }
    }
}
