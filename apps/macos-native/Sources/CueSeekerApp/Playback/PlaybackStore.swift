import Combine
import CoreGraphics
import CueSeekerCore
import Foundation

enum PlaybackCommandPanelPage: Equatable {
    case root
    case searchResults
    case recentVideos
    case recentShioris
}

struct PlaybackCommandPanelPresentation: Equatable {
    static let previewLimit = 50

    var page: PlaybackCommandPanelPage
    var query: String
    var selectedOrdinal: Int?
    let resumesPlaybackOnDismiss: Bool
}

struct PlaybackChromeSnapshot: Equatable {
    let displayTitle: String
    let canGoPrevious: Bool
    let canGoNext: Bool
    let hasPlaybackSelection: Bool

    static let empty = PlaybackChromeSnapshot(
        displayTitle: L("playback.no_video_selected"),
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
final class PlaybackPointerVisibilityStore: ObservableObject {
    @Published private(set) var isVisible = false

    func setVisible(_ isVisible: Bool) {
        guard self.isVisible != isVisible else {
            return
        }
        self.isVisible = isVisible
    }
}

@MainActor
final class PlaybackStore: ObservableObject {
    let timeline = PlaybackTimelineInteractionStore()
    let pointerVisibility = PlaybackPointerVisibilityStore()
    let pointerHideRequests = PassthroughSubject<Void, Never>()

    @Published private(set) var subtitleFocusSession: PlaybackSubtitleFocusSessionStore?
    @Published private(set) var commandPanelPresentation:
        PlaybackCommandPanelPresentation?
    @Published private(set) var commandPanelSearchWindow:
        PlaybackCueResultSessionWindowStore?
    private var commandPanelSearchSource: PlaybackCueResultSource?
    private(set) var commandPanelRecentVideoColumnCount = 1
    private(set) var commandPanelRecentVideoItemFramesByID: [String: CGRect] = [:]
    @Published private(set) var playlistSource: PlaybackPlaylistSource?
    private(set) var playbackSearchPlaylistOrdinal: Int?
    private(set) var playlistPosition: PlaybackPlaylistPosition?
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var isPlaybackSurfaceExpanded = false
    @Published var isPlaybackSidePanelVisible = false
    @Published var playbackViewModel: PlaybackViewModel?
    @Published private(set) var chromeSnapshot = PlaybackChromeSnapshot.empty
    @Published private(set) var canRepeatCurrentCue = false

    /// The player speed menu lives here rather than in the chrome view because
    /// `handlePlaybackKeyDown` is the App's single owner of playback-page keys.
    /// A local event monitor installed when the menu opens cannot reach the
    /// arrow keys first: monitors are invoked in the order they were added, and
    /// the App-wide playback monitor is added at launch.
    @Published private(set) var isSpeedMenuOpen = false
    let speedMenuHighlight = MenuHighlightModel()

    func openSpeedMenu(defaultPosition: Int?) {
        speedMenuHighlight.open(
            selectablePositions: Array(PlaybackViewModel.speedPresets.indices),
            defaultPosition: defaultPosition
        )
        isSpeedMenuOpen = true
    }

    /// Set by the reel that owns an open selected-text menu, and offered every
    /// key before seeking, volume and cue navigation see it. A menu that opens
    /// on the playback page cannot claim keys with its own event monitor:
    /// monitors are invoked in the order they were added, and the App-wide
    /// playback monitor is added at launch.
    var selectedTextMenuKeyHandler: ((UInt16) -> Bool)?

    func closeSpeedMenu() {
        guard isSpeedMenuOpen else {
            return
        }
        speedMenuHighlight.close()
        isSpeedMenuOpen = false
    }
    private(set) var pointerHideRequestGeneration: UInt64 = 0
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
        availableModules: [PlaybackOverlayModule]? = nil,
        searchStore: SearchStore? = nil,
        libraryStore: PlaybackLibrarySessionStore? = nil,
        shioriStore: ShioriStore? = nil
    ) -> PlaybackSubtitleFocusSessionStore? {
        guard subtitleFocusSession == nil else {
            return nil
        }

        subtitleFocusSessionGeneration += 1
        let session = PlaybackSubtitleFocusSessionStore(
            openSnapshot: openSnapshot,
            sessionGeneration: subtitleFocusSessionGeneration,
            availableModules: availableModules
                ?? PlaybackOverlayModule.modules(
                    hasPlaylist: playlistSource?.hasItems == true
                        || libraryStore != nil
                ),
            playlistSource: playlistSource,
            playlistPosition: playlistPosition,
            searchStore: searchStore,
            libraryStore: libraryStore,
            shioriStore: shioriStore
        )
        if libraryStore == nil,
           playlistSource?.hasItems == true {
            _ = session.presentModule(.playlist)
        }
        subtitleFocusSession = session
        synchronizeOverlayInputOwnership()
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

    func presentCommandPanel(_ presentation: PlaybackCommandPanelPresentation) {
        if presentation.page != .recentVideos {
            resetCommandPanelRecentVideoGridLayout()
        }
        if presentation.page != .searchResults {
            releaseCommandPanelSearchPreview()
        }
        // The Command Panel is the topmost surface, so menus opened underneath
        // it stay on screen and stop taking input rather than closing.
        commandPanelPresentation = presentation
        synchronizeOverlayInputOwnership()
    }

    /// Only the topmost interactive surface owns the wheel and the scrollbar.
    private func synchronizeOverlayInputOwnership() {
        subtitleFocusSession?.setCoveredByHigherOverlay(
            commandPanelPresentation != nil
        )
    }

    func synchronizeCommandPanelSearchPreview(
        results: [SubtitleSearchResult],
        selectedOrdinal: Int?
    ) {
        guard commandPanelPresentation?.page == .searchResults else {
            releaseCommandPanelSearchPreview()
            return
        }
        let items = Array(
            results.prefix(PlaybackCommandPanelPresentation.previewLimit)
        ).enumerated().map { ordinal, result in
            PlaybackCueResultItem(searchResult: result, ordinal: ordinal)
        }
        let itemProvider: PlaybackPlaylistSharedItemProvider = { ordinal in
            guard items.indices.contains(ordinal) else {
                return nil
            }
            return items[ordinal]
        }

        if let commandPanelSearchSource {
            _ = commandPanelSearchSource.replaceResidentItems(
                totalCount: items.count,
                itemProvider: itemProvider
            )
        } else {
            let source = PlaybackCueResultSource(
                kind: .search,
                totalCount: items.count,
                itemProvider: itemProvider
            )
            commandPanelSearchSource = source
            commandPanelSearchWindow = source.makeSessionWindowStore(
                includingEmpty: true
            )
        }

        guard let selectedOrdinal,
              items.indices.contains(selectedOrdinal)
        else {
            return
        }
        _ = commandPanelSearchWindow?.restoreSelection(
            itemIdentity: items[selectedOrdinal].identity,
            at: selectedOrdinal
        )
    }

    @discardableResult
    func restoreCommandPanelSearchSelection(at ordinal: Int) -> Bool {
        guard let itemIdentity = commandPanelSearchWindow?
            .knownItemIdentity(at: ordinal)
        else {
            return false
        }
        return commandPanelSearchWindow?.restoreSelection(
            itemIdentity: itemIdentity,
            at: ordinal
        ) == true
    }

    @discardableResult
    func commitCommandPanelSearchSelection(
        _ commit: PlaybackVirtualReelSelectionCommit
    ) -> Bool {
        commandPanelSearchWindow?.commitSelection(commit) == true
    }

    func updateCommandPanelRecentVideoGridLayout(
        columnCount: Int,
        itemFramesByID: [String: CGRect]
    ) {
        guard commandPanelPresentation?.page == .recentVideos else {
            return
        }
        commandPanelRecentVideoColumnCount = max(1, columnCount)
        commandPanelRecentVideoItemFramesByID = itemFramesByID
    }

    @discardableResult
    func dismissCommandPanel() -> PlaybackCommandPanelPresentation? {
        defer {
            commandPanelPresentation = nil
            resetCommandPanelRecentVideoGridLayout()
            releaseCommandPanelSearchPreview()
            synchronizeOverlayInputOwnership()
        }
        return commandPanelPresentation
    }

    private func resetCommandPanelRecentVideoGridLayout() {
        commandPanelRecentVideoColumnCount = 1
        commandPanelRecentVideoItemFramesByID = [:]
    }

    private func releaseCommandPanelSearchPreview() {
        commandPanelSearchWindow?.invalidate()
        commandPanelSearchSource?.invalidate()
        commandPanelSearchWindow = nil
        commandPanelSearchSource = nil
    }

    func setPlaylistSource(
        _ source: PlaybackPlaylistSource,
        playbackSearchSelectedOrdinal: Int? = nil
    ) {
        guard playlistSource !== source else {
            if case .search = source.origin {
                playbackSearchPlaylistOrdinal = playbackSearchSelectedOrdinal
                if let playbackSearchSelectedOrdinal {
                    _ = setPlaylistPosition(at: playbackSearchSelectedOrdinal)
                } else {
                    playlistPosition = nil
                }
            }
            return
        }
        playlistSource?.invalidate()
        playlistPosition = nil
        if case .search = source.origin {
            playbackSearchPlaylistOrdinal = playbackSearchSelectedOrdinal
        } else {
            playbackSearchPlaylistOrdinal = nil
        }
        playlistSource = source
        if let playbackSearchSelectedOrdinal {
            _ = setPlaylistPosition(at: playbackSearchSelectedOrdinal)
        }
    }

    @discardableResult
    func setPlaylistPosition(
        itemIdentity: PlaybackPlaylistItemIdentity,
        ordinal: Int
    ) -> Bool {
        guard let source = playlistSource,
              source.itemIdentity(at: ordinal) == itemIdentity
        else {
            playlistPosition = nil
            return false
        }
        playlistPosition = PlaybackPlaylistPosition(
            datasetID: source.boundary.datasetID,
            itemIdentity: itemIdentity,
            ordinal: ordinal
        )
        return true
    }

    @discardableResult
    func setPlaylistPosition(at ordinal: Int) -> Bool {
        guard let source = playlistSource,
              let itemIdentity = source.itemIdentity(at: ordinal)
        else {
            playlistPosition = nil
            return false
        }
        playlistPosition = PlaybackPlaylistPosition(
            datasetID: source.boundary.datasetID,
            itemIdentity: itemIdentity,
            ordinal: ordinal
        )
        return true
    }

    @discardableResult
    func validatePlaylistPosition() -> Bool {
        guard let source = playlistSource,
              let playlistPosition,
              playlistPosition.datasetID == source.boundary.datasetID,
              source.itemIdentity(at: playlistPosition.ordinal)
                == playlistPosition.itemIdentity
        else {
            self.playlistPosition = nil
            return false
        }
        return true
    }

    func clearPlaylistPosition() {
        playlistPosition = nil
    }

    func clearPlaylistSource() {
        playbackSearchPlaylistOrdinal = nil
        playlistPosition = nil
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

    func setCanRepeatCurrentCue(_ canRepeat: Bool) {
        guard canRepeatCurrentCue != canRepeat else {
            return
        }
        canRepeatCurrentCue = canRepeat
    }

    func requestPointerHide() {
        pointerHideRequestGeneration &+= 1
        pointerHideRequests.send()
    }
}
