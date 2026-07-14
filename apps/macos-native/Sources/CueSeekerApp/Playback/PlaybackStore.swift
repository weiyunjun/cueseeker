import Foundation

struct PlaybackChromeSnapshot: Equatable {
    let displayTitle: String
    let canGoPrevious: Bool
    let canGoNext: Bool
    let hasPlaybackSelection: Bool

    static let empty = PlaybackChromeSnapshot(
        displayTitle: "No video selected",
        canGoPrevious: false,
        canGoNext: false,
        hasPlaybackSelection: false
    )
}

@MainActor
final class PlaybackTimelineScrubTimeStore: ObservableObject {
    @Published var scrubTime: Double?
}

@MainActor
final class PlaybackTimelineInteractionStore: ObservableObject {
    let scrubTimeStore = PlaybackTimelineScrubTimeStore()

    @Published var isScrubbing = false

    var scrubTime: Double? {
        get { scrubTimeStore.scrubTime }
        set { scrubTimeStore.scrubTime = newValue }
    }
}

@MainActor
final class PlaybackStore: ObservableObject {
    let timeline = PlaybackTimelineInteractionStore()

    @Published private(set) var subtitleFocusSession: PlaybackSubtitleFocusSessionStore?
    @Published private(set) var playlistSource: PlaybackPlaylistSource?
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var isPlaybackSurfaceExpanded = false
    @Published var isPlaybackSidePanelVisible = false
    @Published var playbackViewModel: PlaybackViewModel?
    @Published private(set) var chromeSnapshot = PlaybackChromeSnapshot.empty
    private var subtitleFocusSessionGeneration = 0

    init(userDefaults _: UserDefaults) {}

    var isTimelineScrubbing: Bool {
        get { timeline.isScrubbing }
        set { timeline.isScrubbing = newValue }
    }

    var timelineScrubTime: Double? {
        get { timeline.scrubTime }
        set { timeline.scrubTime = newValue }
    }

    func beginSubtitleFocusSession(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot,
        availableModules: [PlaybackOverlayModule] = PlaybackOverlayModule.standardModules
    ) -> PlaybackSubtitleFocusSessionStore? {
        guard subtitleFocusSession == nil else {
            return nil
        }

        subtitleFocusSessionGeneration += 1
        let session = PlaybackSubtitleFocusSessionStore(
            openSnapshot: openSnapshot,
            sessionGeneration: subtitleFocusSessionGeneration,
            availableModules: availableModules,
            playlistSource: playlistSource
        )
        subtitleFocusSession = session
        return session
    }

    func releaseSubtitleFocusSession(
        _ session: PlaybackSubtitleFocusSessionStore
    ) {
        guard subtitleFocusSession === session else {
            return
        }

        session.invalidateForSourceReplacement()
        subtitleFocusSession = nil
    }

    func setPlaylistSource(_ source: PlaybackPlaylistSource) {
        guard playlistSource !== source else {
            return
        }
        playlistSource?.invalidate()
        playlistSource = source
    }

    func clearPlaylistSource() {
        playlistSource?.invalidate()
        playlistSource = nil
    }

    func setChromeSnapshot(_ snapshot: PlaybackChromeSnapshot) {
        guard chromeSnapshot != snapshot else {
            return
        }
        chromeSnapshot = snapshot
    }

    func clearChromeSnapshot() {
        setChromeSnapshot(.empty)
    }
}
