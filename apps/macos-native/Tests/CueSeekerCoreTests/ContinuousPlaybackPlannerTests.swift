import Foundation
import Testing
@testable import CueSeekerCore

@Test
func continuousPlaybackPrecedingSentenceCountRaisesSentenceCount() {
    let settings = ContinuousPlaybackSettings()
        .updatingPrecedingSentenceCount(3)

    #expect(settings.precedingSentenceCount == 3)
    #expect(settings.sentenceCount == 4)
}

@Test
func continuousPlaybackSentenceCountLowersPrecedingSentenceCount() {
    let settings = ContinuousPlaybackSettings(
        sentenceCount: 8,
        precedingSentenceCount: 5
    )
    .updatingSentenceCount(2)

    #expect(settings.sentenceCount == 2)
    #expect(settings.precedingSentenceCount == 1)
}

@Test
func continuousPlaybackSettingsClampSupportedRanges() {
    let settings = ContinuousPlaybackSettings(
        sentenceCount: 50_000,
        precedingSentenceCount: 50
    )

    #expect(settings.sentenceCount == 9_999)
    #expect(settings.precedingSentenceCount == 10)

    let lowerBoundSettings = ContinuousPlaybackSettings(
        sentenceCount: -10,
        precedingSentenceCount: -2
    )

    #expect(lowerBoundSettings.sentenceCount == 1)
    #expect(lowerBoundSettings.precedingSentenceCount == 0)
}

@Test
func continuousPlaybackSegmentUsesPrecedingContextWhenAvailable() {
    let entries = subtitleEntries(count: 6)
    let settings = ContinuousPlaybackSettings(
        sentenceCount: 4,
        precedingSentenceCount: 2
    )

    let segment = ContinuousPlaybackPlanner.segment(
        forSelectedEntryID: entries[3].id,
        entries: entries,
        settings: settings
    )

    #expect(segment?.selectedIndex == 3)
    #expect(segment?.startIndex == 1)
    #expect(segment?.endIndex == 4)
    #expect(segment?.startMilliseconds == 1_000)
    #expect(segment?.endMilliseconds == 4_800)
}

@Test
func continuousPlaybackSegmentStartsAtFirstCueWhenPrecedingContextIsUnavailable() {
    let entries = subtitleEntries(count: 4)
    let settings = ContinuousPlaybackSettings(
        sentenceCount: 4,
        precedingSentenceCount: 3
    )

    let segment = ContinuousPlaybackPlanner.segment(
        forSelectedEntryID: entries[1].id,
        entries: entries,
        settings: settings
    )

    #expect(segment?.startIndex == 0)
    #expect(segment?.endIndex == 3)
    #expect(segment?.startMilliseconds == 0)
    #expect(segment?.endMilliseconds == 3_800)
}

@Test
func continuousPlaybackSegmentCapsAtFinalCue() {
    let entries = subtitleEntries(count: 3)
    let settings = ContinuousPlaybackSettings(sentenceCount: 10)

    let segment = ContinuousPlaybackPlanner.segment(
        forSelectedEntryID: entries[1].id,
        entries: entries,
        settings: settings
    )

    #expect(segment?.startIndex == 1)
    #expect(segment?.endIndex == 2)
    #expect(segment?.startMilliseconds == 1_000)
    #expect(segment?.endMilliseconds == 2_800)
}

@Test
func continuousPlaybackActivationBoundaryWaitsForCurrentCueWhenAlreadyPastSegmentEnd() {
    let entries = subtitleEntries(count: 5)
    let settings = ContinuousPlaybackSettings(sentenceCount: 1)
    let segment = ContinuousPlaybackPlanner.segment(
        forSelectedEntryID: entries[1].id,
        entries: entries,
        settings: settings
    )!

    #expect(
        ContinuousPlaybackPlanner.activationBoundaryMilliseconds(
            forCurrentMilliseconds: 2_100,
            segment: segment,
            entries: entries
        ) == 2_800
    )
}

@Test
func continuousPlaybackPreparesNextItemWhenLastCueStarts() {
    let entries = subtitleEntries(count: 5)
    let settings = ContinuousPlaybackSettings(sentenceCount: 2)
    let segment = ContinuousPlaybackPlanner.segment(
        forSelectedEntryID: entries[1].id,
        entries: entries,
        settings: settings
    )!

    #expect(!ContinuousPlaybackPlanner.shouldPrepareNextItem(
        currentMilliseconds: segment.lastCueStartMilliseconds - 1,
        segment: segment
    ))
    #expect(ContinuousPlaybackPlanner.shouldPrepareNextItem(
        currentMilliseconds: segment.lastCueStartMilliseconds,
        segment: segment
    ))
}

private func subtitleEntries(count: Int) -> [SubtitleDatabaseEntry] {
    var entries: [SubtitleDatabaseEntry] = []
    for index in 0..<count {
        let entry = SubtitleDatabaseEntry(
            id: Int64(index + 1),
            subtitlePath: "/tmp/movie.srt",
            videoPath: "/tmp/movie.mp4",
            videoName: "movie.mp4",
            sequenceNumber: index + 1,
            startTimecode: "00:00:0\(index),000",
            endTimecode: "00:00:0\(index),800",
            startMilliseconds: index * 1_000,
            endMilliseconds: index * 1_000 + 800,
            content: "Cue \(index + 1)"
        )
        entries.append(entry)
    }
    return entries
}
