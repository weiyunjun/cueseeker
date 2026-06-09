import Foundation
import Testing
import CueSeekerCore

@Test
func speakerDisplayOrdersRegularSpeakersBeforeSuspectedSpeakers() {
    let text = SubtitleSpeakerDisplayFormatter.prefixedText(
        "春日影",
        speakers: ["疑似高松灯", "长崎素世"]
    )

    #expect(text == "长崎素世,疑似高松灯: 春日影")
}

@Test
func speakerDisplayPreservesLeadingASSOverrideTags() {
    let text = SubtitleSpeakerDisplayFormatter.prefixedASSDialogueText(
        "{\\an8}{\\pos(10,20)}こんにちは",
        speakers: ["疑似高松灯", "长崎素世"]
    )

    #expect(text == "{\\an8}{\\pos(10,20)}长崎素世,疑似高松灯: こんにちは")
}

@Test
func speakerDisplayTargetCuesUseFirstDisplayLineWithGroupSpeakers() {
    let records = [
        speakerDisplayLineRecord(
            id: 2,
            cueGroupID: 42,
            content: "日本語",
            displayOrder: 1
        ),
        speakerDisplayLineRecord(
            id: 1,
            cueGroupID: 42,
            content: "中文",
            displayOrder: 0
        )
    ]

    let cues = SubtitleSpeakerDisplayCue.targetCues(
        records: records,
        speakersByCueGroupID: [42: ["高松灯"]]
    )

    #expect(cues.count == 1)
    #expect(cues.first?.cleanText == "中文")
    #expect(cues.first?.speakers == ["高松灯"])
}

@Test
func speakerDisplayTargetCuesUseAssignedCueLineSpeakers() {
    let records = [
        speakerDisplayLineRecord(
            id: 1,
            cueGroupID: 42,
            content: "中文",
            style: "Dial_CH",
            displayOrder: 0
        ),
        speakerDisplayLineRecord(
            id: 2,
            cueGroupID: 42,
            content: "日本語",
            style: "Dial_JP",
            displayOrder: 1
        )
    ]

    let cues = SubtitleSpeakerDisplayCue.targetCues(
        records: records,
        speakersByCueLineID: [2: ["高松灯"]]
    )

    #expect(cues.count == 1)
    #expect(cues.first?.cleanText == "日本語")
    #expect(cues.first?.sourceStyle == "Dial_JP")
    #expect(cues.first?.speakers == ["高松灯"])
}

@Test
func assSpeakerDisplayRewriterPrefixesMatchingDialogueTextOnly() {
    let script = """
    [Script Info]
    ScriptType: v4.00+

    [Events]
    Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    Dialogue: 0,0:00:01.00,0:00:02.00,JP,,0,0,0,,{\\an2}こんにちは
    Dialogue: 0,0:00:03.00,0:00:04.00,JP,,0,0,0,,さようなら
    """
    let cues = [
        SubtitleSpeakerDisplayCue(
            cueGroupID: 7,
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            sourceStyle: "JP",
            sourceLayer: 0,
            cleanText: "こんにちは",
            speakers: ["疑似高松灯", "长崎素世"]
        )
    ]

    let rewritten = ASSSpeakerDisplayRewriter.rewrite(script: script, cues: cues)

    #expect(rewritten.contains("Dialogue: 0,0:00:01.00,0:00:02.00,JP,,0,0,0,,{\\an2}长崎素世,疑似高松灯: こんにちは"))
    #expect(rewritten.contains("Dialogue: 0,0:00:03.00,0:00:04.00,JP,,0,0,0,,さようなら"))
}

private func speakerDisplayLineRecord(
    id: Int64,
    cueGroupID: Int64,
    content: String,
    style: String = "JP",
    displayOrder: Int
) -> SubtitleCueLineRecord {
    SubtitleCueLineRecord(
        id: id,
        cueGroupID: cueGroupID,
        line: SubtitleCueLine(
            eventIndex: Int(id),
            sourceFormat: .ass,
            sourceStyle: style,
            sourceLayer: 0,
            startTimecode: "0:00:01.00",
            endTimecode: "0:00:02.00",
            startMilliseconds: 1_000,
            endMilliseconds: 2_000,
            content: content,
            displayX: nil,
            displayY: nil,
            displayOrder: displayOrder
        )
    )
}
