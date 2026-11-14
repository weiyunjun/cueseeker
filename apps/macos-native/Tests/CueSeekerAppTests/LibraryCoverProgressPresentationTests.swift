import Foundation
import Testing
import CueSeekerCore
@testable import CueSeekerApp

@Test
func libraryCoverProgressPresentationKeepsFinishedProgressAtSavedPosition() throws {
    let watchState = LibraryWatchState(
        positionMilliseconds: 42_500,
        duration: 100.0,
        startedAt: "2026-07-04T00:00:00Z",
        completedAt: "2026-07-04T00:01:25Z"
    )
    #expect(watchState == .finished)

    let presentation = LibraryCoverProgressPresentation(
        positionMilliseconds: 42_500,
        duration: 100.0
    )

    let progressFraction = try #require(presentation.progressFraction)
    #expect(abs(progressFraction - 0.425) < 0.000_001)
    #expect(presentation.timeBadgeText == "00:42/01:40")
}

@Test
func libraryCoverProgressPresentationZeroPadsMinutesAndHoursConsistently() {
    let subHour = LibraryCoverProgressPresentation(
        positionMilliseconds: 185_900,
        duration: 3_599.0
    )
    #expect(subHour.timeBadgeText == "03:05/59:59")
    #expect(
        subHour.coverSummaryProgress(episodeNumber: 3).labelText == "EP03  03:05 / 59:59"
    )

    let hourPlus = LibraryCoverProgressPresentation(
        positionMilliseconds: 3_930_800,
        duration: 7_200.0
    )
    #expect(hourPlus.timeBadgeText == "01:05:30/02:00:00")
    #expect(
        hourPlus.coverSummaryProgress(episodeNumber: 12).labelText == "EP12  01:05:30 / 02:00:00"
    )

    let unknownDuration = LibraryCoverProgressPresentation(
        positionMilliseconds: 0,
        duration: nil
    )
    #expect(unknownDuration.timeBadgeText == "00:00")
    #expect(unknownDuration.coverSummaryProgress(episodeNumber: 1).labelText == "EP01  00:00")
}
