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
    case navigation
    case result
}

enum PlaybackQuickSearchResultSource: Equatable {
    case direct
    case chunk
}

enum PlaybackQuickSearchAIOption: Equatable {
    case chunks
    case refresh
    case copy
}

enum PlaybackQuickSearchNavigationCommand: Equatable {
    case back
    case forward
}

enum PlaybackQuickSearchNavigationState: Equatable {
    case hidden
    case visible(commands: [PlaybackQuickSearchNavigationCommand], selectedIndex: Int)
}

private enum PlaybackQuickSearchOptionStop: Equatable {
    case chunks
    case sentenceActions
    case navigation
}

struct PlaybackQuickSearchAIOptionsSnapshot: Equatable {
    let draft: String
    let aiState: PlaybackQuickSearchAIState
}

enum PlaybackQuickSearchAIState: Equatable {
    case hidden
    case loading
    case failed(String)
    case options(chunks: [AIChunkItem], selectedChunkIndex: Int?, selectedOption: PlaybackQuickSearchAIOption?)

    var selectedOption: PlaybackQuickSearchAIOption? {
        guard case .options(_, _, let selectedOption) = self else {
            return nil
        }

        return selectedOption
    }
}

enum PlaybackQuickSearchChunkCountState: Equatable {
    case hidden
    case loading(query: String)
    case exact(query: String, count: Int)

    var count: Int? {
        guard case .exact(_, let count) = self else {
            return nil
        }

        return count
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
    @Published private(set) var quickSearchNavigationState: PlaybackQuickSearchNavigationState = .hidden
    @Published private(set) var quickSearchSelectedChunkCountState: PlaybackQuickSearchChunkCountState = .hidden
    private(set) var quickSearchAIRequestID = 0
    private(set) var quickSearchSelectedChunkCountRequestID = 0
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
        cachedChunks: [AIChunkItem]?
    ) {
        let currentSentence = quickSearchCurrentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEnabled, hasAPIKey, !currentSentence.isEmpty else {
            resetQuickSearchAIState()
            return
        }

        if let cachedChunks, !cachedChunks.isEmpty {
            quickSearchAIRequestID += 1
            resetQuickSearchSelectedChunkCount()
            quickSearchAIState = .options(
                chunks: cachedChunks,
                selectedChunkIndex: 0,
                selectedOption: .chunks
            )
        } else {
            resetQuickSearchSelectedChunkCount()
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
        resetQuickSearchSelectedChunkCount()
        quickSearchAIState = .loading
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
        return quickSearchAIRequestID
    }

    func markQuickSearchAIChunkingFailed(_ message: String, requestID: Int) {
        guard requestID == quickSearchAIRequestID else {
            return
        }
        resetQuickSearchSelectedChunkCount()
        quickSearchAIState = .failed(message)
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
    }

    func markQuickSearchAIChunkingSucceeded(_ chunks: [AIChunkItem], requestID: Int) {
        guard requestID == quickSearchAIRequestID else {
            return
        }
        resetQuickSearchSelectedChunkCount()
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
    func moveQuickSearchOptionRowSelection(by offset: Int) -> Bool {
        switch quickSearchFocusTarget {
        case .aiOption:
            guard case .options(let chunks, let selectedIndex, let selectedOption?) = quickSearchAIState else {
                return false
            }

            switch selectedOption {
            case .chunks:
                guard let selectedIndex, !chunks.isEmpty else {
                    return false
                }
                let nextIndex = Self.cyclicIndex(from: selectedIndex, offset: offset, count: chunks.count)
                if nextIndex != selectedIndex {
                    resetQuickSearchSelectedChunkCount()
                }
                quickSearchAIState = .options(
                    chunks: chunks,
                    selectedChunkIndex: nextIndex,
                    selectedOption: .chunks
                )
            case .refresh, .copy:
                let options: [PlaybackQuickSearchAIOption] = [.refresh, .copy]
                let currentIndex = options.firstIndex(of: selectedOption) ?? 0
                let nextIndex = Self.cyclicIndex(from: currentIndex, offset: offset, count: options.count)
                quickSearchAIState = .options(
                    chunks: chunks,
                    selectedChunkIndex: selectedIndex,
                    selectedOption: options[nextIndex]
                )
            }
            quickSearchFocusTarget = .aiOption
            isQuickSearchFocused = false
            return true
        case .navigation:
            guard case .visible(let commands, let selectedIndex) = quickSearchNavigationState,
                  !commands.isEmpty
            else {
                return false
            }
            let nextIndex = Self.cyclicIndex(from: selectedIndex, offset: offset, count: commands.count)
            quickSearchNavigationState = .visible(commands: commands, selectedIndex: nextIndex)
            quickSearchFocusTarget = .navigation
            isQuickSearchFocused = false
            return true
        case .input, .result:
            return false
        }
    }

    private static func cyclicIndex(from current: Int, offset: Int, count: Int) -> Int {
        let modulus = max(count, 1)
        let raw = (current + offset) % modulus
        return raw < 0 ? raw + modulus : raw
    }

    @discardableResult
    func moveQuickSearchAIOptionFocus(by offset: Int) -> Bool {
        let stops = visibleOptionStops()
        guard !stops.isEmpty else {
            return false
        }

        let currentStop = currentOptionStop()
        let currentIndex: Int
        if let currentStop, let foundIndex = stops.firstIndex(of: currentStop) {
            currentIndex = foundIndex
        } else {
            currentIndex = offset < 0 ? stops.count : -1
        }

        let nextIndex = currentIndex + offset
        guard stops.indices.contains(nextIndex) else {
            quickSearchSelectedResultIndex = nil
            focusQuickSearchInput()
            return true
        }

        applyOptionStopFocus(stops[nextIndex])
        return true
    }

    private func visibleOptionStops() -> [PlaybackQuickSearchOptionStop] {
        var stops: [PlaybackQuickSearchOptionStop] = []
        if case .options(let chunks, _, _) = quickSearchAIState, !chunks.isEmpty {
            stops.append(.chunks)
        }
        if case .options = quickSearchAIState {
            stops.append(.sentenceActions)
        }
        if case .visible = quickSearchNavigationState {
            stops.append(.navigation)
        }
        return stops
    }

    func focusFirstVisibleQuickSearchOptionRow() {
        guard quickSearchFocusTarget == .input else {
            return
        }
        let stops = visibleOptionStops()
        guard let first = stops.first else {
            return
        }
        applyOptionStopFocus(first)
    }

    private func currentOptionStop() -> PlaybackQuickSearchOptionStop? {
        switch quickSearchFocusTarget {
        case .input, .result:
            return nil
        case .navigation:
            return .navigation
        case .aiOption:
            if case .options(_, _, let selectedOption?) = quickSearchAIState {
                switch selectedOption {
                case .chunks:
                    return .chunks
                case .refresh, .copy:
                    return .sentenceActions
                }
            }
            return nil
        }
    }

    private func applyOptionStopFocus(_ stop: PlaybackQuickSearchOptionStop) {
        switch stop {
        case .chunks:
            if case .options(let chunks, let selectedChunkIndex, _) = quickSearchAIState {
                let nextSelectedChunkIndex = selectedChunkIndexForFocus(
                    option: .chunks,
                    chunks: chunks,
                    currentIndex: selectedChunkIndex
                )
                if nextSelectedChunkIndex != selectedChunkIndex {
                    resetQuickSearchSelectedChunkCount()
                }
                quickSearchAIState = .options(
                    chunks: chunks,
                    selectedChunkIndex: nextSelectedChunkIndex,
                    selectedOption: .chunks
                )
            }
            quickSearchFocusTarget = .aiOption
        case .sentenceActions:
            if case .options(let chunks, let selectedChunkIndex, _) = quickSearchAIState {
                quickSearchAIState = .options(
                    chunks: chunks,
                    selectedChunkIndex: selectedChunkIndex,
                    selectedOption: .refresh
                )
            }
            quickSearchFocusTarget = .aiOption
        case .navigation:
            if case .options(let chunks, let selectedChunkIndex, _) = quickSearchAIState {
                quickSearchAIState = .options(
                    chunks: chunks,
                    selectedChunkIndex: selectedChunkIndex,
                    selectedOption: nil
                )
            }
            quickSearchFocusTarget = .navigation
        }
        isQuickSearchFocused = false
    }

    func configureQuickSearchNavigation(canMoveBack: Bool, canMoveForward: Bool) {
        var commands: [PlaybackQuickSearchNavigationCommand] = []
        if canMoveBack { commands.append(.back) }
        if canMoveForward { commands.append(.forward) }

        if commands.isEmpty {
            if quickSearchNavigationState != .hidden {
                quickSearchNavigationState = .hidden
            }
            if quickSearchFocusTarget == .navigation {
                quickSearchFocusTarget = .input
            }
            return
        }

        quickSearchNavigationState = .visible(commands: commands, selectedIndex: 0)
    }

    var isQuickSearchAIRefreshOptionActive: Bool {
        quickSearchFocusTarget == .aiOption && quickSearchAIState.selectedOption == .refresh
    }

    var isQuickSearchAICopyOptionActive: Bool {
        quickSearchFocusTarget == .aiOption && quickSearchAIState.selectedOption == .copy
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
        return chunks[selectedIndex].item
    }

    func selectedQuickSearchCurrentSentenceForCopy() -> String? {
        guard isQuickSearchAICopyOptionActive else {
            return nil
        }

        let sentence = quickSearchCurrentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        return sentence.isEmpty ? nil : sentence
    }

    func selectedQuickSearchAIChunkForCount() -> String? {
        guard case .options(let chunks, let selectedIndex?, _) = quickSearchAIState,
              chunks.indices.contains(selectedIndex)
        else {
            return nil
        }

        let query = chunks[selectedIndex].item.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? nil : query
    }

    func isQuickSearchSelectedChunkCountCurrent(for query: String) -> Bool {
        switch quickSearchSelectedChunkCountState {
        case .hidden:
            return false
        case .loading(let currentQuery), .exact(let currentQuery, _):
            return currentQuery == query
        }
    }

    @discardableResult
    func markQuickSearchSelectedChunkCountStarted(query: String) -> Int {
        quickSearchSelectedChunkCountRequestID += 1
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        quickSearchSelectedChunkCountState = trimmedQuery.isEmpty
            ? .hidden
            : .loading(query: trimmedQuery)
        return quickSearchSelectedChunkCountRequestID
    }

    func markQuickSearchSelectedChunkCountFinished(
        query: String,
        count: Int,
        requestID: Int
    ) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard requestID == quickSearchSelectedChunkCountRequestID,
              selectedQuickSearchAIChunkForCount() == trimmedQuery
        else {
            return
        }

        quickSearchSelectedChunkCountState = .exact(
            query: trimmedQuery,
            count: max(0, count)
        )
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
        quickSearchAIState = restoredQuickSearchAIState(snapshot.aiState)
        quickSearchFocusTarget = .aiOption
        isQuickSearchFocused = false
        return true
    }

    func resetQuickSearchAIState() {
        if quickSearchAIState != .hidden {
            quickSearchAIState = .hidden
        }
        quickSearchAIRequestID += 1
        resetQuickSearchSelectedChunkCount()
        quickSearchAIOptionsSnapshot = nil
        if quickSearchNavigationState != .hidden {
            quickSearchNavigationState = .hidden
        }
        if quickSearchFocusTarget == .aiOption || quickSearchFocusTarget == .navigation {
            quickSearchFocusTarget = .input
        }
    }

    func resetQuickSearchSelectedChunkCount() {
        quickSearchSelectedChunkCountRequestID += 1
        quickSearchSelectedChunkCountState = .hidden
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

    private func selectedChunkIndexForFocus(
        option: PlaybackQuickSearchAIOption,
        chunks: [AIChunkItem],
        currentIndex: Int?
    ) -> Int? {
        guard option == .chunks, !chunks.isEmpty else {
            return currentIndex
        }

        return chunks.startIndex
    }

    private func restoredQuickSearchAIState(_ state: PlaybackQuickSearchAIState) -> PlaybackQuickSearchAIState {
        guard case .options(let chunks, _, .chunks) = state else {
            return state
        }

        resetQuickSearchSelectedChunkCount()
        return .options(
            chunks: chunks,
            selectedChunkIndex: chunks.isEmpty ? nil : chunks.startIndex,
            selectedOption: .chunks
        )
    }
}
