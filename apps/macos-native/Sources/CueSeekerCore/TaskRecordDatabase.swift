import Foundation

/// Where a task sits. `running` and `queued` are what the Current tab shows;
/// the other two are the history the Completed and Incomplete tabs show.
public enum TaskRecordState: String, Sendable, CaseIterable {
    case running
    case queued
    case completed
    case incomplete
}

/// The work a task performs.
public enum TaskRecordKind: String, Sendable {
    case ankiExport = "anki_export"
    case renameFolder = "rename_folder"
    case renameFiles = "rename_files"
}

public struct TaskRecord: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let kind: TaskRecordKind
    public let fileName: String
    public let folderPath: String
    public let itemCount: Int
    public let state: TaskRecordState
    public let errorMessage: String?
    public let createdAt: Date
    /// When the task entered the state it is in. The history tabs show it.
    public let stateChangedAt: Date
    /// What a rename task moves, as absolute paths before and after. Empty
    /// for an export.
    public let oldPaths: [String]
    public let newPaths: [String]

    public init(
        id: Int64,
        kind: TaskRecordKind,
        fileName: String,
        folderPath: String,
        itemCount: Int,
        state: TaskRecordState,
        errorMessage: String?,
        createdAt: Date,
        stateChangedAt: Date,
        oldPaths: [String] = [],
        newPaths: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.fileName = fileName
        self.folderPath = folderPath
        self.itemCount = itemCount
        self.state = state
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.stateChangedAt = stateChangedAt
        self.oldPaths = oldPaths
        self.newPaths = newPaths
    }

    public func withState(
        _ state: TaskRecordState,
        errorMessage: String?,
        changedAt: Date
    ) -> TaskRecord {
        TaskRecord(
            id: id,
            kind: kind,
            fileName: fileName,
            folderPath: folderPath,
            itemCount: itemCount,
            state: state,
            errorMessage: errorMessage,
            createdAt: createdAt,
            stateChangedAt: changedAt,
            oldPaths: oldPaths,
            newPaths: newPaths
        )
    }
}

/// The task queue's durable side.
///
/// Progress is deliberately not stored. It changes once per exported card and
/// means nothing to a later launch, which never resumes a task; writing it
/// would put the database in the path of every progress tick for no answer it
/// could give back. What a later launch does have to answer — that a task
/// existed, what it was writing, and how it ended — is what lives here.
///
/// A running or queued row is therefore a claim by a process that is still
/// alive. If the App never gets to finish that row, the next launch finds it
/// and closes it out; see `markUnfinishedTasksIncomplete`.
public final class TaskRecordDatabase: @unchecked Sendable {
    private static let selectSQL = """
        SELECT id,
               kind,
               file_name,
               folder_path,
               item_count,
               state,
               error_message,
               created_at,
               state_changed_at,
               old_paths,
               new_paths
        FROM task_records
        """

    private let database: SQLiteDatabase

    public init(
        path: URL,
        access: DatabaseConnectionAccess = .readWrite
    ) throws {
        database = try SQLiteDatabase(path: path, access: access)
    }

    /// Every task, oldest first. One read at launch is enough: the store keeps
    /// the list in memory afterwards and writes through to here.
    public func records() throws -> [TaskRecord] {
        let statement = try database.prepare("\(Self.selectSQL) ORDER BY id ASC;")
        var records: [TaskRecord] = []
        while try statement.step() {
            if let record = Self.record(from: statement) {
                records.append(record)
            }
        }
        return records
    }

    public func insertQueuedTask(
        kind: TaskRecordKind,
        fileName: String,
        folderPath: String,
        itemCount: Int,
        oldPaths: [String] = [],
        newPaths: [String] = [],
        createdAt: Date = Date()
    ) throws -> TaskRecord {
        let timestamp = Self.timestamp(from: createdAt)
        let statement = try database.prepare(
            """
            INSERT INTO task_records(
                kind, file_name, folder_path, item_count,
                state, error_message, created_at, state_changed_at,
                old_paths, new_paths
            )
            VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?);
            """
        )
        try statement.bind(kind.rawValue, at: 1)
        try statement.bind(fileName, at: 2)
        try statement.bind(folderPath, at: 3)
        try statement.bind(itemCount, at: 4)
        try statement.bind(TaskRecordState.queued.rawValue, at: 5)
        try statement.bind(timestamp, at: 6)
        try statement.bind(timestamp, at: 7)
        try bindPaths(oldPaths, to: statement, at: 8)
        try bindPaths(newPaths, to: statement, at: 9)
        try statement.run()

        return TaskRecord(
            id: database.lastInsertRowID(),
            kind: kind,
            fileName: fileName,
            folderPath: folderPath,
            itemCount: itemCount,
            state: .queued,
            errorMessage: nil,
            createdAt: createdAt,
            stateChangedAt: createdAt,
            oldPaths: oldPaths,
            newPaths: newPaths
        )
    }

    /// Paths are stored one per line; a path cannot contain a newline.
    private func bindPaths(_ paths: [String], to statement: SQLiteStatement, at index: Int32) throws {
        if paths.isEmpty {
            try statement.bindNull(at: index)
        } else {
            try statement.bind(paths.joined(separator: "\n"), at: index)
        }
    }

    private static func paths(from value: String?) -> [String] {
        guard let value, !value.isEmpty else {
            return []
        }
        return value.components(separatedBy: "\n")
    }

    public func updateState(
        id: Int64,
        to state: TaskRecordState,
        errorMessage: String? = nil,
        changedAt: Date = Date()
    ) throws {
        let statement = try database.prepare(
            """
            UPDATE task_records
            SET state = ?, error_message = ?, state_changed_at = ?
            WHERE id = ?;
            """
        )
        try statement.bind(state.rawValue, at: 1)
        if let errorMessage {
            try statement.bind(errorMessage, at: 2)
        } else {
            try statement.bindNull(at: 2)
        }
        try statement.bind(Self.timestamp(from: changedAt), at: 3)
        try statement.bind(id, at: 4)
        try statement.run()
    }

    public func deleteRecord(id: Int64) throws {
        let statement = try database.prepare("DELETE FROM task_records WHERE id = ?;")
        try statement.bind(id, at: 1)
        try statement.run()
    }

    /// Closes out what the previous launch left open. A row still marked
    /// running or queued belongs to a process that is gone, so it never
    /// finished; the queue does not resume across launches.
    @discardableResult
    public func markUnfinishedTasksIncomplete(
        message: String,
        at date: Date = Date()
    ) throws -> Int {
        let statement = try database.prepare(
            """
            UPDATE task_records
            SET state = ?, error_message = ?, state_changed_at = ?
            WHERE state IN (?, ?);
            """
        )
        try statement.bind(TaskRecordState.incomplete.rawValue, at: 1)
        try statement.bind(message, at: 2)
        try statement.bind(Self.timestamp(from: date), at: 3)
        try statement.bind(TaskRecordState.running.rawValue, at: 4)
        try statement.bind(TaskRecordState.queued.rawValue, at: 5)
        try statement.run()
        return database.changesCount()
    }

    private static func record(from statement: SQLiteStatement) -> TaskRecord? {
        guard let kind = TaskRecordKind(rawValue: statement.stringColumn(1)),
              let state = TaskRecordState(rawValue: statement.stringColumn(5)),
              let createdAt = date(from: statement.stringColumn(7))
        else {
            return nil
        }

        return TaskRecord(
            id: statement.int64Column(0),
            kind: kind,
            fileName: statement.stringColumn(2),
            folderPath: statement.stringColumn(3),
            itemCount: statement.intColumn(4),
            state: state,
            errorMessage: statement.nullableStringColumn(6),
            createdAt: createdAt,
            stateChangedAt: date(from: statement.stringColumn(8)) ?? createdAt,
            oldPaths: paths(from: statement.nullableStringColumn(9)),
            newPaths: paths(from: statement.nullableStringColumn(10))
        )
    }

    private static func timestamp(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func date(from value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
