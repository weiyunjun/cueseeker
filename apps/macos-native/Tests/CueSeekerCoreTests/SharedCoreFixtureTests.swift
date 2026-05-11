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
