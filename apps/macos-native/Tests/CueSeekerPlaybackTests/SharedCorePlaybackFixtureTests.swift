import Foundation
import Testing
import CueSeekerPlayback

@Test
func sharedPlaybackIntentFixtureMatchesCurrentMacOSPlaybackRequest() throws {
    let root = try sharedFixtureRoot().appendingPathComponent("playback-intent")
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSharedPlayback-\(UUID().uuidString)", isDirectory: true)

    defer {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

    let actual = try playbackRows(
        casesURL: root.appendingPathComponent("cases.tsv"),
        tempRoot: tempRoot
    )
    let expected = try expectedRows(at: root.appendingPathComponent("expected-rows.tsv"))

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

private func playbackRows(casesURL: URL, tempRoot: URL) throws -> [String] {
    try expectedRows(at: casesURL).map { line in
        let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            .map(String.init)
        try #require(fields.count == 13)

        let caseName = fields[0]
        let videoURL = try playbackVideoURL(kind: fields[1], logicalPath: fields[2], tempRoot: tempRoot)
        if fields[3] == "true", videoURL.isFileURL {
            try createEmptyFile(at: videoURL)
        }

        do {
            let request = try PlaybackRequest(
                videoURL: videoURL,
                startMilliseconds: try #require(Int(fields[4])),
                subtitleSource: try playbackSubtitleSource(fields: fields, tempRoot: tempRoot)
            )
            return playbackRequestRow(caseName: caseName, request: request, tempRoot: tempRoot)
        } catch PlaybackError.missingVideoFile(_) {
            return [caseName, "missingVideoFile"].joined(separator: "\t")
        } catch PlaybackError.invalidVideoURL(_) {
            return [caseName, "invalidVideoURL"].joined(separator: "\t")
        }
    }
}

private func playbackVideoURL(kind: String, logicalPath: String, tempRoot: URL) throws -> URL {
    switch kind {
    case "file":
        return fileURL(forLogicalPath: logicalPath, tempRoot: tempRoot)
    case "remote":
        return try #require(URL(string: logicalPath))
    default:
        throw SharedFixtureError.invalidPlaybackURLKind(kind)
    }
}

private func playbackSubtitleSource(fields: [String], tempRoot: URL) throws -> PlaybackSubtitleSource? {
    guard fields[5] != "none" else {
        return nil
    }

    let timeWindow: PlaybackSubtitleTimeWindow?
    if fields[9] == "NONE" {
        timeWindow = nil
    } else {
        timeWindow = PlaybackSubtitleTimeWindow(
            startMilliseconds: try #require(Int(fields[9])),
            endMilliseconds: try #require(Int(fields[10]))
        )
    }

    return PlaybackSubtitleSource(
        url: fileURL(forLogicalPath: fields[6], tempRoot: tempRoot),
        format: .ass,
        matchedVideoURL: optionalFileURL(forLogicalPath: fields[7], tempRoot: tempRoot),
        fontResourceDirectoryURL: optionalFileURL(forLogicalPath: fields[8], tempRoot: tempRoot),
        preparationTimeWindow: timeWindow,
        renderCacheDatabaseURL: optionalFileURL(forLogicalPath: fields[11], tempRoot: tempRoot)
    )
}

private func playbackRequestRow(caseName: String, request: PlaybackRequest, tempRoot: URL) -> String {
    let source = request.subtitleSource
    return [
        caseName,
        "ok",
        String(request.startMilliseconds),
        source?.format.rawValue ?? "none",
        logicalPath(source?.matchedVideoURL, tempRoot: tempRoot),
        logicalPath(source?.fontResourceDirectoryURL, tempRoot: tempRoot),
        source?.preparationTimeWindow.map { String($0.startMilliseconds) } ?? "NONE",
        source?.preparationTimeWindow.map { String($0.endMilliseconds) } ?? "NONE",
        logicalPath(source?.renderCacheDatabaseURL, tempRoot: tempRoot)
    ].joined(separator: "\t")
}

private func fileURL(forLogicalPath path: String, tempRoot: URL) -> URL {
    let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return tempRoot.appendingPathComponent(relativePath)
}

private func optionalFileURL(forLogicalPath path: String, tempRoot: URL) -> URL? {
    path == "NONE" ? nil : fileURL(forLogicalPath: path, tempRoot: tempRoot)
}

private func logicalPath(_ url: URL?, tempRoot: URL) -> String {
    guard let url else {
        return "NONE"
    }

    let rootPath = tempRoot.standardizedFileURL.path
    let path = url.standardizedFileURL.path
    guard path.hasPrefix(rootPath + "/") else {
        return url.path
    }

    return "/" + String(path.dropFirst(rootPath.count + 1))
}

private func createEmptyFile(at url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data().write(to: url)
}

private func expectedRows(at url: URL) throws -> [String] {
    try String(contentsOf: url, encoding: .utf8)
        .components(separatedBy: .newlines)
        .filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }
}

private enum SharedFixtureError: Error {
    case notFound
    case invalidPlaybackURLKind(String)
}
