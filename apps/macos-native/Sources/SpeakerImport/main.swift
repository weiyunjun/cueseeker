import Foundation
import CueSeekerCore

private struct ImportOptions {
    let databaseURL: URL
    let sourceDirectory: URL
    let applyChanges: Bool
}

private struct SpeakerRow {
    let episode: Int
    let startMilliseconds: Int
    let endMilliseconds: Int
    let speaker: String
    let subtitle: String
}

private struct SuspectedSpeakerRow {
    let episode: Int
    let startMilliseconds: Int
    let endMilliseconds: Int
    let currentSpeaker: String
    let suspectedSpeaker: String
    let subtitle: String
}

private struct EpisodeImportReport {
    let episode: Int
    let subtitlePath: String
    let baseRows: Int
    let baseMatchedRows: Int
    let suspectedRows: Int
    let suspectedMatchedRows: Int
    let cueLineAssignments: Int
    let speakerTags: Int
    let unmatchedBaseRows: [SpeakerRow]
    let unmatchedSuspectedRows: [SuspectedSpeakerRow]
}

private struct CueLineKey: Hashable {
    let startMilliseconds: Int
    let endMilliseconds: Int
    let content: String
}

@main
struct SpeakerImport {
    static func main() throws {
        let options = try parseOptions()
        try DatabaseBootstrap.prepare(at: options.databaseURL)
        let database = try SubtitleDatabase(path: options.databaseURL)

        let subtitlePathsByEpisode = try myGOSubtitlePathsByEpisode(database: database)
        let baseRowsByEpisode = try loadBaseRowsByEpisode(sourceDirectory: options.sourceDirectory)
        let suspectedRowsByEpisode = try loadSuspectedRowsByEpisode(sourceDirectory: options.sourceDirectory)

        var reports: [EpisodeImportReport] = []
        for episode in 1...13 {
            guard let subtitlePath = subtitlePathsByEpisode[episode] else {
                throw ImportError.missingSubtitleFile(episode: episode)
            }

            let subtitleFile = URL(fileURLWithPath: subtitlePath)
            let cueLines = try database.cueLineRecords(forSubtitleFile: subtitleFile)
            let recordsByKey = Dictionary(grouping: cueLines) { record in
                CueLineKey(
                    startMilliseconds: record.line.startMilliseconds,
                    endMilliseconds: record.line.endMilliseconds,
                    content: normalizedSpeakerMatchContent(record.line.content)
                )
            }

            var speakersByCueLineID: [Int64: Set<String>] = [:]
            var matchedBaseRows = 0
            var unmatchedBaseRows: [SpeakerRow] = []
            for row in baseRowsByEpisode[episode] ?? [] {
                guard let record = bestRecord(
                    for: row,
                    recordsByKey: recordsByKey
                ) else {
                    unmatchedBaseRows.append(row)
                    continue
                }

                matchedBaseRows += 1
                speakersByCueLineID[record.id, default: []].insert(row.speaker)
            }

            var matchedSuspectedRows = 0
            var unmatchedSuspectedRows: [SuspectedSpeakerRow] = []
            for row in suspectedRowsByEpisode[episode] ?? [] {
                let records = suspectedRecords(for: row, recordsByKey: recordsByKey)
                guard !records.isEmpty else {
                    unmatchedSuspectedRows.append(row)
                    continue
                }

                matchedSuspectedRows += 1
                for record in records {
                    speakersByCueLineID[record.id, default: []].insert("疑似\(row.suspectedSpeaker)")
                }
            }

            let assignments = speakersByCueLineID
                .map { cueLineID, speakers in
                    SubtitleCueLineSpeakerAssignment(cueLineID: cueLineID, speakers: speakers)
                }
                .sorted { $0.cueLineID < $1.cueLineID }

            if options.applyChanges {
                try database.replaceCueLineSpeakers(
                    forSubtitleFile: subtitleFile,
                    assignments: assignments
                )
            }

            reports.append(
                EpisodeImportReport(
                    episode: episode,
                    subtitlePath: subtitlePath,
                    baseRows: (baseRowsByEpisode[episode] ?? []).count,
                    baseMatchedRows: matchedBaseRows,
                    suspectedRows: (suspectedRowsByEpisode[episode] ?? []).count,
                    suspectedMatchedRows: matchedSuspectedRows,
                    cueLineAssignments: assignments.count,
                    speakerTags: assignments.reduce(0) { $0 + $1.speakers.count },
                    unmatchedBaseRows: unmatchedBaseRows,
                    unmatchedSuspectedRows: unmatchedSuspectedRows
                )
            )
        }

        printReport(reports, applied: options.applyChanges)
        let hasUnmatchedRows = reports.contains {
            !$0.unmatchedBaseRows.isEmpty || !$0.unmatchedSuspectedRows.isEmpty
        }
        if hasUnmatchedRows {
            print("Import contains unmatched rows.")
            Foundation.exit(2)
        }
    }

    private static func parseOptions() throws -> ImportOptions {
        var databasePath: String?
        var sourceDirectoryPath = "/Users/weiyunjun/Documents/mygo"
        var applyChanges = false

        var arguments = Array(CommandLine.arguments.dropFirst())
        while !arguments.isEmpty {
            let argument = arguments.removeFirst()
            switch argument {
            case "--database":
                guard !arguments.isEmpty else {
                    throw ImportError.missingArgumentValue(argument)
                }
                databasePath = arguments.removeFirst()
            case "--source-dir":
                guard !arguments.isEmpty else {
                    throw ImportError.missingArgumentValue(argument)
                }
                sourceDirectoryPath = arguments.removeFirst()
            case "--apply":
                applyChanges = true
            case "--help", "-h":
                printUsage()
                Foundation.exit(0)
            default:
                throw ImportError.unknownArgument(argument)
            }
        }

        guard let databasePath else {
            throw ImportError.missingRequiredArgument("--database")
        }

        return ImportOptions(
            databaseURL: URL(fileURLWithPath: databasePath),
            sourceDirectory: URL(fileURLWithPath: sourceDirectoryPath),
            applyChanges: applyChanges
        )
    }

    private static func printUsage() {
        print(
            """
            Usage: SpeakerImport --database <CueSeeker.sqlite> [--source-dir /Users/weiyunjun/Documents/mygo] [--apply]

            Without --apply the command performs a dry-run and does not modify the database.
            """
        )
    }
}

private func myGOSubtitlePathsByEpisode(database: SubtitleDatabase) throws -> [Int: String] {
    var pathsByEpisode: [Int: String] = [:]
    for metadata in try database.subtitleFiles() {
        guard metadata.subtitleFormat == .ass,
              metadata.subtitlePath.contains("It's MyGO!!!!!"),
              metadata.subtitlePath.hasSuffix(".scjp.ass"),
              let episode = episodeNumber(fromSubtitlePath: metadata.subtitlePath)
        else {
            continue
        }

        pathsByEpisode[episode] = metadata.subtitlePath
    }
    return pathsByEpisode
}

private func loadBaseRowsByEpisode(sourceDirectory: URL) throws -> [Int: [SpeakerRow]] {
    var rowsByEpisode: [Int: [SpeakerRow]] = [:]
    for episode in 1...13 {
        let filename = "mygo_ep\(String(format: "%02d", episode))_Dial_JP_speakers.txt"
        let url = sourceDirectory.appendingPathComponent(filename)
        let rows = try parseTSV(url: url).map { columns -> SpeakerRow in
            guard columns.count >= 4 else {
                throw ImportError.invalidRow(path: url.path, columns: columns)
            }
            let range = try parseTimeRange(columns[1])
            return SpeakerRow(
                episode: episode,
                startMilliseconds: range.startMilliseconds,
                endMilliseconds: range.endMilliseconds,
                speaker: normalizedContent(columns[2]),
                subtitle: normalizedContent(columns[3])
            )
        }
        rowsByEpisode[episode] = rows
    }
    return rowsByEpisode
}

private func loadSuspectedRowsByEpisode(sourceDirectory: URL) throws -> [Int: [SuspectedSpeakerRow]] {
    let url = sourceDirectory.appendingPathComponent("mygo_ecapa_main_speaker_matches.txt")
    var rowsByEpisode: [Int: [SuspectedSpeakerRow]] = [:]
    for columns in try parseTSV(url: url) {
        guard columns.count >= 5 else {
            throw ImportError.invalidRow(path: url.path, columns: columns)
        }
        guard let episode = episodeNumber(fromEpisodeLabel: columns[0]) else {
            throw ImportError.invalidEpisodeLabel(columns[0])
        }

        let range = try parseTimeRange(columns[1])
        rowsByEpisode[episode, default: []].append(
            SuspectedSpeakerRow(
                episode: episode,
                startMilliseconds: range.startMilliseconds,
                endMilliseconds: range.endMilliseconds,
                currentSpeaker: normalizedContent(columns[2]),
                suspectedSpeaker: normalizedContent(columns[3]),
                subtitle: normalizedContent(columns[4])
            )
        )
    }
    return rowsByEpisode
}

private func parseTSV(url: URL) throws -> [[String]] {
    let contents = try String(contentsOf: url, encoding: .utf8)
        .replacingOccurrences(of: "\u{feff}", with: "")
    let lines = contents
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map(String.init)
    return lines.dropFirst().map { line in
        line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
    }
}

private func bestRecord(
    for row: SpeakerRow,
    recordsByKey: [CueLineKey: [SubtitleCueLineRecord]]
) -> SubtitleCueLineRecord? {
    let key = CueLineKey(
        startMilliseconds: row.startMilliseconds,
        endMilliseconds: row.endMilliseconds,
        content: normalizedSpeakerMatchContent(row.subtitle)
    )
    return recordsByKey[key]?.first
}

private func suspectedRecords(
    for row: SuspectedSpeakerRow,
    recordsByKey: [CueLineKey: [SubtitleCueLineRecord]]
) -> [SubtitleCueLineRecord] {
    let subtitleParts = row.subtitle
        .components(separatedBy: " || ")
        .map(normalizedSpeakerMatchContent)
        .filter { !$0.isEmpty }

    var records: [SubtitleCueLineRecord] = []
    var seenIDs = Set<Int64>()
    for part in subtitleParts {
        let matchingRecords = recordsByKey
            .filter { key, _ in
                key.startMilliseconds >= row.startMilliseconds &&
                    key.endMilliseconds <= row.endMilliseconds &&
                    key.content == part
            }
            .flatMap(\.value)
            .sorted {
                if $0.line.startMilliseconds == $1.line.startMilliseconds {
                    return $0.id < $1.id
                }
                return $0.line.startMilliseconds < $1.line.startMilliseconds
            }
        for record in matchingRecords where seenIDs.insert(record.id).inserted {
            records.append(record)
        }
    }
    return records
}

private func episodeNumber(fromSubtitlePath path: String) -> Int? {
    for episode in 1...13 {
        let marker = "][\(String(format: "%02d", episode))]["
        if path.contains(marker) {
            return episode
        }
    }
    return nil
}

private func episodeNumber(fromEpisodeLabel label: String) -> Int? {
    let trimmed = normalizedContent(label).uppercased()
    guard trimmed.hasPrefix("EP") else {
        return nil
    }
    return Int(trimmed.dropFirst(2))
}

private func parseTimeRange(_ text: String) throws -> (startMilliseconds: Int, endMilliseconds: Int) {
    let parts = text.split(separator: "-", maxSplits: 1).map(String.init)
    guard parts.count == 2 else {
        throw ImportError.invalidTimeRange(text)
    }
    return (
        startMilliseconds: try parseTimestamp(parts[0]),
        endMilliseconds: try parseTimestamp(parts[1])
    )
}

private func parseTimestamp(_ text: String) throws -> Int {
    let parts = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 3,
          let hours = Int(parts[0]),
          let minutes = Int(parts[1])
    else {
        throw ImportError.invalidTimestamp(text)
    }

    let secondParts = parts[2].split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        .map(String.init)
    guard let seconds = Int(secondParts[0]) else {
        throw ImportError.invalidTimestamp(text)
    }

    let milliseconds: Int
    if secondParts.count == 2 {
        let fraction = secondParts[1]
        let padded = String((fraction + "000").prefix(3))
        guard let parsedMilliseconds = Int(padded) else {
            throw ImportError.invalidTimestamp(text)
        }
        milliseconds = parsedMilliseconds
    } else {
        milliseconds = 0
    }

    return (((hours * 60) + minutes) * 60 + seconds) * 1_000 + milliseconds
}

private func normalizedContent(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func normalizedSpeakerMatchContent(_ text: String) -> String {
    var result = ""
    var isInsideBrace = false
    for character in normalizedContent(text) {
        if character == "{" {
            isInsideBrace = true
            continue
        }
        if character == "}" {
            isInsideBrace = false
            continue
        }
        if !isInsideBrace {
            result.append(character)
        }
    }
    return normalizedContent(result)
}

private func printReport(_ reports: [EpisodeImportReport], applied: Bool) {
    print(applied ? "Speaker import applied." : "Speaker import dry-run.")
    for report in reports {
        print(
            "EP\(String(format: "%02d", report.episode)): " +
                "base \(report.baseMatchedRows)/\(report.baseRows), " +
                "suspected \(report.suspectedMatchedRows)/\(report.suspectedRows), " +
                "cueLines \(report.cueLineAssignments), tags \(report.speakerTags)"
        )
        for row in report.unmatchedBaseRows.prefix(5) {
            print("  unmatched base: \(row.episode) \(row.startMilliseconds)-\(row.endMilliseconds) \(row.subtitle)")
        }
        for row in report.unmatchedSuspectedRows.prefix(5) {
            print("  unmatched suspected: \(row.episode) \(row.startMilliseconds)-\(row.endMilliseconds) \(row.subtitle)")
        }
    }
    let baseRows = reports.reduce(0) { $0 + $1.baseRows }
    let baseMatchedRows = reports.reduce(0) { $0 + $1.baseMatchedRows }
    let suspectedRows = reports.reduce(0) { $0 + $1.suspectedRows }
    let suspectedMatchedRows = reports.reduce(0) { $0 + $1.suspectedMatchedRows }
    let cueLineAssignments = reports.reduce(0) { $0 + $1.cueLineAssignments }
    let speakerTags = reports.reduce(0) { $0 + $1.speakerTags }
    print(
        "Total: base \(baseMatchedRows)/\(baseRows), " +
            "suspected \(suspectedMatchedRows)/\(suspectedRows), " +
            "cueLines \(cueLineAssignments), tags \(speakerTags)"
    )
}

private enum ImportError: Error, CustomStringConvertible {
    case missingArgumentValue(String)
    case missingRequiredArgument(String)
    case unknownArgument(String)
    case missingSubtitleFile(episode: Int)
    case invalidRow(path: String, columns: [String])
    case invalidEpisodeLabel(String)
    case invalidTimeRange(String)
    case invalidTimestamp(String)
    case unmatchedRows

    var description: String {
        switch self {
        case .missingArgumentValue(let argument):
            "Missing value for \(argument)"
        case .missingRequiredArgument(let argument):
            "Missing required argument \(argument)"
        case .unknownArgument(let argument):
            "Unknown argument \(argument)"
        case .missingSubtitleFile(let episode):
            "Missing indexed MyGO subtitle file for EP\(String(format: "%02d", episode))"
        case .invalidRow(let path, let columns):
            "Invalid TSV row in \(path): \(columns)"
        case .invalidEpisodeLabel(let label):
            "Invalid episode label: \(label)"
        case .invalidTimeRange(let text):
            "Invalid time range: \(text)"
        case .invalidTimestamp(let text):
            "Invalid timestamp: \(text)"
        case .unmatchedRows:
            "Import contains unmatched rows"
        }
    }
}
