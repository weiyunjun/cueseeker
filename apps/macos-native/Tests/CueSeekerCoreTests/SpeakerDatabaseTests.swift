import Foundation
import Testing
@testable import CueSeekerCore

@Test
func replacesCueLineSpeakersAsStringSets() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/SpeakerSetTest.srt")
    let videoFile = URL(fileURLWithPath: "/Media/SpeakerSetTest.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:01,000",
                endTimecode: "00:00:01,500",
                startMilliseconds: 1_000,
                endMilliseconds: 1_500,
                text: "first cue"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:02,000",
                endTimecode: "00:00:02,500",
                startMilliseconds: 2_000,
                endMilliseconds: 2_500,
                text: "second cue"
            ),
        ]
    )

    let cueLines = try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile)
    let firstCueLine = try #require(cueLines.first { $0.line.content == "first cue" })
    let secondCueLine = try #require(cueLines.first { $0.line.content == "second cue" })

    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(
                cueLineID: firstCueLine.id,
                speakers: ["高松灯", "疑似长崎素世", "  "]
            ),
            SubtitleCueLineSpeakerAssignment(
                cueLineID: secondCueLine.id,
                speakers: ["千早爱音"]
            )
        ]
    )

    #expect(try PlaybackSubtitleDatabase(path: database.path).speakersByCueLineID(forSubtitleFile: subtitleFile) == [
        firstCueLine.id: ["高松灯", "疑似长崎素世"],
        secondCueLine.id: ["千早爱音"]
    ])
    #expect(try PlaybackSubtitleDatabase(path: database.path).speakersByCueGroupID(forSubtitleFile: subtitleFile) == [
        firstCueLine.cueGroupID: ["高松灯", "疑似长崎素世"],
        secondCueLine.cueGroupID: ["千早爱音"]
    ])

    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(cueLineID: secondCueLine.id, speakers: ["椎名立希"])
        ]
    )

    #expect(try PlaybackSubtitleDatabase(path: database.path).speakersByCueLineID(forSubtitleFile: subtitleFile) == [
        secondCueLine.id: ["椎名立希"]
    ])

    try database.clearCueLineSpeakers(forSubtitleFile: subtitleFile)

    #expect(try PlaybackSubtitleDatabase(path: database.path).speakersByCueLineID(forSubtitleFile: subtitleFile).isEmpty)
}

@Test
func preservesCueLineSpeakersWhenReplacingCueGroups() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        try? FileManager.default.removeItem(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/SpeakerPreserve.srt")
    let videoFile = URL(fileURLWithPath: "/Media/SpeakerPreserve.mkv")
    let entries = [
        SubtitleEntry(
            sequenceNumber: 1,
            startTimecode: "00:00:01,000",
            endTimecode: "00:00:01,500",
            startMilliseconds: 1_000,
            endMilliseconds: 1_500,
            text: "first cue"
        ),
        SubtitleEntry(
            sequenceNumber: 2,
            startTimecode: "00:00:02,000",
            endTimecode: "00:00:02,500",
            startMilliseconds: 2_000,
            endMilliseconds: 2_500,
            text: "second cue"
        ),
    ]
    try database.replaceEntries(subtitleFile: subtitleFile, videoFile: videoFile, entries: entries)

    let initialCueLines = try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile)
    let initialSecondCueLine = try #require(initialCueLines.first { $0.line.content == "second cue" })
    try database.replaceCueLineSpeakers(
        forSubtitleFile: subtitleFile,
        assignments: [
            SubtitleCueLineSpeakerAssignment(cueLineID: initialSecondCueLine.id, speakers: ["高松灯"])
        ]
    )

    try database.replaceEntries(subtitleFile: subtitleFile, videoFile: videoFile, entries: entries)

    let rebuiltCueLines = try PlaybackSubtitleDatabase(path: database.path).cueLineRecords(forSubtitleFile: subtitleFile)
    let rebuiltSecondCueLine = try #require(rebuiltCueLines.first { $0.line.content == "second cue" })
    #expect(rebuiltSecondCueLine.id == initialSecondCueLine.id)
    #expect(try PlaybackSubtitleDatabase(path: database.path).speakersByCueLineID(forSubtitleFile: subtitleFile) == [
        rebuiltSecondCueLine.id: ["高松灯"]
    ])
}
