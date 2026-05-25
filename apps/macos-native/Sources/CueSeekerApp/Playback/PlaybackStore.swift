import Foundation
import CueSeekerCore

struct PlaybackQuickSearchLineCandidate: Equatable {
    let entryID: Int64
    let entryIndex: Int
    let lineIndex: Int
    let text: String
}

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
    @Published var quickSearchDraft = "" {
        didSet {
            guard isQuickSearchOverlayVisible,
                  !isApplyingQuickSearchDraftUpdate
            else {
                return
            }

            quickSearchCanNavigateSubtitleLines = false
            if quickSearchSubmittedQuery != quickSearchDraft.trimmingCharacters(in: .whitespacesAndNewlines) {
                resetQuickSearchResultSelection()
            }
        }
    }
    @Published var isQuickSearchFocused = false
    @Published private(set) var quickSearchForcedTextUpdateID = 0
    @Published private(set) var quickSearchFocusRequestID = 0
    @Published private(set) var quickSearchCanNavigateSubtitleLines = false
    @Published private(set) var quickSearchSubtitleLineCandidates: [PlaybackQuickSearchLineCandidate] = []
    @Published private(set) var quickSearchSelectedSubtitleLineIndex: Int?
    @Published private(set) var quickSearchSubmittedQuery: String?
    @Published private(set) var quickSearchSelectedResultIndex: Int?
    var quickSearchPlaybackWasPlayingOnOpen = false
    private var isApplyingQuickSearchDraftUpdate = false

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        isPlaybackSidePanelVisible = userDefaults.object(forKey: Self.sidePanelVisibleKey) as? Bool ?? false
    }

    func setQuickSearchDraft(_ draft: String) {
        resetQuickSearchResultSelection()
        applyQuickSearchDraft(
            draft,
            canNavigateSubtitleLines: false,
            selectedSubtitleLineIndex: quickSearchSelectedSubtitleLineIndex
        )
    }

    func requestQuickSearchFocus() {
        isQuickSearchFocused = true
        quickSearchFocusRequestID += 1
    }

    func setQuickSearchSubtitleLineCandidates(
        _ candidates: [PlaybackQuickSearchLineCandidate],
        selectedIndex: Int?
    ) {
        quickSearchSubtitleLineCandidates = candidates

        guard let selectedIndex,
              candidates.indices.contains(selectedIndex)
        else {
            applyQuickSearchDraft(
                "",
                canNavigateSubtitleLines: false,
                selectedSubtitleLineIndex: nil
            )
            return
        }

        applyQuickSearchDraft(
            candidates[selectedIndex].text,
            canNavigateSubtitleLines: true,
            selectedSubtitleLineIndex: selectedIndex
        )
    }

    @discardableResult
    func moveQuickSearchSubtitleLineSelection(by offset: Int) -> Bool {
        guard quickSearchCanNavigateSubtitleLines,
              let selectedIndex = quickSearchSelectedSubtitleLineIndex,
              !quickSearchSubtitleLineCandidates.isEmpty
        else {
            return false
        }

        let nextIndex = min(
            max(selectedIndex + offset, quickSearchSubtitleLineCandidates.startIndex),
            quickSearchSubtitleLineCandidates.index(before: quickSearchSubtitleLineCandidates.endIndex)
        )
        guard quickSearchSubtitleLineCandidates.indices.contains(nextIndex) else {
            return true
        }

        applyQuickSearchDraft(
            quickSearchSubtitleLineCandidates[nextIndex].text,
            canNavigateSubtitleLines: true,
            selectedSubtitleLineIndex: nextIndex
        )
        return true
    }

    func resetQuickSearchSubtitleLineNavigation() {
        quickSearchSubtitleLineCandidates = []
        quickSearchSelectedSubtitleLineIndex = nil
        quickSearchCanNavigateSubtitleLines = false
    }

    func markQuickSearchSubmitted(query: String) {
        quickSearchSubmittedQuery = query
        quickSearchSelectedResultIndex = nil
        quickSearchCanNavigateSubtitleLines = false
    }

    func selectDefaultQuickSearchResultIfNeeded(resultCount: Int) {
        guard quickSearchSubmittedQuery != nil, resultCount > 0 else {
            quickSearchSelectedResultIndex = nil
            return
        }

        quickSearchSelectedResultIndex = 0
    }

    func selectedQuickSearchResult(in results: [SubtitleSearchResult]) -> SubtitleSearchResult? {
        guard let quickSearchSelectedResultIndex,
              results.indices.contains(quickSearchSelectedResultIndex)
        else {
            return nil
        }

        return results[quickSearchSelectedResultIndex]
    }

    @discardableResult
    func moveQuickSearchResultSelection(by offset: Int, resultCount: Int) -> Bool {
        guard quickSearchSubmittedQuery != nil else {
            return false
        }

        guard resultCount > 0 else {
            quickSearchSelectedResultIndex = nil
            return true
        }

        let currentIndex = quickSearchSelectedResultIndex ?? 0
        quickSearchSelectedResultIndex = min(
            max(currentIndex + offset, 0),
            resultCount - 1
        )
        return true
    }

    func resetQuickSearchResultSelection() {
        quickSearchSubmittedQuery = nil
        quickSearchSelectedResultIndex = nil
    }

    private func applyQuickSearchDraft(
        _ draft: String,
        canNavigateSubtitleLines: Bool,
        selectedSubtitleLineIndex: Int?
    ) {
        isApplyingQuickSearchDraftUpdate = true
        quickSearchDraft = draft
        quickSearchForcedTextUpdateID += 1
        quickSearchCanNavigateSubtitleLines = canNavigateSubtitleLines
        quickSearchSelectedSubtitleLineIndex = selectedSubtitleLineIndex
        isApplyingQuickSearchDraftUpdate = false
    }
}
