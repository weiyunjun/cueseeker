import Foundation
import Testing
import CueSeekerCore

@Test
func matchesSameDirectoryVideoByBaseName() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.srt")
    let video = root.appendingPathComponent("Movie.mkv")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: video)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(matcher.matchingVideo(for: subtitle) == video)
}

@Test
func matchesVideoAfterSimpleLanguageSuffixRemoval() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.en.srt")
    let video = root.appendingPathComponent("Movie.mp4")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: video)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(matcher.matchingVideo(for: subtitle) == video)
}

@Test
func returnsNilWhenNoMatchingVideoExists() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.srt")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(matcher.matchingVideo(for: subtitle) == nil)
}

