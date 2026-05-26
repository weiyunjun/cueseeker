import Foundation
import CueSeekerCore

struct PlaybackQuickSearchLineCandidate: Equatable {
    let entryID: Int64
    let entryIndex: Int
    let lineIndex: Int
    let text: String
}

enum PlaybackQuickSearchFocusTarget: Equatable {
    case input
    case aiOption
    case result
}

enum PlaybackQuickSearchResultSource: Equatable {
    case direct
    case chunk
}

enum PlaybackQuickSearchAIOption: Equatable {
    case chunks
    case refresh
}

struct PlaybackQuickSearchAIOptionsSnapshot: Equatable {
    let draft: String
    let aiState: PlaybackQuickSearchAIState
}

enum PlaybackQuickSearchAIState: Equatable {
    case hidden
    case loading
    case failed(String)
    case options(chunks: [String], selectedChunkIndex: Int?, selectedOption: PlaybackQuickSearchAIOption?)

    var selectedOption: PlaybackQuickSearchAIOption? {
        guard case .options(_, _, let selectedOption) = self else {
            return nil
        }

        return selectedOption
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
            quickSearchAIOptionsSnapshot = nil
            quickSearchFocusTarget = .input
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
    @Published private(set) var quickSearchCurrentSentence = ""
    @Published private(set) var quickSearchSubmittedQuery: String?
    @Published private(set) var quickSearchSelectedResultIndex: Int?
    @Published private(set) var quickSearchResultSource: PlaybackQuickSearchResultSource?
    @Published private(set) var quickSearchFocusTarget: PlaybackQuickSearchFocusTarget = .input
    @Published private(set) var quickSearchAIState: PlaybackQuickSearchAIState = .hidden
    private(set) var quickSearchAIRequestID = 0
    var quickSearchPlaybackWasPlayingOnOpen = false
    private var isApplyingQuickSearchDraftUpdate = false
    private var quickSearchAIOptionsSnapshot: PlaybackQuickSearchAIOptionsSnapshot?

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        isPlaybackSidePanelVisible = userDefaults.object(forKey: Self.sidePanelVisibleKey) as? Bool ?? false
    }

    func setQuickSearchDraft(_ draft: String) {
        resetQuickSearchResultSelection()
        resetQuickSearchAIState()
        focusQuickSearchInput()
        applyQuickSearchDraft(
            draft,
            canNavigateSubtitleLines: false,
            selectedSubtitleLineIndex: quickSearchSelectedSubtitleLineIndex
        )
    }

    func requestQuickSearchFocus() {
        focusQuickSearchInput()
    }

    func clearQuickSearchInputFocus() {
        isQuickSearchFocused = false
    }

    func focusQuickSearchInput() {
        quickSearchFocusTarget = .input
        quickSearchSelectedResultIndex = nil
        if case .options(let chunks, let selectedChunkIndex, _) = quickSearchAIState {
            quickSearchAIState = .options(
                chunks: chunks,
                selectedChunkIndex: selectedChunkIndex,
                selectedOption: nil
            )
        }
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
            quickSearchCurrentSentence = ""
            applyQuickSearchDraft(
                "",
                canNavigateSubtitleLines: false,
                selectedSubtitleLineIndex: nil
            )
            quickSearchFocusTarget = .input
            isQuickSearchFocused = false
            return
        }

        quickSearchCurrentSentence = candidates[selectedIndex].text
        applyQuickSearchDraft(
            "",
            canNavigateSubtitleLines: false,
            selectedSubtitleLineIndex: selectedIndex
        )
        quickSearchFocusTarget = .input
        isQuickSearchFocused = false
    }

    @discardableResult
    func moveQuickSearchSubtitleLineSelection(by offset: Int) -> Bool {
        false
    }

    func resetQuickSearchSubtitleLineNavigation() {
        quickSearchSubtitleLineCandidates = []
        quickSearchSelectedSubtitleLineIndex = nil
        quickSearchCanNavigateSubtitleLines = false
        quickSearchCurrentSentence = ""
    }

    func markQuickSearchSubmitted(query: String, source: PlaybackQuickSearchResultSource) {
        quickSearchSubmittedQuery = query
        quickSearchResultSource = source
        quickSearchSelectedResultIndex = nil
        quickSearchCanNavigateSubtitleLines = false
        quickSearchFocusTarget = .input
    }

    func selectDefaultQuickSearchResultIfNeeded(resultCount: Int) {
        guard quickSearchSubmittedQuery != nil, resultCount > 0 else {
            quickSearchSelectedResultIndex = nil
            return
        }

        quickSearchSelectedResultIndex = 0
        quickSearchFocusTarget = .result
        isQuickSearchFocused = false
    }

    func selectedQuickSearchResult(in results: [SubtitleSearchResult]) -> SubtitleSearchResult? {
        guard quickSearchFocusTarget == .result,
              let quickSearchSelectedResultIndex,
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
            focusQuickSearchInput()
            return true
        }

        if quickSearchFocusTarget == .input {
            quickSearchSelectedResultIndex = offset < 0 ? resultCount - 1 : 0
            quickSearchFocusTarget = .result
            isQuickSearchFocused = false
            return true
        }

        let currentIndex = quickSearchSelectedResultIndex ?? 0
        if offset < 0, currentIndex <= 0 {
            quickSearchSelectedResultIndex = nil
            focusQuickSearchInput()
            return true
        }
        if offset > 0, currentIndex >= resultCount - 1 {
            quickSearchSelectedResultIndex = nil
            focusQuickSearchInput()
            return true
        }

        quickSearchSelectedResultIndex = min(max(currentIndex + offset, 0), resultCount - 1)
        quickSearchFocusTarget = .result
        isQuickSearchFocused = false
        return true
    }

    func resetQuickSearchResultSelection() {
        quickSearchSubmittedQuery = nil
        quickSearchSelectedResultIndex = nil
        quickSearchResultSource = nil
        if quickSearchFocusTarget == .result {
            quickSearchFocusTarget = .input
        }
    }

    func showQuickSearchAIEntryIfPossible(
        isEnabled: Bool,
        hasAPIKey: Bool,
        cachedChunks: [String]?
    ) {
        let currentSentence = quickSearchCurrentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, hasAPIKey, !currentSentence.isEmpty else {
            resetQuickSearchAIState()
            return
        }

        if let cachedChunks, !cachedChunks.isEmpty {
            quickSearchAIRequestID += 1
            quickSearchAIState = .options(
                chunks: cachedChunks,
                selectedChunkIndex: 0,
                selectedOption: .chunks
            )
        } else {
            quickSearchAIState = .options(
                chunks: [],
                selectedChunkIndex: nil,
                selectedOption: .refresh
            )
        }
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
    }

    @discardableResult
    func markQuickSearchAIChunkingStarted() -> Int {
        quickSearchAIRequestID += 1
        quickSearchCanNavigateSubtitleLines = false
        quickSearchAIState = .loading
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
        return quickSearchAIRequestID
    }

    func markQuickSearchAIChunkingFailed(_ message: String, requestID: Int) {
        guard requestID == quickSearchAIRequestID else {
            return
        }
        quickSearchAIState = .failed(message)
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
    }

    func markQuickSearchAIChunkingSucceeded(_ chunks: [String], requestID: Int) {
        guard requestID == quickSearchAIRequestID else {
            return
        }
        guard !chunks.isEmpty else {
            quickSearchAIState = .failed("The AI service returned no usable chunks.")
            quickSearchFocusTarget = .aiOption
            isQuickSearchFocused = false
            return
        }
        quickSearchAIState = .options(
            chunks: chunks,
            selectedChunkIndex: 0,
            selectedOption: .chunks
        )
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
    }

    @discardableResult
    func moveQuickSearchAIChunkSelection(by offset: Int) -> Bool {
        guard case .options(let chunks, let selectedIndex?, .chunks) = quickSearchAIState,
              !chunks.isEmpty
        else {
            return false
        }

        let nextIndex = min(
            max(selectedIndex + offset, chunks.startIndex),
            chunks.index(before: chunks.endIndex)
        )
        quickSearchAIState = .options(
            chunks: chunks,
            selectedChunkIndex: nextIndex,
            selectedOption: .chunks
        )
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
        return true
    }

    @discardableResult
    func moveQuickSearchAIOptionFocus(by offset: Int) -> Bool {
        guard case .options(let chunks, let selectedChunkIndex, let selectedOption) = quickSearchAIState else {
            return false
        }

        let options = aiOptions(for: chunks)
        guard !options.isEmpty else {
            focusQuickSearchInput()
            return true
        }

        if quickSearchFocusTarget == .input || selectedOption == nil {
            let nextOption = offset < 0 ? options[options.index(before: options.endIndex)] : options[0]
            quickSearchAIState = .options(
                chunks: chunks,
                selectedChunkIndex: selectedChunkIndexForFocus(
                    option: nextOption,
                    chunks: chunks,
                    currentIndex: selectedChunkIndex
                ),
                selectedOption: nextOption
            )
            quickSearchFocusTarget = .aiOption
            isQuickSearchFocused = false
            return true
        }

        guard let selectedOption,
              let optionIndex = options.firstIndex(of: selectedOption)
        else {
            return false
        }

        let nextIndex = optionIndex + offset
        guard options.indices.contains(nextIndex) else {
            quickSearchAIState = .options(
                chunks: chunks,
                selectedChunkIndex: selectedChunkIndex,
                selectedOption: nil
            )
            quickSearchSelectedResultIndex = nil
            focusQuickSearchInput()
            return true
        }

        let nextOption = options[nextIndex]
        quickSearchAIState = .options(
            chunks: chunks,
            selectedChunkIndex: selectedChunkIndexForFocus(
                option: nextOption,
                chunks: chunks,
                currentIndex: selectedChunkIndex
            ),
            selectedOption: nextOption
        )
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
        return true
    }

    var isQuickSearchAIRefreshOptionActive: Bool {
        quickSearchFocusTarget == .aiOption && quickSearchAIState.selectedOption == .refresh
    }

    var canStartQuickSearchAIChunkingRequest: Bool {
        switch quickSearchAIState {
        case .options(_, _, .refresh):
            return quickSearchFocusTarget == .aiOption
        case .hidden, .loading, .failed, .options:
            return false
        }
    }

    func selectedQuickSearchAIChunk() -> String? {
        guard quickSearchFocusTarget == .aiOption,
              case .options(let chunks, let selectedIndex?, .chunks) = quickSearchAIState,
              chunks.indices.contains(selectedIndex)
        else {
            return nil
        }
        return chunks[selectedIndex]
    }

    func applyQuickSearchAIChunkQuery(_ chunk: String) {
        quickSearchAIOptionsSnapshot = PlaybackQuickSearchAIOptionsSnapshot(
            draft: quickSearchDraft,
            aiState: quickSearchAIState
        )
        resetQuickSearchResultSelection()
        applyQuickSearchDraft(
            chunk,
            canNavigateSubtitleLines: false,
            selectedSubtitleLineIndex: quickSearchSelectedSubtitleLineIndex
        )
        quickSearchFocusTarget = .input
        isQuickSearchFocused = false
    }

    @discardableResult
    func restoreQuickSearchAIOptionsAfterChunkSearch() -> Bool {
        guard quickSearchResultSource == .chunk,
              let snapshot = quickSearchAIOptionsSnapshot
        else {
            return false
        }

        resetQuickSearchResultSelection()
        applyQuickSearchDraft(
            snapshot.draft,
            canNavigateSubtitleLines: false,
            selectedSubtitleLineIndex: quickSearchSelectedSubtitleLineIndex
        )
        quickSearchAIState = snapshot.aiState
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
        return true
    }

    func resetQuickSearchAIState() {
        if quickSearchAIState != .hidden {
            quickSearchAIState = .hidden
        }
        quickSearchAIRequestID += 1
        quickSearchAIOptionsSnapshot = nil
        if quickSearchFocusTarget == .aiOption {
            quickSearchFocusTarget = .input
        }
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

    private func aiOptions(for chunks: [String]) -> [PlaybackQuickSearchAIOption] {
        chunks.isEmpty ? [.refresh] : [.chunks, .refresh]
    }

    private func selectedChunkIndexForFocus(
        option: PlaybackQuickSearchAIOption,
        chunks: [String],
        currentIndex: Int?
    ) -> Int? {
        guard option == .chunks, !chunks.isEmpty else {
            return currentIndex
        }

        return min(max(currentIndex ?? 0, chunks.startIndex), chunks.index(before: chunks.endIndex))
    }
}
