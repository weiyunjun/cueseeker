import Testing
@testable import CueSeekerCore

@Test
func parsesASSDialogueEventsIntoExactTimeCueGroups() {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Alignment, MarginL, MarginR, MarginV
    Style: Top,8,20,20,40
    Style: Bottom,2,20,20,30

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,Bottom,,0,0,0,,{\\an2}Hello\\Nworld
    Comment: 0,0:00:01.00,0:00:03.00,Bottom,,0,0,0,,Not indexed
    Dialogue: 1,0:00:01.00,0:00:03.00,Top,,0,0,0,,{\\an8}こんにちは
    Dialogue: 0,0:00:01.01,0:00:03.00,Bottom,,0,0,0,,Near timestamp
    """

    let groups = ASSParser.parseCueGroups(contents)

    #expect(groups.count == 2)
    #expect(groups[0].startMilliseconds == 1_000)
    #expect(groups[0].endMilliseconds == 3_000)
    #expect(groups[0].cueLines.map(\.content) == ["こんにちは", "Hello\nworld"])
    #expect(groups[0].cueLines.map(\.sourceStyle) == ["Top", "Bottom"])
    #expect(groups[0].cueLines.map(\.sourceLayer) == [1, 0])
    #expect(groups[0].searchContent == "こんにちは\nHello\nworld")

    #expect(groups[1].startMilliseconds == 1_010)
    #expect(groups[1].cueLines.map(\.content) == ["Near timestamp"])
}

@Test
func groupsASSDialogueByNormalizedMilliseconds() {
    let contents = """
    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.0,0:00:03.0,Default,,0,0,0,,First Cue
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,Second Cue
    """

    let groups = ASSParser.parseCueGroups(contents)

    #expect(groups.count == 1)
    #expect(groups.first?.startMilliseconds == 1_000)
    #expect(groups.first?.endMilliseconds == 3_000)
    #expect(groups.first?.cueLines.map(\.content) == ["First Cue", "Second Cue"])
}

@Test
func filtersShortASSDialogueAndDeduplicatesCleanedRetainedFields() {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Alignment, MarginL, MarginR, MarginV
    Style: JP,2,20,20,30
    Style: CN,8,20,20,40

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:01.10,JP,,0,0,0,fx,Too short
    Dialogue: 0,0:00:02.00,0:00:03.00,JP,,0,0,0,fx,{\\bord2}Same text
    Dialogue: 0,0:00:02.00,0:00:03.00,JP,,0,0,0,fx,Same text
    Dialogue: 1,0:00:02.00,0:00:03.00,CN,,0,0,0,fx,Same text
    Dialogue: 0,0:00:04.00,0:00:04.20,JP,,0,0,0,fx,Boundary kept
    """

    let groups = ASSParser.parseCueGroups(contents)

    #expect(groups.count == 2)
    #expect(groups[0].cueLines.map(\.content) == ["Same text", "Same text"])
    #expect(groups[0].cueLines.map(\.sourceStyle) == ["CN", "JP"])
    #expect(groups[1].cueLines.map(\.content) == ["Boundary kept"])
}

@Test
func assLogicalDuplicatesIncludeRemainingDialogueFields() {
    let contents = """
    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:02.00,0:00:03.00,JP,Alice,0,0,0,,Same text
    Dialogue: 0,0:00:02.00,0:00:03.00,JP,Alice,0,0,0,,Same text
    Dialogue: 0,0:00:02.00,0:00:03.00,JP,Bob,0,0,0,,Same text
    """

    let lines = ASSParser.parseCueGroups(contents).flatMap(\.cueLines)

    #expect(lines.count == 2)
    #expect(Set(lines.map(\.sourceIdentityRemainder)).count == 2)
}

@Test
func ordersSameTimestampBottomAlignedASSLinesByCollisionPositionAtIndexTime() {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontsize, Alignment, MarginL, MarginR, MarginV
    Style: JP,25,2,10,10,13
    Style: CN,40,2,10,10,10

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:11:15.90,0:11:19.86,JP,,0000,0000,0000,,Japanese lower line
    Dialogue: 0,0:11:15.90,0:11:19.86,CN,,0000,0000,0000,,Chinese upper line
    """

    let groups = ASSParser.parseCueGroups(contents)

    #expect(groups.count == 1)
    #expect(groups[0].cueLines.map(\.content) == ["Chinese upper line", "Japanese lower line"])
    #expect(groups[0].cueLines.map(\.displayOrder) == [0, 1])
    #expect(groups[0].searchContent == "Chinese upper line\nJapanese lower line")
}

@Test
func parsesASSDialogueWithNonDefaultEventFieldOrderAndCommasInText() {
    let contents = """
    [Events]
    Format: End, Start, Style, Layer, Text
    Dialogue: 0:00:05.50,0:00:04.25,Default,3,Hello, with comma
    """

    let groups = ASSParser.parseCueGroups(contents)

    #expect(groups.count == 1)
    #expect(groups[0].startMilliseconds == 4_250)
    #expect(groups[0].endMilliseconds == 5_500)
    #expect(groups[0].cueLines[0].content == "Hello, with comma")
    #expect(groups[0].cueLines[0].sourceLayer == 3)
}

@Test
func extractsASSReferencedFontsFromStylesAndInlineOverrides() {
    let contents = """
    [Script Info]
    ScriptType: v4.00+

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: CN, 华文中宋 ,42
    Style: JP,EPSON 太明朝体Ｂ,28
    Style: CN-Alt,华文中宋,36

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,CN,,0,0,0,,{\\fn汉仪小隶书简\\bord2}Hello {\\fn華康采風體}world
    Dialogue: 0,0:00:04.00,0:00:05.00,CN,,0,0,0,,literal \\fnIgnored text
    Dialogue: 0,0:00:06.00,0:00:07.00,CN,,0,0,0,,{\\fn汉仪小隶书简}again
    """

    let references = ASSFontIntentExtractor.references(from: contents)

    #expect(references == [
        ASSFontReferenceIntent(fontName: "华文中宋", source: .style, occurrenceCount: 2, firstOccurrenceOrder: 0),
        ASSFontReferenceIntent(fontName: "EPSON 太明朝体Ｂ", source: .style, occurrenceCount: 1, firstOccurrenceOrder: 1),
        ASSFontReferenceIntent(fontName: "汉仪小隶书简", source: .inlineOverride, occurrenceCount: 2, firstOccurrenceOrder: 3),
        ASSFontReferenceIntent(fontName: "華康采風體", source: .inlineOverride, occurrenceCount: 1, firstOccurrenceOrder: 4)
    ])
}

@Test
func rejectsInvalidASSTimecodes() {
    #expect(ASSParser.milliseconds(from: "0:00:00.00") == 0)
    #expect(ASSParser.milliseconds(from: "1:02:03.45") == 3_723_450)
    #expect(ASSParser.milliseconds(from: "0:60:00.00") == nil)
    #expect(ASSParser.milliseconds(from: "0:00:60.00") == nil)
    #expect(ASSParser.milliseconds(from: "bad") == nil)
}

@Test
func parsesSSADialogueWithV4StylesLeadingStarAndLegacyAlignment() throws {
    let contents = """
    [Script Info]
    ScriptType: v4.00
    PlayResX: 1920
    PlayResY: 1080

    [V4 Styles]
    Format: Name, Fontname, Fontsize, Alignment, MarginL, MarginR, MarginV
    Style: *Bottom,Arial,28,2,20,20,30
    Style: Top,Arial,28,6,20,20,40

    [Events]
    Format: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: Marked=0,0:00:01.00,0:00:03.00,Bottom,,0000,0000,0000,,Hello from SSA bottom subtitle line for language detection
    Dialogue: Marked=0,0:00:01.00,0:00:03.00,*Top,,0000,0000,0000,,こんにちは、今日はとても良い天気ですね
    Dialogue: Marked=0,0:00:04.00,0:00:06.00,Bottom,,0000,0000,0000,,{\\a6}Inline top override
    Dialogue: Marked=0,0:00:04.00,0:00:06.00,Bottom,,0000,0000,0000,,{\\a2}Inline bottom override
    """

    let groups = try ASSParser.parseCueGroupsForIndexing(contents, format: .ssa)

    #expect(groups.count == 2)
    #expect(groups[0].cueLines.map(\.sourceFormat) == [.ssa, .ssa])
    #expect(groups[0].cueLines.map(\.content) == [
        "こんにちは、今日はとても良い天気ですね",
        "Hello from SSA bottom subtitle line for language detection"
    ])
    #expect(groups[0].cueLines.map(\.sourceLayer) == [nil, nil])
    #expect(groups[1].cueLines.map(\.content) == ["Inline top override", "Inline bottom override"])

    let analysis = SubtitleLanguageAnalyzer().analyze(format: .ssa, cueGroups: groups)
    #expect(analysis.format == .ssa)
    #expect(analysis.styleDetections["Bottom"]?.languages.contains(.english) == true)
    #expect(analysis.styleDetections["Top"]?.languages.contains(.japanese) == true)
}

@Test
func ordersSameNamedVideoSubtitlesWithAssBeforeSsaBeforeSrtBeforeVtt() {
    let videoPath = "/Media/Episode01.mkv"
    let subtitles = VideoSubtitles(
        videoPath: videoPath,
        subtitles: [
            VideoSubtitle(subtitleFileID: 1, subtitlePath: "/Media/Episode01.vtt", format: .vtt),
            VideoSubtitle(subtitleFileID: 2, subtitlePath: "/Media/Episode01.srt", format: .srt),
            VideoSubtitle(subtitleFileID: 3, subtitlePath: "/Media/Episode01.ssa", format: .ssa),
            VideoSubtitle(subtitleFileID: 4, subtitlePath: "/Media/Episode01.ass", format: .ass),
            VideoSubtitle(subtitleFileID: 5, subtitlePath: "/Media/Episode01.chs.ass", format: .ass)
        ],
        defaultSubtitleFileID: nil
    )

    #expect(subtitles.subtitles.map(\.subtitlePath) == [
        "/Media/Episode01.ass",
        "/Media/Episode01.ssa",
        "/Media/Episode01.srt",
        "/Media/Episode01.vtt",
        "/Media/Episode01.chs.ass"
    ])
    #expect(subtitles.effectiveDefault?.format == .ass)
}

@Test
func reconcilesSSACueIdentityUsingFourPartRules() throws {
    let originalContents = """
    [Script Info]
    ScriptType: v4.00

    [V4 Styles]
    Format: Name, Fontname, Fontsize, Alignment, MarginL, MarginR, MarginV
    Style: *Default,Arial,28,2,20,20,30

    [Events]
    Format: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: Marked=0,0:00:01.00,0:00:03.00,Default,Alice,0000,0000,0000,,Original SSA text
    """
    let editedContents = """
    [Script Info]
    ScriptType: v4.00

    [V4 Styles]
    Format: Name, Fontname, Fontsize, Alignment, MarginL, MarginR, MarginV
    Style: *Default,Arial,28,2,20,20,30

    [Events]
    Format: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: Marked=0,0:00:01.00,0:00:03.00,Default,Alice,0000,0000,0000,,Edited SSA text
    """

    let originalCue = try #require(
        try ASSParser.parseCueGroupsForIndexing(originalContents, format: .ssa).first?.cueLines.first
    )
    let editedCue = try #require(
        try ASSParser.parseCueGroupsForIndexing(editedContents, format: .ssa).first?.cueLines.first
    )

    let stored = StoredCueIdentity(
        cueID: 42,
        sourceFormat: originalCue.sourceFormat,
        sourceStyle: originalCue.sourceStyle,
        sourceIdentityRemainder: originalCue.sourceIdentityRemainder,
        startMilliseconds: originalCue.startMilliseconds,
        endMilliseconds: originalCue.endMilliseconds,
        content: originalCue.content
    )

    let assignments = CueIdentityReconciler.reconcile(
        storedCues: [stored],
        newCues: [editedCue]
    )

    #expect(assignments[0] == CueIdentityAssignment(cueID: 42, previousContent: "Original SSA text"))
}
