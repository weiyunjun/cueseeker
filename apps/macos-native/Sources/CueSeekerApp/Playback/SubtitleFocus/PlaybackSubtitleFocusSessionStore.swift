import Combine
import CueSeekerCore
import Foundation

struct PlaybackSubtitleFocusOpenSnapshot: Equatable, Sendable {
    let source: SubtitleFocusSourceIdentity
    let timestampMilliseconds: Int
    let wasPlaying: Bool

    init(
        source: SubtitleFocusSourceIdentity,
        timestampMilliseconds: Int,
        wasPlaying: Bool
    ) {
        self.source = source
        self.timestampMilliseconds = max(0, timestampMilliseconds)
        self.wasPlaying = wasPlaying
    }
}

struct PlaybackSubtitleFocusSessionToken: Equatable, Sendable {
    let source: SubtitleFocusSourceIdentity
    let sessionGeneration: Int
}

enum PlaybackSubtitleFocusState: Equatable, Sendable {
    case closed
    case opening
    case cueSelection(SubtitleFocusSnapshot)
}

enum PlaybackOverlayModule: String, CaseIterable, Equatable, Sendable {
    case current
    case playlist
    case search
    case recent
    case library
    case shiori

    static let standardModules: [Self] = [
        .current,
        .search,
        .recent,
        .library,
        .shiori,
    ]

    static func modules(hasPlaylist: Bool) -> [Self] {
        hasPlaylist ? allCases : standardModules
    }

    var label: String {
        switch self {
        case .current:
            "Current"
        case .playlist:
            "Playlist"
        case .search:
            "Search"
        case .recent:
            "Recent"
        case .library:
            "Library"
        case .shiori:
            "Shiori"
        }
    }

    var systemImage: String {
        switch self {
        case .current, .recent:
            "clock"
        case .playlist:
            "list.bullet"
        case .search:
            "magnifyingglass"
        case .library:
            "folder"
        case .shiori:
            "bookmark"
        }
    }
}

struct PlaybackSubtitleFocusKeyboardNavigationRequest: Equatable, Sendable {
    let sequence: Int
    let direction: SubtitleFocusNavigationDirection
    let targetOrdinal: Int
    let contentDatasetID: String?
    let contentGeneration: UInt64?

    init(
        sequence: Int,
        direction: SubtitleFocusNavigationDirection,
        targetOrdinal: Int,
        contentDatasetID: String? = nil,
        contentGeneration: UInt64? = nil
    ) {
        self.sequence = sequence
        self.direction = direction
        self.targetOrdinal = targetOrdinal
        self.contentDatasetID = contentDatasetID
        self.contentGeneration = contentGeneration
    }
}

@MainActor
final class PlaybackSubtitleFocusSessionStore: ObservableObject {
    let openSnapshot: PlaybackSubtitleFocusOpenSnapshot
    let token: PlaybackSubtitleFocusSessionToken

    @Published private(set) var state: PlaybackSubtitleFocusState = .opening
    @Published private(set) var keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
        = nil
    @Published private(set) var pendingKeyboardAction: PlaybackSubtitleFocusAction? = nil
    @Published private(set) var activeKeyboardAction: PlaybackSubtitleFocusActionExecution? = nil
    @Published private(set) var completeCueBatch: SubtitleFocusCueBatch? = nil
    @Published private(set) var availableModules: [PlaybackOverlayModule]
    @Published private(set) var selectedModule: PlaybackOverlayModule? = .current
    @Published private(set) var playlistWindow: PlaybackPlaylistSessionWindowStore?

    private var keyboardActionGeneration = 0
    private var isSessionActive = true
    private var isScrollbarDragging = false
    private var isCueReelMotionActive = false
    private var keyboardNavigationSequence = 0
    private var pendingKeyboardNavigationTargetOrdinal: Int?
    private var pendingKeyboardNavigationTargetIdentity: PlaybackPlaylistItemIdentity?
    private var playlistWindowSnapshotCancellable: AnyCancellable?
    private var observedPlaylistDatasetID: AnyHashable?
    private var observedPlaylistGeneration: UInt64?
    private var observedPlaylistRevision: UInt64?

    init(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot,
        sessionGeneration: Int,
        availableModules: [PlaybackOverlayModule] = PlaybackOverlayModule.standardModules,
        playlistSource: PlaybackPlaylistSource? = nil
    ) {
        self.openSnapshot = openSnapshot
        let requestedModules = Set(availableModules)
        var normalizedModules = PlaybackOverlayModule.allCases.filter {
            requestedModules.contains($0)
        }
        if !normalizedModules.contains(.current) {
            normalizedModules.insert(.current, at: 0)
        }
        self.availableModules = normalizedModules
        let playlistWindow = playlistSource?.makeSessionWindowStore()
        self.playlistWindow = playlistWindow
        token = PlaybackSubtitleFocusSessionToken(
            source: openSnapshot.source,
            sessionGeneration: sessionGeneration
        )
        if let playlistWindow {
            observedPlaylistDatasetID = playlistWindow.snapshot.datasetID
            observedPlaylistGeneration = playlistWindow.snapshot.generation
            observedPlaylistRevision = playlistWindow.snapshot.revision
            playlistWindowSnapshotCancellable = playlistWindow.$snapshot
                .dropFirst()
                .sink { [weak self] snapshot in
                    self?.observePlaylistSnapshot(snapshot)
                }
        }
    }

    var isActive: Bool {
        isSessionActive
    }

    var currentSnapshot: SubtitleFocusSnapshot? {
        guard case .cueSelection(let snapshot) = state else {
            return nil
        }
        return snapshot
    }

    var retainedCueCount: Int {
        completeCueBatch?.cues.count ?? currentSnapshot?.cues.count ?? 0
    }

    var completeCueLoadTotalCount: Int? {
        guard completeCueBatch == nil,
              let snapshot = currentSnapshot,
              snapshot.cues.count < snapshot.totalCount
        else {
            return nil
        }
        return snapshot.totalCount
    }

    @discardableResult
    func selectModule(_ module: PlaybackOverlayModule) -> Bool {
        guard isSessionActive,
              availableModules.contains(module),
              selectedModule != module
        else {
            return false
        }

        prepareReelForModuleTransition()
        selectedModule = module
        return true
    }

    @discardableResult
    func selectNextModule() -> Bool {
        guard isSessionActive,
              let selectedModule,
              let currentIndex = availableModules.firstIndex(of: selectedModule),
              !availableModules.isEmpty
        else {
            return false
        }

        let nextIndex = availableModules.index(
            after: currentIndex
        ) == availableModules.endIndex
            ? availableModules.startIndex
            : availableModules.index(after: currentIndex)
        return selectModule(availableModules[nextIndex])
    }

    func cue(at ordinal: Int) -> SubtitleFocusCue? {
        if let completeCueBatch,
           completeCueBatch.cues.indices.contains(ordinal) {
            let cue = completeCueBatch.cues[ordinal]
            return cue.ordinal == ordinal ? cue : nil
        }
        return currentSnapshot?.cues.first { $0.ordinal == ordinal }
    }

    @discardableResult
    func publishInitialSnapshot(
        _ snapshot: SubtitleFocusSnapshot,
        token requestToken: PlaybackSubtitleFocusSessionToken
    ) -> Bool {
        let expectedRange = SubtitleFocusWindowPolicy.standard.windowRange(
            totalCount: snapshot.totalCount,
            selectedOrdinal: snapshot.selectedOrdinal
        )
        guard accepts(requestToken),
              state == .opening,
              snapshot.selectedCue != nil,
              !snapshot.cues.isEmpty,
              snapshot.totalCount > 0,
              snapshot.selectedOrdinal < snapshot.totalCount,
              snapshot.cues.count == expectedRange.count,
              let ordinalRange = snapshot.ordinalRange,
              ordinalRange.count == snapshot.cues.count,
              ordinalRange == expectedRange,
              snapshot.cues.map(\.ordinal) == Array(expectedRange)
        else {
            return false
        }
        if snapshot.cues.count == snapshot.totalCount,
           snapshot.cues.map(\.ordinal) == Array(0..<snapshot.totalCount) {
            completeCueBatch = SubtitleFocusCueBatch(
                totalCount: snapshot.totalCount,
                cues: snapshot.cues
            )
        }
        state = .cueSelection(snapshot)
        return true
    }

    @discardableResult
    func publishCompleteCueBatch(
        _ batch: SubtitleFocusCueBatch,
        token requestToken: PlaybackSubtitleFocusSessionToken
    ) -> Bool {
        guard accepts(requestToken),
              completeCueBatch == nil,
              let snapshot = currentSnapshot,
              batch.totalCount == snapshot.totalCount,
              batch.cues.count == snapshot.totalCount,
              batch.cues.map(\.ordinal) == Array(0..<snapshot.totalCount),
              snapshot.cues.allSatisfy({ cue in
                  batch.cues.indices.contains(cue.ordinal)
                      && batch.cues[cue.ordinal] == cue
              }),
              batch.cues.indices.contains(snapshot.selectedOrdinal),
              batch.cues[snapshot.selectedOrdinal] == snapshot.selectedCue
        else {
            return false
        }

        completeCueBatch = batch
        return true
    }

    @discardableResult
    func requestKeyboardNavigation(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard isSessionActive,
              pendingKeyboardAction == nil,
              activeKeyboardAction == nil,
              (!isCueReelMotionActive
                  || pendingKeyboardNavigationTargetOrdinal != nil),
              let selectedModule
        else {
            return false
        }

        let currentTarget: Int
        let totalCount: Int
        let contentDatasetID: String?
        let contentGeneration: UInt64?
        var targetIdentity: PlaybackPlaylistItemIdentity?
        switch selectedModule {
        case .current:
            guard let snapshot = currentSnapshot else {
                return false
            }
            currentTarget = pendingKeyboardNavigationTargetOrdinal
                ?? snapshot.selectedOrdinal
            totalCount = snapshot.totalCount
            contentDatasetID = nil
            contentGeneration = nil
            targetIdentity = nil
        case .playlist:
            guard let playlistWindow,
                  let selectedOrdinal = playlistWindow.selectedOrdinal,
                  let reelDatasetID = playlistWindow.reelDatasetID
            else {
                return false
            }
            currentTarget = pendingKeyboardNavigationTargetOrdinal
                ?? selectedOrdinal
            totalCount = playlistWindow.snapshot.totalCount
            contentDatasetID = reelDatasetID
            contentGeneration = playlistWindow.snapshot.generation
            targetIdentity = nil
        default:
            return false
        }

        let targetOrdinal = direction == .backward
            ? currentTarget - 1
            : currentTarget + 1
        guard targetOrdinal >= 0,
              targetOrdinal < totalCount,
              selectedModule != .current || cue(at: targetOrdinal) != nil
        else {
            return false
        }
        if selectedModule == .playlist {
            targetIdentity = playlistWindow?.item(at: targetOrdinal)?.identity
                ?? playlistWindow?.knownItemIdentity(at: targetOrdinal)
        }
        keyboardNavigationSequence += 1
        pendingKeyboardNavigationTargetOrdinal = targetOrdinal
        pendingKeyboardNavigationTargetIdentity = targetIdentity
        keyboardNavigationRequest = PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: keyboardNavigationSequence,
            direction: direction,
            targetOrdinal: targetOrdinal,
            contentDatasetID: contentDatasetID,
            contentGeneration: contentGeneration
        )
        return true
    }

    @discardableResult
    func commitKeyboardNavigation(
        _ request: PlaybackSubtitleFocusKeyboardNavigationRequest
    ) -> Bool {
        guard isSessionActive,
              selectedModule == .current,
              keyboardNavigationRequest == request,
              pendingKeyboardNavigationTargetOrdinal == request.targetOrdinal,
              activeKeyboardAction == nil,
              selectAvailableCue(ordinal: request.targetOrdinal)
        else {
            return false
        }
        pendingKeyboardNavigationTargetOrdinal = nil
        keyboardNavigationRequest = nil
        return true
    }

    @discardableResult
    func commitNativeReelSelection(ordinal: Int) -> Bool {
        guard isSessionActive,
              selectedModule == .current,
              activeKeyboardAction == nil,
              (pendingKeyboardAction == nil
                  || isCueReelMotionActive
                  || isScrollbarDragging),
              pendingKeyboardNavigationTargetOrdinal == nil
        else {
            return false
        }
        if currentSnapshot?.selectedOrdinal == ordinal {
            return true
        }
        return selectAvailableCue(ordinal: ordinal)
    }

    @discardableResult
    func commitVirtualReelSelection(
        _ commit: PlaybackVirtualReelSelectionCommit
    ) -> Bool {
        let commitsPendingKeyboardIntent =
            pendingKeyboardNavigationTargetOrdinal == commit.ordinal
        guard isSessionActive,
              selectedModule == .playlist,
              let playlistWindow,
              activeKeyboardAction == nil,
              (pendingKeyboardAction == nil
                  || isCueReelMotionActive
                  || isScrollbarDragging
                  || commitsPendingKeyboardIntent),
              pendingKeyboardNavigationTargetOrdinal == nil
                  || commitsPendingKeyboardIntent,
              playlistWindow.commitSelection(commit)
        else {
            return false
        }

        if commitsPendingKeyboardIntent {
            cancelKeyboardNavigationIntent()
        }
        return true
    }

    func noteScrollbarDragging(_ isDragging: Bool) {
        guard isSessionActive else {
            return
        }
        isScrollbarDragging = isDragging
    }

    func noteCueReelMotion(_ isActive: Bool) {
        guard isSessionActive else {
            return
        }
        isCueReelMotionActive = isActive
    }

    func allowsNativeWheelInput() -> Bool {
        isSessionActive
            && pendingKeyboardAction == nil
            && activeKeyboardAction == nil
            && pendingKeyboardNavigationTargetOrdinal == nil
            && !isScrollbarDragging
    }

    func allowsNativeScrollbarInput() -> Bool {
        isSessionActive
            && hasSelectedReelItem
            && pendingKeyboardAction == nil
            && activeKeyboardAction == nil
            && pendingKeyboardNavigationTargetOrdinal == nil
            && !isScrollbarDragging
            && !isCueReelMotionActive
    }

    func requestKeyboardAction(
        _ action: PlaybackSubtitleFocusAction
    ) -> PlaybackSubtitleFocusKeyboardActionRequestResult {
        guard isSessionActive,
              selectedModule == .current || selectedModule == .playlist,
              pendingKeyboardAction == nil,
              activeKeyboardAction == nil
        else {
            return .rejected
        }

        if pendingKeyboardNavigationTargetOrdinal != nil
            || isCueReelMotionActive
            || isScrollbarDragging {
            pendingKeyboardAction = action
            return .deferred
        }

        guard let execution = beginKeyboardAction(action) else {
            return .rejected
        }
        return .ready(execution)
    }

    func consumeDeferredKeyboardActionIfReady()
        -> PlaybackSubtitleFocusActionExecution? {
        guard isSessionActive,
              let action = pendingKeyboardAction,
              activeKeyboardAction == nil,
              pendingKeyboardNavigationTargetOrdinal == nil,
              !isCueReelMotionActive,
              !isScrollbarDragging,
              selectedActionTarget() != nil
        else {
            return nil
        }

        pendingKeyboardAction = nil
        return beginKeyboardAction(action)
    }

    @discardableResult
    func finishKeyboardAction(
        _ execution: PlaybackSubtitleFocusActionExecution
    ) -> Bool {
        guard isSessionActive,
              activeKeyboardAction == execution
        else {
            return false
        }
        activeKeyboardAction = nil
        return true
    }

    @discardableResult
    func closeAfterPlay(
        _ execution: PlaybackSubtitleFocusActionExecution
    ) -> Bool {
        guard isSessionActive,
              execution.action == .playFromThisCue,
              activeKeyboardAction == execution
        else {
            return false
        }
        _ = closeSession()
        return true
    }

    @discardableResult
    func failOpening(
        token requestToken: PlaybackSubtitleFocusSessionToken
    ) -> Bool? {
        guard accepts(requestToken), state == .opening else {
            return nil
        }
        return closeSession()
    }

    @discardableResult
    func dismissByUser() -> Bool? {
        guard isSessionActive else {
            return nil
        }
        return closeSession()
    }

    func invalidateForSourceReplacement() {
        guard isSessionActive else {
            return
        }
        _ = closeSession()
    }

    private func accepts(_ requestToken: PlaybackSubtitleFocusSessionToken) -> Bool {
        isSessionActive && requestToken == token
    }

    private func beginKeyboardAction(
        _ action: PlaybackSubtitleFocusAction
    ) -> PlaybackSubtitleFocusActionExecution? {
        guard isSessionActive,
              pendingKeyboardAction == nil,
              activeKeyboardAction == nil,
              let target = selectedActionTarget()
        else {
            return nil
        }

        keyboardActionGeneration += 1
        let execution: PlaybackSubtitleFocusActionExecution
        switch target {
        case .current(let context):
            execution = PlaybackSubtitleFocusActionExecution(
                action: action,
                context: context,
                generation: keyboardActionGeneration
            )
        case .playlist(let item):
            execution = PlaybackSubtitleFocusActionExecution(
                action: action,
                playlistItem: item,
                generation: keyboardActionGeneration
            )
        }
        activeKeyboardAction = execution
        return execution
    }

    private var hasSelectedReelItem: Bool {
        guard let selectedModule else {
            return false
        }
        switch selectedModule {
        case .current:
            return currentSnapshot?.selectedCue != nil
        case .playlist:
            return playlistWindow?.selectedOrdinal.flatMap {
                playlistWindow?.item(at: $0)
            } != nil
        default:
            return false
        }
    }

    private func selectedActionTarget() -> PlaybackSubtitleFocusActionTarget? {
        guard let selectedModule else {
            return nil
        }
        switch selectedModule {
        case .current:
            guard let cue = currentSnapshot?.selectedCue else {
                return nil
            }
            return .current(PlaybackSubtitleFocusActionContext(
                source: openSnapshot.source,
                cue: cue
            ))
        case .playlist:
            guard let playlistWindow,
                  let selectedOrdinal = playlistWindow.selectedOrdinal,
                  let item = playlistWindow.item(at: selectedOrdinal)
            else {
                return nil
            }
            return .playlist(item)
        default:
            return nil
        }
    }

    private func selectAvailableCue(ordinal: Int) -> Bool {
        guard let snapshot = currentSnapshot,
              ordinal >= 0,
              ordinal < snapshot.totalCount,
              cue(at: ordinal) != nil
        else {
            return false
        }

        let cues: [SubtitleFocusCue]
        if let completeCueBatch {
            let range = SubtitleFocusWindowPolicy.standard.windowRange(
                totalCount: snapshot.totalCount,
                selectedOrdinal: ordinal
            )
            cues = Array(completeCueBatch.cues[range])
        } else {
            cues = snapshot.cues
        }
        state = .cueSelection(SubtitleFocusSnapshot(
            totalCount: snapshot.totalCount,
            selectedOrdinal: ordinal,
            cues: cues
        ))
        return true
    }

    private func cancelKeyboardNavigationIntent() {
        pendingKeyboardNavigationTargetOrdinal = nil
        pendingKeyboardNavigationTargetIdentity = nil
        keyboardNavigationRequest = nil
    }

    private func observePlaylistSnapshot(
        _ snapshot: PlaybackVirtualReelSnapshot
    ) {
        guard isSessionActive else {
            return
        }
        let changesDataset = observedPlaylistDatasetID != snapshot.datasetID
            || observedPlaylistGeneration != snapshot.generation
        let clearsSameDatasetWindow = !changesDataset
            && observedPlaylistRevision != snapshot.revision
            && snapshot.loadedItemCount == 0
        observedPlaylistDatasetID = snapshot.datasetID
        observedPlaylistGeneration = snapshot.generation
        observedPlaylistRevision = snapshot.revision
        guard selectedModule == .playlist,
              changesDataset || clearsSameDatasetWindow
        else {
            return
        }
        if snapshot.totalCount == 0 {
            isScrollbarDragging = false
            isCueReelMotionActive = false
        }
        guard let targetOrdinal = pendingKeyboardNavigationTargetOrdinal else {
            if snapshot.totalCount == 0 {
                pendingKeyboardAction = nil
            }
            return
        }
        let targetRemainsValid = snapshot.totalCount > targetOrdinal
            && pendingKeyboardNavigationTargetIdentity.map { identity in
                playlistWindow?.knownItemIdentity(at: targetOrdinal).map {
                    $0 == identity
                } ?? true
            } ?? true
        guard targetRemainsValid,
              let reelDatasetID = playlistWindow?.reelDatasetID,
              let direction = keyboardNavigationRequest?.direction
        else {
            pendingKeyboardAction = nil
            cancelKeyboardNavigationIntent()
            return
        }

        keyboardNavigationSequence += 1
        keyboardNavigationRequest = PlaybackSubtitleFocusKeyboardNavigationRequest(
            sequence: keyboardNavigationSequence,
            direction: direction,
            targetOrdinal: targetOrdinal,
            contentDatasetID: reelDatasetID,
            contentGeneration: snapshot.generation
        )
    }

    private func prepareReelForModuleTransition() {
        pendingKeyboardAction = nil
        isScrollbarDragging = false
        isCueReelMotionActive = false
        cancelKeyboardNavigationIntent()
    }

    private func closeSession() -> Bool {
        let wasPlaying = openSnapshot.wasPlaying
        isSessionActive = false
        pendingKeyboardAction = nil
        activeKeyboardAction = nil
        isScrollbarDragging = false
        isCueReelMotionActive = false
        completeCueBatch = nil
        playlistWindowSnapshotCancellable?.cancel()
        playlistWindowSnapshotCancellable = nil
        observedPlaylistDatasetID = nil
        observedPlaylistGeneration = nil
        observedPlaylistRevision = nil
        playlistWindow?.invalidate()
        playlistWindow = nil
        cancelKeyboardNavigationIntent()
        selectedModule = nil
        availableModules = []
        state = .closed
        return wasPlaying
    }
}
