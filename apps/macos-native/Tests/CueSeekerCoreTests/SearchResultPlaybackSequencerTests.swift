import XCTest
@testable import CueSeekerCore

final class SearchResultPlaybackSequencerTests: XCTestCase {
    func testContinuousWhenSameSubtitleFilenameOverlapsWithinOneSecond() {
        let current = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 10_000,
            endMilliseconds: 15_000
        )
        let next = makeResult(
            subtitlePath: "/Other/Copy/Episode 01.ass",
            startMilliseconds: 14_250,
            endMilliseconds: 16_000
        )

        XCTAssertTrue(SearchResultPlaybackSequencer.shouldPlayContinuously(current: current, next: next))
    }

    func testNotContinuousWhenSameSubtitleFilenameHasPositiveGap() {
        let current = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 10_000,
            endMilliseconds: 15_000
        )
        let next = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 15_001,
            endMilliseconds: 16_000
        )

        XCTAssertFalse(SearchResultPlaybackSequencer.shouldPlayContinuously(current: current, next: next))
    }

    func testNotContinuousWhenSameSubtitleFilenameOverlapsByMoreThanOneSecond() {
        let current = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 10_000,
            endMilliseconds: 20_000
        )
        let next = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 18_500,
            endMilliseconds: 21_000
        )

        XCTAssertFalse(SearchResultPlaybackSequencer.shouldPlayContinuously(current: current, next: next))
    }

    func testNotContinuousWhenSubtitleFilenamesDifferEvenIfTimingsOverlap() {
        let current = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 10_000,
            endMilliseconds: 15_000
        )
        let next = makeResult(
            subtitlePath: "/Library/Show/Episode 02.ass",
            startMilliseconds: 14_250,
            endMilliseconds: 16_000
        )

        XCTAssertFalse(SearchResultPlaybackSequencer.shouldPlayContinuously(current: current, next: next))
    }

    func testShioriUsesSameSubtitleFilenameContinuityRule() {
        let current = makeShiori(
            id: 1,
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 10_000,
            endMilliseconds: 15_000
        )
        let next = makeShiori(
            id: 2,
            subtitlePath: "/Other/Copy/Episode 01.ass",
            startMilliseconds: 14_250,
            endMilliseconds: 16_000
        )

        XCTAssertTrue(SearchResultPlaybackSequencer.shouldPlayContinuously(current: current, next: next))
    }

    func testPlaybackWindowIncludesConfiguredSubtitleCountAndTracksFirstExcludedCue() {
        let window = SearchResultPlaybackSequencer.playbackWindow(
            startMilliseconds: 10_000,
            endMilliseconds: 11_000,
            availableCueTimings: [
                SubtitleCueTiming(startMilliseconds: 10_000, endMilliseconds: 11_000),
                SubtitleCueTiming(startMilliseconds: 12_000, endMilliseconds: 13_000),
                SubtitleCueTiming(startMilliseconds: 14_000, endMilliseconds: 16_000),
                SubtitleCueTiming(startMilliseconds: 18_000, endMilliseconds: 19_000)
            ],
            subtitleCount: 3
        )

        XCTAssertEqual(window.cueTimings, [
            SubtitleCueTiming(startMilliseconds: 10_000, endMilliseconds: 11_000),
            SubtitleCueTiming(startMilliseconds: 12_000, endMilliseconds: 13_000),
            SubtitleCueTiming(startMilliseconds: 14_000, endMilliseconds: 16_000)
        ])
        XCTAssertEqual(
            window.firstExcludedCueTiming,
            SubtitleCueTiming(startMilliseconds: 18_000, endMilliseconds: 19_000)
        )
        XCTAssertEqual(window.endMilliseconds, 16_000)
    }

    func testContinuousWhenNextResultIsInsideConfiguredPlaybackWindow() {
        let current = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 10_000,
            endMilliseconds: 11_000
        )
        let next = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 14_000,
            endMilliseconds: 15_000
        )
        let window = SearchResultPlaybackSequencer.playbackWindow(
            startMilliseconds: current.startMilliseconds,
            endMilliseconds: current.endMilliseconds,
            availableCueTimings: [
                SubtitleCueTiming(startMilliseconds: 10_000, endMilliseconds: 11_000),
                SubtitleCueTiming(startMilliseconds: 12_000, endMilliseconds: 13_000),
                SubtitleCueTiming(startMilliseconds: 14_000, endMilliseconds: 15_000)
            ],
            subtitleCount: 3
        )

        XCTAssertTrue(
            SearchResultPlaybackSequencer.shouldPlayContinuously(
                current: current,
                currentWindow: window,
                next: next
            )
        )
    }

    func testContinuousWhenConfiguredWindowReachesCueImmediatelyBeforeNextResult() {
        let current = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 10_000,
            endMilliseconds: 11_000
        )
        let next = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 15_000,
            endMilliseconds: 16_000
        )
        let window = SearchResultPlaybackSequencer.playbackWindow(
            startMilliseconds: current.startMilliseconds,
            endMilliseconds: current.endMilliseconds,
            availableCueTimings: [
                SubtitleCueTiming(startMilliseconds: 10_000, endMilliseconds: 11_000),
                SubtitleCueTiming(startMilliseconds: 12_000, endMilliseconds: 13_000),
                SubtitleCueTiming(startMilliseconds: 14_000, endMilliseconds: 15_750),
                SubtitleCueTiming(startMilliseconds: 15_000, endMilliseconds: 16_000)
            ],
            subtitleCount: 3
        )

        XCTAssertTrue(
            SearchResultPlaybackSequencer.shouldPlayContinuously(
                current: current,
                currentWindow: window,
                next: next
            )
        )
    }

    func testNotContinuousWhenConfiguredWindowDoesNotReachCueBeforeNextResult() {
        let current = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 10_000,
            endMilliseconds: 11_000
        )
        let next = makeResult(
            subtitlePath: "/Library/Show/Episode 01.ass",
            startMilliseconds: 15_000,
            endMilliseconds: 16_000
        )
        let window = SearchResultPlaybackSequencer.playbackWindow(
            startMilliseconds: current.startMilliseconds,
            endMilliseconds: current.endMilliseconds,
            availableCueTimings: [
                SubtitleCueTiming(startMilliseconds: 10_000, endMilliseconds: 11_000),
                SubtitleCueTiming(startMilliseconds: 12_000, endMilliseconds: 15_750),
                SubtitleCueTiming(startMilliseconds: 14_000, endMilliseconds: 15_750),
                SubtitleCueTiming(startMilliseconds: 15_000, endMilliseconds: 16_000)
            ],
            subtitleCount: 2
        )

        XCTAssertFalse(
            SearchResultPlaybackSequencer.shouldPlayContinuously(
                current: current,
                currentWindow: window,
                next: next
            )
        )
    }

    private func makeResult(
        subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) -> SubtitleSearchResult {
        SubtitleSearchResult(
            entryID: Int64(startMilliseconds),
            subtitlePath: subtitlePath,
            subtitleFormat: .ass,
            videoPath: "/Library/Show/Episode 01.mkv",
            videoName: "Episode 01.mkv",
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            content: "line",
            cueLines: ["line"]
        )
    }

    private func makeShiori(
        id: Int64,
        subtitlePath: String,
        startMilliseconds: Int,
        endMilliseconds: Int
    ) -> Shiori {
        Shiori(
            id: id,
            subtitlePath: subtitlePath,
            subtitleFormat: .ass,
            videoPath: "/Library/Show/Episode 01.mkv",
            videoName: "Episode 01.mkv",
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            content: "line",
            isValid: true,
            createdAt: "2026-05-11T00:00:00Z"
        )
    }
}
