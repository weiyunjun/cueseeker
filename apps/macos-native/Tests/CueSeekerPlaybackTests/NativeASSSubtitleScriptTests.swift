import Foundation
import Testing
@testable import CueSeekerPlayback

@Test
func nativeASSParserReadsScriptStylesAndEvents() {
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
    Comment: 1,0:00:01.20,0:00:04.50,Dial_EN,,0,0,0,,Not rendered
    """

    let document = NativeASSParser.parse(contents)

    #expect(document.playResX == 1920)
    #expect(document.playResY == 1080)
    #expect(document.styles["Dial_EN"]?.fontName == "Helvetica Neue")
    #expect(document.styles["Dial_EN"]?.fontSize == 54)
    #expect(document.styles["Dial_EN"]?.primaryColor.red == 1)
    #expect(document.styles["Dial_EN"]?.primaryColor.green == 1)
    #expect(document.styles["Dial_EN"]?.primaryColor.blue == 1)
    #expect(document.styles["Dial_EN"]?.isBold == true)
    #expect(document.styles["Dial_EN"]?.isItalic == false)
    #expect(document.styles["Dial_EN"]?.alignment == 2)
    #expect(document.styles["Dial_EN"]?.marginV == 42)
    #expect(document.styles["Dial_EN"]?.outline == 3)
    #expect(document.styles["Dial_EN"]?.shadow == 2)

    #expect(document.events.count == 1)
    #expect(document.events[0].layer == 1)
    #expect(document.events[0].startMilliseconds == 1_200)
    #expect(document.events[0].endMilliseconds == 4_500)
    #expect(document.events[0].styleName == "Dial_EN")
    #expect(document.events[0].rawText == "{\\an8}Hello\\Nworld{\\pos(100,200)}")
    #expect(document.events[0].cleanedText == "Hello\nworld")
    #expect(document.events[0].alignmentOverride == 8)
}

@Test
func nativeASSParserReadsNonDefaultFormatsAndCommasInText() {
    let contents = """
    [V4 Styles]
    Format: Fontsize, Name, Fontname, BackColour, PrimaryColour, OutlineColour, Italic, Bold
    Style: 70,Dial_CH,FZCuYuan-M03,&H40000000,&H14FFFFFF,&H14211711,-1,0

    [Events]
    Format: End, Start, Style, Layer, Text
    Dialogue: 0:00:05.00,0:00:03.25,Dial_CH,4,One, two, three
    """

    let document = NativeASSParser.parse(contents)
    let style = document.styles["Dial_CH"]

    #expect(style?.fontName == "FZCuYuan-M03")
    #expect(style?.fontSize == 70)
    #expect(style?.isItalic == true)
    #expect(style?.isBold == false)
    #expect(style?.primaryColor.alpha == 1 - (20.0 / 255.0))
    #expect(style?.outlineColor.red == 17.0 / 255.0)
    #expect(style?.outlineColor.green == 23.0 / 255.0)
    #expect(style?.outlineColor.blue == 33.0 / 255.0)
    #expect(style?.shadowColor.alpha == 1 - (64.0 / 255.0))

    #expect(document.events.count == 1)
    #expect(document.events[0].startMilliseconds == 3_250)
    #expect(document.events[0].endMilliseconds == 5_000)
    #expect(document.events[0].layer == 4)
    #expect(document.events[0].styleName == "Dial_CH")
    #expect(document.events[0].cleanedText == "One, two, three")
}
