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

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        isPlaybackSidePanelVisible = userDefaults.object(forKey: Self.sidePanelVisibleKey) as? Bool ?? false
    }
}
