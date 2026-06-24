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
func parsesTimecodesToMilliseconds() {
    #expect(SRTParser.milliseconds(from: "00:00:00,000") == 0)
    #expect(SRTParser.milliseconds(from: "00:00:01,001") == 1_001)
    #expect(SRTParser.milliseconds(from: "01:02:03,456") == 3_723_456)
    #expect(SRTParser.milliseconds(from: "01:02:03.456") == 3_723_456)
}

@Test
func rejectsInvalidTimecodes() {
    #expect(SRTParser.milliseconds(from: "00:60:00,000") == nil)
    #expect(SRTParser.milliseconds(from: "00:00:60,000") == nil)
    #expect(SRTParser.milliseconds(from: "00:00:00,1000") == nil)
    #expect(SRTParser.milliseconds(from: "not a timecode") == nil)
}
