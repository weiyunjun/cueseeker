import AppKit
import SwiftUI
import Testing
@testable import CueSeekerApp
import CueSeekerCore

@Suite
@MainActor
struct TaskCardMenuTests {
    @Test
    func taskCardMenuItemProperties() {
        let removeItem = WorkbenchCardMenuItem(
            title: L("task.menu.remove"),
            icon: .minusCircle,
            isEnabled: true,
            isDestructive: true,
            action: {}
        )
        #expect(removeItem.title == "Remove Task")
        #expect(removeItem.icon == .minusCircle)
        #expect(removeItem.isEnabled == true)
        #expect(removeItem.isDestructive == true)

        let deleteItem = WorkbenchCardMenuItem(
            title: L("task.menu.delete"),
            icon: .trash,
            isEnabled: true,
            isDestructive: true,
            action: {}
        )
        #expect(deleteItem.title == "Delete Record")
        #expect(deleteItem.icon == .trash)
        #expect(deleteItem.isEnabled == true)
        #expect(deleteItem.isDestructive == true)
    }

    @Test
    func taskCardToastAndStateChangeInterception() {
        let toast = TaskToastRequest.taskStatusChanged
        #expect(toast.scenarioID == "task.action.status_changed")
        #expect(toast.icon == .warning)
        #expect(toast.duration == ToastDuration.alert)
        #expect(toast.message == "Task status has changed")

        // Interception logic verification
        var toastShown = false
        var confirmationShown = false
        let fakeTasksCurrent: [Int64] = [] // Empty, simulating task already finished
        let targetTaskID: Int64 = 999

        let handleRemove = {
            guard fakeTasksCurrent.contains(targetTaskID) else {
                toastShown = true
                return
            }
            confirmationShown = true
        }

        handleRemove()
        #expect(toastShown == true)
        #expect(confirmationShown == false)
    }

    @Test
    func taskCardGeometryAndTokensMatchSpecification() {
        let baselineCardHeight = WorkbenchControlMetrics.redesignCardBaselineHeight
        let cardPadding = WorkbenchControlMetrics.redesignSpacing4
        let buttonSize = WorkbenchControlMetrics.redesignIconButtonSize
        let buttonTopOffset = WorkbenchControlMetrics.redesignCardTrailingIconButtonTopOffset

        // Top margin in baseline state
        let baselineTopMargin = cardPadding + buttonTopOffset
        // Bottom margin in baseline state
        let baselineBottomMargin = baselineCardHeight - (baselineTopMargin + buttonSize)

        #expect(baselineCardHeight == 68)
        #expect(buttonSize == 32)
        #expect(baselineTopMargin == 18)
        #expect(baselineBottomMargin == 18)
        #expect(baselineTopMargin == baselineBottomMargin)

        // Line 3 expansion retains top distance of 18px
        let multiLineTopMargin = cardPadding + buttonTopOffset
        #expect(multiLineTopMargin == baselineTopMargin)
        #expect(multiLineTopMargin == 18)

        // Tokens
        #expect(hexString(WorkbenchRedesignColors.NS.tableBg, appearance: .aqua) == "#FFFFFF")
        #expect(hexString(WorkbenchRedesignColors.NS.tableBg, appearance: .darkAqua) == "#2E2E34")

        #expect(hexString(WorkbenchRedesignColors.NS.rowHover, appearance: .aqua) == "#F9FAFB")
        #expect(hexString(WorkbenchRedesignColors.NS.rowHover, appearance: .darkAqua) == "#383840")

        #expect(hexString(WorkbenchRedesignColors.NS.rowSelected, appearance: .aqua) == "#ECEEF2")
        #expect(hexString(WorkbenchRedesignColors.NS.rowSelected, appearance: .darkAqua) == "#43434C")

        #expect(hexString(WorkbenchRedesignColors.NS.rowActionBgPressed, appearance: .aqua) == "#DEE2E8")
        #expect(hexString(WorkbenchRedesignColors.NS.rowActionBgPressed, appearance: .darkAqua) == "#4E4E58")
    }

    @Test
    func taskCardPopoverRendersFittingSizeWithoutOverflow() {
        let highlight = MenuHighlightModel()
        let items = [
            WorkbenchCardMenuItem(
                title: "Remove Task",
                icon: .minusCircle,
                isEnabled: true,
                isDestructive: true,
                action: {}
            )
        ]

        let popover = WorkbenchCardMenuPopover(
            items: items,
            highlight: highlight,
            onDismiss: {}
        )

        let host = NSHostingView(rootView: popover)
        host.layoutSubtreeIfNeeded()
        let fittingSize = host.fittingSize

        #expect(fittingSize.width >= 160)
        #expect(fittingSize.height > 30)
        #expect(fittingSize.height < 80)
    }

    @Test
    func taskPanelMenuLayerIsNotCoveredInDialog() {
        let registry = InterfaceLayerRegistry()
        registry.setOpen(.dialog, true)

        // When TaskPanel is open, .dialog is active.
        // A menu registered with owner: .workbenchPage would be erroneously treated as covered by the dialog.
        #expect(registry.isMenuCovered(ownedBy: .workbenchPage) == true)
        // A menu registered with owner: .dialog must NOT be treated as covered.
        #expect(registry.isMenuCovered(ownedBy: .dialog) == false)
    }

    @Test
    func taskPanelMenuItemsPlaceGetInfoFirst() throws {
        defer { AppLocalization.apply(.english) }
        AppLocalization.apply(.english)

        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerTaskCardMenuTests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { removeTemporaryDatabase(at: databaseURL) }
        try DatabaseBootstrap.prepare(at: databaseURL)

        let store = TaskQueueStore(
            database: try TaskRecordDatabase(path: databaseURL),
            runExport: { _, _, _, _ in
                try await Task.sleep(nanoseconds: 3_600_000_000_000)
            },
            runRemoveFolder: { _ in
                try await Task.sleep(nanoseconds: 3_600_000_000_000)
            }
        )
        let panel = TaskPanel(tasks: store, confirmation: ConfirmationCenter())

        store.enqueueAnkiExport(
            items: [
                AnkiExportItem(
                    deckDisplayTitle: "Deck",
                    videoPath: "/Videos/episode.mkv",
                    startMilliseconds: 0,
                    endMilliseconds: 500,
                    text: "line",
                    displayTitle: "Deck",
                    timeRange: "",
                    cueGroupOtherTexts: [],
                    cueID: nil,
                    subtitlePath: ""
                )
            ],
            options: AnkiExportOptions(),
            destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
        )
        store.enqueueRemoveFolder(URL(fileURLWithPath: "/Videos/Show"))

        let exportEntry = try #require(store.current.first(where: { $0.record.kind == .ankiExport }))
        let exportMenuItems = panel.currentMenuItems(for: exportEntry)
        #expect(exportMenuItems.count == 2)
        #expect(exportMenuItems[0].title == "Get Info")
        #expect(exportMenuItems[0].icon == .info)
        #expect(exportMenuItems[0].isEnabled == true)
        #expect(exportMenuItems[0].isDestructive == false)
        #expect(exportMenuItems[1].title == "Remove Task")
        #expect(exportMenuItems[1].icon == .minusCircle)
        #expect(exportMenuItems[1].isEnabled == true)
        #expect(exportMenuItems[1].isDestructive == true)

        let removeFolderEntry = try #require(store.current.first(where: { $0.record.kind == .removeFolder }))
        let removeFolderMenuItems = panel.currentMenuItems(for: removeFolderEntry)
        #expect(removeFolderMenuItems.count == 2)
        #expect(removeFolderMenuItems[0].title == "Get Info")
        #expect(removeFolderMenuItems[0].icon == .info)
        #expect(removeFolderMenuItems[0].isEnabled == true)
        #expect(removeFolderMenuItems[0].isDestructive == false)
        #expect(removeFolderMenuItems[1].title == "Remove Task")
        #expect(removeFolderMenuItems[1].isEnabled == false)

        let historyRecord = exportEntry.record.withState(.completed, errorMessage: nil, changedAt: Date())
        let historyItems = panel.historyMenuItems(for: historyRecord)
        #expect(historyItems.count == 2)
        #expect(historyItems[0].title == "Get Info")
        #expect(historyItems[0].icon == .info)
        #expect(historyItems[0].isEnabled == true)
        #expect(historyItems[0].isDestructive == false)
        #expect(historyItems[1].title == "Delete Record")
        #expect(historyItems[1].icon == .trash)
        #expect(historyItems[1].isEnabled == true)
        #expect(historyItems[1].isDestructive == true)
    }

    @Test
    func getInfoFromCurrentMenuOpensLatestCompletedOrIncompleteRecordAfterTaskFinishes() async throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerTaskCardMenuTransitionTests-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
        defer { removeTemporaryDatabase(at: databaseURL) }
        try DatabaseBootstrap.prepare(at: databaseURL)

        let store = TaskQueueStore(
            database: try TaskRecordDatabase(path: databaseURL),
            runExport: { _, _, _, _ in }
        )
        let panel = TaskPanel(tasks: store, confirmation: ConfirmationCenter())
        let item = AnkiExportItem(
            deckDisplayTitle: "Deck",
            videoPath: "/Videos/episode.mkv",
            startMilliseconds: 0,
            endMilliseconds: 500,
            text: "line",
            displayTitle: "Deck",
            timeRange: "",
            cueGroupOtherTexts: [],
            cueID: nil,
            subtitlePath: ""
        )

        store.enqueueAnkiExport(
            items: [item],
            options: AnkiExportOptions(),
            destinationURL: URL(fileURLWithPath: "/Exports/First.apkg")
        )
        store.enqueueAnkiExport(
            items: [item],
            options: AnkiExportOptions(),
            destinationURL: URL(fileURLWithPath: "/Exports/Second.apkg")
        )

        let firstEntry = try #require(store.current.first)
        let secondEntry = try #require(store.current.last)
        let firstMenuItems = panel.currentMenuItems(for: firstEntry)
        let secondMenuItems = panel.currentMenuItems(for: secondEntry)

        // Move second task to Incomplete and let first task finish into Completed.
        store.removeCurrentTask(id: secondEntry.id)
        await store.waitUntilIdle()

        #expect(store.current.isEmpty)

        // Invoking Get Info from the menu built while in Current still opens the task detail for Completed/Incomplete.
        firstMenuItems[0].action()
        #expect(store.detailTaskID == firstEntry.id)
        let completedSnapshot = try #require(store.taskDetailSnapshot(for: firstEntry.id))
        #expect(completedSnapshot.record.state == .completed)
        #expect(completedSnapshot.progress == nil)

        secondMenuItems[0].action()
        #expect(store.detailTaskID == secondEntry.id)
        let incompleteSnapshot = try #require(store.taskDetailSnapshot(for: secondEntry.id))
        #expect(incompleteSnapshot.record.state == .incomplete)
        #expect(incompleteSnapshot.progress == nil)
    }

    @Test
    func taskDetailLocalizationKeysResolveAcrossAllLanguages() {
        defer { AppLocalization.apply(.english) }

        let allKeys = [
            "task_detail.get_info",
            "task_detail.title",
            "task_detail.section.export_info",
            "task_detail.section.rename_info",
            "task_detail.section.original_file_names",
            "task_detail.section.new_file_names",
            "task_detail.section.index_info",
            "task_detail.section.target_folders",
            "task_detail.section.folder_info",
            "task_detail.section.task_status",
            "task_detail.file_name",
            "task_detail.location",
            "task_detail.card_count",
            "task_detail.original_path",
            "task_detail.new_path",
            "task_detail.file_count",
            "task_detail.path",
            "task_detail.folder_count",
            "task_detail.indexed_subtitles",
            "task_detail.status",
            "task_detail.status.in_progress",
            "task_detail.status.queued",
            "task_detail.status.completed",
            "task_detail.status.incomplete",
            "task_detail.current_stage",
            "task_detail.progress",
            "task_detail.failure_reason",
            "task_detail.created",
            "task_detail.started",
            "task_detail.completed",
            "task_detail.ended"
        ]

        AppLocalization.apply(.english)
        #expect(L("task_detail.get_info") == "Get Info")
        #expect(L("task_detail.title") == "Task Info")
        #expect(L("task_detail.status.in_progress") == "In Progress")
        for key in allKeys {
            #expect(L(key) != key)
            #expect(!L(key).isEmpty)
        }

        AppLocalization.apply(.simplifiedChinese)
        #expect(L("task_detail.get_info") == "查看详情")
        #expect(L("task_detail.title") == "任务详情")
        #expect(L("task_detail.location") == "位置")
        #expect(L("task_detail.path") == "位置")
        #expect(L("task_detail.folder_count") == "文件夹数量")
        #expect(L("task_detail.status.in_progress") == "正在执行")
        for key in allKeys {
            #expect(L(key) != key)
            #expect(!L(key).isEmpty)
        }

        AppLocalization.apply(.traditionalChinese)
        #expect(L("task_detail.get_info") == "查看詳情")
        #expect(L("task_detail.title") == "任務詳情")
        #expect(L("task_detail.location") == "位置")
        #expect(L("task_detail.path") == "位置")
        #expect(L("task_detail.folder_count") == "資料夾數量")
        #expect(L("task_detail.status.in_progress") == "正在執行")
        for key in allKeys {
            #expect(L(key) != key)
            #expect(!L(key).isEmpty)
        }
    }

    @Test
    func taskDetailDialogRendersInHostingViewAcrossAllKindsAndStates() {
        let now = Date(timeIntervalSince1970: 1_712_203_800)
        let started = now.addingTimeInterval(5)
        let finished = now.addingTimeInterval(25)

        let records: [TaskRecord] = [
            TaskRecord(
                id: 1,
                kind: .ankiExport,
                fileName: "Deck.apkg",
                folderPath: "/Users/reader/Exports",
                itemCount: 80,
                state: .running,
                errorMessage: nil,
                createdAt: now,
                startedAt: started,
                stateChangedAt: started
            ),
            TaskRecord(
                id: 2,
                kind: .renameFolder,
                fileName: "Show Renamed",
                folderPath: "",
                itemCount: 1,
                state: .queued,
                errorMessage: nil,
                createdAt: now,
                startedAt: nil,
                stateChangedAt: now,
                oldPaths: ["/Videos/Show"],
                newPaths: ["/Videos/Show Renamed"]
            ),
            TaskRecord(
                id: 3,
                kind: .renameFiles,
                fileName: "EP01_new",
                folderPath: "/Videos/Show",
                itemCount: 2,
                state: .completed,
                errorMessage: nil,
                createdAt: now,
                startedAt: started,
                stateChangedAt: finished,
                oldPaths: ["/Videos/Show/EP01.mkv", "/Videos/Show/EP01.ass"],
                newPaths: ["/Videos/Show/EP01_new.mkv", "/Videos/Show/EP01_new.ass"]
            ),
            TaskRecord(
                id: 4,
                kind: .index,
                fileName: "Show",
                folderPath: "",
                itemCount: 12,
                state: .completed,
                errorMessage: nil,
                createdAt: now,
                startedAt: started,
                stateChangedAt: finished,
                oldPaths: ["/Videos/Show"]
            ),
            TaskRecord(
                id: 5,
                kind: .index,
                fileName: "",
                folderPath: "",
                itemCount: 36,
                state: .incomplete,
                errorMessage: "Task cancelled by user",
                createdAt: now,
                startedAt: started,
                stateChangedAt: finished,
                oldPaths: ["/Videos/Show", "/Videos/Movies"]
            ),
            TaskRecord(
                id: 6,
                kind: .addFolder,
                fileName: "Show",
                folderPath: "",
                itemCount: 12,
                state: .completed,
                errorMessage: nil,
                createdAt: now,
                startedAt: started,
                stateChangedAt: finished,
                oldPaths: ["/Videos/Show"]
            ),
            TaskRecord(
                id: 7,
                kind: .removeFolder,
                fileName: "Show",
                folderPath: "",
                itemCount: 0,
                state: .running,
                errorMessage: nil,
                createdAt: now,
                startedAt: started,
                stateChangedAt: started,
                oldPaths: ["/Videos/Show"]
            )
        ]

        for record in records {
            let progress: TaskProgressModel? = record.state == .running ? TaskProgressModel() : nil
            let dialog = TaskDetailDialog(
                record: record,
                progress: progress,
                onClose: {}
            )
            let host = NSHostingView(rootView: dialog)
            host.layoutSubtreeIfNeeded()
            let fittingSize = host.fittingSize
            #expect(fittingSize.width == WorkbenchControlMetrics.redesignDialogWidthXLarge)
            #expect(fittingSize.height > 100)
        }
    }
}

private func hexString(_ color: NSColor, appearance: NSAppearance.Name = .aqua) -> String {
    var resolved: NSColor?
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        resolved = color.usingColorSpace(.sRGB)
    }
    guard let srgb = resolved else {
        return ""
    }
    let red = Int((srgb.redComponent * 255).rounded())
    let green = Int((srgb.greenComponent * 255).rounded())
    let blue = Int((srgb.blueComponent * 255).rounded())
    return String(format: "#%02X%02X%02X", red, green, blue)
}
