import Foundation
import CueSeekerCore

/// The Task panel's three tabs.
enum TaskQueueTab: String, CaseIterable, Identifiable {
    case current
    case completed
    case incomplete

    var id: String { rawValue }

    var label: String {
        switch self {
        case .current:
            L("task.tab.current")
        case .completed:
            L("task.tab.completed")
        case .incomplete:
            L("task.tab.incomplete")
        }
    }
}

/// What a task will do once it reaches the front of the queue.
///
/// Memory only. A task never resumes across launches — an interrupted one goes
/// to Incomplete — so nothing here has to survive one, and the cues a queued
/// export is holding never reach the database.
enum TaskWork {
    case ankiExport(items: [AnkiExportItem], options: AnkiExportOptions, destinationURL: URL)
    case rename(LibraryRenameRequest)
}

/// The two stages of a rename task. Each is half of its progress bar.
enum TaskRenameStage: Equatable {
    case checkingConflicts
    case renaming

    var fraction: Double {
        switch self {
        case .checkingConflicts:
            0
        case .renaming:
            0.5
        }
    }

    var label: String {
        switch self {
        case .checkingConflicts:
            L("rename.stage.checking")
        case .renaming:
            L("rename.stage.renaming")
        }
    }
}

/// How far the running task has got.
///
/// Its own object rather than a field on the entry, because progress moves
/// once per exported card. Only the running card's progress row observes it,
/// so a tick re-reads that row instead of rebuilding the panel, its tabs and
/// every other card.
@MainActor
final class TaskProgressModel: ObservableObject {
    @Published fileprivate(set) var exportedCount = 0
    @Published fileprivate(set) var renameStage = TaskRenameStage.checkingConflicts
}

/// Runs one export. The queue calls this rather than the exporter directly so
/// its own behaviour — one at a time, what a finished task becomes, what a
/// cancelled one records — can be exercised without ffmpeg and a real video.
typealias TaskExportRunner = @Sendable (
    _ items: [AnkiExportItem],
    _ options: AnkiExportOptions,
    _ destinationURL: URL,
    _ onItemExported: @escaping @Sendable (Int) -> Void
) async throws -> Void

/// Runs one rename: the conflict check, then the renames and the database
/// update. Reports the stage it enters. The coordinator supplies it, because
/// the check has to know what is playing and the pages have to be refreshed
/// afterwards; the queue only orders and records.
typealias TaskRenameRunner = @Sendable (
    _ request: LibraryRenameRequest,
    _ onStage: @escaping @Sendable (TaskRenameStage) -> Void
) async throws -> Void

/// Why a rename was refused before its conflict check began.
enum LibraryRenameRefusal: Error {
    case videoPlaying
    case exportQueued
}

/// One task in the Current tab: the durable record, the work it is holding,
/// and — while it runs — how far it has got.
struct TaskQueueEntry: Identifiable {
    var record: TaskRecord
    let work: TaskWork
    let progress: TaskProgressModel

    var id: Int64 { record.id }

    var isRename: Bool {
        if case .rename = work {
            return true
        }
        return false
    }
}

/// The App's one task queue.
///
/// One task runs at a time. A task is one command the reader gave — a single
/// export of a selection, or one rename — so running two at once would have
/// two ffmpeg pipelines competing for the same disk, or a rename moving files
/// an export is reading, while the reader cannot tell which numbers belong to
/// which task.
///
/// Current is memory-backed and Completed/Incomplete are read once at launch,
/// because that is the only shape in which the two agree: a queued task holds
/// cues that are never written down, so a record that outlives its process can
/// only be history.
@MainActor
final class TaskQueueStore: ObservableObject {
    /// Running and queued, oldest first.
    @Published private(set) var current: [TaskQueueEntry] = []
    @Published private(set) var completed: [TaskRecord] = []
    @Published private(set) var incomplete: [TaskRecord] = []
    @Published private(set) var isPanelOpen = false
    /// Which tab the panel shows. Not persisted, and reset by every open.
    @Published var selectedTab: TaskQueueTab = .current
    /// The open Export to Anki dialog, whose Export queues its task here.
    @Published var ankiExportSession: AnkiExportSession?

    /// Running plus queued — what the entry button's badge counts.
    var remainingTaskCount: Int { current.count }

    /// Whether a rename is running or waiting, which is when the File page
    /// must not start an Index or change the root folders under it.
    var hasRenameTasks: Bool { current.contains(where: \.isRename) }

    private let database: TaskRecordDatabase?
    private let runExport: TaskExportRunner
    var runRename: TaskRenameRunner
    private var runningTask: Task<Void, Never>?
    /// Tasks the reader removed while they were running. The running task ends
    /// on whatever error the cancellation produced, and this is how the outcome
    /// is recorded as the removal it actually was.
    private var cancelledTaskIDs: Set<Int64> = []

    static let ankiExportRunner: TaskExportRunner = { items, options, destinationURL, onItemExported in
        try await AnkiPackageExporter.export(
            items: items,
            options: options,
            to: destinationURL,
            onItemExported: onItemExported
        )
    }

    init(
        database: TaskRecordDatabase?,
        runExport: @escaping TaskExportRunner = TaskQueueStore.ankiExportRunner,
        runRename: @escaping TaskRenameRunner = { _, _ in
            throw LibraryRenameError.databaseUpdateFailed("The rename runner is not configured.")
        }
    ) {
        self.database = database
        self.runExport = runExport
        self.runRename = runRename
    }

    /// Reads the history, after closing out whatever the previous launch left
    /// open. See `TaskRecordDatabase.markUnfinishedTasksIncomplete`.
    func loadPersistedRecords() {
        guard let database else {
            return
        }

        do {
            try database.markUnfinishedTasksIncomplete(
                message: L("task.error.interrupted")
            )
            let records = try database.records()
            completed = records.filter { $0.state == .completed }
            incomplete = records.filter { $0.state == .incomplete }
        } catch {
            print("Failed to read task records: \(error)")
        }
    }

    // MARK: - Queue

    func enqueueAnkiExport(
        items: [AnkiExportItem],
        options: AnkiExportOptions,
        destinationURL: URL
    ) {
        guard !items.isEmpty, let database else {
            return
        }

        do {
            let record = try database.insertQueuedTask(
                kind: .ankiExport,
                fileName: destinationURL.lastPathComponent,
                folderPath: destinationURL.deletingLastPathComponent().path,
                itemCount: items.count
            )
            current.append(
                TaskQueueEntry(
                    record: record,
                    work: .ankiExport(items: items, options: options, destinationURL: destinationURL),
                    progress: TaskProgressModel()
                )
            )
            startNextTaskIfIdle()
        } catch {
            print("Failed to queue Anki export: \(error)")
        }
    }

    /// Queues a rename. The paths are what the reader saw when they asked;
    /// the conflict check reads the disk and the database again when the task
    /// actually starts.
    func enqueueRename(
        _ request: LibraryRenameRequest,
        oldPaths: [String],
        newPaths: [String]
    ) {
        guard let database else {
            return
        }

        let kind: TaskRecordKind
        switch request {
        case .folder:
            kind = .renameFolder
        case .fileGroup:
            kind = .renameFiles
        }
        do {
            let record = try database.insertQueuedTask(
                kind: kind,
                fileName: "",
                folderPath: "",
                itemCount: oldPaths.count,
                oldPaths: oldPaths,
                newPaths: newPaths
            )
            current.append(
                TaskQueueEntry(
                    record: record,
                    work: .rename(request),
                    progress: TaskProgressModel()
                )
            )
            startNextTaskIfIdle()
        } catch {
            print("Failed to queue rename: \(error)")
        }
    }

    /// Takes a task out of Current. A running export is cancelled first and
    /// recorded when it actually stops; a queued task never started, so it
    /// moves straight across. A running rename is not removable: its two
    /// stages either complete together or roll back together, and there is
    /// no point between them at which stopping leaves anything consistent.
    func removeCurrentTask(id: Int64) {
        guard let entry = current.first(where: { $0.id == id }) else {
            return
        }

        guard entry.record.state == .running else {
            moveToHistory(
                id: id,
                state: .incomplete,
                errorMessage: L("task.error.cancelled")
            )
            return
        }

        guard !entry.isRename else {
            return
        }
        cancelledTaskIDs.insert(id)
        runningTask?.cancel()
    }

    func deleteRecord(id: Int64) {
        completed.removeAll { $0.id == id }
        incomplete.removeAll { $0.id == id }
        do {
            try database?.deleteRecord(id: id)
        } catch {
            print("Failed to delete task record: \(error)")
        }
    }

    // MARK: - Panel

    func openPanel() {
        selectedTab = .current
        isPanelOpen = true
    }

    func closePanel() {
        isPanelOpen = false
    }

    // MARK: - Running

    private func startNextTaskIfIdle() {
        guard runningTask == nil,
              let index = current.firstIndex(where: { $0.record.state == .queued })
        else {
            return
        }

        let entry = current[index]
        setState(.running, at: index)

        switch entry.work {
        case .ankiExport(let items, let options, let destinationURL):
            let progress = entry.progress
            let runExport = runExport
            runningTask = Task { [weak self] in
                var failure: String?
                do {
                    try await runExport(items, options, destinationURL) { exportedCount in
                        Task { @MainActor in
                            progress.exportedCount = exportedCount
                        }
                    }
                } catch {
                    failure = Self.message(for: error)
                }
                await self?.finishRunningTask(
                    id: entry.record.id,
                    failure: failure
                )
            }
        case .rename(let request):
            // An export waiting behind this rename holds the paths it was given;
            // renaming them first would only make that export fail later.
            guard !queuedExportUses(request) else {
                finishRunningTask(
                    id: entry.record.id,
                    failure: Self.message(for: LibraryRenameRefusal.exportQueued)
                )
                return
            }
            let progress = entry.progress
            let runRename = runRename
            runningTask = Task { [weak self] in
                var failure: String?
                do {
                    try await runRename(request) { stage in
                        Task { @MainActor in
                            progress.renameStage = stage
                        }
                    }
                } catch {
                    failure = Self.message(for: error)
                }
                await self?.finishRunningTask(
                    id: entry.record.id,
                    failure: failure
                )
            }
        }
    }

    private func queuedExportUses(_ request: LibraryRenameRequest) -> Bool {
        current.contains { entry in
            guard entry.record.state == .queued,
                  case .ankiExport(let items, _, _) = entry.work
            else {
                return false
            }
            return items.contains { request.involves(videoPath: $0.videoPath) }
        }
    }

    private func finishRunningTask(id: Int64, failure: String?) {
        runningTask = nil

        if cancelledTaskIDs.remove(id) != nil {
            // Whatever the export threw on the way down, the reader removed
            // this task; that is what the record has to say.
            moveToHistory(
                id: id,
                state: .incomplete,
                errorMessage: L("task.error.cancelled")
            )
        } else if let failure {
            moveToHistory(id: id, state: .incomplete, errorMessage: failure)
        } else {
            moveToHistory(id: id, state: .completed, errorMessage: nil)
        }

        startNextTaskIfIdle()
    }

    private func moveToHistory(
        id: Int64,
        state: TaskRecordState,
        errorMessage: String?
    ) {
        guard let index = current.firstIndex(where: { $0.id == id }) else {
            return
        }

        let changedAt = Date()
        let record = current[index].record.withState(
            state,
            errorMessage: errorMessage,
            changedAt: changedAt
        )
        current.remove(at: index)

        if state == .completed {
            completed.append(record)
        } else {
            incomplete.append(record)
        }

        write(
            id: id,
            state: state,
            errorMessage: errorMessage,
            changedAt: changedAt
        )
    }

    private func setState(_ state: TaskRecordState, at index: Int) {
        let changedAt = Date()
        let previous = current[index].record
        current[index].record = previous.withState(
            state,
            errorMessage: previous.errorMessage,
            changedAt: changedAt
        )
        write(
            id: previous.id,
            state: state,
            errorMessage: previous.errorMessage,
            changedAt: changedAt
        )
    }

    private func write(
        id: Int64,
        state: TaskRecordState,
        errorMessage: String?,
        changedAt: Date
    ) {
        do {
            try database?.updateState(
                id: id,
                to: state,
                errorMessage: errorMessage,
                changedAt: changedAt
            )
        } catch {
            print("Failed to update task record: \(error)")
        }
    }

    private static func message(for error: Error) -> String {
        if let exportError = error as? AnkiPackageExportError {
            return exportError.description
        }
        if let conflict = error as? LibraryRenameConflict {
            switch conflict {
            case .filesChangedSinceIndex:
                return L("rename.error.files_changed")
            case .destinationExists(let name):
                return L("rename.error.exists", name)
            case .pairingWouldChange(let name):
                return L("rename.error.pairing", name)
            }
        }
        if let renameError = error as? LibraryRenameError {
            switch renameError {
            case .renameFailed(let path):
                return L("rename.error.rename_failed", path)
            case .databaseUpdateFailed:
                return L("rename.error.database_failed")
            }
        }
        if let refusal = error as? LibraryRenameRefusal {
            switch refusal {
            case .videoPlaying:
                return L("rename.error.playing")
            case .exportQueued:
                return L("rename.error.export_queued")
            }
        }
        return error.localizedDescription
    }
}
