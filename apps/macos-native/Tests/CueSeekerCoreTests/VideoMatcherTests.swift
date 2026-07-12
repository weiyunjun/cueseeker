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
func matchesVideoAfterFinalBasenameSuffixRemoval() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.commentary.srt")
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
func prefersCompleteBasenameAcrossVideoExtensions() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.commentary.ass")
    let exactVideo = root.appendingPathComponent("Movie.commentary.mkv")
    let fallbackVideo = root.appendingPathComponent("Movie.mp4")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: exactVideo)
    try Data().write(to: fallbackVideo)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(matcher.matchingVideo(for: subtitle) == exactVideo)
}

@Test
func basenameWithoutAdditionalSuffixDoesNotMatchLongerVideoBasename() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.ass")
    let longerVideo = root.appendingPathComponent("Movie.commentary.mp4")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: longerVideo)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(matcher.matchingVideo(for: subtitle) == nil)
}

@Test
func candidateBasenamesRemoveOnlyTheFinalSuffix() {
    let matcher = VideoMatcher()

    #expect(matcher.candidateBaseNames(for: "Movie") == ["Movie"])
    #expect(matcher.candidateBaseNames(for: "Movie.commentary") == ["Movie.commentary", "Movie"])
    #expect(matcher.candidateBaseNames(for: "Movie.cut.commentary") == ["Movie.cut.commentary", "Movie.cut"])
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
