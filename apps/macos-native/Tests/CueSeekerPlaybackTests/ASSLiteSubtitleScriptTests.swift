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
func assLiteColorParsesASSBGRAlphaFormat() {
    let color = ASSLiteColor(assText: "&H80402010")

    #expect(color?.red == 16.0 / 255.0)
    #expect(color?.green == 32.0 / 255.0)
    #expect(color?.blue == 64.0 / 255.0)
    #expect(color?.alpha == 1.0 - (128.0 / 255.0))
}
