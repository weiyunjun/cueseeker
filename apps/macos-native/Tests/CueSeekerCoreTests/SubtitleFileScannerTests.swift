import Foundation
import Testing
import CueSeekerCore

@Test
func scansSupportedSubtitleFilesRecursivelyAndIgnoresOtherFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerScannerTests-\(UUID().uuidString)")
    let nested = root.appendingPathComponent("Nested")

    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try "one".write(to: root.appendingPathComponent("Movie.srt"), atomically: true, encoding: .utf8)
    try "two".write(to: nested.appendingPathComponent("Episode.SRT"), atomically: true, encoding: .utf8)
    try "three".write(to: nested.appendingPathComponent("Episode.ass"), atomically: true, encoding: .utf8)
    try "four".write(to: nested.appendingPathComponent("Episode.vtt"), atomically: true, encoding: .utf8)
    try "ignore".write(to: root.appendingPathComponent("Movie.txt"), atomically: true, encoding: .utf8)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let scanner = SubtitleFileScanner()
    let results = scanner.scanSubtitleFiles(in: root)

    #expect(results.map(\.lastPathComponent) == ["Movie.srt", "Episode.SRT", "Episode.ass", "Episode.vtt"])
    #expect(scanner.scanSRTFiles(in: root).map(\.lastPathComponent) == ["Movie.srt", "Episode.SRT"])
}

@Test
func safeScanRejectsAFileAsLibraryRoot() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerScannerFile-\(UUID().uuidString)")
    try "not a directory".write(to: root, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    #expect(throws: SubtitleFileScanningError.rootIsNotReadableDirectory(root.path)) {
        try SubtitleFileScanner().scanSubtitleFilesSafely(in: root)
    }
}
