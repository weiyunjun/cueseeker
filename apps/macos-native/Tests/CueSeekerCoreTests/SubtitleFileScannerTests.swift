import Foundation
import Testing
import CueSeekerCore

@Test
func scansSRTFilesRecursivelyAndIgnoresOtherFiles() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerScannerTests-\(UUID().uuidString)")
    let nested = root.appendingPathComponent("Nested")

    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try "one".write(to: root.appendingPathComponent("Movie.srt"), atomically: true, encoding: .utf8)
    try "two".write(to: nested.appendingPathComponent("Episode.SRT"), atomically: true, encoding: .utf8)
    try "ignore".write(to: root.appendingPathComponent("Movie.txt"), atomically: true, encoding: .utf8)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let scanner = SubtitleFileScanner()
    let results = scanner.scanSRTFiles(in: root)

    #expect(results.map(\.lastPathComponent) == ["Movie.srt", "Episode.SRT"])
}

