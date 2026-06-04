import Testing
import CueSeekerCore

@Test
func analyzesSRTUsingFullSubtitleContentAndAppliesLanguageSetToCueGroups() {
    let contents = """
    1
    00:00:01,000 --> 00:00:03,000
    今日はみんなで映画を見に行きます。

    2
    00:00:04,000 --> 00:00:06,000
    明日は学校のあとで友達と話します。

    """
    let cueGroups = SRTParser.parseCueGroups(contents)
    let analysis = SubtitleLanguageAnalyzer().analyze(format: .srt, cueGroups: cueGroups)

    #expect(analysis.fileDetection?.languages == [.japanese])
    #expect(analysis.styleDetections.isEmpty)
    #expect(analysis.cueGroupLanguages == [
        [.japanese],
        [.japanese]
    ])
}

@Test
func analyzesOnlyUsedASSStylesAndMapsStyleLanguagesToCueGroups() {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Alignment, MarginL, MarginR, MarginV
    Style: JP,2,20,20,30
    Style: CN,8,20,20,40
    Style: Unused,2,20,20,30

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,JP,,0,0,0,,今日はライブの準備をします
    Dialogue: 0,0:00:01.00,0:00:03.00,CN,,0,0,0,,我们今天准备演出，大家一起练习新的歌曲。
    Dialogue: 0,0:00:04.00,0:00:06.00,JP,,0,0,0,,明日はスタジオで練習します
    """
    let cueGroups = ASSParser.parseCueGroups(contents)
    let analysis = SubtitleLanguageAnalyzer().analyze(format: .ass, cueGroups: cueGroups)

    #expect(Set(analysis.styleDetections.keys) == ["JP", "CN"])
    #expect(analysis.styleDetections["JP"]?.languages == [.japanese])
    #expect(analysis.styleDetections["CN"]?.languages == [.simplifiedChinese])
    #expect(analysis.cueGroupLanguages == [
        [.japanese, .simplifiedChinese],
        [.japanese]
    ])
}

@Test
func canonicalizesStarPrefixedASSStyleNames() {
    let contents = """
    [Script Info]

    [V4+ Styles]
    Format: Name, Alignment, MarginL, MarginR, MarginV
    Style: Default,2,20,20,30

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,*Default,,0,0,0,,This is a clear English subtitle line.
    Dialogue: 0,0:00:04.00,0:00:06.00,*Default,,0,0,0,,Another English sentence gives enough context.
    """
    let cueGroups = ASSParser.parseCueGroups(contents)
    let analysis = SubtitleLanguageAnalyzer().analyze(format: .ass, cueGroups: cueGroups)

    #expect(Set(analysis.styleDetections.keys) == ["Default"])
    #expect(analysis.styleDetections["Default"]?.languages == [.english])
    #expect(analysis.cueGroupLanguages == [
        [.english],
        [.english]
    ])
}

@Test
func returnsUnknownForUsedASSStyleWithOnlyDrawingResiduals() {
    let contents = """
    [Script Info]

    [V4+ Styles]
    Format: Name, Alignment, MarginL, MarginR, MarginV
    Style: FX,2,20,20,30

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,FX,,0,0,0,,{\\p1}m 0 0 l 24 -1 b 34 -2 44 -2 54 -1
    """
    let cueGroups = ASSParser.parseCueGroups(contents)
    let analysis = SubtitleLanguageAnalyzer().analyze(format: .ass, cueGroups: cueGroups)

    #expect(Set(analysis.styleDetections.keys) == ["FX"])
    #expect(analysis.styleDetections["FX"]?.languages == [.unknown])
    #expect(analysis.cueGroupLanguages == [
        [.unknown]
    ])
}

@Test
func splitsLanguageSegmentsOnSubtitleLineBreaks() {
    let segments = SubtitleLanguageAnalyzer.languageSegments(
        from: "中文第一行\\N日本語の二行目\nm 0 0 l 10 10"
    )

    #expect(segments == [
        "中文第一行",
        "日本語の二行目"
    ])
}
