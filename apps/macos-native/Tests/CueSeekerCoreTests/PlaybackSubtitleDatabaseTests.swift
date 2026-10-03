import Foundation
import Testing
@testable import CueSeekerCore

@Test
func subtitleEntryIndexAndWindowLoadCurrentSubtitleRows() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/WindowedSubtitles.srt")
    let videoFile = URL(fileURLWithPath: "/Media/WindowedSubtitles.mkv")
    let entries = (0..<6).map { index in
        SubtitleEntry(
            sequenceNumber: index + 1,
            startTimecode: String(format: "00:00:%02d,000", index),
            endTimecode: String(format: "00:00:%02d,500", index),
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 500,
            text: "Current subtitle row \(index)"
        )
    }

    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: entries
    )

    let index = try PlaybackSubtitleDatabase(path: database.path).subtitleEntryIndex(forSubtitleFile: subtitleFile)
    #expect(index.count == 6)
    #expect(index.map(\.startMilliseconds) == [0, 1_000, 2_000, 3_000, 4_000, 5_000])

    let lookup = SubtitleActiveEntryLookup(entryIndex: index)
    #expect(lookup.activeEntryID(atMilliseconds: 2_250) == index[2].id)

    let window = try PlaybackSubtitleDatabase(path: database.path).entries(forSubtitleFile: subtitleFile, limit: 2, offset: 3)
    #expect(window.map(\.content) == [
        "Current subtitle row 3",
        "Current subtitle row 4",
    ])
    #expect(try PlaybackSubtitleDatabase(path: database.path).entries(forSubtitleFile: subtitleFile, limit: 0, offset: 3).isEmpty)
}

@Test
func storesAndLoadsASSRenderSegmentsByTimestamp() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Effects.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Effects.mkv")
    let segments = [
        ASSRenderSegmentPayload(
            segmentIndex: 0,
            startMilliseconds: 0,
            endMilliseconds: 30_000,
            scriptText: "[Script Info]\n[Events]\n",
            eventCount: 0,
            byteCount: 23
        ),
        ASSRenderSegmentPayload(
            segmentIndex: 1,
            startMilliseconds: 30_000,
            endMilliseconds: 60_000,
            scriptText: "[Script Info]\n[Events]\nDialogue: 0,0:00:30.00,0:00:31.00,Default,,0,0,0,,fx\n",
            eventCount: 1,
            byteCount: 89
        )
    ]

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [],
        assRenderSegments: segments
    )

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    #expect(try playback.hasASSRenderSegments(forSubtitleFile: subtitleFile))
    let loadedSegment = try playback.assRenderSegment(forSubtitleFile: subtitleFile, atMilliseconds: 30_250)
    let segment = try #require(loadedSegment)
    #expect(segment.startMilliseconds == 30_000)
    #expect(segment.endMilliseconds == 60_000)
    #expect(segment.eventCount == 1)
    #expect(segment.scriptText.contains("Dialogue:"))
    #expect(try playback.assRenderSegment(forSubtitleFile: subtitleFile, atMilliseconds: 60_000) == nil)
}

@Test
func storesAndLoadsASSFontReferences() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Effects.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Effects.mkv")
    let references = [
        ASSFontReferenceIntent(
            fontName: "华文中宋",
            source: .style,
            occurrenceCount: 2,
            firstOccurrenceOrder: 0
        ),
        ASSFontReferenceIntent(
            fontName: "汉仪小隶书简",
            source: .inlineOverride,
            occurrenceCount: 1,
            firstOccurrenceOrder: 2
        )
    ]

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [],
        assFontReferences: references
    )

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    #expect(try playback.hasCurrentASSFontReferenceManifest(forSubtitleFile: subtitleFile))
    #expect(try playback.assFontReferences(forSubtitleFile: subtitleFile) == [
        ASSFontReference(
            subtitlePath: subtitleFile.path,
            fontName: "华文中宋",
            source: .style,
            occurrenceCount: 2,
            firstOccurrenceOrder: 0
        ),
        ASSFontReference(
            subtitlePath: subtitleFile.path,
            fontName: "汉仪小隶书简",
            source: .inlineOverride,
            occurrenceCount: 1,
            firstOccurrenceOrder: 2
        )
    ])
}

@Test
func storesASSPrimaryStylePlaybackFinishMetadata() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Primary.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Primary.mkv")

    let sharedTimestampGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "1000",
        endTimecode: "2000",
        startMilliseconds: 1_000,
        endMilliseconds: 2_000,
        searchContent: "main jp\nmain cn",
        cueLines: [
            testCueLine(
                eventIndex: 0,
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "main jp",
                displayOrder: 0,
                sourceStyle: "MainJP"
            ),
            testCueLine(
                eventIndex: 1,
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "main cn",
                displayOrder: 1,
                sourceStyle: "MainCN"
            ),
            testCueLine(
                eventIndex: 2,
                startMilliseconds: 1_000,
                endMilliseconds: 2_000,
                content: "duplicate main cn",
                displayOrder: 2,
                sourceStyle: "MainCN"
            )
        ]
    )

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            sharedTimestampGroup,
            testCueGroup(
                startMilliseconds: 2_000,
                endMilliseconds: 3_000,
                content: "adjacent main jp",
                eventIndex: 3,
                sourceStyle: "MainJP"
            ),
            testCueGroup(
                startMilliseconds: 2_000,
                endMilliseconds: 3_000,
                content: "adjacent main cn",
                eventIndex: 4,
                sourceStyle: "MainCN"
            ),
            testCueGroup(
                startMilliseconds: 4_000,
                endMilliseconds: 5_000,
                content: "overlap sign",
                eventIndex: 5,
                sourceStyle: "Sign"
            ),
            testCueGroup(
                startMilliseconds: 4_500,
                endMilliseconds: 5_500,
                content: "overlap alt",
                eventIndex: 6,
                sourceStyle: "Alt"
            ),
            testCueGroup(
                startMilliseconds: 90_000,
                endMilliseconds: 91_000,
                content: "last main jp",
                eventIndex: 7,
                sourceStyle: "MainJP"
            ),
            testCueGroup(
                startMilliseconds: 92_000,
                endMilliseconds: 93_000,
                content: "last main cn",
                eventIndex: 8,
                sourceStyle: "MainCN"
            ),
            testCueGroup(
                startMilliseconds: 98_000,
                endMilliseconds: 99_000,
                content: "last subtitle",
                eventIndex: 9,
                sourceStyle: "Credits"
            )
        ]
    )

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    let metadata = try #require(try playback.playbackFinishMetadata(forSubtitleFile: subtitleFile))
    #expect(metadata.primaryStyles == ["MainCN", "MainJP"])
    #expect(metadata.primaryStyleLastEndMilliseconds == 93_000)
    #expect(metadata.lastSubtitleEndMilliseconds == 99_000)
    #expect(metadata.finishPointMilliseconds(videoDuration: 100) == 93_000)
}

@Test
func playbackFinishMetadataFallsBackToLastSubtitleOrVideoEnd() throws {
    let lastSubtitleMetadata = SubtitlePlaybackFinishMetadata(
        primaryStyles: ["Main"],
        primaryStyleLastEndMilliseconds: 70_000,
        lastSubtitleEndMilliseconds: 90_000
    )
    #expect(lastSubtitleMetadata.finishPointMilliseconds(videoDuration: 100) == 90_000)

    let videoEndMetadata = SubtitlePlaybackFinishMetadata(
        primaryStyles: [],
        primaryStyleLastEndMilliseconds: nil,
        lastSubtitleEndMilliseconds: 70_000
    )
    #expect(videoEndMetadata.finishPointMilliseconds(videoDuration: 100) == 100_000)
    #expect(SubtitlePlaybackFinishMetadata.finishPointMilliseconds(
        metadata: nil,
        videoDuration: 100
    ) == 100_000)
}

@Test
func returnsCueTimingsForWindowedASSPreparation() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Windowed.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Windowed.mkv")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(startMilliseconds: 1_000, endMilliseconds: 1_500, content: "before", eventIndex: 0),
            testCueGroup(startMilliseconds: 2_000, endMilliseconds: 2_500, content: "selected", eventIndex: 1),
            testCueGroup(startMilliseconds: 4_000, endMilliseconds: 4_500, content: "next", eventIndex: 2),
            testCueGroup(startMilliseconds: 7_000, endMilliseconds: 7_500, content: "outside limit", eventIndex: 3)
        ]
    )

    let playback = try PlaybackSubtitleDatabase(path: databaseURL)
    let timings = try playback.cueTimings(
        forSubtitleFile: subtitleFile,
        startingAtMilliseconds: 2_000,
        limit: 2
    )

    #expect(timings == [
        SubtitleCueTiming(startMilliseconds: 2_000, endMilliseconds: 2_500),
        SubtitleCueTiming(startMilliseconds: 4_000, endMilliseconds: 4_500)
    ])
}

@Test
func cueTextSelectionUsesShortestActiveCueAndLatestEndTieBreak() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Selection.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Selection.mkv")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(startMilliseconds: 1_000, endMilliseconds: 8_000, content: "long", eventIndex: 0),
            testCueGroup(startMilliseconds: 3_000, endMilliseconds: 5_000, content: "short earlier", eventIndex: 1),
            testCueGroup(startMilliseconds: 3_500, endMilliseconds: 5_500, content: "short later", eventIndex: 2)
        ]
    )

    let selectedCue = try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(forSubtitleFile: subtitleFile, atMilliseconds: 4_000)
    let selection = try #require(selectedCue)
    #expect(selection.startMilliseconds == 3_500)
    #expect(selection.endMilliseconds == 5_500)
    #expect(selection.text == "short later")
}

@Test
func cueTextSelectionFallsBackToPreviousCueRange() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Previous.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Previous.mkv")

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [
            testCueGroup(startMilliseconds: 1_000, endMilliseconds: 5_000, content: "wide previous", eventIndex: 0),
            testCueGroup(startMilliseconds: 4_500, endMilliseconds: 5_000, content: "short previous", eventIndex: 1),
            testCueGroup(startMilliseconds: 7_000, endMilliseconds: 8_000, content: "future", eventIndex: 2)
        ]
    )

    let selectedCue = try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(forSubtitleFile: subtitleFile, atMilliseconds: 6_000)
    let selection = try #require(selectedCue)
    #expect(selection.startMilliseconds == 4_500)
    #expect(selection.endMilliseconds == 5_000)
    #expect(selection.text == "short previous")

    #expect(try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(forSubtitleFile: subtitleFile, atMilliseconds: 500) == nil)
}

@Test
func cueTextSelectionReturnsPhysicallyBottommostCueAsSingleCue() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Lines.ass")
    let videoFile = URL(fileURLWithPath: "/Media/Lines.mkv")
    let cueGroup = SubtitleCueGroup(
        sequenceNumber: nil,
        startTimecode: "0:00:01.00",
        endTimecode: "0:00:03.00",
        startMilliseconds: 1_000,
        endMilliseconds: 3_000,
        searchContent: "bottom\ntop",
        cueLines: [
            testCueLine(
                eventIndex: 0,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "bottom",
                displayOrder: 1
            ),
            testCueLine(
                eventIndex: 1,
                startMilliseconds: 1_000,
                endMilliseconds: 3_000,
                content: "top",
                displayOrder: 0
            )
        ]
    )

    try database.replaceCueGroups(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        format: .ass,
        cueGroups: [cueGroup]
    )

    let selectedCue = try PlaybackSubtitleDatabase(path: database.path).cueTextSelection(forSubtitleFile: subtitleFile, atMilliseconds: 2_000)
    let selection = try #require(selectedCue)
    #expect(selection.lines == ["bottom"])
    #expect(selection.text == "bottom")
    #expect(selection.cueEventIndex == 0)
    #expect(selection.cueDisplayOrder == 1)
}

@Test
func activeSubtitleEntryLookupKeepsLongRunningCueActivePastShortLaterCues() throws {
    let databaseURL = temporaryDatabaseURL()
    defer {
        removeTemporaryDatabase(at: databaseURL)
    }

    let database = try IndexingDatabase(path: databaseURL)
    try DatabaseBootstrap.prepare(at: databaseURL)

    let subtitleFile = URL(fileURLWithPath: "/Media/Signs.srt")
    let videoFile = URL(fileURLWithPath: "/Media/Signs.mkv")
    try database.replaceEntries(
        subtitleFile: subtitleFile,
        videoFile: videoFile,
        entries: [
            SubtitleEntry(
                sequenceNumber: 1,
                startTimecode: "00:00:00,000",
                endTimecode: "00:02:00,000",
                startMilliseconds: 0,
                endMilliseconds: 120_000,
                text: "long running sign"
            ),
            SubtitleEntry(
                sequenceNumber: 2,
                startTimecode: "00:00:30,000",
                endTimecode: "00:00:35,000",
                startMilliseconds: 30_000,
                endMilliseconds: 35_000,
                text: "short dialogue"
            ),
            SubtitleEntry(
                sequenceNumber: 3,
                startTimecode: "00:01:00,000",
                endTimecode: "00:01:05,000",
                startMilliseconds: 60_000,
                endMilliseconds: 65_000,
                text: "later short dialogue"
            )
        ]
    )

    let entries = try PlaybackSubtitleDatabase(path: database.path).entries(forSubtitleFile: subtitleFile)
    let lookup = SubtitleActiveEntryLookup(entries: entries)

    #expect(lookup.activeEntryID(atMilliseconds: 90_000) == entries[0].id)
    #expect(lookup.activeEntryID(atMilliseconds: 150_000) == entries[2].id)
    #expect(lookup.activeEntryID(atMilliseconds: -1) == nil)
}
