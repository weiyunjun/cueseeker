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

    #expect(try matcher.matchingVideo(for: subtitle) == video)
}

@Test
func batchMatchingPreservesPerSubtitleMatchingRules() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")
    let nested = root.appendingPathComponent("Nested")

    try FileManager.default.createDirectory(
        at: nested,
        withIntermediateDirectories: true
    )
    let firstSubtitle = root.appendingPathComponent("First.srt")
    let firstVideo = root.appendingPathComponent("First.mkv")
    let secondSubtitle = root.appendingPathComponent("Second.commentary.ass")
    let secondVideo = root.appendingPathComponent("Second.mp4")
    let nestedSubtitle = nested.appendingPathComponent("Third.ass")
    let nestedVideo = nested.appendingPathComponent("Third.mov")
    for subtitle in [firstSubtitle, secondSubtitle, nestedSubtitle] {
        try "".write(to: subtitle, atomically: true, encoding: .utf8)
    }
    for video in [firstVideo, secondVideo, nestedVideo] {
        try Data().write(to: video)
    }

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matches = try VideoMatcher().matchingVideos(
        for: [firstSubtitle, secondSubtitle, nestedSubtitle]
    )

    #expect(matches[firstSubtitle] == firstVideo)
    #expect(matches[secondSubtitle] == secondVideo)
    #expect(matches[nestedSubtitle] == nestedVideo)
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

    #expect(try matcher.matchingVideo(for: subtitle) == video)
}

@Test
func prefersCompleteBasenameAcrossVideoExtensions() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.commentary.ass")
    let exactVideo = root.appendingPathComponent("Movie.commentary.mov")
    let fallbackVideo = root.appendingPathComponent("Movie.mkv")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: exactVideo)
    try Data().write(to: fallbackVideo)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(try matcher.matchingVideo(for: subtitle) == exactVideo)
}

@Test
func matchesVideoAfterVideoFinalBasenameSuffixRemoval() throws {
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

    #expect(try matcher.matchingVideo(for: subtitle) == longerVideo)
}

@Test
func matchesVideoAfterSubtitleAndVideoFinalBasenameSuffixRemoval() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.SC.ass")
    let video = root.appendingPathComponent("Movie.TC.mkv")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: video)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(try matcher.matchingVideo(for: subtitle) == video)
}

@Test
func prefersEarlierNameMatchBeforeVideoExtensionPriority() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.SC.ass")
    let earlierNameMatch = root.appendingPathComponent("Movie.SC.commentary.mov")
    let laterNameMatch = root.appendingPathComponent("Movie.mkv")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: earlierNameMatch)
    try Data().write(to: laterNameMatch)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(try matcher.matchingVideo(for: subtitle) == earlierNameMatch)
}

@Test
func prefersRequiredVideoExtensionOrderWithinNameMatch() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Movie.ass")
    let preferredVideo = root.appendingPathComponent("Movie.mkv")
    let otherVideo = root.appendingPathComponent("Movie.mp4")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: preferredVideo)
    try Data().write(to: otherVideo)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(try matcher.matchingVideo(for: subtitle) == preferredVideo)
    #expect(
        VideoMatcher.defaultVideoExtensions
            == ["mkv", "mp4", "webm", "flv", "avi", "mov"]
    )
}

@Test
func matchesFLVAndCaseInsensitiveVideoExtension() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let flvSubtitle = root.appendingPathComponent("First.ass")
    let flvVideo = root.appendingPathComponent("First.FLV")
    let mkvSubtitle = root.appendingPathComponent("Second.srt")
    let mkvVideo = root.appendingPathComponent("Second.MKV")
    try "".write(to: flvSubtitle, atomically: true, encoding: .utf8)
    try Data().write(to: flvVideo)
    try "".write(to: mkvSubtitle, atomically: true, encoding: .utf8)
    try Data().write(to: mkvVideo)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(try matcher.matchingVideo(for: flvSubtitle) == flvVideo)
    #expect(try matcher.matchingVideo(for: mkvSubtitle) == mkvVideo)
}

@Test
func matchesCanonicallyEquivalentUnicodeNames() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMatcherTests-\(UUID().uuidString)")

    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let subtitle = root.appendingPathComponent("Cafe\u{301}.ass")
    let video = root.appendingPathComponent("Caf\u{00E9}.mkv")
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: video)

    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let matcher = VideoMatcher()

    #expect(try matcher.matchingVideo(for: subtitle) == video)
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

    #expect(try matcher.matchingVideo(for: subtitle) == nil)
}

@Test
func reportsVideoDirectoryEnumerationFailure() throws {
    let root = URL(fileURLWithPath: "/Video Directory Failure")
    let subtitle = root.appendingPathComponent("Episode.srt")
    let matcher = VideoMatcher(
        fileManager: FailingVideoFileManager(
            directoryPath: root.path
        )
    )

    #expect(
        throws: VideoMatchingError.directoryEnumerationFailed(root.path)
    ) {
        try matcher.matchingVideos(for: [subtitle])
    }
}

@Test
func reportsSupportedVideoCandidateMetadataFailure() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerVideoMetadataFailure-\(UUID().uuidString)")
    let subtitle = root.appendingPathComponent("Episode.srt")
    let video = root.appendingPathComponent("Episode.mkv")
    defer {
        try? FileManager.default.removeItem(at: root)
    }
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    try "".write(to: subtitle, atomically: true, encoding: .utf8)
    try Data().write(to: video)
    let matcher = VideoMatcher(
        fileManager: FailingVideoFileManager(
            metadataPath: video.path
        )
    )

    #expect(throws: VideoMatchingError.self) {
        try matcher.matchingVideos(for: [subtitle])
    }
}

private final class FailingVideoFileManager: FileManager, @unchecked Sendable {
    private let directoryPath: String?
    private let metadataPath: String?

    init(directoryPath: String? = nil, metadataPath: String? = nil) {
        self.directoryPath = directoryPath
        self.metadataPath = metadataPath
        super.init()
    }

    override func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options mask: FileManager.DirectoryEnumerationOptions = []
    ) throws -> [URL] {
        if url.path == directoryPath {
            throw CocoaError(.fileReadNoPermission)
        }
        return try super.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: mask
        )
    }

    override func attributesOfItem(
        atPath path: String
    ) throws -> [FileAttributeKey: Any] {
        if URL(fileURLWithPath: path).lastPathComponent
            == metadataPath.map({ URL(fileURLWithPath: $0).lastPathComponent })
        {
            throw CocoaError(.fileReadNoPermission)
        }
        return try super.attributesOfItem(atPath: path)
    }
}

@Test
func nameListMatchingFollowsTheDirectoryRules() {
    let matches = VideoMatcher().matchingVideoNames(
        subtitleFileNames: ["First.srt", "Second.commentary.ass", "Orphan.srt"],
        among: ["First.srt", "First.mkv", "Second.commentary.ass", "Second.mp4", "Orphan.srt", "Notes.txt"]
    )

    #expect(matches == ["First.srt": "First.mkv", "Second.commentary.ass": "Second.mp4"])
}
