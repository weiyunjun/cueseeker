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
    static let taskCardCoordinateSpaceName = "TaskPanel.cardCoordinateSpace"

    @ObservedObject var tasks: TaskQueueStore
    /// Observed because a confirmation open above the panel takes its Escape.
    @ObservedObject var confirmation: ConfirmationCenter
    // Observed so the labels below are re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var appState: AppCoordinator

    @State private var activeMenu: WorkbenchCardMenuState?
    @StateObject private var menuHighlight = MenuHighlightModel()
    @State private var viewportSize: CGSize = .zero

    var body: some View {
        VStack(spacing: WorkbenchControlMetrics.redesignSpacing4) {
            headerRow

            // The list reaches the dialog's sides and bottom: the scrollbar
            // runs in the inset, and the last card ends one inset above the
            // bottom edge.
            GeometryReader { geometry in
                WorkbenchScrollView {
                    tabContent
                        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
                        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
                }
                .coordinateSpace(name: Self.taskCardCoordinateSpaceName)
                .onAppear {
                    viewportSize = geometry.size
                }
                .onChange(of: geometry.size) { newSize in
                    viewportSize = newSize
                }
                .overlay(alignment: .topLeading) {
                    if let activeMenu {
                        let menuFrame = activeMenu.menuFrame
                        ZStack(alignment: .topLeading) {
                            MenuGateClientView(
                                gate: appState.interfaceLayers.menuGate,
                                owner: .dialog,
                                kind: .cardMenu,
                                menuFrame: menuFrame,
                                anchorFrame: activeMenu.anchorFrame,
                                handleKey: { keyCode, _ in
                                    switch keyCode {
                                    case 53:
                                        dismissMenu()
                                        return true
                                    case 126:
                                        _ = menuHighlight.moveHighlight(by: -1)
                                        return true
                                    case 125:
                                        _ = menuHighlight.moveHighlight(by: 1)
                                        return true
                                    case 123, 124:
                                        return true
                                    case 36, 76:
                                        return activateHighlightedItem(in: activeMenu)
                                    default:
                                        return false
                                    }
                                },
                                dismiss: { _ in
                                    dismissMenu()
                                }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)

                            WorkbenchCardMenuPopover(
                                items: activeMenu.items,
                                highlight: menuHighlight,
                                onDismiss: { dismissMenu() }
                            )
                            .offset(x: menuFrame.minX, y: menuFrame.minY)
                        }
                        .zIndex(1000)
                    }
                }
            }
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthXLarge)
        .frame(height: WorkbenchControlMetrics.redesignTaskPanelHeight)
        .background(WorkbenchRedesignColors.bgDialog)
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    private var headerRow: some View {
        let titleText = L("task.title")
        let titleFont = Font.system(
            size: WorkbenchControlMetrics.redesignDialogTitleFontSize,
            weight: .semibold
        )

        return WorkbenchAdaptiveHeaderBar(
            leadingInset: WorkbenchControlMetrics.redesignDialogInset,
            trailingInset: WorkbenchControlMetrics.redesignDialogInset,
            minimumGap: WorkbenchControlMetrics.redesignSpacing3
        ) {
            Text(titleText)
                .font(titleFont)
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .workbenchTruncatedTextTooltip(
                    scenarioID: "truncated.dialog.title",
                    text: titleText,
                    font: titleFont
                )
                .allowsHitTesting(false)
        } center: {
            WorkbenchSegmentedControl(
                options: TaskQueueTab.allCases,
                selection: Binding(
                    get: { tasks.selectedTab },
                    set: { tab in
                        dismissMenu()
                        tasks.selectedTab = tab
                    }
                ),
                title: { $0.label },
                accessibilityLabel: { $0.label },
                accessibilityIdentifier: { "task-tab-\($0.rawValue)" }
            )
        } trailing: {
            WorkbenchIconButton(
                icon: .x,
                isRedesign: true,
                iconSize: WorkbenchControlMetrics.redesignDialogCloseIconSize,
                boxSize: WorkbenchControlMetrics.redesignDialogCloseButtonSize,
                action: {
                    dismissMenu()
                    tasks.closePanel()
                }
            )
            .workbenchTooltip(
                scenarioID: "dialog.header.close",
                label: L("common.close"),
                shortcut: .fixed("Esc")
            )
            .keyboardShortcut(confirmation.session == nil ? .cancelAction : nil)
            .accessibilityLabel(L("common.close"))
        }
        .frame(height: WorkbenchControlMetrics.redesignSegmentedControlHeight)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tasks.selectedTab {
        case .current:
            cardList(isEmpty: tasks.current.isEmpty, emptyMessage: L("task.empty.current")) {
                ForEach(tasks.current) { entry in
                    let items = currentMenuItems(for: entry)
                    TaskCurrentCard(
                        entry: entry,
                        isMenuOpen: activeMenu?.cardID == "current-\(entry.id)",
                        onOpenMenu: { anchorFrame in
                            toggleMenu(for: "current-\(entry.id)", anchorFrame: anchorFrame, items: items)
                        }
                    )
                }
            }
        case .completed:
            cardList(isEmpty: tasks.completed.isEmpty, emptyMessage: L("task.empty.completed")) {
                ForEach(tasks.completed) { record in
                    let items = historyMenuItems(for: record)
                    TaskHistoryCard(
                        record: record,
                        isMenuOpen: activeMenu?.cardID == "history-\(record.id)",
                        onOpenMenu: { anchorFrame in
                            toggleMenu(for: "history-\(record.id)", anchorFrame: anchorFrame, items: items)
                        }
                    )
                }
            }
        case .incomplete:
            cardList(isEmpty: tasks.incomplete.isEmpty, emptyMessage: L("task.empty.incomplete")) {
                ForEach(tasks.incomplete) { record in
                    let items = historyMenuItems(for: record)
                    TaskHistoryCard(
                        record: record,
                        isMenuOpen: activeMenu?.cardID == "history-\(record.id)",
                        onOpenMenu: { anchorFrame in
                            toggleMenu(for: "history-\(record.id)", anchorFrame: anchorFrame, items: items)
                        }
                    )
                }
            }
        }
    }

    private func currentMenuItems(for entry: TaskQueueEntry) -> [WorkbenchCardMenuItem] {
        let isCancellable = entry.record.state != .running || entry.canBeRemovedWhileRunning
        return [
            WorkbenchCardMenuItem(
                title: L("task.menu.remove"),
                icon: .minusCircle,
                isEnabled: isCancellable,
                isDestructive: true,
                action: {
                    handleRemoveTask(entry: entry)
                }
            )
        ]
    }

    private func historyMenuItems(for record: TaskRecord) -> [WorkbenchCardMenuItem] {
        [
            WorkbenchCardMenuItem(
                title: L("task.menu.delete"),
                icon: .trash,
                isEnabled: true,
                isDestructive: true,
                action: {
                    handleDeleteRecord(record: record)
                }
            )
        ]
    }

    private func handleRemoveTask(entry: TaskQueueEntry) {
        guard let liveEntry = tasks.current.first(where: { $0.id == entry.id }) else {
            appState.toast.show(TaskToastRequest.taskStatusChanged)
            return
        }

        guard liveEntry.record.state != .running || liveEntry.canBeRemovedWhileRunning else {
            appState.toast.show(TaskToastRequest.taskStatusChanged)
            return
        }

        confirmRemove(liveEntry.record)
    }

    private func handleDeleteRecord(record: TaskRecord) {
        let exists = tasks.completed.contains(where: { $0.id == record.id }) ||
                     tasks.incomplete.contains(where: { $0.id == record.id })
        guard exists else {
            appState.toast.show(TaskToastRequest.taskStatusChanged)
            return
        }

        confirmDelete(record)
    }

    private func confirmRemove(_ record: TaskRecord) {
        confirmation.session = WorkbenchConfirmationSession(
            title: L("task.confirm.remove.title"),
            message: removeMessage(for: record),
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

    private func removeMessage(for record: TaskRecord) -> String {
        switch record.kind {
        case .ankiExport:
            return L("task.confirm.remove.message", record.fileName)
        case .index:
            return L("task.confirm.remove.index")
        case .addFolder:
            return L("task.confirm.remove.add_folder", record.fileName)
        case .renameFolder, .renameFiles, .removeFolder:
            return ""
        }
    }

    private func confirmDelete(_ record: TaskRecord) {
        confirmation.session = WorkbenchConfirmationSession(
            title: L("task.confirm.delete.title"),
            message: record.kind == .ankiExport
                ? L("task.confirm.delete.message", record.fileName)
                : L("task.confirm.delete.other"),
            destructiveTitle: L("excerpt.delete"),
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

    private func toggleMenu(for cardID: String, anchorFrame: CGRect, items: [WorkbenchCardMenuItem]) {
        if activeMenu?.cardID == cardID {
            dismissMenu()
        } else {
            openMenu(for: cardID, anchorFrame: anchorFrame, items: items)
        }
    }

    private func openMenu(for cardID: String, anchorFrame: CGRect, items: [WorkbenchCardMenuItem]) {
        let naturalSize = measuredMenuSize(for: items)
        let container = CGRect(origin: .zero, size: viewportSize)
        let anchorForPlacement = CGRect(
            x: anchorFrame.maxX - naturalSize.width,
            y: anchorFrame.minY,
            width: naturalSize.width,
            height: anchorFrame.height
        )
        let openingFrame = MenuPlacement.openingFrame(
            anchor: anchorForPlacement,
            menuSize: naturalSize,
            in: container,
            gap: WorkbenchControlMetrics.redesignSpacing1,
            shrinksToFit: false
        )
        activeMenu = WorkbenchCardMenuState(
            cardID: cardID,
            anchorFrame: anchorFrame,
            menuFrame: openingFrame,
            items: items
        )
        menuHighlight.open(
            selectablePositions: items.indices.filter { items[$0].isEnabled }
        )
    }

    private func dismissMenu() {
        activeMenu = nil
        menuHighlight.close()
    }

    private func activateHighlightedItem(in menu: WorkbenchCardMenuState) -> Bool {
        guard let position = menuHighlight.highlightedPosition,
              menu.items.indices.contains(position),
              menu.items[position].isEnabled
        else {
            return false
        }
        let item = menu.items[position]
        dismissMenu()
        item.action()
        return true
    }

    private func measuredMenuSize(for items: [WorkbenchCardMenuItem]) -> CGSize {
        let host = NSHostingView(
            rootView: WorkbenchCardMenuPopover(
                items: items,
                highlight: menuHighlight,
                onDismiss: {}
            )
        )
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
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
    let isMenuOpen: Bool
    let onOpenMenu: (CGRect) -> Void

    var body: some View {
        TaskCardContainer {
            WorkbenchCardIcon(icon: entry.record.icon)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                TaskCardTitleView(title: entry.record.displayTitle)

                if entry.record.state == .running {
                    TaskCurrentRunningContent(entry: entry)
                } else {
                    TaskCurrentQueuedContent(entry: entry)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            GeometryReader { buttonProxy in
                WorkbenchIconButton(
                    icon: .dotsThree,
                    isRedesign: true,
                    isOpen: isMenuOpen,
                    hoverBackground: WorkbenchRedesignColors.rowSelected,
                    action: {
                        let frame = buttonProxy.frame(in: .named(TaskPanel.taskCardCoordinateSpaceName))
                        onOpenMenu(frame)
                    }
                )
            }
            .frame(
                width: WorkbenchControlMetrics.redesignIconButtonSize,
                height: WorkbenchControlMetrics.redesignIconButtonSize
            )
            .padding(.top, WorkbenchControlMetrics.redesignCardTrailingIconButtonTopOffset)
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
    let isMenuOpen: Bool
    let onOpenMenu: (CGRect) -> Void

    var body: some View {
        TaskCardContainer {
            WorkbenchCardIcon(icon: record.icon)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                TaskCardTitleView(title: record.displayTitle)
 
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

            Spacer(minLength: 0)

            GeometryReader { buttonProxy in
                WorkbenchIconButton(
                    icon: .dotsThree,
                    isRedesign: true,
                    isOpen: isMenuOpen,
                    hoverBackground: WorkbenchRedesignColors.rowSelected,
                    action: {
                        let frame = buttonProxy.frame(in: .named(TaskPanel.taskCardCoordinateSpaceName))
                        onOpenMenu(frame)
                    }
                )
            }
            .frame(
                width: WorkbenchControlMetrics.redesignIconButtonSize,
                height: WorkbenchControlMetrics.redesignIconButtonSize
            )
            .padding(.top, WorkbenchControlMetrics.redesignCardTrailingIconButtonTopOffset)
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
     let title: String
 
     var body: some View {
         Text(title)
             .font(.system(
                 size: WorkbenchControlMetrics.redesignFontSizeBody,
                 weight: WorkbenchControlMetrics.redesignFontWeightControl
             ))
             .foregroundStyle(WorkbenchRedesignColors.textPrimary)
             .lineLimit(1)
             .truncationMode(.middle)
     }
 }

private struct TaskCardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            content()
        }
        .padding(WorkbenchControlMetrics.redesignSpacing4)
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignCardBaselineHeight,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
                style: .continuous
            )
            .fill(isHovered ? WorkbenchRedesignColors.rowHover : WorkbenchRedesignColors.tableBg)
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
        .contentShape(RoundedRectangle(
            cornerRadius: WorkbenchControlMetrics.redesignCornerRadius,
            style: .continuous
        ))
        .onPointerHover { isHovered = $0 }
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

    var displayTitle: String {
        "\(titleActionPrefix)\(titleTargetName)"
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
            return IndexingStore.displayName(for: URL.fromMediaPath(oldPaths.first ?? ""))
        }
    }
}
