import Foundation
import Testing
@testable import CueSeekerPlayback

@Test
func assLiteParserReadsScriptStylesAndDialogues() {
    let contents = """
    [Script Info]
    PlayResX: 1920
    PlayResY: 1080

    [V4+ Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, BackColour, Bold, Italic, Alignment, MarginL, MarginR, MarginV, Outline, Shadow
    Style: Dial_EN,Helvetica Neue,54,&H00FFFFFF,&H00000000,&H80000000,-1,0,2,36,36,42,3,2

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 1,0:00:01.20,0:00:04.50,Dial_EN,,0,0,0,,{\\an8}Hello\\Nworld{\\pos(100,200)}
    """

    let script = ASSLiteParser.parse(contents)

    #expect(script.playResX == 1920)
    #expect(script.playResY == 1080)
    #expect(script.styles["Dial_EN"]?.fontName == "Helvetica Neue")
    #expect(script.styles["Dial_EN"]?.fontSize == 54)
    #expect(script.styles["Dial_EN"]?.isBold == true)
    #expect(script.styles["Dial_EN"]?.isItalic == false)
    #expect(script.styles["Dial_EN"]?.borderStyle == 1)
    #expect(script.styles["Dial_EN"]?.alignment == 2)
    #expect(script.styles["Dial_EN"]?.marginV == 42)
    #expect(script.styles["Dial_EN"]?.outline == 3)
    #expect(script.styles["Dial_EN"]?.shadow == 2)

    #expect(script.dialogues.count == 1)
    #expect(script.dialogues[0].layer == 1)
    #expect(script.dialogues[0].startMilliseconds == 1_200)
    #expect(script.dialogues[0].endMilliseconds == 4_500)
    #expect(script.dialogues[0].styleName == "Dial_EN")
    #expect(script.dialogues[0].alignmentOverride == 8)
    #expect(script.dialogues[0].text == "Hello\nworld")
}

@Test
func assLiteParserReadsV4StyleRenderingFields() {
    let contents = """
    [V4 Styles]
    Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
    Style: Dial_CH,FZCuYuan-M03,70,&H14FFFFFF,&H000000FF,&H14211711,&H00000000,0,-1,1,0,90,95,1.5,12,1,2.8,3,8,10,20,56,1
    """

    let style = ASSLiteParser.parse(contents).styles["Dial_CH"]

    #expect(style?.fontName == "FZCuYuan-M03")
    #expect(style?.fontSize == 70)
    #expect(style?.primaryColor.red == 1)
    #expect(style?.primaryColor.green == 1)
    #expect(style?.primaryColor.blue == 1)
    #expect(style?.primaryColor.alpha == 1 - (20.0 / 255.0))
    #expect(style?.outlineColor.red == 17.0 / 255.0)
    #expect(style?.outlineColor.green == 23.0 / 255.0)
    #expect(style?.outlineColor.blue == 33.0 / 255.0)
    #expect(style?.outlineColor.alpha == 1 - (20.0 / 255.0))
    #expect(style?.isBold == false)
    #expect(style?.isItalic == true)
    #expect(style?.isUnderline == true)
    #expect(style?.isStrikeOut == false)
    #expect(style?.scaleX == 90)
    #expect(style?.scaleY == 95)
    #expect(style?.spacing == 1.5)
    #expect(style?.angle == 12)
    #expect(style?.borderStyle == 1)
    #expect(style?.outline == 2.8)
    #expect(style?.shadow == 3)
    #expect(style?.alignment == 8)
    #expect(style?.marginL == 10)
    #expect(style?.marginR == 20)
    #expect(style?.marginV == 56)
    #expect(style?.encoding == 1)
}

@Test
func assLiteParserHandlesNonDefaultEventFormatAndCommasInText() {
    let contents = """
    [Events]
    Format: End, Start, Layer, Style, Text
    Dialogue: 0:00:05.00,0:00:03.25,4,Alt,One, two, three
    """

    let script = ASSLiteParser.parse(contents)

    #expect(script.dialogues.count == 1)
    #expect(script.dialogues[0].startMilliseconds == 3_250)
    #expect(script.dialogues[0].endMilliseconds == 5_000)
    #expect(script.dialogues[0].layer == 4)
    #expect(script.dialogues[0].styleName == "Alt")
    #expect(script.dialogues[0].text == "One, two, three")
}

@Test
func assLiteParserSortsActiveDialoguesByLayerAndSourceOrder() {
    let contents = """
    [Events]
    Format: Layer, Start, End, Style, Text
    Dialogue: 2,0:00:01.00,0:00:03.00,Default,Top layer
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,Base layer first
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,Base layer second
    Dialogue: 5,0:00:04.00,0:00:05.00,Default,Inactive
    """

    let active = ASSLiteParser.parse(contents).activeDialogues(atMilliseconds: 1_500)

    #expect(active.map(\.text) == ["Base layer first", "Base layer second", "Top layer"])
}

@Test
func assLiteParserKeepsOnlyDialoguesOverlappingTimeWindow() {
    let contents = """
    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default,Helvetica,48

    [Events]
    Format: Layer, Start, End, Style, Text
    Dialogue: 0,0:00:01.00,0:00:02.00,Default,Before
    Dialogue: 0,0:00:02.00,0:00:03.00,Default,Inside
    Dialogue: 0,0:00:04.50,0:00:07.00,Default,Overlapping
    Dialogue: 0,0:00:05.00,0:00:05.00,Default,Zero duration
    Dialogue: 0,0:00:08.00,0:00:09.00,Default,After
    """

    let script = ASSLiteParser.parse(
        contents,
        timeWindow: PlaybackSubtitleTimeWindow(
            startMilliseconds: 2_000,
            endMilliseconds: 5_000
        )
    )

    #expect(script.styles["Default"]?.fontName == "Helvetica")
    #expect(script.dialogues.map(\.text) == ["Inside", "Overlapping", "Zero duration"])
}

@Test
func assLiteFallbackPreparationIgnoresPreparationWindow() {
    let contents = """
    [Events]
    Format: Layer, Start, End, Style, Text
    Dialogue: 0,0:00:01.00,0:00:02.00,Default,Before
    Dialogue: 0,0:00:04.00,0:00:05.00,Default,Inside
    Dialogue: 0,0:00:08.00,0:00:09.00,Default,After
    """
    let source = PlaybackSubtitleSource(
        url: URL(fileURLWithPath: "/tmp/Movie.ass"),
        format: .ass,
        preparationTimeWindow: PlaybackSubtitleTimeWindow(
            startMilliseconds: 4_000,
            endMilliseconds: 5_000
        )
    )

    let script = ASSLiteSubtitlePreparation.fallbackScript(contents, source: source)

    #expect(script.dialogues.map(\.text) == ["Before", "Inside", "After"])
}

@Test
func assLiteColorParsesASSBGRAlphaFormat() {
    let color = ASSLiteColor(assText: "&H80402010")

    #expect(color?.red == 16.0 / 255.0)
    #expect(color?.green == 32.0 / 255.0)
    #expect(color?.blue == 64.0 / 255.0)
    #expect(color?.alpha == 1.0 - (128.0 / 255.0))
}
