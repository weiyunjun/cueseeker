import Foundation
import CueSeekerCore

@MainActor
final class PlaybackStore: ObservableObject {
    @Published var currentSubtitleEntries: [SubtitleDatabaseEntry] = []
    @Published var currentSubtitleEntryLookup = SubtitleActiveEntryLookup()
    @Published var playbackStatus: PlaybackStatus = .idle
    @Published var isPlaybackSurfaceExpanded = false
    @Published var isPlaybackSidePanelVisible = true
    @Published var isTimelineScrubbing = false
    @Published var playbackViewModel: PlaybackViewModel?
}
