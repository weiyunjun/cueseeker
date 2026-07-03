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
    #expect(presentation.timeBadgeText == "0:42/1:40")
}
