import Testing
@testable import CueSeekerCore

@Test
func libraryPlaybackStartPositionRestartsOnlyWhenProgressReachedEnd() {
    let manuallyFinishedPartialHistory = LibraryPlaybackHistory(
        videoPath: "/Media/Episode 1.mkv",
        positionMilliseconds: 85_000,
        duration: 100,
        startedAt: "2026-07-19T00:00:00Z",
        completedAt: "2026-07-19T00:01:25Z",
        updatedAt: "2026-07-19T00:01:25Z"
    )
    let completedProgressHistory = LibraryPlaybackHistory(
        videoPath: "/Media/Episode 2.mkv",
        positionMilliseconds: 100_000,
        duration: 100,
        startedAt: "2026-07-19T00:00:00Z",
        completedAt: nil,
        updatedAt: "2026-07-19T00:01:40Z"
    )
    let partialHistoryWithoutDuration = LibraryPlaybackHistory(
        videoPath: "/Media/Episode 3.mkv",
        positionMilliseconds: 42_500,
        duration: nil,
        startedAt: "2026-07-19T00:00:00Z",
        completedAt: "2026-07-19T00:00:42Z",
        updatedAt: "2026-07-19T00:00:42Z"
    )

    #expect(
        LibraryPlaybackIntentResolver.startPositionMilliseconds(
            history: manuallyFinishedPartialHistory
        ) == 85_000
    )
    #expect(
        LibraryPlaybackIntentResolver.startPositionMilliseconds(
            history: completedProgressHistory
        ) == 0
    )
    #expect(
        LibraryPlaybackIntentResolver.startPositionMilliseconds(
            history: partialHistoryWithoutDuration
        ) == 42_500
    )
    #expect(
        LibraryPlaybackIntentResolver.startPositionMilliseconds(history: nil)
            == 0
    )
}

@Test
func libraryPlaybackCompletionAdvancesOnlyWhenNextVideoExists() {
    #expect(
        LibraryPlaybackIntentResolver.completionAction(hasNextVideo: true)
            == .playNextVideo
    )
    #expect(
        LibraryPlaybackIntentResolver.completionAction(hasNextVideo: false)
            == .remainAtEnd
    )
}
