import CNativePlayback
import CryptoKit
import CueSeekerCore
import Foundation
import SQLite3

struct AnkiExportItem: Sendable {
    let deckDisplayTitle: String
    let videoPath: String
    let startMilliseconds: Int
    let endMilliseconds: Int
    let text: String
    /// The card's Display Title and Time Range, as the table row shows them.
    let displayTitle: String
    let timeRange: String
    /// The Cue Group's other lines in subtitle order, without the Cue itself.
    let cueGroupOtherTexts: [String]
    /// Nil for a Excerpt without a Cue identity, which has no Deep Link.
    let cueID: Int64?
    let subtitlePath: String
    /// The video's default audio track, counted from 0 among its audio streams.
    var audioTrackIndex = 0
}

/// An item that can be placed on an Anki card.
enum AnkiCardItem: String, CaseIterable, Codable, Sendable, Identifiable {
    case screenshot
    case audio
    case cueText
    case cueGroupText
    case displayTitle
    case timeRange
    case deepLink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenshot:
            L("anki_export.item.screenshot")
        case .audio:
            L("anki_export.item.audio")
        case .cueText:
            L("anki_export.item.cue_text")
        case .cueGroupText:
            L("anki_export.item.cue_group_text")
        case .displayTitle:
            L("anki_export.item.display_title")
        case .timeRange:
            L("anki_export.item.time_range")
        case .deepLink:
            L("anki_export.item.deep_link")
        }
    }
}

/// What one export puts on its cards and their placement on Front and Back.
struct AnkiExportOptions: Equatable, Codable, Sendable {
    var frontItems: [AnkiCardItem] = [.audio]
    var backItems: [AnkiCardItem] = [.cueText]

    /// Items remaining for the specified side, preserved in canonical order.
    func remainingItems(for side: AnkiExportSide) -> [AnkiCardItem] {
        let assigned = Set(side == .front ? frontItems : backItems)
        return AnkiCardItem.allCases.filter { !assigned.contains($0) }
    }

    /// Whether a specific item is included on either front or back.
    func includes(_ item: AnkiCardItem) -> Bool {
        frontItems.contains(item) || backItems.contains(item)
    }
}

enum AnkiPackageExportError: Error, CustomStringConvertible {
    case emptyItems
    case ffmpegNotFound
    case sqliteOpenFailed(String)
    case sqliteExecuteFailed(String)
    case sqlitePrepareFailed(String)
    case sqliteBindFailed(String)
    case sqliteStepFailed(String)
    case processFailed(String, Int32)

    var description: String {
        switch self {
        case .emptyItems:
            L("export.error.no_items")
        case .ffmpegNotFound:
            L("export.error.ffmpeg_missing")
        case .sqliteOpenFailed(let message):
            L("export.error.database_create", message)
        case .sqliteExecuteFailed(let message):
            L("export.error.database_execute", message)
        case .sqlitePrepareFailed(let message):
            L("export.error.database_prepare", message)
        case .sqliteBindFailed(let message):
            L("export.error.database_bind", message)
        case .sqliteStepFailed(let message):
            L("export.error.database_write", message)
        case .processFailed(let executable, let status):
            L("export.error.process_exit", executable, status)
        }
    }
}

enum AnkiPackageExporter {
    private static let deckPrefix = "CueSeeker::"
    /// Two spaces between the items that share a line of the card.
    private static let itemSeparator = "&nbsp;&nbsp;"

    /// `onItemExported` reports how many cards are finished, once per card. It
    /// is called off the main actor, so a caller that drives UI with it has to
    /// hop.
    static func export(
        items: [AnkiExportItem],
        options: AnkiExportOptions,
        to destinationURL: URL,
        onItemExported: (@Sendable (Int) -> Void)? = nil
    ) async throws {
        guard !items.isEmpty else {
            throw AnkiPackageExportError.emptyItems
        }
        guard let ffmpegURL = ffmpegExecutableURL() else {
            throw AnkiPackageExportError.ffmpegNotFound
        }

        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueSeekerAnki-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: workspaceURL)
        }

        var notes: [AnkiPackageNote] = []
        var mediaMap: [String: String] = [:]
        var mediaIndex = 0
        var audioTrackIndexes: [String: Int] = [:]

        for (index, item) in items.enumerated() {
            try Task.checkCancellation()

            let baseName = "cueseeker_\(index + 1)_\(stableHash(item.videoPath + "\(item.startMilliseconds)"))"
            var audioField = ""
            if options.includes(.audio) {
                let audioName = "\(baseName).mp3"
                let audioMediaKey = "\(mediaIndex)"
                let audioURL = workspaceURL.appendingPathComponent(audioMediaKey)
                let audioExportURL = workspaceURL.appendingPathComponent("\(audioMediaKey).mp3")
                mediaMap[audioMediaKey] = audioName
                mediaIndex += 1

                let audioTrackIndex = audioTrackIndexes[item.videoPath] ?? audioTrackIndex(for: item)
                audioTrackIndexes[item.videoPath] = audioTrackIndex
                try await exportAudio(
                    item: item,
                    audioTrackIndex: audioTrackIndex,
                    ffmpegURL: ffmpegURL,
                    outputURL: audioExportURL
                )
                try FileManager.default.moveItem(at: audioExportURL, to: audioURL)
                audioField = "[sound:\(audioName)]"
            }

            var imageField = ""
            if options.includes(.screenshot) {
                let imageName = "\(baseName).jpg"
                let imageMediaKey = "\(mediaIndex)"
                let imageURL = workspaceURL.appendingPathComponent(imageMediaKey)
                let imageExportURL = workspaceURL.appendingPathComponent("\(imageMediaKey).jpg")
                mediaMap[imageMediaKey] = imageName
                mediaIndex += 1

                try await exportImage(item: item, ffmpegURL: ffmpegURL, outputURL: imageExportURL)
                try FileManager.default.moveItem(at: imageExportURL, to: imageURL)
                imageField = "<img src=\"\(imageName)\">"
            }

            let details = detailFields(for: item, options: options)
            notes.append(
                AnkiPackageNote(
                    deckName: deckPrefix + item.deckDisplayTitle,
                    audioField: audioField,
                    imageField: imageField,
                    textField: options.includes(.cueText) ? textHTML(for: item.text) : "",
                    cueGroupField: details.cueGroup,
                    displayTitleField: details.displayTitle,
                    timeRangeField: details.timeRange,
                    deepLinkField: details.deepLink
                )
            )

            onItemExported?(index + 1)
        }

        let collectionURL = workspaceURL.appendingPathComponent("collection.anki2")
        try createCollection(
            at: collectionURL,
            notes: notes,
            options: options
        )

        let mediaURL = workspaceURL.appendingPathComponent("media")
        let mediaData = try JSONSerialization.data(
            withJSONObject: mediaMap,
            options: [.sortedKeys]
        )
        try mediaData.write(to: mediaURL)

        try? FileManager.default.removeItem(at: destinationURL)
        try await runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/zip"),
            arguments: ["-q", "-r", destinationURL.path, "collection.anki2", "media"] + mediaMap.keys.sorted(),
            currentDirectoryURL: workspaceURL
        )
    }

    static func defaultFileName(exportedAt: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "CueSeeker-\(formatter.string(from: exportedAt)).apkg"
    }

    /// The item's default audio track when the file has it, otherwise the
    /// first. Only a track past the first needs the file inspected.
    private static func audioTrackIndex(for item: AnkiExportItem) -> Int {
        let resolvedInput = WebDAVClient.shared.resolvePlayableInput(
            for: URL.fromMediaPath(item.videoPath)
        )
        guard item.audioTrackIndex > 0,
              let metadata = try? SFXMediaMetadataInspector.metadata(
                atMediaPath: resolvedInput.inputPath,
                httpHeaders: resolvedInput.httpHeaders
              ),
              metadata.audioTracks.indices.contains(item.audioTrackIndex)
        else {
            return 0
        }
        return item.audioTrackIndex
    }

    private static func exportAudio(
        item: AnkiExportItem,
        audioTrackIndex: Int,
        ffmpegURL: URL,
        outputURL: URL
    ) async throws {
        let startSeconds = max(0, Double(item.startMilliseconds) / 1_000)
        let endMilliseconds = max(item.endMilliseconds, item.startMilliseconds + 100)
        let endSeconds = max(startSeconds + 0.1, Double(endMilliseconds) / 1_000)
        let resolvedInput = WebDAVClient.shared.resolvePlayableInput(
            for: URL.fromMediaPath(item.videoPath)
        )
        var arguments = [
            "-nostdin",
            "-y",
            "-hide_banner",
            "-loglevel", "error",
            "-ss", String(format: "%.3f", startSeconds),
            "-to", String(format: "%.3f", endSeconds)
        ]
        if let headers = resolvedInput.httpHeaders {
            arguments += ["-headers", headers]
        }
        arguments += [
            "-i", resolvedInput.inputPath,
            "-map", "0:a:\(audioTrackIndex)",
            "-vn",
            "-ac", "1",
            "-ar", "44100",
            "-codec:a", "libmp3lame",
            "-b:a", "96k",
            outputURL.path
        ]
        try await runProcess(
            executableURL: ffmpegURL,
            arguments: arguments
        )
    }

    private static func exportImage(
        item: AnkiExportItem,
        ffmpegURL: URL,
        outputURL: URL
    ) async throws {
        let midpointMilliseconds = max(0, (item.startMilliseconds + item.endMilliseconds) / 2)
        let midpointSeconds = Double(midpointMilliseconds) / 1_000
        let resolvedInput = WebDAVClient.shared.resolvePlayableInput(
            for: URL.fromMediaPath(item.videoPath)
        )
        var arguments = [
            "-nostdin",
            "-y",
            "-hide_banner",
            "-loglevel", "error",
            "-ss", String(format: "%.3f", midpointSeconds)
        ]
        if let headers = resolvedInput.httpHeaders {
            arguments += ["-headers", headers]
        }
        arguments += [
            "-i", resolvedInput.inputPath,
            "-frames:v", "1",
            "-q:v", "2",
            outputURL.path
        ]
        try await runProcess(
            executableURL: ffmpegURL,
            arguments: arguments
        )
    }

    private static func createCollection(
        at url: URL,
        notes: [AnkiPackageNote],
        options: AnkiExportOptions
    ) throws {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let database
        else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(database)
            throw AnkiPackageExportError.sqliteOpenFailed(message)
        }
        defer {
            sqlite3_close(database)
        }

        try execute(collectionSchemaSQL, in: database)

        let now = Int(Date().timeIntervalSince1970)
        let nowMilliseconds = Int64(Date().timeIntervalSince1970 * 1_000)
        let modelID = noteType(for: options).id
        let deckNames = orderedDeckNames(from: notes)
        let deckIDs = Dictionary(uniqueKeysWithValues: deckNames.map { ($0, deckID(for: $0)) })
        let defaultDeckID = deckIDs[deckNames.first ?? deckPrefix] ?? deckID(for: deckPrefix)
        let modelsJSON = try jsonString(
            modelJSON(options: options, deckID: defaultDeckID, now: now)
        )
        let decksJSON = try jsonString(
            Dictionary(uniqueKeysWithValues: deckNames.map { deckName in
                let deckID = deckIDs[deckName] ?? deckID(for: deckName)
                return (String(deckID), deckJSON(deckID: deckID, name: deckName, now: now))
            })
        )
        let dconfJSON = try jsonString(deckConfigJSON())
        let confJSON = try jsonString(confJSON(deckID: defaultDeckID, modelID: modelID))

        try insertCollection(
            database: database,
            now: now,
            nowMilliseconds: nowMilliseconds,
            confJSON: confJSON,
            modelsJSON: modelsJSON,
            decksJSON: decksJSON,
            dconfJSON: dconfJSON
        )

        for (index, note) in notes.enumerated() {
            let noteID = nowMilliseconds + 10 + Int64(index * 2)
            let cardID = noteID + 1
            let sortField = note.plainTextSortField
            try insertNote(
                database: database,
                id: noteID,
                modelID: modelID,
                now: now,
                guid: guid(seed: "\(noteID)-\(sortField)"),
                fields: note.fieldsString,
                sortField: sortField
            )
            try insertCard(
                database: database,
                id: cardID,
                noteID: noteID,
                deckID: deckIDs[note.deckName] ?? defaultDeckID,
                now: now,
                due: index + 1
            )
        }
    }

    private static func execute(_ sql: String, in database: OpaquePointer) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            sqlite3_free(errorMessage)
            throw AnkiPackageExportError.sqliteExecuteFailed(message)
        }
    }

    private static func insertCollection(
        database: OpaquePointer,
        now: Int,
        nowMilliseconds: Int64,
        confJSON: String,
        modelsJSON: String,
        decksJSON: String,
        dconfJSON: String
    ) throws {
        let sql = """
        INSERT INTO col VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        try withStatement(sql, database: database) { statement in
            try bind(1, at: 1, statement: statement, database: database)
            try bind(now / 86_400, at: 2, statement: statement, database: database)
            try bind(nowMilliseconds, at: 3, statement: statement, database: database)
            try bind(nowMilliseconds, at: 4, statement: statement, database: database)
            try bind(11, at: 5, statement: statement, database: database)
            try bind(0, at: 6, statement: statement, database: database)
            try bind(0, at: 7, statement: statement, database: database)
            try bind(0, at: 8, statement: statement, database: database)
            try bind(confJSON, at: 9, statement: statement, database: database)
            try bind(modelsJSON, at: 10, statement: statement, database: database)
            try bind(decksJSON, at: 11, statement: statement, database: database)
            try bind(dconfJSON, at: 12, statement: statement, database: database)
            try bind("{}", at: 13, statement: statement, database: database)
            try stepDone(statement, database: database)
        }
    }

    private static func insertNote(
        database: OpaquePointer,
        id: Int64,
        modelID: Int64,
        now: Int,
        guid: String,
        fields: String,
        sortField: String
    ) throws {
        let sql = """
        INSERT INTO notes VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        try withStatement(sql, database: database) { statement in
            try bind(id, at: 1, statement: statement, database: database)
            try bind(guid, at: 2, statement: statement, database: database)
            try bind(modelID, at: 3, statement: statement, database: database)
            try bind(now, at: 4, statement: statement, database: database)
            try bind(-1, at: 5, statement: statement, database: database)
            try bind(" cueseeker ", at: 6, statement: statement, database: database)
            try bind(fields, at: 7, statement: statement, database: database)
            try bind(sortField, at: 8, statement: statement, database: database)
            try bind(checksum(sortField), at: 9, statement: statement, database: database)
            try bind(0, at: 10, statement: statement, database: database)
            try bind("", at: 11, statement: statement, database: database)
            try stepDone(statement, database: database)
        }
    }

    private static func insertCard(
        database: OpaquePointer,
        id: Int64,
        noteID: Int64,
        deckID: Int64,
        now: Int,
        due: Int
    ) throws {
        let sql = """
        INSERT INTO cards VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        try withStatement(sql, database: database) { statement in
            try bind(id, at: 1, statement: statement, database: database)
            try bind(noteID, at: 2, statement: statement, database: database)
            try bind(deckID, at: 3, statement: statement, database: database)
            try bind(0, at: 4, statement: statement, database: database)
            try bind(now, at: 5, statement: statement, database: database)
            try bind(-1, at: 6, statement: statement, database: database)
            try bind(0, at: 7, statement: statement, database: database)
            try bind(0, at: 8, statement: statement, database: database)
            try bind(due, at: 9, statement: statement, database: database)
            try bind(0, at: 10, statement: statement, database: database)
            try bind(0, at: 11, statement: statement, database: database)
            try bind(0, at: 12, statement: statement, database: database)
            try bind(0, at: 13, statement: statement, database: database)
            try bind(0, at: 14, statement: statement, database: database)
            try bind(0, at: 15, statement: statement, database: database)
            try bind(0, at: 16, statement: statement, database: database)
            try bind(0, at: 17, statement: statement, database: database)
            try bind("", at: 18, statement: statement, database: database)
            try stepDone(statement, database: database)
        }
    }

    private static func withStatement(
        _ sql: String,
        database: OpaquePointer,
        body: (OpaquePointer) throws -> Void
    ) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw AnkiPackageExportError.sqlitePrepareFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer {
            sqlite3_finalize(statement)
        }
        try body(statement)
    }

    private static func bind(_ value: String, at index: Int32, statement: OpaquePointer, database: OpaquePointer) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw AnkiPackageExportError.sqliteBindFailed(String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func bind(_ value: Int, at index: Int32, statement: OpaquePointer, database: OpaquePointer) throws {
        try bind(Int64(value), at: index, statement: statement, database: database)
    }

    private static func bind(_ value: Int64, at index: Int32, statement: OpaquePointer, database: OpaquePointer) throws {
        guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else {
            throw AnkiPackageExportError.sqliteBindFailed(String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func stepDone(_ statement: OpaquePointer, database: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw AnkiPackageExportError.sqliteStepFailed(String(cString: sqlite3_errmsg(database)))
        }
    }

    /// Runs a helper and stops it if the export is cancelled.
    ///
    /// A cancel that only takes effect between cards leaves the reader waiting
    /// for the card already in flight, which for a long cue is several seconds
    /// of an action that visibly did nothing. The running helper is therefore
    /// terminated with the task, and the export ends on the error that
    /// termination produces.
    private static func runProcess(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) async throws {
        let runningProcess = RunningProcess()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments
                process.currentDirectoryURL = currentDirectoryURL
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                process.qualityOfService = .utility
                process.terminationHandler = { process in
                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(
                            throwing: AnkiPackageExportError.processFailed(
                                executableURL.lastPathComponent,
                                process.terminationStatus
                            )
                        )
                    }
                }
                // Cancellation can arrive before the helper is launched. Adopt
                // it first so that case ends here instead of starting work
                // nobody is waiting for.
                guard runningProcess.adopt(process) else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            runningProcess.terminate()
        }
    }

    /// The helper an in-flight `runProcess` is waiting on, so cancellation
    /// reaches it from whichever thread cancels.
    private final class RunningProcess: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var isCancelled = false

        /// Returns false when cancellation already arrived.
        func adopt(_ process: Process) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !isCancelled else {
                return false
            }
            self.process = process
            return true
        }

        func terminate() {
            lock.lock()
            isCancelled = true
            let running = process
            lock.unlock()
            running?.terminate()
        }
    }

    private static func ffmpegExecutableURL() -> URL? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/ffmpeg")
        let candidates = [
            bundled,
            URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
            URL(fileURLWithPath: "/usr/bin/ffmpeg")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// Stable note type derived from the exact items and order on Front and Back.
    private static func noteType(
        for options: AnkiExportOptions
    ) -> (id: Int64, name: String, templateName: String) {
        let signature = "front:" + options.frontItems.map(\.rawValue).joined(separator: ",")
            + "|back:" + options.backItems.map(\.rawValue).joined(separator: ",")
        let id = 1_780_000_000_000 + abs(checksum(signature)) % 900_000_000
        return (id, "CueSeeker Media Recall", "Cue Card")
    }

    static func _noteTypeForTesting(
        options: AnkiExportOptions
    ) -> (id: Int64, name: String, templateName: String) {
        noteType(for: options)
    }

    static func _cardTemplatesForTesting(
        options: AnkiExportOptions
    ) -> (question: String, answer: String) {
        cardTemplates(options: options)
    }

    /// Front items sit on the question face in order. Back items sit on the answer
    /// face below the divider in order.
    private static func cardTemplates(
        options: AnkiExportOptions
    ) -> (question: String, answer: String) {
        let questionBlock = options.frontItems
            .map { "  " + templateFragment(for: $0) }
            .joined(separator: "\n")
        let answerBlock = options.backItems
            .map { "  " + templateFragment(for: $0) }
            .joined(separator: "\n")
        return (
            """
            <div class="cue-card front">
            \(questionBlock)
            </div>
            """,
            """
            {{FrontSide}}
            <hr id="answer">
            <div class="cue-card back">
            \(answerBlock)
            </div>
            """
        )
    }

    private static func templateFragment(for item: AnkiCardItem) -> String {
        switch item {
        case .audio:
            "{{#Audio}}<div class=\"audio\">{{Audio}}</div>{{/Audio}}"
        case .screenshot:
            "{{#Image}}<div class=\"image\">{{Image}}</div>{{/Image}}"
        case .cueText:
            "{{#Text}}<div class=\"text\">{{Text}}</div>{{/Text}}"
        case .cueGroupText:
            "{{#CueGroup}}<div class=\"cue-group\">{{CueGroup}}</div>{{/CueGroup}}"
        case .displayTitle:
            "{{#DisplayTitle}}<div class=\"display-title\">{{DisplayTitle}}</div>{{/DisplayTitle}}"
        case .timeRange:
            "{{#TimeRange}}<div class=\"time-range\">{{TimeRange}}</div>{{/TimeRange}}"
        case .deepLink:
            "{{#DeepLink}}<div class=\"deep-link\">{{DeepLink}}</div>{{/DeepLink}}"
        }
    }

    private static func modelJSON(
        options: AnkiExportOptions,
        deckID: Int64,
        now: Int
    ) -> [String: Any] {
        let noteType = noteType(for: options)
        let templates = cardTemplates(options: options)
        let questionFields = options.frontItems.compactMap { item -> Int? in
            switch item {
            case .audio: 0
            case .screenshot: 1
            case .cueText: 2
            case .cueGroupText: 3
            case .displayTitle: 4
            case .timeRange: 5
            case .deepLink: 6
            }
        }
        let reqFields = questionFields.isEmpty ? [0] : questionFields
        return [
            String(noteType.id): [
                "id": noteType.id,
                "name": noteType.name,
                "type": 0,
                "mod": now,
                "usn": -1,
                "sortf": 2,
                "did": deckID,
                "flds": [
                    fieldJSON(name: "Audio", order: 0, size: 20),
                    fieldJSON(name: "Image", order: 1, size: 20),
                    fieldJSON(name: "Text", order: 2, size: 24),
                    fieldJSON(name: "CueGroup", order: 3, size: 20),
                    fieldJSON(name: "DisplayTitle", order: 4, size: 20),
                    fieldJSON(name: "TimeRange", order: 5, size: 20),
                    fieldJSON(name: "DeepLink", order: 6, size: 20)
                ],
                "tmpls": [
                    [
                        "name": noteType.templateName,
                        "ord": 0,
                        "qfmt": templates.question,
                        "afmt": templates.answer,
                        "bqfmt": "",
                        "bafmt": "",
                        "did": NSNull(),
                        "bfont": "",
                        "bsize": 0
                    ]
                ],
                "css": cardCSS,
                "latexPre": "\\documentclass[12pt]{article}\n\\special{papersize=3in,5in}\n\\usepackage[utf8]{inputenc}\n\\usepackage{amssymb,amsmath}\n\\pagestyle{empty}\n\\setlength{\\parindent}{0in}\n\\begin{document}\n",
                "latexPost": "\\end{document}",
                "latexsvg": false,
                "req": [[0, "any", reqFields]]
            ]
        ]
    }

    private static func fieldJSON(name: String, order: Int, size: Int) -> [String: Any] {
        [
            "name": name,
            "ord": order,
            "sticky": false,
            "rtl": false,
            "font": "Arial",
            "size": size,
            "description": "",
            "plainText": false,
            "collapsed": false,
            "excludeFromSearch": false,
            "tag": NSNull(),
            "preventDeletion": false
        ]
    }

    private static func deckJSON(deckID: Int64, name: String, now: Int) -> [String: Any] {
        [
            "id": deckID,
            "name": name,
            "desc": "",
            "dyn": 0,
            "collapsed": false,
            "browserCollapsed": false,
            "conf": 1,
            "extendNew": 10,
            "extendRev": 50,
            "mod": now,
            "usn": -1,
            "newToday": [0, 0],
            "revToday": [0, 0],
            "lrnToday": [0, 0],
            "timeToday": [0, 0]
        ]
    }

    private static func deckConfigJSON() -> [String: Any] {
        [
            "1": [
                "id": 1,
                "name": "Default",
                "mod": 0,
                "usn": 0,
                "maxTaken": 60,
                "autoplay": true,
                "timer": 0,
                "replayq": true,
                "new": [
                    "bury": false,
                    "delays": [1, 10],
                    "initialFactor": 2_500,
                    "ints": [1, 4, 7],
                    "order": 1,
                    "perDay": 20,
                    "separate": true
                ],
                "rev": [
                    "bury": false,
                    "ease4": 1.3,
                    "fuzz": 0.05,
                    "ivlFct": 1.0,
                    "maxIvl": 36_500,
                    "perDay": 200
                ],
                "lapse": [
                    "delays": [10],
                    "leechAction": 0,
                    "leechFails": 8,
                    "minInt": 1,
                    "mult": 0.0
                ]
            ]
        ]
    }

    private static func confJSON(deckID: Int64, modelID: Int64) -> [String: Any] {
        [
            "activeDecks": [deckID],
            "curDeck": deckID,
            "curModel": modelID,
            "newSpread": 0,
            "collapseTime": 1_200,
            "timeLim": 0,
            "estTimes": true,
            "dueCounts": true,
            "sortType": "noteFld",
            "sortBackwards": false,
            "addToCur": true,
            "nextPos": 1
        ]
    }

    private static func jsonString(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func _textHTMLForTesting(_ text: String) -> String {
        textHTML(for: text)
    }

    /// The item's detail fields. An item not included in options or with nothing
    /// to show is left empty, and an empty field is not rendered by the card.
    static func detailFields(
        for item: AnkiExportItem,
        options: AnkiExportOptions
    ) -> (cueGroup: String, displayTitle: String, timeRange: String, deepLink: String) {
        let cueGroup = options.includes(.cueGroupText)
            ? item.cueGroupOtherTexts.map(textHTML(for:)).joined(separator: "<br>")
            : ""
        let displayTitle = (options.includes(.displayTitle) && !item.displayTitle.isEmpty)
            ? htmlEscaped(item.displayTitle)
            : ""
        let timeRange = (options.includes(.timeRange) && !item.timeRange.isEmpty)
            ? htmlEscaped(item.timeRange)
            : ""
        let deepLink: String
        if options.includes(.deepLink), let cueID = item.cueID {
            deepLink = linkHTML(href: "cueseeker://cue?id=\(cueID)", icon: .linkSimple)
        } else {
            deepLink = ""
        }

        return (
            cueGroup,
            displayTitle,
            timeRange,
            deepLink
        )
    }

    /// Anki opens a card's links through the system: the Deep Link in
    /// CueSeeker, a file in the App the system opens it with.
    private static func linkHTML(href: String, icon: AppIcon) -> String {
        "<a href=\"\(htmlEscaped(href))\">\(linkIconMarkup[icon] ?? "")</a>"
    }

    /// The card's link icons, drawn from the App's own icon assets.
    private static let linkIconMarkup: [AppIcon: String] = Dictionary(
        uniqueKeysWithValues: [AppIcon.linkSimple].map { icon in
            let markup = Bundle.appResources.url(forResource: icon.rawValue, withExtension: "svg")
                .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            return (icon, markup ?? "")
        }
    )

    private static func textHTML(for text: String) -> String {
        let normalizedLineEndings = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return htmlEscaped(normalizedLineEndings)
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private static func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func checksum(_ value: String) -> Int64 {
        let digest = Insecure.SHA1.hash(data: Data(value.utf8))
        return digest.prefix(4).reduce(Int64(0)) { ($0 << 8) + Int64($1) }
    }

    private static func stableHash(_ value: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(value.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    private static func orderedDeckNames(from notes: [AnkiPackageNote]) -> [String] {
        var seen: Set<String> = []
        var names: [String] = []
        for note in notes where !seen.contains(note.deckName) {
            seen.insert(note.deckName)
            names.append(note.deckName)
        }
        return names.isEmpty ? [deckPrefix] : names
    }

    private static func deckID(for deckName: String) -> Int64 {
        let digest = Insecure.SHA1.hash(data: Data(deckName.utf8))
        let suffix = digest.prefix(5).reduce(Int64(0)) { ($0 << 8) + Int64($1) }
        return 1_781_000_000_000 + suffix % 900_000_000
    }

    private static func guid(seed: String) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let digest = Insecure.SHA1.hash(data: Data(seed.utf8))
        return digest.prefix(10).map { alphabet[Int($0) % alphabet.count] }.map(String.init).joined()
    }

    private static func safeFileName(_ value: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\")
        let safe = value
            .components(separatedBy: forbidden)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return safe.isEmpty ? L("export.anki_default_name") : safe
    }

    private static let collectionSchemaSQL = """
    CREATE TABLE col (
      id integer PRIMARY KEY,
      crt integer NOT NULL,
      mod integer NOT NULL,
      scm integer NOT NULL,
      ver integer NOT NULL,
      dty integer NOT NULL,
      usn integer NOT NULL,
      ls integer NOT NULL,
      conf text NOT NULL,
      models text NOT NULL,
      decks text NOT NULL,
      dconf text NOT NULL,
      tags text NOT NULL
    );
    CREATE TABLE notes (
      id integer PRIMARY KEY,
      guid text NOT NULL,
      mid integer NOT NULL,
      mod integer NOT NULL,
      usn integer NOT NULL,
      tags text NOT NULL,
      flds text NOT NULL,
      sfld text NOT NULL,
      csum integer NOT NULL,
      flags integer NOT NULL,
      data text NOT NULL
    );
    CREATE TABLE cards (
      id integer PRIMARY KEY,
      nid integer NOT NULL,
      did integer NOT NULL,
      ord integer NOT NULL,
      mod integer NOT NULL,
      usn integer NOT NULL,
      type integer NOT NULL,
      queue integer NOT NULL,
      due integer NOT NULL,
      ivl integer NOT NULL,
      factor integer NOT NULL,
      reps integer NOT NULL,
      lapses integer NOT NULL,
      left integer NOT NULL,
      odue integer NOT NULL,
      odid integer NOT NULL,
      flags integer NOT NULL,
      data text NOT NULL
    );
    CREATE TABLE revlog (
      id integer PRIMARY KEY,
      cid integer NOT NULL,
      usn integer NOT NULL,
      ease integer NOT NULL,
      ivl integer NOT NULL,
      lastIvl integer NOT NULL,
      factor integer NOT NULL,
      time integer NOT NULL,
      type integer NOT NULL
    );
    CREATE TABLE graves (
      usn integer NOT NULL,
      oid integer NOT NULL,
      type integer NOT NULL
    );
    CREATE INDEX ix_notes_usn ON notes (usn);
    CREATE INDEX ix_notes_csum ON notes (csum);
    CREATE INDEX ix_cards_usn ON cards (usn);
    CREATE INDEX ix_cards_nid ON cards (nid);
    CREATE INDEX ix_cards_sched ON cards (did, queue, due);
    """

    private static let cardCSS = """
    .card {
      font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Yu Gothic", "Noto Sans CJK JP", Arial, sans-serif;
      font-size: 24px;
      line-height: 1.45;
      text-align: center;
      color: #f4f4f5;
      background: #111114;
    }
    .cue-card { max-width: 900px; margin: 0 auto; }
    .audio { margin: 18px 0 16px; }
    .image img { width: 100%; max-width: 900px; height: auto; border-radius: 10px; }
    .text { margin-top: 18px; font-size: 30px; font-weight: 650; letter-spacing: 0; }
    .cue-group { margin-top: 12px; color: #a1a1aa; }
    .display-title { margin-top: 16px; font-size: 16px; color: #a1a1aa; }
    .time-range { margin-top: 8px; font-size: 14px; color: #71717a; }
    .deep-link { margin-top: 8px; font-size: 16px; }
    .deep-link a { color: #a1a1aa; text-decoration: none; }
    .deep-link svg { width: 20px; height: 20px; vertical-align: middle; }
    hr#answer { border: 0; border-top: 1px solid #3a3a40; margin: 22px 0; }
    """
}

private struct AnkiPackageNote {
    let deckName: String
    let audioField: String
    let imageField: String
    let textField: String
    let cueGroupField: String
    let displayTitleField: String
    let timeRangeField: String
    let deepLinkField: String

    var fieldsString: String {
        [audioField, imageField, textField, cueGroupField, displayTitleField, timeRangeField, deepLinkField]
            .joined(separator: "\u{1f}")
    }

    var plainTextSortField: String {
        let candidate = !textField.isEmpty ? textField : (!displayTitleField.isEmpty ? displayTitleField : audioField)
        return candidate
            .replacingOccurrences(of: "<br>", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
