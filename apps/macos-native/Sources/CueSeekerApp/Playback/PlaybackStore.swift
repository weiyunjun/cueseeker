import Foundation
import CueSeekerCore

@MainActor
final class PlaybackStore: ObservableObject {
    private static let sidePanelVisibleKey = "playbackSidePanelVisible"

    private let userDefaults: UserDefaults

    @Published var currentSubtitleEntries: [SubtitleDatabaseEntry] = []
    @Published var currentSubtitleEntryLookup = SubtitleActiveEntryLookup()
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var isPlaybackSurfaceExpanded = false
    @Published var isPlaybackSidePanelVisible: Bool {
        didSet {
            userDefaults.set(isPlaybackSidePanelVisible, forKey: Self.sidePanelVisibleKey)
        }
    }
    @Published var isTimelineScrubbing = false
    @Published var timelineScrubTime: Double?
    @Published var playbackViewModel: PlaybackViewModel?
    @Published var isQuickSearchOverlayVisible = false
    @Published var quickSearchDraft = ""
    @Published var isQuickSearchFocused = false
    @Published private(set) var quickSearchForcedTextUpdateID = 0
    @Published private(set) var quickSearchFocusRequestID = 0
    var quickSearchPlaybackWasPlayingOnOpen = false

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        isPlaybackSidePanelVisible = userDefaults.object(forKey: Self.sidePanelVisibleKey) as? Bool ?? false
    }

    func setQuickSearchDraft(_ draft: String) {
        quickSearchDraft = draft
        quickSearchForcedTextUpdateID += 1
    }

    func requestQuickSearchFocus() {
        isQuickSearchFocused = true
        quickSearchFocusRequestID += 1
    }
}
