import Combine
import CueSeekerCore
import Foundation

struct PlaybackSubtitleFocusOpenSnapshot: Equatable, Sendable {
    let source: SubtitleFocusSourceIdentity
    let timestampMilliseconds: Int
    let wasPlaying: Bool
    let videoPresentation: CompleteLibraryVideoPresentation?

    init(
        source: SubtitleFocusSourceIdentity,
        timestampMilliseconds: Int,
        wasPlaying: Bool,
        videoPresentation: CompleteLibraryVideoPresentation? = nil
    ) {
        self.source = source
        self.timestampMilliseconds = max(0, timestampMilliseconds)
        self.wasPlaying = wasPlaying
        self.videoPresentation = videoPresentation
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
    case library
    case shiori

    static let standardModules: [Self] = [
        .current,
    ]

    static func modules(hasPlaylist: Bool) -> [Self] {
        hasPlaylist ? [.current, .playlist] : standardModules
    }

    var label: String {
        switch self {
        case .current:
            "Current"
        case .playlist:
            "Playlist"
        case .search:
            "Search"
        case .library:
            "Library"
        case .shiori:
            "Shiori"
        }
    }

    var systemImage: String {
        switch self {
        case .current:
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

    var usesSharedCueShortcuts: Bool {
        switch self {
        case .current, .playlist, .shiori:
            true
        case .search, .library:
            false
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

private struct PlaybackCueResultObservedSnapshot {
    var datasetID: AnyHashable
    var generation: UInt64
    var revision: UInt64
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
    @Published private(set) var isEditingCollage = false
    @Published private(set) var playlistWindow: PlaybackPlaylistSessionWindowStore?
    @Published private(set) var searchStore: SearchStore?
    @Published private(set) var searchWindow: PlaybackCueResultSessionWindowStore?
    @Published private(set) var libraryStore: PlaybackLibrarySessionStore?
    @Published private(set) var shioriStore: ShioriStore?
    @Published private(set) var shioriWindow: PlaybackCueResultSessionWindowStore?

    private var keyboardActionGeneration = 0
    private var isSessionActive = true
    private var isScrollbarDragging = false
    private var isCueReelMotionActive = false
    private var keyboardNavigationSequence = 0
    private var pendingKeyboardNavigationTargetOrdinal: Int?
    private var pendingKeyboardNavigationTargetIdentity: PlaybackCueResultItemIdentity?
    private var shioriPresentationSource: PlaybackCueResultSource?
    private var shioriResultsCancellable: AnyCancellable?
    private var searchSource: PlaybackCueResultSource?
    private var searchResultsCancellable: AnyCancellable?
    private var cueResultWindowSnapshotCancellables: [
        PlaybackOverlayModule: AnyCancellable
    ] = [:]
    private var observedCueResultSnapshots: [
        PlaybackOverlayModule: PlaybackCueResultObservedSnapshot
    ] = [:]

    init(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot,
        sessionGeneration: Int,
        availableModules: [PlaybackOverlayModule] = PlaybackOverlayModule.standardModules,
        playlistSource: PlaybackPlaylistSource? = nil,
        playlistPosition: PlaybackPlaylistPosition? = nil,
        searchStore: SearchStore? = nil,
        libraryStore: PlaybackLibrarySessionStore? = nil,
        shioriStore: ShioriStore? = nil
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
        let playlistWindow = playlistSource?.makeSessionWindowStore(
            initialPosition: playlistPosition
        )
        self.playlistWindow = playlistWindow
        self.searchStore = searchStore
        self.libraryStore = libraryStore
        self.shioriStore = shioriStore
        token = PlaybackSubtitleFocusSessionToken(
            source: openSnapshot.source,
            sessionGeneration: sessionGeneration
        )
        if let playlistWindow {
            observeCueResultWindow(playlistWindow, module: .playlist)
        }
        if let searchStore {
            let searchSource = PlaybackCueResultSource(
                origin: .search(
                    resultListGeneration: 0,
                    usesFacetProjection: false
                ),
                totalCount: searchStore.searchResults.count
            ) { [weak searchStore] ordinal in
                guard let searchStore else {
                    return nil
                }
                let results = searchStore.searchResults
                guard results.indices.contains(ordinal)
                else {
                    return nil
                }
                return PlaybackCueResultItem(
                    searchResult: results[ordinal],
                    ordinal: ordinal
                )
            }
            self.searchSource = searchSource
            let searchWindow = searchSource.makeSessionWindowStore(
                includingEmpty: true
            )
            self.searchWindow = searchWindow
            if let searchWindow {
                observeCueResultWindow(searchWindow, module: .search)
            }
            searchResultsCancellable = searchStore.$resultRevision
                .dropFirst()
                .sink { [weak self, weak searchStore, weak searchSource] _ in
                    Task { @MainActor [weak self, weak searchStore, weak searchSource] in
                        guard let self, let searchStore, let searchSource else {
                            return
                        }
                        _ = searchSource.updateBoundary(
                            totalCount: searchStore.searchResults.count
                        )
                        if searchSource.boundary.totalCount > 0,
                           self.searchWindow?.selectedOrdinal == nil {
                            self.searchWindow?.resetSelectionToFirst()
                        }
                    }
                }
        }
        if let shioriStore {
            let shioriPresentationSource = PlaybackCueResultSource(
                origin: .unspecified(.shiori),
                totalCount: shioriStore.tableRowStore.snapshot.totalRowCount
            ) { [weak shioriStore] ordinal in
                guard let shioriStore else {
                    return nil
                }
                let snapshot = shioriStore.tableRowStore.snapshot
                guard let row = snapshot.row(at: ordinal),
                      let shiori = snapshot.shiori(entryID: row.id)
                else {
                    return nil
                }
                return PlaybackCueResultItem(
                    shiori: shiori,
                    cuePresentation: snapshot.shioriCuePresentation(
                        entryID: row.id
                    ),
                    ordinal: ordinal
                )
            }
            self.shioriPresentationSource = shioriPresentationSource
            let shioriWindow = shioriPresentationSource.makeSessionWindowStore(
                includingEmpty: true
            )
            self.shioriWindow = shioriWindow
            if let shioriWindow {
                observeCueResultWindow(shioriWindow, module: .shiori)
            }
            shioriResultsCancellable = shioriStore.tableRowStore.$snapshot
                .dropFirst()
                .sink { [weak self, weak shioriStore, weak shioriPresentationSource] _ in
                    Task { @MainActor [weak self, weak shioriStore, weak shioriPresentationSource] in
                        guard let self, let shioriStore, let shioriPresentationSource else {
                            return
                        }
                        _ = shioriPresentationSource.updateBoundary(
                            totalCount: shioriStore.tableRowStore.snapshot.totalRowCount
                        )
                        if shioriPresentationSource.boundary.totalCount > 0,
                           self.shioriWindow?.selectedOrdinal == nil {
                            self.shioriWindow?.resetSelectionToFirst()
                        }
                    }
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
              !isEditingCollage,
              case .cueSelection = state,
              availableModules.contains(module),
              selectedModule != module
        else {
            return false
        }

        prepareReelForModuleTransition()
        selectedModule = module
        if module == .library {
            libraryStore?.activate(refreshesExistingSnapshot: true)
        } else if module == .playlist {
            libraryStore?.activate(refreshesExistingSnapshot: true)
        }
        return true
    }

    @discardableResult
    func presentModule(_ module: PlaybackOverlayModule) -> Bool {
        guard isSessionActive,
              !isEditingCollage,
              availableModules.contains(module)
        else {
            return false
        }
        guard selectedModule != module else {
            return true
        }

        if case .opening = state {
            selectedModule = module
            return true
        }
        return selectModule(module)
    }

    @discardableResult
    func requestMediaSelectionNavigation(
        _ direction: PlaybackMediaSelectionDirection
    ) -> Bool {
        guard isSessionActive else {
            return false
        }
        switch selectedModule {
        case .library:
            return libraryStore?.moveSelection(direction) == true
        case .playlist:
            return libraryStore?.moveSelection(direction) == true
        default:
            return false
        }
    }

    func selectedLibraryPrimaryActionVideo()
        -> CompleteLibraryVideoPresentation? {
        guard isSessionActive,
              (
                  selectedModule == .library
                      || selectedModule == .playlist && libraryStore != nil
              )
        else {
            return nil
        }
        return libraryStore?.primaryActionVideo()
    }

    @discardableResult
    func selectNextModule() -> Bool {
        guard isSessionActive,
              !isEditingCollage,
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

    @discardableResult
    func toggleEditingCollage() -> Bool {
        guard isSessionActive,
              case .cueSelection = state
        else {
            return false
        }

        if isEditingCollage {
            isEditingCollage = false
            return true
        }

        guard selectedModule == .current else {
            return false
        }
        prepareReelForModuleTransition()
        isEditingCollage = true
        return true
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
        var targetIdentity: PlaybackCueResultItemIdentity?
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
        case .playlist, .search, .shiori:
            guard let window = cueResultWindow(for: selectedModule),
                  let selectedOrdinal = window.selectedOrdinal,
                  let reelDatasetID = window.reelDatasetID
            else {
                return false
            }
            currentTarget = pendingKeyboardNavigationTargetOrdinal
                ?? selectedOrdinal
            totalCount = window.snapshot.totalCount
            contentDatasetID = reelDatasetID
            contentGeneration = window.snapshot.generation
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
        if let window = cueResultWindow(for: selectedModule) {
            targetIdentity = window.item(at: targetOrdinal)?.identity
                ?? window.knownItemIdentity(at: targetOrdinal)
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
        guard let selectedModule else {
            return false
        }
        return commitVirtualReelSelection(commit, module: selectedModule)
    }

    @discardableResult
    func commitVirtualReelSelection(
        _ commit: PlaybackVirtualReelSelectionCommit,
        module: PlaybackOverlayModule
    ) -> Bool {
        let commitsPendingKeyboardIntent =
            pendingKeyboardNavigationTargetOrdinal == commit.ordinal
        guard isSessionActive,
              selectedModule == module,
              let window = cueResultWindow(for: module),
              activeKeyboardAction == nil,
              (pendingKeyboardAction == nil
                  || isCueReelMotionActive
                  || isScrollbarDragging
                  || commitsPendingKeyboardIntent),
              pendingKeyboardNavigationTargetOrdinal == nil
                  || commitsPendingKeyboardIntent,
              window.commitSelection(commit)
        else {
            return false
        }

        if commitsPendingKeyboardIntent {
            cancelKeyboardNavigationIntent()
        }
        return true
    }

    func noteScrollbarDragging(
        _ isDragging: Bool,
        module: PlaybackOverlayModule? = nil
    ) {
        guard isSessionActive,
              module == nil || selectedModule == module
        else {
            return
        }
        isScrollbarDragging = isDragging
    }

    func noteCueReelMotion(
        _ isActive: Bool,
        module: PlaybackOverlayModule? = nil
    ) {
        guard isSessionActive,
              module == nil || selectedModule == module
        else {
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
              selectedModule?.usesSharedCueShortcuts == true,
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

    func requestSettledSearchPlayAction()
        -> PlaybackSubtitleFocusKeyboardActionRequestResult {
        guard isSessionActive,
              selectedModule == .search,
              pendingKeyboardAction == nil,
              activeKeyboardAction == nil,
              pendingKeyboardNavigationTargetOrdinal == nil,
              keyboardNavigationRequest == nil,
              !isCueReelMotionActive,
              !isScrollbarDragging,
              selectedActionTarget() != nil,
              let execution = beginKeyboardAction(.playFromThisCue)
        else {
            return .rejected
        }
        return .ready(execution)
    }

    func consumeDeferredKeyboardActionIfReady(
        module: PlaybackOverlayModule? = nil
    ) -> PlaybackSubtitleFocusActionExecution? {
        guard isSessionActive,
              module == nil || selectedModule == module,
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
        case .search(let item):
            execution = PlaybackSubtitleFocusActionExecution(
                searchItem: item,
                generation: keyboardActionGeneration
            )
        case .shiori(let item):
            execution = PlaybackSubtitleFocusActionExecution(
                action: action,
                shioriItem: item,
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
        case .playlist, .search, .shiori:
            let window = cueResultWindow(for: selectedModule)
            return window?.selectedOrdinal.flatMap {
                window?.item(at: $0)
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
        case .search:
            guard let searchWindow,
                  let selectedOrdinal = searchWindow.selectedOrdinal,
                  let item = searchWindow.item(at: selectedOrdinal)
            else {
                return nil
            }
            return .search(item)
        case .shiori:
            guard let shioriWindow,
                  let selectedOrdinal = shioriWindow.selectedOrdinal,
                  let item = shioriWindow.item(at: selectedOrdinal)
            else {
                return nil
            }
            return .shiori(item)
        default:
            return nil
        }
    }

    func cueResultWindow(
        for module: PlaybackOverlayModule
    ) -> PlaybackCueResultSessionWindowStore? {
        switch module {
        case .playlist:
            playlistWindow
        case .search:
            searchWindow
        case .shiori:
            shioriWindow
        default:
            nil
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

    private func observeCueResultWindow(
        _ window: PlaybackCueResultSessionWindowStore,
        module: PlaybackOverlayModule
    ) {
        observedCueResultSnapshots[module] = PlaybackCueResultObservedSnapshot(
            datasetID: window.snapshot.datasetID,
            generation: window.snapshot.generation,
            revision: window.snapshot.revision
        )
        cueResultWindowSnapshotCancellables[module] = window.$snapshot
            .dropFirst()
            .sink { [weak self] snapshot in
                self?.observeCueResultSnapshot(snapshot, module: module)
            }
    }

    private func observeCueResultSnapshot(
        _ snapshot: PlaybackVirtualReelSnapshot,
        module: PlaybackOverlayModule
    ) {
        guard isSessionActive else {
            return
        }
        let observed = observedCueResultSnapshots[module]
        let changesDataset = observed?.datasetID != snapshot.datasetID
            || observed?.generation != snapshot.generation
        let clearsSameDatasetWindow = !changesDataset
            && observed?.revision != snapshot.revision
            && snapshot.loadedItemCount == 0
        observedCueResultSnapshots[module] = PlaybackCueResultObservedSnapshot(
            datasetID: snapshot.datasetID,
            generation: snapshot.generation,
            revision: snapshot.revision
        )
        guard selectedModule == module,
              changesDataset || clearsSameDatasetWindow
        else {
            return
        }
        if module == .search {
            prepareReelForModuleTransition()
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
                cueResultWindow(for: module)?
                    .knownItemIdentity(at: targetOrdinal).map {
                    $0 == identity
                } ?? true
            } ?? true
        guard targetRemainsValid,
              let reelDatasetID = cueResultWindow(for: module)?.reelDatasetID,
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
        isEditingCollage = false
        pendingKeyboardAction = nil
        activeKeyboardAction = nil
        isScrollbarDragging = false
        isCueReelMotionActive = false
        completeCueBatch = nil
        for cancellable in cueResultWindowSnapshotCancellables.values {
            cancellable.cancel()
        }
        cueResultWindowSnapshotCancellables.removeAll(keepingCapacity: false)
        observedCueResultSnapshots.removeAll(keepingCapacity: false)
        searchResultsCancellable?.cancel()
        searchResultsCancellable = nil
        playlistWindow?.invalidate()
        playlistWindow = nil
        searchWindow?.invalidate()
        searchWindow = nil
        searchSource?.invalidate()
        searchSource = nil
        searchStore = nil
        libraryStore?.invalidate()
        libraryStore = nil
        shioriResultsCancellable?.cancel()
        shioriResultsCancellable = nil
        shioriWindow?.invalidate()
        shioriWindow = nil
        shioriPresentationSource?.invalidate()
        shioriPresentationSource = nil
        shioriStore = nil
        cancelKeyboardNavigationIntent()
        selectedModule = nil
        availableModules = []
        state = .closed
        return wasPlaying
    }
}
