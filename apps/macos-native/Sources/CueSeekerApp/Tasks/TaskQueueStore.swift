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
    /// Index Now, over the outermost root of every group.
    case index(folders: [URL])
    case addFolder(URL)
    case removeFolder(URL)
}

/// Which tasks have to wait for each other.
///
/// An export reads the media files and writes its own package. Index, Add
/// Folder, Remove Folder and the renames all take the library's absolute
/// paths as identity and write the indexing database, so they are one
/// category and an export is another. The two categories run side by side.
enum TaskCategory {
    case export
    case library
}

/// The four stages of an Index, as the reader sees them.
///
/// Each stage owns a fixed share of the bar rather than a share of the real
/// time: the shares would otherwise have to be guessed before the folder has
/// been scanned, and a second Index of unchanged files has nothing to do in
/// the last three stages anyway.
enum TaskIndexStage: Equatable, Sendable {
    case scanningFiles
    case indexingSubtitles
    case readingVideoInfo
    case generatingCovers

    var weight: Double {
        switch self {
        case .scanningFiles:
            0.2
        case .indexingSubtitles:
            0.4
        case .readingVideoInfo:
            0.2
        case .generatingCovers:
            0.2
        }
    }

    /// Where the stage begins — the weights before it, written out so the bar
    /// lands on the numbers the requirement names rather than on what adding
    /// fractions leaves behind.
    var start: Double {
        switch self {
        case .scanningFiles:
            0
        case .indexingSubtitles:
            0.2
        case .readingVideoInfo:
            0.6
        case .generatingCovers:
            0.8
        }
    }

    var label: String {
        switch self {
        case .scanningFiles:
            L("index.stage.scanning")
        case .indexingSubtitles:
            L("index.stage.subtitles")
        case .readingVideoInfo:
            L("index.stage.video_info")
        case .generatingCovers:
            L("index.stage.covers")
        }
    }
}

/// How far a running Index has got: which folder it is on, which stage of
/// that folder, and how far through that stage.
struct TaskIndexProgress: Equatable, Sendable {
    var stage = TaskIndexStage.scanningFiles
    var folderName = ""
    var completedFolders = 0
    var totalFolders = 1
    var stageCompleted = 0
    var stageTotal = 0

    /// The folders divide the bar evenly, and the stages divide the current
    /// folder's share by their own weights.
    var fraction: Double {
        guard totalFolders > 0 else {
            return 0
        }
        let withinFolder = stage.start + stage.weight * stageFraction
        return min(1, (Double(completedFolders) + withinFolder) / Double(totalFolders))
    }

    /// The stage, the folder it is working on, and the stage's own count. The
    /// scan has no count to show: it only knows how many files there are once
    /// it has finished.
    var label: String {
        var parts = [stage.label]
        if !folderName.isEmpty {
            parts.append(folderName)
        }
        if stage != .scanningFiles, stageTotal > 0 {
            parts.append("\(stageCompleted) / \(stageTotal)")
        }
        return parts.joined(separator: " · ")
    }

    private var stageFraction: Double {
        guard stageTotal > 0 else {
            return 0
        }
        return min(1, Double(stageCompleted) / Double(stageTotal))
    }
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
    @Published fileprivate(set) var indexProgress = TaskIndexProgress()
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

/// Indexes the given folders one after another and answers how many subtitle
/// files it indexed, which is what the finished card shows. Index Now and Add
/// Folder each have one. Supplied by the coordinator, because indexing owns
/// the databases, the root list and the pages that follow; the queue only
/// orders and records.
typealias TaskIndexRunner = @Sendable (
    _ folders: [URL],
    _ onProgress: @escaping @Sendable (TaskIndexProgress) -> Void
) async throws -> Int

/// Removes one root folder. One database transaction with nothing to report
/// on the way, so it has no progress. Supplied by the coordinator.
typealias TaskRemoveFolderRunner = @Sendable (_ folder: URL) async throws -> Void

/// Why a rename was refused before its conflict check began.
enum LibraryRenameRefusal: Error {
    case videoPlaying
    case exportQueued
}

/// Why an export was refused when it came to start.
enum AnkiExportRefusal: Error {
    case renameRunning
}

/// One task in the Current tab: the durable record, the work it is holding,
/// and — while it runs — how far it has got.
struct TaskQueueEntry: Identifiable {
    var record: TaskRecord
    let work: TaskWork
    let progress: TaskProgressModel

    var id: Int64 { record.id }

    var category: TaskCategory {
        switch work {
        case .ankiExport:
            .export
        case .rename, .index, .addFolder, .removeFolder:
            .library
        }
    }

    /// A running rename or root-folder removal is one database transaction
    /// that either completes or rolls back, so there is no point within it at
    /// which stopping leaves anything consistent.
    var canBeRemovedWhileRunning: Bool {
        switch work {
        case .ankiExport, .index, .addFolder:
            true
        case .rename, .removeFolder:
            false
        }
    }
}

/// The App's one task queue.
///
/// One export and one library task can run at once. Exports queue behind each
/// other: two at once would have two ffmpeg pipelines competing for the same
/// disk. A library task — Index, Add Folder, Remove Folder or a rename — never
/// queues: while one exists no other is taken, because one waiting behind
/// another would act on a root list or on paths that the first has changed.
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

    /// Whether an Index, Add Folder, Remove Folder or rename exists, which is
    /// when no other of them can be started.
    var hasLibraryTask: Bool { current.contains { $0.category == .library } }

    private let database: TaskRecordDatabase?
    private let writeQueue = DispatchQueue(
        label: "app.cueseeker.task-record-writer",
        qos: .utility
    )
    var runExport: TaskExportRunner
    var runRename: TaskRenameRunner
    var runIndex: TaskIndexRunner
    var runAddFolder: TaskIndexRunner
    var runRemoveFolder: TaskRemoveFolderRunner
    /// The running tasks by record id, at most one per category.
    private var runningTasks: [Int64: Task<Void, Never>] = [:]
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
        },
        runIndex: @escaping TaskIndexRunner = { _, _ in
            throw LibraryRenameError.databaseUpdateFailed("The index runner is not configured.")
        },
        runAddFolder: @escaping TaskIndexRunner = { _, _ in
            throw LibraryRenameError.databaseUpdateFailed("The add folder runner is not configured.")
        },
        runRemoveFolder: @escaping TaskRemoveFolderRunner = { _ in
            throw LibraryRenameError.databaseUpdateFailed("The remove folder runner is not configured.")
        }
    ) {
        self.database = database
        self.runExport = runExport
        self.runRename = runRename
        self.runIndex = runIndex
        self.runAddFolder = runAddFolder
        self.runRemoveFolder = runRemoveFolder
    }

    deinit {
        writeQueue.sync {}
    }

    /// Reads the history, after closing out whatever the previous launch left
    /// open. See `TaskRecordDatabase.markUnfinishedTasksIncomplete`. Answers
    /// the folders of the Add Folder tasks it closed out, whose indexed content
    /// has to be taken back the way a removed one's is.
    @discardableResult
    func loadPersistedRecords() -> [URL] {
        guard let database else {
            return []
        }

        do {
            let unfinishedFolderAdditions = try database.records()
                .filter { $0.kind == .addFolder && ($0.state == .running || $0.state == .queued) }
                .compactMap { $0.oldPaths.first.map { URL(fileURLWithPath: $0) } }
            try database.markUnfinishedTasksIncomplete(
                message: L("task.error.interrupted")
            )
            let records = try database.records()
            completed = records.filter { $0.state == .completed }
            incomplete = records.filter { $0.state == .incomplete }
            return unfinishedFolderAdditions
        } catch {
            print("Failed to read task records: \(error)")
            return []
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
            startEligibleTasks()
        } catch {
            print("Failed to queue Anki export: \(error)")
        }
    }

    /// Starts a rename. The paths are what the reader saw when they asked;
    /// the conflict check reads the disk and the database again when the task
    /// actually starts.
    @discardableResult
    func enqueueRename(
        _ request: LibraryRenameRequest,
        oldPaths: [String],
        newPaths: [String]
    ) -> Bool {
        let kind: TaskRecordKind
        let fileName: String
        switch request {
        case .folder(_, let newName):
            kind = .renameFolder
            fileName = newName
        case .fileGroup(_, let newBaseName):
            kind = .renameFiles
            fileName = newBaseName
        }
        return enqueueLibraryTask(
            kind: kind,
            fileName: fileName,
            itemCount: oldPaths.count,
            oldPaths: oldPaths,
            newPaths: newPaths,
            work: .rename(request)
        )
    }

    /// Starts Index Now over these folders. The count it will show is only
    /// known once it has run, so the record starts at zero.
    @discardableResult
    func enqueueIndex(folders: [URL]) -> Bool {
        guard !folders.isEmpty else {
            return false
        }
        return enqueueLibraryTask(
            kind: .index,
            fileName: "",
            itemCount: 0,
            oldPaths: folders.map(\.path),
            work: .index(folders: folders)
        )
    }

    @discardableResult
    func enqueueAddFolder(_ folder: URL) -> Bool {
        enqueueLibraryTask(
            kind: .addFolder,
            fileName: folder.lastPathComponent,
            itemCount: 0,
            oldPaths: [folder.path],
            work: .addFolder(folder)
        )
    }

    @discardableResult
    func enqueueRemoveFolder(_ folder: URL) -> Bool {
        enqueueLibraryTask(
            kind: .removeFolder,
            fileName: folder.lastPathComponent,
            itemCount: 0,
            oldPaths: [folder.path],
            work: .removeFolder(folder)
        )
    }

    /// A library task is only taken while no other exists, so it starts at
    /// once. This is the rule; the File page's disabled controls only show it.
    private func enqueueLibraryTask(
        kind: TaskRecordKind,
        fileName: String = "",
        itemCount: Int,
        oldPaths: [String],
        newPaths: [String] = [],
        work: TaskWork
    ) -> Bool {
        guard let database, !hasLibraryTask else {
            return false
        }

        do {
            let record = try database.insertQueuedTask(
                kind: kind,
                fileName: fileName,
                folderPath: "",
                itemCount: itemCount,
                oldPaths: oldPaths,
                newPaths: newPaths
            )
            current.append(
                TaskQueueEntry(
                    record: record,
                    work: work,
                    progress: TaskProgressModel()
                )
            )
            startEligibleTasks()
            return true
        } catch {
            print("Failed to queue \(kind.rawValue): \(error)")
            return false
        }
    }

    /// Takes a task out of Current. A running export, Index or Add Folder is
    /// cancelled first and recorded when it actually stops; a queued task never
    /// started, so it moves straight across. A running rename or folder removal
    /// is not removable; see `canBeRemovedWhileRunning`.
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

        guard entry.canBeRemovedWhileRunning else {
            return
        }
        cancelledTaskIDs.insert(id)
        runningTasks[id]?.cancel()
    }

    func deleteRecord(id: Int64) {
        completed.removeAll { $0.id == id }
        incomplete.removeAll { $0.id == id }
        let database = self.database
        writeQueue.async {
            do {
                try database?.deleteRecord(id: id)
            } catch {
                print("Failed to delete task record: \(error)")
            }
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

    /// Starts every queued task whose category is free, oldest first. Called
    /// on every enqueue and every finish, so this is the only place that
    /// decides a task may run.
    private func startEligibleTasks() {
        var busyCategories = Set(
            current
                .filter { $0.record.state == .running }
                .map(\.category)
        )
        var startableIDs: [Int64] = []

        for entry in current
        where entry.record.state == .queued && !busyCategories.contains(entry.category) {
            busyCategories.insert(entry.category)
            startableIDs.append(entry.id)
        }

        for id in startableIDs {
            start(id: id)
        }
    }

    private func start(id: Int64) {
        guard let index = current.firstIndex(where: { $0.id == id }),
              current[index].record.state == .queued
        else {
            return
        }

        let entry = current[index]
        setState(.running, at: index)

        switch entry.work {
        case .ankiExport(let items, let options, let destinationURL):
            // A rename moving these files would pull them out from under the
            // export halfway through.
            guard !runningRenameUses(items) else {
                refuse(id: entry.id, reason: AnkiExportRefusal.renameRunning)
                return
            }
            let progress = entry.progress
            let runExport = runExport
            run(id: entry.id) {
                try await runExport(items, options, destinationURL) { exportedCount in
                    Task { @MainActor in
                        progress.exportedCount = exportedCount
                    }
                }
                return nil
            }
        case .rename(let request):
            // An export holding these paths — running now, or queued and
            // holding the paths it was given — would only fail if the rename
            // moved them first.
            guard !exportUses(request) else {
                refuse(id: entry.id, reason: LibraryRenameRefusal.exportQueued)
                return
            }
            let progress = entry.progress
            let runRename = runRename
            run(id: entry.id) {
                try await runRename(request) { stage in
                    Task { @MainActor in
                        progress.renameStage = stage
                    }
                }
                return nil
            }
        case .index(let folders):
            runIndexing(entry, folders: folders, runner: runIndex)
        case .addFolder(let folder):
            runIndexing(entry, folders: [folder], runner: runAddFolder)
        case .removeFolder(let folder):
            let runRemoveFolder = runRemoveFolder
            run(id: entry.id) {
                try await runRemoveFolder(folder)
                return nil
            }
        }
    }

    private func runIndexing(
        _ entry: TaskQueueEntry,
        folders: [URL],
        runner: @escaping TaskIndexRunner
    ) {
        let progress = entry.progress
        run(id: entry.id) {
            try await runner(folders) { indexProgress in
                Task { @MainActor in
                    progress.indexProgress = indexProgress
                }
            }
        }
    }

    /// Runs a task's work and records how it ended. The work answers the
    /// count the finished card shows, when it has one.
    private func run(id: Int64, work: @escaping @Sendable () async throws -> Int?) {
        runningTasks[id] = Task { [weak self] in
            var failure: String?
            var itemCount: Int?
            do {
                itemCount = try await work()
            } catch {
                failure = Self.message(for: error)
            }
            self?.finishRunningTask(id: id, failure: failure, itemCount: itemCount)
        }
    }

    /// Recorded on the next turn rather than here, so a refusal reaches the
    /// same path a task that failed at once would.
    private func refuse(id: Int64, reason: Error) {
        runningTasks[id] = Task { [weak self] in
            self?.finishRunningTask(id: id, failure: Self.message(for: reason))
        }
    }

    private func exportUses(_ request: LibraryRenameRequest) -> Bool {
        current.contains { entry in
            guard case .ankiExport(let items, _, _) = entry.work else {
                return false
            }
            return items.contains { request.involves(videoPath: $0.videoPath) }
        }
    }

    private func runningRenameUses(_ items: [AnkiExportItem]) -> Bool {
        current.contains { entry in
            guard entry.record.state == .running,
                  case .rename(let request) = entry.work
            else {
                return false
            }
            return items.contains { request.involves(videoPath: $0.videoPath) }
        }
    }

    private func finishRunningTask(id: Int64, failure: String?, itemCount: Int? = nil) {
        defer { runningTasks[id] = nil }

        if let itemCount, let index = current.firstIndex(where: { $0.id == id }) {
            current[index].record = current[index].record.withItemCount(itemCount)
            let database = self.database
            writeQueue.async {
                do {
                    try database?.updateItemCount(id: id, to: itemCount)
                } catch {
                    print("Failed to update task item count: \(error)")
                }
            }
        }

        if cancelledTaskIDs.remove(id) != nil {
            // Whatever the task threw on the way down, the reader removed it;
            // that is what the record has to say.
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

        startEligibleTasks()
    }

    /// Waits until nothing is running. For tests, which drive the queue
    /// directly and have to know when its work is over.
    func waitUntilIdle() async {
        while let task = runningTasks.values.first {
            await task.value
        }
        await withCheckedContinuation { continuation in
            writeQueue.async {
                continuation.resume()
            }
        }
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
        let database = self.database
        writeQueue.async {
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
        if let refusal = error as? AnkiExportRefusal {
            switch refusal {
            case .renameRunning:
                return L("anki_export.error.rename_running")
            }
        }
        return error.localizedDescription
    }
}
