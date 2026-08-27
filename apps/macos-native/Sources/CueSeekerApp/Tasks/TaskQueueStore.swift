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
    case ankiExport(items: [AnkiExportItem], destinationURL: URL)
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
}

/// Runs one export. The queue calls this rather than the exporter directly so
/// its own behaviour — one at a time, what a finished task becomes, what a
/// cancelled one records — can be exercised without ffmpeg and a real video.
typealias TaskExportRunner = @Sendable (
    _ items: [AnkiExportItem],
    _ destinationURL: URL,
    _ onItemExported: @escaping @Sendable (Int) -> Void
) async throws -> Void

/// One task in the Current tab: the durable record, the work it is holding,
/// and — while it runs — how far it has got.
struct TaskQueueEntry: Identifiable {
    var record: TaskRecord
    let work: TaskWork
    let progress: TaskProgressModel

    var id: Int64 { record.id }
}

/// The App's one task queue.
///
/// One task runs at a time. A task is one command the reader gave — a single
/// export of a selection — so running two at once would have two ffmpeg
/// pipelines competing for the same disk while the reader cannot tell which
/// numbers belong to which export.
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

    /// Running plus queued — what the entry button's badge counts.
    var remainingTaskCount: Int { current.count }

    private let database: TaskRecordDatabase?
    private let runExport: TaskExportRunner
    private var runningTask: Task<Void, Never>?
    /// Tasks the reader removed while they were running. The running task ends
    /// on whatever error the cancellation produced, and this is how the outcome
    /// is recorded as the removal it actually was.
    private var cancelledTaskIDs: Set<Int64> = []

    static let ankiExportRunner: TaskExportRunner = { items, destinationURL, onItemExported in
        try await AnkiPackageExporter.export(
            items: items,
            to: destinationURL,
            onItemExported: onItemExported
        )
    }

    init(
        database: TaskRecordDatabase?,
        runExport: @escaping TaskExportRunner = TaskQueueStore.ankiExportRunner
    ) {
        self.database = database
        self.runExport = runExport
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

    func enqueueAnkiExport(items: [AnkiExportItem], destinationURL: URL) {
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
                    work: .ankiExport(items: items, destinationURL: destinationURL),
                    progress: TaskProgressModel()
                )
            )
            startNextTaskIfIdle()
        } catch {
            print("Failed to queue Anki export: \(error)")
        }
    }

    /// Takes a task out of Current. A running one is cancelled first and
    /// recorded when it actually stops; a queued one never started, so it moves
    /// straight across.
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
        case .ankiExport(let items, let destinationURL):
            let progress = entry.progress
            let runExport = runExport
            runningTask = Task { [weak self] in
                var failure: String?
                do {
                    try await runExport(items, destinationURL) { exportedCount in
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
        let record = TaskRecord(
            id: id,
            kind: current[index].record.kind,
            fileName: current[index].record.fileName,
            folderPath: current[index].record.folderPath,
            itemCount: current[index].record.itemCount,
            state: state,
            errorMessage: errorMessage,
            createdAt: current[index].record.createdAt,
            stateChangedAt: changedAt
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
        current[index].record = TaskRecord(
            id: previous.id,
            kind: previous.kind,
            fileName: previous.fileName,
            folderPath: previous.folderPath,
            itemCount: previous.itemCount,
            state: state,
            errorMessage: previous.errorMessage,
            createdAt: previous.createdAt,
            stateChangedAt: changedAt
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
        return error.localizedDescription
    }
}
