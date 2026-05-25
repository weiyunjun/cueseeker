import Foundation
import CueSeekerCore

struct PlaybackQuickSearchLineCandidate: Equatable {
    let entryID: Int64
    let entryIndex: Int
    let lineIndex: Int
    let text: String
}

enum PlaybackQuickSearchAIState: Equatable {
    case hidden
    case hint
    case loading
    case failed(String)
    case chunks([String], selectedIndex: Int)

    var ghostSuffix: String {
        switch self {
        case .hint:
            return " /chunks"
        case .hidden, .loading, .failed, .chunks:
            return ""
        }
    }
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
            resetQuickSearchAIState()
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
    @Published private(set) var quickSearchAIState: PlaybackQuickSearchAIState = .hidden
    private(set) var quickSearchAIRequestID = 0
    var quickSearchPlaybackWasPlayingOnOpen = false
    private var isApplyingQuickSearchDraftUpdate = false

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        isPlaybackSidePanelVisible = userDefaults.object(forKey: Self.sidePanelVisibleKey) as? Bool ?? false
    }

    func setQuickSearchDraft(_ draft: String) {
        resetQuickSearchResultSelection()
        resetQuickSearchAIState()
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
        resetQuickSearchAIState()
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

    func showQuickSearchAIEntryIfPossible(
        isEnabled: Bool,
        hasAPIKey: Bool,
        cachedChunks: [String]?
    ) {
        let trimmedDraft = quickSearchDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, hasAPIKey, !trimmedDraft.isEmpty else {
            resetQuickSearchAIState()
            return
        }

        if let cachedChunks, !cachedChunks.isEmpty {
            quickSearchAIRequestID += 1
            quickSearchAIState = .chunks(cachedChunks, selectedIndex: 0)
        } else {
            quickSearchAIState = .hint
        }
    }

    @discardableResult
    func markQuickSearchAIChunkingStarted() -> Int {
        quickSearchAIRequestID += 1
        quickSearchCanNavigateSubtitleLines = false
        quickSearchAIState = .loading
        return quickSearchAIRequestID
    }

    func markQuickSearchAIChunkingFailed(_ message: String, requestID: Int) {
        guard requestID == quickSearchAIRequestID else {
            return
        }
        quickSearchAIState = .failed(message)
    }

    func markQuickSearchAIChunkingSucceeded(_ chunks: [String], requestID: Int) {
        guard requestID == quickSearchAIRequestID else {
            return
        }
        guard !chunks.isEmpty else {
            quickSearchAIState = .failed("The AI service returned no usable chunks.")
            return
        }
        quickSearchAIState = .chunks(chunks, selectedIndex: 0)
    }

    @discardableResult
    func moveQuickSearchAIChunkSelection(by offset: Int) -> Bool {
        guard case .chunks(let chunks, let selectedIndex) = quickSearchAIState,
              !chunks.isEmpty
        else {
            return false
        }

        let nextIndex = min(
            max(selectedIndex + offset, chunks.startIndex),
            chunks.index(before: chunks.endIndex)
        )
        quickSearchAIState = .chunks(chunks, selectedIndex: nextIndex)
        return true
    }

    func selectedQuickSearchAIChunk() -> String? {
        guard case .chunks(let chunks, let selectedIndex) = quickSearchAIState,
              chunks.indices.contains(selectedIndex)
        else {
            return nil
        }
        return chunks[selectedIndex]
    }

    func applyQuickSearchAIChunkQuery(_ chunk: String) {
        resetQuickSearchResultSelection()
        applyQuickSearchDraft(
            chunk,
            canNavigateSubtitleLines: false,
            selectedSubtitleLineIndex: quickSearchSelectedSubtitleLineIndex
        )
        resetQuickSearchAIState()
    }

    func resetQuickSearchAIState() {
        if quickSearchAIState != .hidden {
            quickSearchAIState = .hidden
        }
        quickSearchAIRequestID += 1
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
