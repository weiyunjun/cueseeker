import Testing
@testable import CueSeekerCore

@Test
func libraryPlaybackStartPositionRestartsCompletedVideo() {
    let completedHistory = LibraryPlaybackHistory(
        videoPath: "/Media/Episode 1.mkv",
        positionMilliseconds: 85_000,
        duration: 100,
        startedAt: "2026-07-19T00:00:00Z",
        completedAt: "2026-07-19T00:01:25Z",
        updatedAt: "2026-07-19T00:01:25Z"
    )
    let watchingHistory = LibraryPlaybackHistory(
        videoPath: "/Media/Episode 2.mkv",
        positionMilliseconds: 42_500,
        duration: 100,
        startedAt: "2026-07-19T00:00:00Z",
        completedAt: nil,
        updatedAt: "2026-07-19T00:00:42Z"
    )

    #expect(
        LibraryPlaybackIntentResolver.startPositionMilliseconds(
            history: completedHistory
        ) == 0
    )
    #expect(
        LibraryPlaybackIntentResolver.startPositionMilliseconds(
            history: watchingHistory
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
