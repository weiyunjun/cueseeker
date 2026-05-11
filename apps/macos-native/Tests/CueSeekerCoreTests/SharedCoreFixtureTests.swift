import Foundation
import Testing
import CueSeekerCore

@Test
func sharedSRTFixtureMatchesCurrentMacOSParser() throws {
    let root = try sharedFixtureRoot()
    let contents = try String(
        contentsOf: root.appendingPathComponent("subtitles/srt-baseline.srt"),
        encoding: .utf8
    )
    let expected = try expectedRows(
        at: root.appendingPathComponent("subtitles/srt-baseline.expected.tsv")
    )

    let actual = cueGroupRows(SRTParser.parseCueGroups(contents))

    #expect(actual == expected)
}

@Test
func sharedASSFixtureMatchesCurrentMacOSParser() throws {
    let root = try sharedFixtureRoot()
    let contents = try String(
        contentsOf: root.appendingPathComponent("subtitles/ass-baseline.ass"),
        encoding: .utf8
    )
    let expected = try expectedRows(
        at: root.appendingPathComponent("subtitles/ass-baseline.expected.tsv")
    )

    let actual = cueGroupRows(ASSParser.parseCueGroups(contents))

    #expect(actual == expected)
}

@Test
func sharedVideoMatchingFixtureMatchesCurrentMacOSMatcher() throws {
    let root = try sharedFixtureRoot().appendingPathComponent("video-matching")
    let contents = try String(
        contentsOf: root.appendingPathComponent("cases.tsv"),
        encoding: .utf8
    )
    let matcher = VideoMatcher()

    for line in contents.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
            continue
        }

        let fields = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
            .map(String.init)
        try #require(fields.count == 2)

        let subtitle = root.appendingPathComponent(fields[0])
        let actual = matcher.matchingVideo(for: subtitle).map { relativePath(from: root, to: $0) }
        let expected = fields[1] == "NONE" ? nil : fields[1]

        #expect(actual == expected)
    }
}

@Test
func sharedSubtitleScanningFixtureMatchesCurrentMacOSScanner() throws {
    let root = try sharedFixtureRoot()
    let scanningRoot = root.appendingPathComponent("scanning")
    let scanner = SubtitleFileScanner()
    let scanRoot = scanningRoot.appendingPathComponent("library")

    #expect(
        scanner.scanSubtitleFiles(in: scanRoot).map { relativePath(from: scanningRoot, to: $0) }
            == (try expectedRows(at: root.appendingPathComponent("scanning/expected-subtitles.txt")))
    )
    #expect(
        scanner.scanSRTFiles(in: scanRoot).map { relativePath(from: scanningRoot, to: $0) }
            == (try expectedRows(at: root.appendingPathComponent("scanning/expected-srt.txt")))
    )
}

@Test
func sharedSubtitleScannerSkipsSymlinkDirectories() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerScannerContractTests-\(UUID().uuidString)")
    let real = root.appendingPathComponent("Real")
    let linked = root.appendingPathComponent("Linked")

    try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
    try "subtitle".write(
        to: real.appendingPathComponent("LinkedOnly.srt"),
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.createSymbolicLink(at: linked, withDestinationURL: real)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let scanner = SubtitleFileScanner()
    let results = scanner.scanSubtitleFiles(in: root)

    #expect(
        results.map(\.standardizedFileURL)
            == [real.appendingPathComponent("LinkedOnly.srt").standardizedFileURL]
    )
}

@Test
func sharedSubtitleIndexingProjectionFixtureMatchesCurrentMacOSModules() throws {
    let root = try sharedFixtureRoot()
    let indexingRoot = root.appendingPathComponent("indexing")
    let actual = try indexingProjectionRows(
        root: indexingRoot,
        folder: indexingRoot.appendingPathComponent("library")
    )
    let expected = try expectedRows(
        at: root.appendingPathComponent("indexing/expected-projection.tsv")
    )

    #expect(actual == expected)
}

@Test
func sharedSearchFixtureMatchesCurrentMacOSDatabase() throws {
    let root = try sharedFixtureRoot()
    let searchRoot = root.appendingPathComponent("search")
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSharedSearch-\(UUID().uuidString).sqlite")

    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    let indexer = SubtitleIndexer()
    _ = try indexer.index(folder: searchRoot.appendingPathComponent("library"), into: database)

    let actual = try searchRows(
        root: searchRoot,
        database: database,
        casesURL: searchRoot.appendingPathComponent("cases.tsv")
    )
    let expected = try expectedRows(
        at: searchRoot.appendingPathComponent("expected-results.tsv")
    )

    #expect(actual == expected)
}

@Test
func sharedLibraryPresentationFixtureMatchesCurrentMacOSDatabase() throws {
    let root = try sharedFixtureRoot()
    let libraryRoot = root.appendingPathComponent("library")
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSharedLibrary-\(UUID().uuidString).sqlite")

    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()

    for row in try libraryIndexedVideos(at: libraryRoot.appendingPathComponent("indexed-videos.tsv")) {
        try database.replaceCueGroups(
            subtitleFile: URL(fileURLWithPath: row.subtitlePath),
            videoFile: URL(fileURLWithPath: row.videoPath),
            format: row.format,
            cueGroups: [sharedLibraryCueGroup(format: row.format)]
        )
        if let duration = row.duration {
            try database.updateVideoDuration(
                videoFile: URL(fileURLWithPath: row.videoPath),
                duration: duration
            )
        }
    }

    try database.rebuildLibraryPresentationSnapshot()
    let actual = try libraryPresentationRows(
        try database.libraryPresentation(under: [URL(fileURLWithPath: "/Media")])
    )
    let expected = try expectedRows(
        at: libraryRoot.appendingPathComponent("expected-presentation.tsv")
    )

    #expect(actual == expected)
}

@Test
func sharedShioriFixtureMatchesCurrentMacOSDatabase() throws {
    let root = try sharedFixtureRoot()
    let shioriRoot = root.appendingPathComponent("shiori")
    let databaseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSharedShiori-\(UUID().uuidString).sqlite")

    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try SubtitleDatabase(path: databaseURL)
    try database.migrate()
    try applyShioriOperations(
        at: shioriRoot.appendingPathComponent("operations.tsv"),
        to: database
    )

    let actual = shioriRows(try database.shioris())
    let expected = try expectedRows(
        at: shioriRoot.appendingPathComponent("expected-rows.tsv")
    )

    #expect(actual == expected)
}

private func sharedFixtureRoot() throws -> URL {
    var cursor = URL(fileURLWithPath: #filePath)
    while cursor.path != "/" {
        let candidate = cursor.appendingPathComponent("fixtures/shared-core")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        cursor.deleteLastPathComponent()
    }

    throw SharedFixtureError.notFound
}

private func searchRows(root: URL, database: SubtitleDatabase, casesURL: URL) throws -> [String] {
    let cases = try searchCases(at: casesURL)
    var rows: [String] = []

    for searchCase in cases {
        let page = try database.searchPage(
            searchCase.query,
            limit: searchCase.limit,
            offset: searchCase.offset
        )
        rows.append([
            "case",
            searchCase.name,
            String(page.totalCount)
        ].joined(separator: "\t"))

        for result in page.results {
            rows.append([
                "result",
                relativePath(from: root, to: URL(fileURLWithPath: result.subtitlePath)),
                relativePath(from: root, to: URL(fileURLWithPath: result.videoPath)),
                result.subtitleFormat.rawValue,
                String(result.startMilliseconds),
                String(result.endMilliseconds),
                escapeText(result.content),
                escapeText(result.cueLines.joined(separator: "\n"))
            ].joined(separator: "\t"))
        }
    }

    return rows
}

private func searchCases(at url: URL) throws -> [SharedSearchCase] {
    try String(contentsOf: url, encoding: .utf8)
        .components(separatedBy: .newlines)
        .compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                return nil
            }

            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
                .map(String.init)
            guard fields.count == 4,
                  let limit = Int(fields[2]),
                  let offset = Int(fields[3])
            else {
                return nil
            }

            return SharedSearchCase(
                name: fields[0],
                query: fields[1] == "<EMPTY>" ? "" : fields[1],
                limit: limit,
                offset: offset
            )
        }
}

private struct SharedSearchCase {
    let name: String
    let query: String
    let limit: Int
    let offset: Int
}

private func libraryIndexedVideos(at url: URL) throws -> [SharedLibraryVideoRow] {
    try String(contentsOf: url, encoding: .utf8)
        .components(separatedBy: .newlines)
        .compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                return nil
            }

            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
                .map(String.init)
            guard fields.count == 4,
                  let format = SubtitleFormat(rawValue: fields[2])
            else {
                return nil
            }

            return SharedLibraryVideoRow(
                subtitlePath: fields[0],
                videoPath: fields[1],
                format: format,
                duration: fields[3] == "NONE" ? nil : Double(fields[3])
            )
        }
}

private struct SharedLibraryVideoRow {
    let subtitlePath: String
    let videoPath: String
    let format: SubtitleFormat
    let duration: Double?
}

private func sharedLibraryCueGroup(format: SubtitleFormat) -> SubtitleCueGroup {
    SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "00:00:01,000",
        endTimecode: "00:00:02,000",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        searchContent: "library fixture",
        cueLines: [
            SubtitleCueLine(
                eventIndex: 0,
                sourceFormat: format,
                sourceStyle: nil,
                sourceLayer: nil,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:02,000",
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "library fixture",
                displayX: nil,
                displayY: nil,
                displayOrder: 0
            )
        ]
    )
}

private func libraryPresentationRows(_ folders: [LibraryFolderPresentation]) throws -> [String] {
    var rows: [String] = []

    for folder in folders {
        rows.append([
            "folder",
            folder.folderPath,
            folder.folderTitle
        ].joined(separator: "\t"))

        for video in folder.videos {
            rows.append([
                "video",
                folder.folderPath,
                folder.folderTitle,
                video.videoPath,
                video.videoName,
                formatOptionalDouble(video.duration),
                video.subtitlePath,
                video.subtitleFormat.rawValue,
                video.displayTitle,
                video.fileExtension
            ].joined(separator: "\t"))
        }
    }

    return rows
}

private func applyShioriOperations(at url: URL, to database: SubtitleDatabase) throws {
    let dateFormatter = ISO8601DateFormatter()
    for line in try expectedRows(at: url) {
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            .map(String.init)
        try #require(fields.count == 9)

        let subtitleFile = URL(fileURLWithPath: fields[1])
        let startMilliseconds = try #require(Int(fields[3]))
        let endMilliseconds = try #require(Int(fields[4]))

        switch fields[0] {
        case "upsert":
            let format = try #require(SubtitleFormat(rawValue: fields[2]))
            let createdAt = try #require(dateFormatter.date(from: fields[8]))
            _ = try database.upsertShiori(
                subtitleFile: subtitleFile,
                subtitleFormat: format,
                videoFile: URL(fileURLWithPath: fields[5]),
                videoName: fields[6],
                selection: SubtitleCueTextSelection(
                    cueGroupID: 0,
                    startMilliseconds: startMilliseconds,
                    endMilliseconds: endMilliseconds,
                    lines: unescapeText(fields[7]).components(separatedBy: .newlines)
                ),
                createdAt: createdAt
            )
        case "remove":
            _ = try database.removeShiori(
                subtitleFile: subtitleFile,
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds
            )
        default:
            Issue.record("Unknown Shiori operation: \(fields[0])")
        }
    }
}

private func shioriRows(_ shioris: [Shiori]) -> [String] {
    shioris.map { shiori in
        [
            "shiori",
            String(shiori.id),
            shiori.subtitlePath,
            shiori.subtitleFormat.rawValue,
            shiori.videoPath,
            shiori.videoName,
            String(shiori.startMilliseconds),
            String(shiori.endMilliseconds),
            escapeText(shiori.content),
            String(shiori.isValid),
            shiori.createdAt,
            shiori.cueLines.joined(separator: "|")
        ].joined(separator: "\t")
    }
}

private func indexingProjectionRows(root: URL, folder: URL) throws -> [String] {
    let scanner = SubtitleFileScanner()
    let matcher = VideoMatcher()
    let subtitleFiles = scanner.scanSubtitleFiles(in: folder)
    var indexedFiles: [(subtitle: URL, video: URL, format: SubtitleFormat, cueGroups: [SubtitleCueGroup])] = []
    var skippedMissingVideo = 0
    var skippedUnreadableSubtitle = 0
    var failedFiles: [String] = []

    for subtitleFile in subtitleFiles {
        guard let videoFile = matcher.matchingVideo(for: subtitleFile) else {
            skippedMissingVideo += 1
            continue
        }

        let contents: String
        do {
            contents = try String(contentsOf: subtitleFile)
        } catch {
            skippedUnreadableSubtitle += 1
            failedFiles.append(subtitleFile.path)
            continue
        }

        guard let format = subtitleFormat(for: subtitleFile) else {
            continue
        }

        let cueGroups: [SubtitleCueGroup]
        switch format {
        case .srt:
            cueGroups = SRTParser.parseCueGroups(contents)
        case .ass:
            cueGroups = ASSParser.parseCueGroups(contents)
        }

        indexedFiles.append((subtitleFile, videoFile, format, cueGroups))
    }

    var rows = [[
        "summary",
        String(subtitleFiles.count),
        String(indexedFiles.count),
        String(indexedFiles.reduce(0) { $0 + $1.cueGroups.count }),
        String(skippedMissingVideo),
        String(skippedUnreadableSubtitle),
        String(failedFiles.count)
    ].joined(separator: "\t")]

    for file in indexedFiles {
        rows.append([
            "file",
            relativePath(from: root, to: file.subtitle),
            relativePath(from: root, to: file.video),
            file.format.rawValue,
            String(file.cueGroups.count)
        ].joined(separator: "\t"))
        rows.append(contentsOf: cueGroupRows(file.cueGroups))
    }

    return rows
}

private func subtitleFormat(for url: URL) -> SubtitleFormat? {
    switch url.pathExtension.lowercased() {
    case "srt":
        return .srt
    case "ass":
        return .ass
    default:
        return nil
    }
}

private func expectedRows(at url: URL) throws -> [String] {
    try String(contentsOf: url, encoding: .utf8)
        .components(separatedBy: .newlines)
        .filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }
}

private func cueGroupRows(_ groups: [SubtitleCueGroup]) -> [String] {
    var rows: [String] = []

    for group in groups {
        rows.append([
            "group",
            group.sequenceNumber.map(String.init) ?? "",
            group.startTimecode,
            group.endTimecode,
            String(group.startMilliseconds),
            String(group.endMilliseconds),
            escapeText(group.searchContent)
        ].joined(separator: "\t"))

        for line in group.cueLines {
            rows.append([
                "line",
                String(line.eventIndex),
                line.sourceFormat.rawValue,
                line.sourceStyle ?? "",
                line.sourceLayer.map(String.init) ?? "",
                line.startTimecode,
                line.endTimecode,
                String(line.startMilliseconds),
                String(line.endMilliseconds),
                escapeText(line.content),
                formatOptionalDouble(line.displayX),
                formatOptionalDouble(line.displayY),
                String(line.displayOrder)
            ].joined(separator: "\t"))
        }
    }

    return rows
}

private func escapeText(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\t", with: "\\t")
}

private func unescapeText(_ text: String) -> String {
    var result = ""
    var iterator = text.makeIterator()

    while let character = iterator.next() {
        if character == "\\" {
            switch iterator.next() {
            case "n":
                result.append("\n")
            case "t":
                result.append("\t")
            case "\\":
                result.append("\\")
            case .some(let escaped):
                result.append("\\")
                result.append(escaped)
            case .none:
                result.append("\\")
            }
        } else {
            result.append(character)
        }
    }

    return result
}

private func formatOptionalDouble(_ value: Double?) -> String {
    guard let value else {
        return ""
    }

    if value.rounded() == value {
        return String(Int(value))
    }

    return String(value)
}

private func relativePath(from root: URL, to url: URL) -> String {
    let rootPath = root.standardizedFileURL.path
    let path = url.standardizedFileURL.path
    let relative = path.dropFirst(rootPath.count + 1)
    return String(relative)
}

private enum SharedFixtureError: Error {
    case notFound
}
