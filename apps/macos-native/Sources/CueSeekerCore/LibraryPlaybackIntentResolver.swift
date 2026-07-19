public enum LibraryPlaybackCompletionAction: Equatable, Sendable {
    case remainAtEnd
    case playNextVideo
}

public enum LibraryPlaybackIntentResolver {
    public static func startPositionMilliseconds(
        history: LibraryPlaybackHistory?
    ) -> Int {
        guard let history, history.completedAt == nil else {
            return 0
        }
        return max(0, history.positionMilliseconds)
    }

    public static func completionAction(
        hasNextVideo: Bool
    ) -> LibraryPlaybackCompletionAction {
        hasNextVideo ? .playNextVideo : .remainAtEnd
    }
}
