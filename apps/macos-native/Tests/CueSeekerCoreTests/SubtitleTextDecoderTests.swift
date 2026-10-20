import CoreFoundation
import Foundation
import Testing
import CueSeekerCore

@Test
func decodesUnicodeSubtitleByteOrderMarksToUTF8() throws {
    let contents = assScript(text: "日本語字幕")
    let variants: [(String.Encoding, [UInt8])] = [
        (.utf8, [0xEF, 0xBB, 0xBF]),
        (.utf16LittleEndian, [0xFF, 0xFE]),
        (.utf16BigEndian, [0xFE, 0xFF]),
        (.utf32LittleEndian, [0xFF, 0xFE, 0x00, 0x00]),
        (.utf32BigEndian, [0x00, 0x00, 0xFE, 0xFF]),
    ]

    for (encoding, byteOrderMark) in variants {
        var data = Data(byteOrderMark)
        data.append(try #require(contents.data(using: encoding)))

        let decoded = try SubtitleTextDecoder.decode(data, format: .ass)

        #expect(decoded == contents)
        #expect(Data(decoded.utf8) == Data(contents.utf8))
    }
}

@Test
func detectsCommonUnmarkedEastAsianSubtitleEncodings() throws {
    let samples: [(CFStringEncodings, String)] = [
        (.dosJapanese, "日本語字幕の再生を確認します"),
        (.shiftJIS, "日本語字幕の再生を確認します"),
        (.EUC_JP, "日本語字幕の再生を確認します"),
        (.GB_18030_2000, "简体中文字幕测试播放"),
        (.GBK_95, "简体中文字幕测试播放"),
        (.big5, "繁體中文字幕測試播放"),
    ]

    for (encoding, text) in samples {
        let contents = assScript(text: String(repeating: text, count: 3))
        let data = try #require(contents.data(using: stringEncoding(encoding)))

        let decoded = try SubtitleTextDecoder.decode(data, format: .ass)
        let groups = try ASSParser.parseCueGroupsForIndexing(decoded)

        #expect(decoded == contents)
        #expect(groups.first?.cueLines.first?.content == String(repeating: text, count: 3))
    }
}

@Test
func sharesDecodedSRTTextBetweenIndexingAndPlaybackParsing() throws {
    let text = "日本語字幕の索引と再生を確認します"
    let contents = """
    1
    00:00:01,000 --> 00:00:03,000
    \(text)

    """
    let data = try #require(contents.data(using: stringEncoding(.dosJapanese)))

    let decoded = try SubtitleTextDecoder.decode(data, format: .srt)
    let indexedGroups = try SRTParser.parseCueGroupsForIndexing(decoded)
    let playbackEntries = try SRTParser.parseForRendering(data)

    #expect(indexedGroups.first?.cueLines.first?.content == text)
    #expect(playbackEntries.first?.text == text)
}

@Test
func rejectsDecodedTextWithoutSubtitleStructure() throws {
    let data = Data("plain text without subtitle structure".utf8)

    #expect(throws: SubtitleTextDecodingError.invalidStructure(.ass)) {
        try SubtitleTextDecoder.decode(data, format: .ass)
    }
    #expect(throws: SubtitleTextDecodingError.invalidStructure(.srt)) {
        try SubtitleTextDecoder.decode(data, format: .srt)
    }
    #expect(throws: SubtitleTextDecodingError.invalidStructure(.vtt)) {
        try SubtitleTextDecoder.decode(data, format: .vtt)
    }
}

@Test
func rejectsMalformedByteOrderMarkedTextWithoutFallingBackToDetection() {
    let malformedUTF16LE = Data([0xFF, 0xFE, 0x41])

    #expect(throws: SubtitleTextDecodingError.undecodableData) {
        try SubtitleTextDecoder.decode(malformedUTF16LE, format: .ass)
    }
}

@Test
func decodesEmptyOrByteOrderMarkOnlySubtitlesWithoutStructureError() throws {
    let utf8BOMOnly = Data([0xEF, 0xBB, 0xBF])

    #expect(try SubtitleTextDecoder.decode(Data(), format: .srt).isEmpty)
    #expect(try SubtitleTextDecoder.decode(utf8BOMOnly, format: .srt).isEmpty)
    #expect(try SubtitleTextDecoder.decode(Data(), format: .ass).isEmpty)
    #expect(try SubtitleTextDecoder.decode(utf8BOMOnly, format: .ass).isEmpty)
}

private func assScript(text: String) -> String {
    """
    [Script Info]
    ScriptType: v4.00+

    [V4+ Styles]
    Format: Name, Fontname, Fontsize
    Style: Default,Helvetica,24

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:03.00,Default,,0,0,0,,\(text)
    """
}

private func stringEncoding(_ encoding: CFStringEncodings) -> String.Encoding {
    String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(encoding.rawValue)
        )
    )
}
