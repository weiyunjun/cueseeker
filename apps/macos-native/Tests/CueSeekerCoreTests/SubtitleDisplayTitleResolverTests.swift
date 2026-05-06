import Foundation
import Testing
import CueSeekerCore

@Test
func derivesFriendlyTitleFromParentFolderAndFinderLikeSiblingRank() throws {
    let root = temporaryDisplayTitleDirectory()
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let series = root.appendingPathComponent("葬送的芙莉莲")
    try FileManager.default.createDirectory(at: series, withIntermediateDirectories: true)

    for name in ["aa1.ass", "aa2.ass", "aa3.ass", "aa4.ass", "aa11.ass"] {
        try "subtitle".write(to: series.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    let displayTitle = SubtitleDisplayTitleResolver.displayTitle(
        forSubtitlePath: series.appendingPathComponent("aa11.ass").path
    )

    #expect(displayTitle == "葬送的芙莉莲 - 05")
}

@Test
func ignoresDirectoriesAndDescendantsWhenRankingFriendlyTitles() throws {
    let root = temporaryDisplayTitleDirectory()
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let series = root.appendingPathComponent("Series")
    let descendant = series.appendingPathComponent("Nested")
    try FileManager.default.createDirectory(at: descendant, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: series.appendingPathComponent("aa0.ass"), withIntermediateDirectories: true)
    try "subtitle".write(to: descendant.appendingPathComponent("aa0.ass"), atomically: true, encoding: .utf8)
    try "subtitle".write(to: series.appendingPathComponent("aa1.ass"), atomically: true, encoding: .utf8)
    try "subtitle".write(to: series.appendingPathComponent("aa2.ass"), atomically: true, encoding: .utf8)

    let displayTitle = SubtitleDisplayTitleResolver.displayTitle(
        forSubtitlePath: series.appendingPathComponent("aa2.ass").path
    )

    #expect(displayTitle == "Series - 02")
}

@Test
func ranksFriendlyTitlesByFinalSubtitleExtension() throws {
    let root = temporaryDisplayTitleDirectory()
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let series = root.appendingPathComponent("Series")
    try FileManager.default.createDirectory(at: series, withIntermediateDirectories: true)
    try "subtitle".write(to: series.appendingPathComponent("aa1.ass"), atomically: true, encoding: .utf8)
    try "subtitle".write(to: series.appendingPathComponent("aa1.srt"), atomically: true, encoding: .utf8)
    try "subtitle".write(to: series.appendingPathComponent("aa2.srt"), atomically: true, encoding: .utf8)

    #expect(
        SubtitleDisplayTitleResolver.displayTitle(
            forSubtitlePath: series.appendingPathComponent("aa1.ass").path
        ) == "Series - 01"
    )
    #expect(
        SubtitleDisplayTitleResolver.displayTitle(
            forSubtitlePath: series.appendingPathComponent("aa2.srt").path
        ) == "Series - 02"
    )
}

@Test
func expandsFriendlyTitlePaddingWidthForLargeSiblingSets() throws {
    let root = temporaryDisplayTitleDirectory()
    defer {
        try? FileManager.default.removeItem(at: root)
    }

    let series = root.appendingPathComponent("Series")
    try FileManager.default.createDirectory(at: series, withIntermediateDirectories: true)
    for index in 1...100 {
        try "subtitle".write(
            to: series.appendingPathComponent("Episode \(index).ass"),
            atomically: true,
            encoding: .utf8
        )
    }

    let displayTitle = SubtitleDisplayTitleResolver.displayTitle(
        forSubtitlePath: series.appendingPathComponent("Episode 100.ass").path
    )

    #expect(displayTitle == "Series - 100")
}

@Test
func fallsBackToSubtitleFilenameWhenFriendlyTitleCannotBeDerived() {
    let missingPath = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerMissing-\(UUID().uuidString)")
        .appendingPathComponent("aa1.ass")
        .path

    #expect(SubtitleDisplayTitleResolver.displayTitle(forSubtitlePath: missingPath) == "aa1.ass")
}

private func temporaryDisplayTitleDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerDisplayTitleTests-\(UUID().uuidString)")
}
