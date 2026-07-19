public enum LibraryPlaybackCompletionAction: Equatable, Sendable {
    case remainAtEnd
    case playNextVideo
}

public enum LibraryPlaybackIntentResolver {
    public static func startPositionMilliseconds(
        history: LibraryPlaybackHistory?
    ) -> Int {
        guard let history else {
            return 0
        }

        let positionMilliseconds = max(0, history.positionMilliseconds)
        guard let duration = history.duration,
              duration.isFinite,
              duration > 0
        else {
            return positionMilliseconds
        }

        let durationMilliseconds = (duration * 1_000).rounded(.down)
        guard durationMilliseconds.isFinite,
              durationMilliseconds > 0
        else {
            return positionMilliseconds
        }

        return Double(positionMilliseconds) >= durationMilliseconds
            ? 0
            : positionMilliseconds
    }

    public static func completionAction(
        hasNextVideo: Bool
    ) -> LibraryPlaybackCompletionAction {
        hasNextVideo ? .playNextVideo : .remainAtEnd
    }
}
