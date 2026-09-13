import AppKit
import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerPlayback

@Test
@MainActor
func playbackRenderContainerViewInitializesWithoutAttachingBackendView() {
    let view = PlaybackRenderContainerView()

    #expect(view.subviews.isEmpty)
    #expect(view.wantsLayer)
}

@Test
@MainActor
func playbackRenderContainerUsesSourceFaithfulOverlayForASSSource() async throws {
    let view = PlaybackRenderContainerView()
    let subtitleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerASSOverlay-\(UUID().uuidString)")
        .appendingPathExtension("ass")
    defer {
        try? FileManager.default.removeItem(at: subtitleURL)
    }

    try """
    [Script Info]
    ScriptType: v4.00+
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default, Helvetica, 32, &H00FFFFFF, &H000000FF, &H80000000, &H40000000, 0, 0, 0, 0, 100, 100, 0, 0, 1, 2, 1, 2, 20, 20, 20, 1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:00.00,0:00:02.00,Default,,0,0,0,,Hello
    """.write(to: subtitleURL, atomically: true, encoding: .utf8)

    view.setVideoSize(CGSize(width: 640, height: 360))
    view.setSourceFaithfulASSSubtitleSource(
        PlaybackSubtitleSource(url: subtitleURL, format: .ass)
    )

    #expect(view.subviews.contains { String(describing: type(of: $0)).contains("SourceFaithfulASSSubtitleOverlayView") })
    #expect(!view.subviews.contains { String(describing: type(of: $0)).contains("NativeASSSubtitleOverlayView") })
    try await Task.sleep(nanoseconds: 100_000_000)
}

@Test
@MainActor
func playbackRenderContainerUsesDirectOverlayForSRTSource() async throws {
    let view = PlaybackRenderContainerView()
    let subtitleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSRTOverlay-\(UUID().uuidString)")
        .appendingPathExtension("srt")
    defer {
        try? FileManager.default.removeItem(at: subtitleURL)
    }
    try """
    1
    00:00:01,000 --> 00:00:03,000
    （ミコト）はい
    """.write(to: subtitleURL, atomically: true, encoding: .utf8)
    let source = PlaybackSubtitleSource(
        url: subtitleURL,
        format: .srt
    )

    view.setVideoSize(CGSize(width: 640, height: 360))
    view.setSubtitleTime(milliseconds: 2_000)
    view.setSubtitleSource(source)

    #expect(view.subviews.contains {
        String(describing: type(of: $0)).contains("SRTSubtitleOverlayView")
    })
    #expect(!view.subviews.contains {
        String(describing: type(of: $0)).contains("SourceFaithfulASSSubtitleOverlayView")
    })
    for _ in 0..<50 where view.currentSRTSubtitleImage() == nil {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    let image = try #require(view.currentSRTSubtitleImage())
    #expect(image.width == 640)
    #expect(image.height == 360)
}

@Test
@MainActor
func srtOverlayReusesSameSourceAndSameCanvasLayout() async throws {
    let subtitleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSRTReuse-\(UUID().uuidString)")
        .appendingPathExtension("srt")
    defer {
        try? FileManager.default.removeItem(at: subtitleURL)
    }
    try """
    1
    00:00:01,000 --> 00:00:03,000
    First

    2
    00:00:03,000 --> 00:00:05,000
    Second
    """.write(to: subtitleURL, atomically: true, encoding: .utf8)

    let view = SRTSubtitleOverlayView(frame: .zero)
    view.videoSize = CGSize(width: 640, height: 360)
    view.currentTimeMilliseconds = 2_000
    view.setSource(
        PlaybackSubtitleSource(
            url: subtitleURL,
            format: .srt,
            initialTimestampMilliseconds: 2_000,
            preparationTimeWindow: PlaybackSubtitleTimeWindow(
                startMilliseconds: 1_000,
                endMilliseconds: 3_000
            )
        )
    )
    view.setSource(
        PlaybackSubtitleSource(
            url: subtitleURL,
            format: .srt,
            initialTimestampMilliseconds: 2_500,
            preparationTimeWindow: PlaybackSubtitleTimeWindow(
                startMilliseconds: 1_000,
                endMilliseconds: 3_000
            )
        )
    )
    #expect(view.sourceLoadCountForTesting == 1)
    for _ in 0..<50 where view.currentPresentationImage() == nil {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    _ = try #require(view.currentPresentationImage())
    #expect(view.sourceLoadCountForTesting == 1)
    #expect(view.layoutBuildCountForTesting == 1)

    view.currentTimeMilliseconds = 4_000
    view.setSource(
        PlaybackSubtitleSource(
            url: subtitleURL,
            format: .srt,
            initialTimestampMilliseconds: 4_000,
            preparationTimeWindow: PlaybackSubtitleTimeWindow(
                startMilliseconds: 3_000,
                endMilliseconds: 5_000
            )
        )
    )
    view.videoSize = CGSize(width: 640, height: 360)

    #expect(view.currentPresentationImage() != nil)
    #expect(view.sourceLoadCountForTesting == 1)
    #expect(view.layoutBuildCountForTesting == 1)

    view.videoSize = CGSize(width: 1_280, height: 720)
    for _ in 0..<50 where view.currentPresentationImage() == nil {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    _ = try #require(view.currentPresentationImage())
    #expect(view.sourceLoadCountForTesting == 1)
    #expect(view.layoutBuildCountForTesting == 2)
}

@Test
@MainActor
func srtOverlayRejectsReplacedSourceWork() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSRTReplace-\(UUID().uuidString)")
    let firstURL = temporaryDirectory.appendingPathComponent("first.srt")
    let secondURL = temporaryDirectory.appendingPathComponent("second.srt")
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    try """
    1
    00:00:01,000 --> 00:00:03,000
    First source
    """.write(to: firstURL, atomically: true, encoding: .utf8)
    try """
    1
    00:00:01,000 --> 00:00:03,000
    Second source
    """.write(to: secondURL, atomically: true, encoding: .utf8)

    let view = SRTSubtitleOverlayView(frame: .zero)
    view.videoSize = CGSize(width: 640, height: 360)
    view.currentTimeMilliseconds = 2_000
    view.setSource(PlaybackSubtitleSource(url: firstURL, format: .srt))
    view.setSource(PlaybackSubtitleSource(url: secondURL, format: .srt))

    for _ in 0..<50 where view.currentPresentationImage() == nil {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    _ = try #require(view.currentPresentationImage())
    #expect(view.sourceLoadCountForTesting == 2)
    #expect(view.layoutBuildCountForTesting == 1)
}

@Test
@MainActor
func srtPresentationAppliesChangedSourceAndVideoSizeOnce() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerSRTAtomicPresentation-\(UUID().uuidString)")
    let firstURL = temporaryDirectory.appendingPathComponent("first.srt")
    let secondURL = temporaryDirectory.appendingPathComponent("second.srt")
    defer {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    try "1\n00:00:01,000 --> 00:00:03,000\nFirst source\n".write(
        to: firstURL,
        atomically: true,
        encoding: .utf8
    )
    try "1\n00:00:01,000 --> 00:00:03,000\nSecond source\n".write(
        to: secondURL,
        atomically: true,
        encoding: .utf8
    )

    let view = SRTSubtitleOverlayView(frame: .zero)
    view.setPresentation(
        source: PlaybackSubtitleSource(url: firstURL, format: .srt),
        videoSize: CGSize(width: 3_840, height: 2_160),
        milliseconds: 2_000,
        isVisible: true
    )
    view.setPresentation(
        source: PlaybackSubtitleSource(
            url: firstURL,
            format: .srt,
            initialTimestampMilliseconds: 2_500
        ),
        videoSize: CGSize(width: 3_840, height: 2_160),
        milliseconds: 2_500,
        isVisible: true
    )

    #expect(view.sourceLoadCountForTesting == 1)

    view.setPresentation(
        source: PlaybackSubtitleSource(url: secondURL, format: .srt),
        videoSize: CGSize(width: 1_920, height: 800),
        milliseconds: 2_000,
        isVisible: true
    )

    for _ in 0..<50 where view.currentPresentationImage() == nil {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    let image = try #require(view.currentPresentationImage())
    #expect(view.sourceLoadCountForTesting == 2)
    #expect(view.layoutBuildCountForTesting == 1)
    #expect(image.width == 1_920)
    #expect(image.height == 800)

    view.setPresentation(
        source: PlaybackSubtitleSource(url: secondURL, format: .srt),
        videoSize: CGSize(width: 1_280, height: 720),
        milliseconds: 2_000,
        isVisible: false
    )

    #expect(view.sourceLoadCountForTesting == 2)
    #expect(view.layoutBuildCountForTesting == 2)
    #expect(view.currentPresentationImage() == nil)
}

@Test
func playbackDecodeModeRawValuesMatchSettingsControlValues() {
    #expect(PlaybackDecodeMode.allCases.map(\.rawValue) == ["hardware", "software", "auto"])
    #expect(PlaybackDecodeMode.hardware.displayName == "hardware")
    #expect(PlaybackDecodeMode.software.displayName == "software")
    #expect(PlaybackDecodeMode.auto.displayName == "auto")
}

@Test
func sourceFaithfulASSSubtitleLayoutMapsLibassTopOriginToLayerBottomOrigin() {
    let videoRect = SourceFaithfulASSSubtitleLayout.videoRect(
        videoSize: CGSize(width: 640, height: 360),
        in: CGRect(x: 0, y: 0, width: 320, height: 200)
    )
    #expect(videoRect == CGRect(x: 0, y: 10, width: 320, height: 180))

    let frame = SourceFaithfulASSSubtitleLayout.surfaceFrame(
        destinationX: 120,
        destinationY: 300,
        width: 200,
        height: 40,
        frameWidth: 640,
        frameHeight: 360,
        videoRect: CGRect(x: 10, y: 20, width: 640, height: 360)
    )

    #expect(frame == CGRect(x: 130, y: 40, width: 200, height: 40))
}

@Test
func assFontAliasTableMapsFileDerivedNamesToCanonicalFamilyNames() {
    let table = ASSFontAliasTable(
        records: [
            ASSFontAliasRecord(
                canonicalName: "FZZhunYuan-M02",
                aliases: [
                    "FZY3K--GBK1-0",
                    "方正准圆_GBK"
                ]
            )
        ]
    )

    #expect(table.replacement(for: "方正准圆_GBK") == "FZZhunYuan-M02")
    #expect(table.replacement(for: "方正准圆GBK") == "FZZhunYuan-M02")
    #expect(table.replacement(for: "FZY3K--GBK1-0") == "FZZhunYuan-M02")
    #expect(table.replacement(for: "FZZhunYuan-M02") == nil)
}

@Test
func assFontNameTableParserReadsLocalizedInstalledFontNames() {
    let fontData = makeTestFontData(
        nameRecords: [
            TestFontNameRecord(platformID: 3, encodingID: 1, languageID: 0x0804, nameID: 1, text: "华文中宋"),
            TestFontNameRecord(platformID: 3, encodingID: 1, languageID: 0x0804, nameID: 4, text: "华文中宋"),
            TestFontNameRecord(platformID: 3, encodingID: 1, languageID: 0x0409, nameID: 6, text: "STZhongsong")
        ]
    )

    let aliases = ASSFontNameTableParser.aliases(in: fontData, matchingPostScriptName: "STZhongsong")
    let faces = ASSFontNameTableParser.faces(in: fontData)
    let table = ASSFontAliasTable(
        records: [
            ASSFontAliasRecord(canonicalName: "STZhongsong", aliases: aliases)
        ]
    )

    #expect(aliases.contains("华文中宋"))
    #expect(aliases.contains("STZhongsong"))
    #expect(faces.first?.postScriptNames == ["STZhongsong"])
    #expect(table.replacement(for: "华文中宋") == "STZhongsong")
}

@Test
func assFontAliasResolverPrefersNameTableMatchedCanonicalName() {
    let canonicalName = ASSFontAliasResolver.canonicalName(
        candidates: [
            "EPSON mojibake family",
            "EPSON mojibake display",
            "EPSON-FUTO-MINCHO"
        ],
        fontFileAliases: [
            "EPSON 太明朝体Ｂ",
            "EPSON-FUTO-MINCHO"
        ]
    )

    #expect(canonicalName == "EPSON-FUTO-MINCHO")
}

@Test
func assFontAliasRewritePlannerUsesIndexedFontIntentWhenAvailable() {
    let table = ASSFontAliasTable(
        records: [
            ASSFontAliasRecord(
                canonicalName: "STZhongsong",
                aliases: [
                    "华文中宋"
                ]
            )
        ]
    )

    #expect(ASSFontAliasRewritePlanner.shouldRewriteScript(requestedFontNames: nil, aliases: table))
    #expect(ASSFontAliasRewritePlanner.shouldRewriteScript(requestedFontNames: ["华文中宋"], aliases: table))
    #expect(!ASSFontAliasRewritePlanner.shouldRewriteScript(requestedFontNames: ["Helvetica"], aliases: table))
    #expect(!ASSFontAliasRewritePlanner.shouldRewriteScript(requestedFontNames: [], aliases: table))
}

@Test
func assPlaybackFontIntentProviderLoadsIndexedFontNames() throws {
    let directory = try temporaryPlaybackTestDirectory()
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let databaseURL = directory.appendingPathComponent("index.sqlite")
    let subtitleFile = directory.appendingPathComponent("Episode.ass")
    let videoFile = directory.appendingPathComponent("Episode.mkv")
    try DatabaseBootstrap.prepare(at: databaseURL)
    let database = try IndexingDatabase(path: databaseURL)
    try Data().write(to: videoFile)

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [],
        assFontReferences: [
            ASSFontReferenceIntent(
                fontName: "华文中宋",
                source: .style,
                occurrenceCount: 2,
                firstOccurrenceOrder: 0
            ),
            ASSFontReferenceIntent(
                fontName: "汉仪小隶书简",
                source: .inlineOverride,
                occurrenceCount: 1,
                firstOccurrenceOrder: 2
            ),
            ASSFontReferenceIntent(
                fontName: "华文中宋",
                source: .inlineOverride,
                occurrenceCount: 1,
                firstOccurrenceOrder: 3
            )
        ]
    )

    let fontNames = try ASSPlaybackFontIntentProvider.requestedFontNames(
        sourcePath: subtitleFile.path,
        renderCacheDatabaseURL: databaseURL
    )

    #expect(fontNames == ["华文中宋", "汉仪小隶书简"])
}

@Test
func assFontAliasEnvironmentCacheReusesOnlyMatchingFontSnapshot() throws {
    let directory = try temporaryPlaybackTestDirectory()
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let fontURL = directory.appendingPathComponent("STZHONGS.TTF")
    let cacheURL = directory.appendingPathComponent("font-environment-cache.json")
    let fontData = makeTestFontData(
        nameRecords: [
            TestFontNameRecord(platformID: 3, encodingID: 1, languageID: 0x0804, nameID: 1, text: "华文中宋"),
            TestFontNameRecord(platformID: 3, encodingID: 1, languageID: 0x0409, nameID: 6, text: "STZhongsong")
        ]
    )
    try fontData.write(to: fontURL)

    let snapshot = ASSFontAliasResolver.installedFontEnvironmentSnapshot(directories: [directory])
    let facesByURL = [
        fontURL.standardizedFileURL: [
            ASSFontNameTableFace(
                aliases: ["华文中宋", "STZhongsong"],
                postScriptNames: ["STZhongsong"],
                postScriptKeys: [ASSFontAliasTable.normalizedKey("STZhongsong")]
            )
        ]
    ]

    try ASSFontAliasEnvironmentCache.store(
        facesByURL: facesByURL,
        snapshot: snapshot,
        cacheURL: cacheURL
    )

    #expect(try ASSFontAliasEnvironmentCache.cachedFaces(matching: snapshot, cacheURL: cacheURL) == facesByURL)

    var changedFontData = fontData
    changedFontData.append(0)
    try changedFontData.write(to: fontURL)
    let changedSnapshot = ASSFontAliasResolver.installedFontEnvironmentSnapshot(directories: [directory])

    #expect(changedSnapshot != snapshot)
    #expect(try ASSFontAliasEnvironmentCache.cachedFaces(matching: changedSnapshot, cacheURL: cacheURL) == nil)
}

@Test
func assFontAliasRewriterUpdatesStylesAndInlineOverrideTagsOnlyInRenderScript() {
    let table = ASSFontAliasTable(
        records: [
            ASSFontAliasRecord(
                canonicalName: "FZZhunYuan-M02",
                aliases: [
                    "方正准圆_GBK"
                ]
            )
        ]
    )
    let script = #"""
    [Script Info]
    ScriptType: v4.00+

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default, 方正准圆_GBK, 32

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:00.00,0:00:02.00,Default,,0,0,0,,{\fn方正准圆_GBK\bord2}Hello {\fn方正准圆_GBK}world
    Dialogue: 0,0:00:02.00,0:00:03.00,Default,,0,0,0,,literal \fn方正准圆_GBK text
    """#

    let rewritten = ASSFontAliasRewriter.rewrite(script: script, aliases: table)

    #expect(script.contains("Style: Default, 方正准圆_GBK, 32"))
    #expect(rewritten.contains("Style: Default, FZZhunYuan-M02, 32"))
    #expect(rewritten.contains(#"{\fnFZZhunYuan-M02\bord2}"#))
    #expect(rewritten.contains(#"{\fnFZZhunYuan-M02}"#))
    #expect(rewritten.contains(#"literal \fn方正准圆_GBK text"#))
}

@Test
func assFontAliasRewriterCoversReportedASSFontNamesAndPreservesMissingFonts() {
    let table = ASSFontAliasTable(
        records: [
            ASSFontAliasRecord(
                canonicalName: "STZhongsong",
                aliases: [
                    "华文中宋"
                ]
            ),
            ASSFontAliasRecord(
                canonicalName: "EPSON-FUTO-MINCHO",
                aliases: [
                    "EPSON 太明朝体Ｂ"
                ]
            ),
            ASSFontAliasRecord(
                canonicalName: "FZZhunYuan-M02",
                aliases: [
                    "方正准圆_GBK"
                ]
            )
        ]
    )
    let script = #"""
    [Script Info]
    ScriptType: v4.00+

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: TitanCN,华文中宋,42
    Style: TitanJP,EPSON 太明朝体Ｂ,28
    Style: LegalHigh,方正准圆_GBK,36
    Style: Missing,不存在的字体,30

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:02.00,TitanCN,,0,0,0,,{\fn华文中宋}Chinese
    Dialogue: 0,0:00:02.00,0:00:03.00,TitanJP,,0,0,0,,{\fnEPSON 太明朝体Ｂ}Japanese
    Dialogue: 0,0:00:03.00,0:00:04.00,LegalHigh,,0,0,0,,{\fn方正准圆_GBK}Legal
    Dialogue: 0,0:00:04.00,0:00:05.00,Missing,,0,0,0,,{\fn不存在的字体}Missing
    """#

    let rewritten = ASSFontAliasRewriter.rewrite(script: script, aliases: table)

    #expect(rewritten.contains("Style: TitanCN,STZhongsong,42"))
    #expect(rewritten.contains("Style: TitanJP,EPSON-FUTO-MINCHO,28"))
    #expect(rewritten.contains("Style: LegalHigh,FZZhunYuan-M02,36"))
    #expect(rewritten.contains("Style: Missing,不存在的字体,30"))
    #expect(rewritten.contains(#"{\fnSTZhongsong}"#))
    #expect(rewritten.contains(#"{\fnEPSON-FUTO-MINCHO}"#))
    #expect(rewritten.contains(#"{\fnFZZhunYuan-M02}"#))
    #expect(rewritten.contains(#"{\fn不存在的字体}"#))
}

@Test
func assFontAliasRewriterHandlesCRLFLineEndings() {
    let table = ASSFontAliasTable(
        records: [
            ASSFontAliasRecord(
                canonicalName: "FZZhunYuan-M02",
                aliases: [
                    "方正准圆_GBK"
                ]
            )
        ]
    )
    let script = "[Script Info]\r\n[V4+ Styles]\r\nFormat: Name, Fontname, Fontsize\r\nStyle: TEXT-CN,方正准圆_GBK,82\r\n[Events]\r\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\r\nDialogue: 0,0:00:00.00,0:00:02.00,TEXT-CN,,0,0,0,,{\\fn方正准圆_GBK\\bord2}Hello\r\n"

    let rewritten = ASSFontAliasRewriter.rewrite(script: script, aliases: table)

    #expect(rewritten.contains("Style: TEXT-CN,FZZhunYuan-M02,82"))
    #expect(rewritten.contains(#"{\fnFZZhunYuan-M02\bord2}"#))
}

@Test
func assFontAliasRewriterPreservesCRLFScriptWhenNoFontAliasMatches() {
    let table = ASSFontAliasTable(records: [])
    let script = "[Script Info]\r\n[V4+ Styles]\r\nFormat: Name, Fontname, Fontsize\r\nStyle: Default,Helvetica,32\r\n"

    let rewritten = ASSFontAliasRewriter.rewrite(script: script, aliases: table)

    #expect(rewritten == script)
}

@Test
@MainActor
func playbackPlayerStoresDecodeModeSetting() {
    let player = PlaybackPlayer()

    #expect(player.decodeMode == .auto)

    player.decodeMode = .software

    #expect(player.decodeMode == .software)
}

@Test
func playbackRequestRejectsMissingVideoFile() throws {
    let missingVideo = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerMissingVideo-\(UUID().uuidString)")
        .appendingPathExtension("mkv")

    #expect(throws: PlaybackError.missingVideoFile(missingVideo.path)) {
        _ = try PlaybackRequest(videoURL: missingVideo, startMilliseconds: 1_000)
    }
}

@Test
func playbackRequestClampsNegativeStartMilliseconds() throws {
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("mp4")
    defer {
        try? FileManager.default.removeItem(at: videoURL)
    }

    try Data().write(to: videoURL)

    let request = try PlaybackRequest(videoURL: videoURL, startMilliseconds: -250)

    #expect(request.videoURL == videoURL)
    #expect(request.startMilliseconds == 0)
}

@Test
func playbackRequestStoresASSSubtitleSource() throws {
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("mp4")
    defer {
        try? FileManager.default.removeItem(at: videoURL)
    }

    try Data().write(to: videoURL)

    let subtitleURL = videoURL.deletingPathExtension().appendingPathExtension("ass")
    let request = try PlaybackRequest(
        videoURL: videoURL,
        startMilliseconds: 1_000,
        subtitleSource: PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass
        )
    )

    #expect(request.subtitleSource?.url == subtitleURL)
    #expect(request.subtitleSource?.format == .ass)
    #expect(request.subtitleSource?.matchedVideoURL == videoURL.standardizedFileURL)
    #expect(request.subtitleSource?.initialTimestampMilliseconds == 1_000)
}

private struct TestFontNameRecord {
    let platformID: UInt16
    let encodingID: UInt16
    let languageID: UInt16
    let nameID: UInt16
    let text: String
}

private func makeTestFontData(nameRecords: [TestFontNameRecord]) -> Data {
    struct EncodedNameRecord {
        let source: TestFontNameRecord
        let data: Data
        let offset: UInt16
    }

    var stringStorage = Data()
    let encodedRecords = nameRecords.map { record in
        let offset = UInt16(stringStorage.count)
        let data = record.text.data(using: .utf16BigEndian) ?? Data()
        stringStorage.append(data)
        return EncodedNameRecord(source: record, data: data, offset: offset)
    }

    var nameTable = Data()
    appendUInt16BigEndian(0, to: &nameTable)
    appendUInt16BigEndian(UInt16(encodedRecords.count), to: &nameTable)
    appendUInt16BigEndian(UInt16(6 + encodedRecords.count * 12), to: &nameTable)

    for encodedRecord in encodedRecords {
        appendUInt16BigEndian(encodedRecord.source.platformID, to: &nameTable)
        appendUInt16BigEndian(encodedRecord.source.encodingID, to: &nameTable)
        appendUInt16BigEndian(encodedRecord.source.languageID, to: &nameTable)
        appendUInt16BigEndian(encodedRecord.source.nameID, to: &nameTable)
        appendUInt16BigEndian(UInt16(encodedRecord.data.count), to: &nameTable)
        appendUInt16BigEndian(encodedRecord.offset, to: &nameTable)
    }

    nameTable.append(stringStorage)

    var fontData = Data()
    appendUInt32BigEndian(0x0001_0000, to: &fontData)
    appendUInt16BigEndian(1, to: &fontData)
    appendUInt16BigEndian(0, to: &fontData)
    appendUInt16BigEndian(0, to: &fontData)
    appendUInt16BigEndian(0, to: &fontData)
    appendSFNTTag("name", to: &fontData)
    appendUInt32BigEndian(0, to: &fontData)
    appendUInt32BigEndian(28, to: &fontData)
    appendUInt32BigEndian(UInt32(nameTable.count), to: &fontData)
    fontData.append(nameTable)

    return fontData
}

private func appendSFNTTag(_ tag: String, to data: inout Data) {
    data.append(contentsOf: tag.utf8)
}

private func appendUInt16BigEndian(_ value: UInt16, to data: inout Data) {
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}

private func appendUInt32BigEndian(_ value: UInt32, to data: inout Data) {
    data.append(UInt8((value >> 24) & 0xff))
    data.append(UInt8((value >> 16) & 0xff))
    data.append(UInt8((value >> 8) & 0xff))
    data.append(UInt8(value & 0xff))
}

@Test
func playbackRequestStoresASSSubtitleTimeWindow() throws {
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("mp4")
    defer {
        try? FileManager.default.removeItem(at: videoURL)
    }

    try Data().write(to: videoURL)

    let subtitleURL = videoURL.deletingPathExtension().appendingPathExtension("ass")
    let timeWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 1_000,
        endMilliseconds: 9_000
    )
    let request = try PlaybackRequest(
        videoURL: videoURL,
        startMilliseconds: 1_000,
        subtitleSource: PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass,
            initialTimestampMilliseconds: 5_000,
            preparationTimeWindow: timeWindow
        )
    )

    #expect(request.subtitleSource?.initialTimestampMilliseconds == 5_000)
    #expect(request.subtitleSource?.preparationTimeWindow == timeWindow)
    #expect(request.subtitleSource?.initialRenderTimestamp(fallbackMilliseconds: 0) == 5_000)
}

@Test
func playbackRequestUsesStartTimeAsDefaultASSSubtitleInitialTimestamp() throws {
    let videoURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("mp4")
    defer {
        try? FileManager.default.removeItem(at: videoURL)
    }

    try Data().write(to: videoURL)

    let subtitleURL = videoURL.deletingPathExtension().appendingPathExtension("ass")
    let request = try PlaybackRequest(
        videoURL: videoURL,
        startMilliseconds: 42_000,
        subtitleSource: PlaybackSubtitleSource(
            url: subtitleURL,
            format: .ass
        )
    )

    #expect(request.subtitleSource?.initialTimestampMilliseconds == 42_000)
    #expect(request.subtitleSource?.initialRenderTimestamp(fallbackMilliseconds: 0) == 42_000)
}

@Test
func playbackSubtitleSourceClampsInitialRenderTimestampToPreparationWindow() {
    let subtitleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("ass")
    let timeWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 1_000,
        endMilliseconds: 9_000
    )

    let beforeWindow = PlaybackSubtitleSource(
        url: subtitleURL,
        format: .ass,
        initialTimestampMilliseconds: 100,
        preparationTimeWindow: timeWindow
    )
    let afterWindow = PlaybackSubtitleSource(
        url: subtitleURL,
        format: .ass,
        initialTimestampMilliseconds: 12_000,
        preparationTimeWindow: timeWindow
    )
    let fallbackOnly = PlaybackSubtitleSource(
        url: subtitleURL,
        format: .ass,
        preparationTimeWindow: timeWindow
    )
    let zeroDurationWindow = PlaybackSubtitleSource(
        url: subtitleURL,
        format: .ass,
        initialTimestampMilliseconds: 12_000,
        preparationTimeWindow: PlaybackSubtitleTimeWindow(
            startMilliseconds: 4_000,
            endMilliseconds: 4_000
        )
    )

    #expect(beforeWindow.initialRenderTimestamp(fallbackMilliseconds: 6_000) == 1_000)
    #expect(afterWindow.initialRenderTimestamp(fallbackMilliseconds: 6_000) == 8_999)
    #expect(fallbackOnly.initialRenderTimestamp(fallbackMilliseconds: 6_000) == 6_000)
    #expect(fallbackOnly.initialRenderTimestamp(fallbackMilliseconds: 100) == 1_000)
    #expect(zeroDurationWindow.initialRenderTimestamp(fallbackMilliseconds: 6_000) == 4_000)
}

@Test
func playbackSubtitleTimeWindowContainsTimestampWithHalfOpenEnd() {
    let timeWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 2_000,
        endMilliseconds: 5_000
    )
    let zeroDurationWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 4_000,
        endMilliseconds: 4_000
    )

    #expect(!timeWindow.contains(timestampMilliseconds: 1_999))
    #expect(timeWindow.contains(timestampMilliseconds: 2_000))
    #expect(timeWindow.contains(timestampMilliseconds: 4_999))
    #expect(!timeWindow.contains(timestampMilliseconds: 5_000))
    #expect(zeroDurationWindow.contains(timestampMilliseconds: 4_000))
    #expect(!zeroDurationWindow.contains(timestampMilliseconds: 4_001))
}

@Test
func playbackSubtitleRenderTimeGateHoldsInitialTimestampUntilNativeTimeEntersWindow() throws {
    let subtitleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("ass")
    let timeWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 1_000,
        endMilliseconds: 9_000
    )
    let source = PlaybackSubtitleSource(
        url: subtitleURL,
        format: .ass,
        initialTimestampMilliseconds: 5_000,
        preparationTimeWindow: timeWindow
    )

    let gate = try #require(
        PlaybackSubtitleRenderTimeGate(source: source, fallbackMilliseconds: 0)
    )

    #expect(
        gate.renderTimestamp(forNativeMilliseconds: 99)
            == PlaybackSubtitleRenderTimeGateDecision(
                timestampMilliseconds: 5_000,
                releasesGate: false
            )
    )
    #expect(
        gate.renderTimestamp(forNativeMilliseconds: 1_000)
            == PlaybackSubtitleRenderTimeGateDecision(
                timestampMilliseconds: 1_000,
                releasesGate: true
            )
    )
    #expect(
        gate.renderTimestamp(forNativeMilliseconds: 8_999)
            == PlaybackSubtitleRenderTimeGateDecision(
                timestampMilliseconds: 8_999,
                releasesGate: true
            )
    )
    #expect(
        gate.renderTimestamp(forNativeMilliseconds: 9_000)
            == PlaybackSubtitleRenderTimeGateDecision(
                timestampMilliseconds: 5_000,
                releasesGate: false
            )
    )
}

@Test
func playbackSubtitleRenderTimeGateRetargetsExplicitTimestampInsideWindow() throws {
    let subtitleURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)")
        .appendingPathExtension("ass")
    let timeWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 1_000,
        endMilliseconds: 9_000
    )
    let source = PlaybackSubtitleSource(
        url: subtitleURL,
        format: .ass,
        initialTimestampMilliseconds: 5_000,
        preparationTimeWindow: timeWindow
    )
    let gate = try #require(
        PlaybackSubtitleRenderTimeGate(source: source, fallbackMilliseconds: 0)
    )

    let retargetedGate = try #require(
        gate.retargetingHeldTimestamp(forExplicitMilliseconds: 7_000)
    )

    #expect(
        retargetedGate.renderTimestamp(forNativeMilliseconds: 99)
            == PlaybackSubtitleRenderTimeGateDecision(
                timestampMilliseconds: 7_000,
                releasesGate: false
            )
    )
    #expect(
        retargetedGate.renderTimestamp(forNativeMilliseconds: 7_000)
            == PlaybackSubtitleRenderTimeGateDecision(
                timestampMilliseconds: 7_000,
                releasesGate: true
            )
    )
    #expect(gate.retargetingHeldTimestamp(forExplicitMilliseconds: 999) == nil)
    #expect(gate.retargetingHeldTimestamp(forExplicitMilliseconds: 9_000) == nil)
}

@Test
@MainActor
func sourceFaithfulASSSubtitleOverlayReplacesRendererWorkerWhenSourceChanges() throws {
    let directory = try temporaryPlaybackTestDirectory()
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let firstSubtitleURL = directory.appendingPathComponent("First.ass")
    let secondSubtitleURL = directory.appendingPathComponent("Second.ass")
    try minimalASSPlaybackScript(text: "First").write(to: firstSubtitleURL, atomically: true, encoding: .utf8)
    try minimalASSPlaybackScript(text: "Second").write(to: secondSubtitleURL, atomically: true, encoding: .utf8)

    let view = SourceFaithfulASSSubtitleOverlayView(frame: CGRect(x: 0, y: 0, width: 640, height: 360))
    view.videoSize = CGSize(width: 640, height: 360)
    let initialWorker = view.rendererWorkerIdentityForTesting

    view.setSource(PlaybackSubtitleSource(url: firstSubtitleURL, format: .ass))
    let firstWorker = view.rendererWorkerIdentityForTesting

    view.setSource(PlaybackSubtitleSource(url: secondSubtitleURL, format: .ass))
    let secondWorker = view.rendererWorkerIdentityForTesting

    view.setSource(nil)
    let clearedWorker = view.rendererWorkerIdentityForTesting

    #expect(firstWorker != initialWorker)
    #expect(secondWorker != firstWorker)
    #expect(clearedWorker != secondWorker)
}

@Test
@MainActor
func sourceFaithfulASSPresentationAvoidsIntermediateRendererReloads() throws {
    let directory = try temporaryPlaybackTestDirectory()
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let firstSubtitleURL = directory.appendingPathComponent("First.ass")
    let secondSubtitleURL = directory.appendingPathComponent("Second.ass")
    try minimalASSPlaybackScript(text: "First").write(
        to: firstSubtitleURL,
        atomically: true,
        encoding: .utf8
    )
    try minimalASSPlaybackScript(text: "Second").write(
        to: secondSubtitleURL,
        atomically: true,
        encoding: .utf8
    )

    let view = SourceFaithfulASSSubtitleOverlayView(
        frame: CGRect(x: 0, y: 0, width: 640, height: 360)
    )
    let firstSource = PlaybackSubtitleSource(
        url: firstSubtitleURL,
        format: .ass,
        initialTimestampMilliseconds: 1_000
    )
    view.setPresentation(
        source: firstSource,
        videoSize: CGSize(width: 3_840, height: 2_160),
        milliseconds: 1_000,
        isVisible: true
    )
    let firstWorker = view.rendererWorkerIdentityForTesting

    view.setPresentation(
        source: PlaybackSubtitleSource(
            url: firstSubtitleURL,
            format: .ass,
            initialTimestampMilliseconds: 2_000
        ),
        videoSize: CGSize(width: 3_840, height: 2_160),
        milliseconds: 2_000,
        isVisible: true
    )

    #expect(view.rendererLoadCountForTesting == 1)
    #expect(view.rendererWorkerIdentityForTesting == firstWorker)

    view.setPresentation(
        source: PlaybackSubtitleSource(url: secondSubtitleURL, format: .ass),
        videoSize: CGSize(width: 1_920, height: 800),
        milliseconds: 3_000,
        isVisible: true
    )

    #expect(view.rendererLoadCountForTesting == 2)
    #expect(view.rendererWorkerIdentityForTesting != firstWorker)

    view.setPresentation(
        source: PlaybackSubtitleSource(url: secondSubtitleURL, format: .ass),
        videoSize: CGSize(width: 1_280, height: 720),
        milliseconds: 3_500,
        isVisible: false
    )

    #expect(view.rendererLoadCountForTesting == 3)
    #expect(view.currentPresentationFrame() == nil)
}

func playbackSubtitleTimeWindowDetectsOverlappingCues() {
    let timeWindow = PlaybackSubtitleTimeWindow(
        startMilliseconds: 2_000,
        endMilliseconds: 5_000
    )

    #expect(!timeWindow.overlaps(startMilliseconds: 1_000, endMilliseconds: 2_000))
    #expect(timeWindow.overlaps(startMilliseconds: 1_500, endMilliseconds: 2_500))
    #expect(timeWindow.overlaps(startMilliseconds: 5_000, endMilliseconds: 5_000))
    #expect(!timeWindow.overlaps(startMilliseconds: 5_001, endMilliseconds: 6_000))
}

@Test
func playbackSubtitleTrackSelectsCueForCurrentTime() {
    let track = PlaybackSubtitleTrack(cues: [
        PlaybackSubtitleCue(startMilliseconds: 1_000, endMilliseconds: 2_500, text: "First line"),
        PlaybackSubtitleCue(startMilliseconds: 3_000, endMilliseconds: 4_000, text: "Second line")
    ])

    #expect(track.activeText(at: 0.999) == nil)
    #expect(track.activeText(at: 1.0) == "First line")
    #expect(track.activeText(at: 2.499) == "First line")
    #expect(track.activeText(at: 2.5) == nil)
    #expect(track.activeText(at: 3.0) == "Second line")
}

@Test
func playbackSubtitleTrackJoinsOverlappingCues() {
    let track = PlaybackSubtitleTrack(cues: [
        PlaybackSubtitleCue(startMilliseconds: 2_000, endMilliseconds: 4_000, text: "Second"),
        PlaybackSubtitleCue(startMilliseconds: 1_000, endMilliseconds: 3_000, text: "First"),
        PlaybackSubtitleCue(startMilliseconds: 1_000, endMilliseconds: 3_000, text: "   ")
    ])

    #expect(track.activeText(at: 2.5) == "First\nSecond")
}

@Test
func playbackSubtitleTrackReturnsPhysicalCuesInStableOrder() {
    let track = PlaybackSubtitleTrack(cues: [
        PlaybackSubtitleCue(
            sourceOrdinal: 1,
            startMilliseconds: 1_000,
            endMilliseconds: 3_000,
            text: "Second physical block"
        ),
        PlaybackSubtitleCue(
            sourceOrdinal: 0,
            startMilliseconds: 1_000,
            endMilliseconds: 3_000,
            text: "First physical block"
        )
    ])

    #expect(track.activeCues(atMilliseconds: 1_000).map(\.sourceOrdinal) == [0, 1])
    #expect(track.activeCues(atMilliseconds: 3_000).isEmpty)
}

@Test
func srtRendererScalesAndStacksWithoutExtraCueGap() throws {
    let cues = [
        PlaybackSubtitleCue(
            sourceOrdinal: 0,
            startMilliseconds: 0,
            endMilliseconds: 5_000,
            text: "（ミコト）はい"
        ),
        PlaybackSubtitleCue(
            sourceOrdinal: 1,
            startMilliseconds: 2_000,
            endMilliseconds: 7_000,
            text: "ごちそうさまでした"
        )
    ]
    let layout720 = try #require(
        SRTSubtitleRenderer.makeLayout(
            cues: cues,
            canvasSize: CGSize(width: 1_280, height: 720),
            style: SRTSubtitleStyle()
        )
    )
    let layout1080 = try #require(
        SRTSubtitleRenderer.makeLayout(
            cues: cues,
            canvasSize: CGSize(width: 1_920, height: 1_080),
            style: SRTSubtitleStyle()
        )
    )
    let first720 = try #require(layout720.placements[0])
    let second720 = try #require(layout720.placements[1])
    let first1080 = try #require(layout1080.placements[0])

    #expect(abs(second720.maxY - first720.minY) < 0.001)
    #expect(abs((first1080.height / first720.height) - 1.5) < 0.03)
    #expect(SRTSubtitleRenderer.image(layout: layout720, atMilliseconds: 2_500) != nil)

    if let outputPath = ProcessInfo.processInfo.environment["CUESEEKER_SRT_VISUAL_OUTPUT"],
       let image = SRTSubtitleRenderer.image(layout: layout1080, atMilliseconds: 2_500),
       let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
        try png.write(to: URL(fileURLWithPath: outputPath))
    }
}

@Test
func srtRendererMeasuresOptInRealFilePerformance() throws {
    guard let path = ProcessInfo.processInfo.environment["CUESEEKER_SRT_BENCHMARK_PATH"] else {
        return
    }

    let sourceURL = URL(fileURLWithPath: path)
    var startedAt = DispatchTime.now().uptimeNanoseconds
    let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
    let readMilliseconds = elapsedMilliseconds(since: startedAt)

    startedAt = DispatchTime.now().uptimeNanoseconds
    let entries = try SRTParser.parseForRendering(data)
    let parseMilliseconds = elapsedMilliseconds(since: startedAt)
    let cues = entries.enumerated().map { ordinal, entry in
        PlaybackSubtitleCue(
            sourceOrdinal: ordinal,
            startMilliseconds: entry.startMilliseconds,
            endMilliseconds: entry.endMilliseconds,
            text: entry.text
        )
    }

    startedAt = DispatchTime.now().uptimeNanoseconds
    let layout = try #require(
        SRTSubtitleRenderer.makeLayout(
            cues: cues,
            canvasSize: CGSize(width: 1_920, height: 1_080),
            style: SRTSubtitleStyle()
        )
    )
    let layoutMilliseconds = elapsedMilliseconds(since: startedAt)
    let representativeCue = try #require(cues.dropFirst(cues.count / 2).first)

    startedAt = DispatchTime.now().uptimeNanoseconds
    _ = SRTSubtitleRenderer.image(
        layout: layout,
        atMilliseconds: representativeCue.startMilliseconds
    )
    let imageMilliseconds = elapsedMilliseconds(since: startedAt)

    print(
        String(
            format: "SRT_BENCH cues=%d bytes=%d read=%.2fms parse=%.2fms layout=%.2fms image=%.2fms",
            cues.count,
            data.count,
            readMilliseconds,
            parseMilliseconds,
            layoutMilliseconds,
            imageMilliseconds
        )
    )
}

@Test
func srtRendererStopsLayoutWhenCancelled() {
    let cues = (0..<500).map { index in
        PlaybackSubtitleCue(
            sourceOrdinal: index,
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Cue \(index)"
        )
    }
    var cancellationChecks = 0

    let layout = SRTSubtitleRenderer.makeLayout(
        cues: cues,
        canvasSize: CGSize(width: 1_920, height: 1_080),
        style: SRTSubtitleStyle(),
        isCancelled: {
            cancellationChecks += 1
            return cancellationChecks > 5
        }
    )

    #expect(layout == nil)
    #expect(cancellationChecks == 6)
}

@Test
func playbackSubtitleTrackFindsLateCueInLargeTrack() {
    let cues = (0..<10_000).map { index in
        PlaybackSubtitleCue(
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Cue \(index)"
        )
    }
    let track = PlaybackSubtitleTrack(cues: cues)

    #expect(track.activeText(at: 9_876.2) == "Cue 9876")
    #expect(track.activeText(at: 9_876.6) == nil)
}

private func elapsedMilliseconds(since startedAt: UInt64) -> Double {
    Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
}

@Test
func playbackSubtitleTrackFindsEarlyLongCuePastExpiredIntervals() {
    var cues = [
        PlaybackSubtitleCue(
            sourceOrdinal: 0,
            startMilliseconds: 0,
            endMilliseconds: 20_000_000,
            text: "Long cue"
        )
    ]
    cues += (1..<10_000).map { index in
        PlaybackSubtitleCue(
            sourceOrdinal: index,
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 1,
            text: "Expired \(index)"
        )
    }
    let track = PlaybackSubtitleTrack(cues: cues)

    #expect(track.activeCues(atMilliseconds: 15_000_000).map(\.sourceOrdinal) == [0])
}

@Test
@MainActor
func playbackPlayerStoresNonDefaultNativeSpeed() throws {
    let player = PlaybackPlayer()

    try player.setDoubleProperty("speed", value: 1.5)

    #expect(try player.getDoubleProperty("speed") == 1.5)
}

@Test
@MainActor
func playbackPlayerClampsNativeSpeedRange() throws {
    let player = PlaybackPlayer()

    try player.setDoubleProperty("speed", value: 3.0)
    #expect(try player.getDoubleProperty("speed") == 2.0)

    try player.setDoubleProperty("speed", value: 0.25)
    #expect(try player.getDoubleProperty("speed") == 0.5)
}

private func temporaryPlaybackTestDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("CueSeekerPlaybackTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func playbackTestCueGroup(content: String) -> SubtitleCueGroup {
    SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:00.00",
        endTimecode: "0:00:01.00",
        startMilliseconds: 0,
        endMilliseconds: 1_000,
        searchContent: content,
        cueLines: [
            SubtitleCueLine(
                eventIndex: 0,
                sourceFormat: .ass,
                sourceStyle: nil,
                sourceLayer: nil,
                startTimecode: "0:00:00.00",
                endTimecode: "0:00:01.00",
                startMilliseconds: 0,
                endMilliseconds: 1_000,
                content: content,
                displayX: nil,
                displayY: nil,
                displayOrder: 0
            )
        ]
    )
}

private func minimalASSPlaybackScript(text: String) -> String {
    """
    [Script Info]
    ScriptType: v4.00+
    PlayResX: 640
    PlayResY: 360

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Default, Helvetica, 32, &H00FFFFFF, &H000000FF, &H80000000, &H40000000, 0, 0, 0, 0, 100, 100, 0, 0, 1, 2, 1, 2, 20, 20, 20, 1

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:00.00,0:00:02.00,Default,,0,0,0,,\(text)
    """
}
