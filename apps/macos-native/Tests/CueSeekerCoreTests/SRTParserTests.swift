import Foundation
import Testing
import CueSeekerCore

@Test
func parsesValidSubtitleBlocksAndSkipsMalformedBlocks() throws {
    let fixtureURL = try #require(Bundle.module.url(forResource: "sample", withExtension: "srt"))
    let contents = try String(contentsOf: fixtureURL, encoding: .utf8)

    let entries = SRTParser.parse(contents)

    #expect(entries.count == 3)
    #expect(entries[0].sequenceNumber == 1)
    #expect(entries[0].startMilliseconds == 1_000)
    #expect(entries[0].endMilliseconds == 3_500)
    #expect(entries[0].text == "Hello world.")

    #expect(entries[1].sequenceNumber == 2)
    #expect(entries[1].startMilliseconds == 60_250)
    #expect(entries[1].text == "First subtitle line.\nSecond subtitle line.")

    #expect(entries[2].sequenceNumber == nil)
    #expect(entries[2].startMilliseconds == 123_004)
    #expect(entries[2].endMilliseconds == 125_006)
    #expect(entries[2].text == "No sequence number.")
}

@Test
func filtersShortSRTCuesAndDeduplicatesCleanedEntries() {
    let contents = """
    1
    00:00:01,000 --> 00:00:01,100
    Too short.

    2
    00:00:02,000 --> 00:00:03,000
      Duplicate text.

    3
    00:00:02,000 --> 00:00:03,000
    Duplicate text.

    4
    00:00:04,000 --> 00:00:04,200
    Boundary kept.

    """

    let entries = SRTParser.parse(contents)

    #expect(entries.map(\.text) == ["Duplicate text.", "Boundary kept."])
    #expect(entries.map(\.sequenceNumber) == [2, 4])
}

@Test
func deduplicatesSRTEntriesByNormalizedMilliseconds() {
    let contents = """
    1
    00:00:01,000 --> 00:00:03,000
    Same logical Cue.

    2
    00:00:01.000 --> 00:00:03.000
    Same logical Cue.

    """

    let entries = SRTParser.parse(contents)

    #expect(entries.count == 1)
    #expect(entries.first?.startMilliseconds == 1_000)
    #expect(entries.first?.endMilliseconds == 3_000)
}

@Test
func indexingSkipsOneReversedTimeRangeAndKeepsValidBlocks()
    throws
{
    let groups = try SRTParser.parseCueGroupsForIndexing(
        """
        1
        00:00:01,000 --> 00:00:03,000
        First Cue

        2
        00:00:06,000 --> 00:00:04,000
        Reversed Cue

        """
    )

    #expect(groups.count == 1)
    #expect(groups.first?.cueLines.first?.content == "First Cue")
}

@Test
func playbackParsingDecodesUTF16AndIgnoresPositionParameters() throws {
    let contents = """
    1
    00:00:01,000 --> 00:00:02,000 X1:10 X2:20 Y1:30 Y2:40
    First

    2
    00:00:03,000 --> 00:00:03,000
    Zero length

    """
    var data = Data([0xFF, 0xFE])
    data.append(try #require(contents.data(using: .utf16LittleEndian)))

    let entries = try SRTParser.parseForRendering(data)

    #expect(entries.count == 1)
    #expect(entries[0].startMilliseconds == 1_000)
    #expect(entries[0].endMilliseconds == 2_000)
    #expect(entries[0].text == "First")
}

@Test
func parsesTimecodesToMilliseconds() {
    #expect(SRTParser.milliseconds(from: "00:00:00,000") == 0)
    #expect(SRTParser.milliseconds(from: "00:00:01,001") == 1_001)
    #expect(SRTParser.milliseconds(from: "01:02:03,456") == 3_723_456)
    #expect(SRTParser.milliseconds(from: "01:02:03.456") == 3_723_456)
    #expect(SRTParser.milliseconds(from: "00:10.159") == 10_159)
    #expect(SRTParser.milliseconds(from: "02:03.456") == 123_456)
}

@Test
func parsesWebVTTSubtitlesIgnoringHeaderAndMetadataAndStrippingInlineTags() throws {
    let contents = """
    WEBVTT
    Kind: captions
    Language: en

    NOTE
    This is a comment block.

    STYLE
    ::cue {
      color: yellow;
    }

    REGION
    id:footer

    00:00:00.000 --> 00:00:07.000
    Transcriber: Translate TED
    Reviewer: Allam Zedan

    cue-2
    00:10.159 --> 00:12.722 align:start line:85%
    The <c.yellow>people</c> in the back,
    can you <00:00:11.000><c>hear me</c> <i>clearly</i>?

    00:15.000 --> 00:15.100
    Too short.

    00:20.000 --> 00:22.000
    <c></c>

    """

    let groups = try SRTParser.parseCueGroupsForIndexing(contents, format: .vtt)

    #expect(groups.count == 2)
    #expect(groups[0].startMilliseconds == 0)
    #expect(groups[0].endMilliseconds == 7_000)
    #expect(groups[0].cueLines.first?.sourceFormat == .vtt)
    #expect(groups[0].cueLines.first?.content == "Transcriber: Translate TED\nReviewer: Allam Zedan")

    #expect(groups[1].startMilliseconds == 10_159)
    #expect(groups[1].endMilliseconds == 12_722)
    #expect(groups[1].cueLines.first?.sourceFormat == .vtt)
    #expect(groups[1].cueLines.first?.content == "The people in the back,\ncan you hear me clearly?")

    let rendered = try SRTParser.parseForRendering(Data(contents.utf8), format: .vtt)
    #expect(rendered.count == 3)
    #expect(rendered[1].text == "The people in the back,\ncan you hear me clearly?")
}

@Test
func rejectsInvalidTimecodes() {
    #expect(SRTParser.milliseconds(from: "00:60:00,000") == nil)
    #expect(SRTParser.milliseconds(from: "00:00:60,000") == nil)
    #expect(SRTParser.milliseconds(from: "00:00:00,1000") == nil)
    #expect(SRTParser.milliseconds(from: "not a timecode") == nil)
}

@Test
func indexingSkipsEmptyTextSRTBlocksAndKeepsRemainingValidBlocks() throws {
    let groups = try SRTParser.parseCueGroupsForIndexing(
        """
        1
        00:00:01,000 --> 00:00:03,000

        2
        00:00:04,000 --> 00:00:06,000
        Second Cue Kept

        3
        00:00:07,000 --> 00:00:09,000
        4
        00:00:10,000 --> 00:00:12,000
        Fourth Cue Kept
        """
    )

    #expect(groups.map { $0.cueLines.first?.content } == ["Second Cue Kept", "Fourth Cue Kept"])
    #expect(groups.map(\.sequenceNumber) == [2, 4])
}
