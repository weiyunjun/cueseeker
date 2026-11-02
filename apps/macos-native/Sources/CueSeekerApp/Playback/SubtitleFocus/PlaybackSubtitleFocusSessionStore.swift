import Combine
import CueSeekerCore
import CueSeekerPlayback
import Foundation

struct PlaybackSubtitleFocusOpenSnapshot: Equatable, Sendable {
    let source: SubtitleFocusSourceIdentity
    let timestampMilliseconds: Int
    let wasPlaying: Bool
    let videoPresentation: CompleteLibraryVideoPresentation?
    let subtitleRenderSource: PlaybackSubtitleSource?

    init(
        source: SubtitleFocusSourceIdentity,
        timestampMilliseconds: Int,
        wasPlaying: Bool,
        videoPresentation: CompleteLibraryVideoPresentation? = nil,
        subtitleRenderSource: PlaybackSubtitleSource? = nil
    ) {
        self.source = source
        self.timestampMilliseconds = max(0, timestampMilliseconds)
        self.wasPlaying = wasPlaying
        self.videoPresentation = videoPresentation
        self.subtitleRenderSource = subtitleRenderSource
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
    /// The subtitle it opened on is no longer in the library: Current has
    /// nothing to show but says so, and Playlist opens as usual.
    case subtitleLeftLibrary
}

enum PlaybackOverlayModule: String, CaseIterable, Equatable, Sendable {
    case current
    case playlist
    case collage

    static let standardModules: [Self] = [
        .current,
        .collage,
    ]

    static func modules(hasPlaylist: Bool) -> [Self] {
        hasPlaylist ? [.current, .playlist, .collage] : standardModules
    }

    var label: String {
        switch self {
        case .current:
            L("playback.source.current")
        case .playlist:
            L("playback.source.playlist")
        case .collage:
            L("playback.source.collage")
        }
    }

    var usesSharedCueShortcuts: Bool {
        self != .collage
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
    @Published private(set) var selectedModule: PlaybackOverlayModule? = .current {
        didSet {
            if selectedModule != oldValue {
                AppPointerShape.reevaluateAfterInterfaceChange()
            }
        }
    }
    var isEditingCollage: Bool {
        selectedModule == .collage
    }
    private var _collageSnapshot: SubtitleFocusSnapshot?
    var collageSnapshot: SubtitleFocusSnapshot? {
        _collageSnapshot
    }
    private var _collageSelectionPlan = SubtitleCollageSelectionPlan()
    var collageSelectionPlan: SubtitleCollageSelectionPlan {
        _collageSelectionPlan
    }
    private var _collagePreviewStore: PlaybackCollagePreviewStore?
    var collagePreviewStore: PlaybackCollagePreviewStore? {
        _collagePreviewStore
    }
    /// A new style renders the collage preview again from scratch; ASS keeps
    /// its own styles and is left alone.
    var srtSubtitleStyle = SRTSubtitleStyle() {
        didSet {
            guard srtSubtitleStyle != oldValue,
                  let oldPreviewStore = _collagePreviewStore,
                  collageSubtitleSource.format == .srt
            else {
                return
            }
            let previewStore = makeCollagePreviewStore()
            previewStore.update(plan: _collageSelectionPlan)
            oldPreviewStore.invalidate()
            objectWillChange.send()
            _collagePreviewStore = previewStore
        }
    }
    @Published private(set) var playlistWindow: PlaybackPlaylistSessionWindowStore?
    @Published private(set) var libraryStore: PlaybackLibrarySessionStore?

    private var keyboardActionGeneration = 0
    private var isSessionActive = true
    private var isScrollbarDragging = false
    private var isCueReelMotionActive = false
    /// True while the Command Panel is stacked on top of this overlay. The reel
    /// claims wheel events and its menu's presses with window-wide monitors and
    /// only knows its own rectangle, so it cannot see what covers it; the
    /// layer registry answers.
    private let interfaceLayers: InterfaceLayerRegistry
    private var keyboardNavigationSequence = 0
    private var pendingKeyboardNavigationTargetOrdinal: Int?
    private var pendingKeyboardNavigationTargetIdentity: PlaybackCueResultItemIdentity?
    private var cueResultWindowSnapshotCancellables: [
        PlaybackOverlayModule: AnyCancellable
    ] = [:]
    private var observedCueResultSnapshots: [
        PlaybackOverlayModule: PlaybackCueResultObservedSnapshot
    ] = [:]

    @MainActor
    init(
        openSnapshot: PlaybackSubtitleFocusOpenSnapshot,
        sessionGeneration: Int,
        availableModules: [PlaybackOverlayModule] = PlaybackOverlayModule.standardModules,
        playlistSource: PlaybackPlaylistSource? = nil,
        playlistPosition: PlaybackPlaylistPosition? = nil,
        libraryStore: PlaybackLibrarySessionStore? = nil,
        interfaceLayers: InterfaceLayerRegistry? = nil
    ) {
        self.interfaceLayers = interfaceLayers ?? InterfaceLayerRegistry()
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
        self.libraryStore = libraryStore
        token = PlaybackSubtitleFocusSessionToken(
            source: openSnapshot.source,
            sessionGeneration: sessionGeneration
        )
        if let playlistWindow {
            observeCueResultWindow(playlistWindow, module: .playlist)
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

    var focusedCueTextForCommandPanel: String? {
        switch selectedModule {
        case .current:
            return currentSnapshot?.selectedCue?.text
        case .playlist:
            guard let playlistWindow,
                  let selectedOrdinal = playlistWindow.selectedOrdinal
            else {
                return nil
            }
            return playlistWindow.item(at: selectedOrdinal)?.primaryCueText
        case .collage, .none:
            return nil
        }
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
        let startedAt = DebugInteractionLatencyProbe.now()
        guard isSessionActive,
              currentSnapshot != nil || state == .subtitleLeftLibrary,
              availableModules.contains(module),
              selectedModule != module
        else {
            return false
        }

        let fromLabel: String = {
            switch selectedModule {
            case .current:
                return "playback_overlay_current"
            case .playlist:
                return libraryStore != nil ? "playback_overlay_library" : "playback_overlay_playlist"
            case .collage:
                return "playback_overlay_collage"
            case .none:
                return "none"
            }
        }()
        let toLabel: String = {
            switch module {
            case .current:
                return "playback_overlay_current"
            case .playlist:
                return libraryStore != nil ? "playback_overlay_library" : "playback_overlay_playlist"
            case .collage:
                return "playback_overlay_collage"
            }
        }()
        DebugInteractionLatencyProbe.beginNavigation(
            domain: "playback_overlay",
            from: fromLabel,
            to: toLabel,
            trigger: "overlay_tab_select",
            startedAt: startedAt
        )

        prepareReelForModuleTransition()
        if module == .collage, currentSnapshot != nil, _collagePreviewStore == nil {
            let previewStore = makeCollagePreviewStore()
            previewStore.update(plan: _collageSelectionPlan)
            _collagePreviewStore = previewStore
        }
        selectedModule = module
        if module == .playlist {
            libraryStore?.activate()
        }
        AppLogger.shared.info(
            .playback,
            "Playback overlay module selected",
            fields: [("module", "\(module)")]
        )
        DebugInteractionLatencyProbe.markNavigationSyncPrepFinished(domain: "playback_overlay")
        return true
    }

    @discardableResult
    func presentModule(_ module: PlaybackOverlayModule) -> Bool {
        guard isSessionActive,
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
        case .playlist:
            return libraryStore?.moveSelection(direction) == true
        case .current, .collage, .none:
            return false
        }
    }

    func selectedLibraryPrimaryActionVideo()
        -> CompleteLibraryVideoPresentation? {
        guard isSessionActive,
              selectedModule == .playlist && libraryStore != nil
        else {
            return nil
        }
        return libraryStore?.primaryActionVideo()
    }

    @discardableResult
    func selectNextModule() -> Bool {
        selectAdjacentModule(offset: 1)
    }

    @discardableResult
    func selectPreviousModule() -> Bool {
        selectAdjacentModule(offset: -1)
    }

    private func selectAdjacentModule(offset: Int) -> Bool {
        guard isSessionActive,
              let selectedModule,
              let currentIndex = availableModules.firstIndex(of: selectedModule),
              !availableModules.isEmpty
        else {
            return false
        }

        let nextIndex = (
            currentIndex + offset + availableModules.count
        ) % availableModules.count
        return selectModule(availableModules[nextIndex])
    }

    @discardableResult
    func ensureCollagePreviewStoreIfNeeded() -> PlaybackCollagePreviewStore? {
        guard isSessionActive,
              currentSnapshot != nil
        else {
            return nil
        }
        if let existing = _collagePreviewStore {
            return existing
        }
        let previewStore = makeCollagePreviewStore()
        previewStore.update(plan: _collageSelectionPlan)
        objectWillChange.send()
        _collagePreviewStore = previewStore
        return previewStore
    }

    @discardableResult
    func toggleCollageCueSelection(
        at ordinal: Int
    ) -> SubtitleCollageSelectionMutation {
        guard isSessionActive,
              selectedModule == .collage,
              let cue = cue(at: ordinal)
        else {
            return .unchanged
        }

        var selectionPlan = _collageSelectionPlan
        let mutation = selectionPlan.contains(cueID: cue.id)
            ? selectionPlan.deselect(cueID: cue.id)
            : selectionPlan.select(cue)
        if case .changed = mutation {
            let previewStore = ensureCollagePreviewStoreIfNeeded()
            objectWillChange.send()
            _collageSelectionPlan = selectionPlan
            previewStore?.update(plan: selectionPlan)
        }
        return mutation
    }

    // Collage Copy and Export actions route all readiness and completion states
    // through playback feedback rather than disabling footer actions.
    var presentCollageFeedback: ((PlaybackCollageFeedbackEvent) -> Void)?

    @discardableResult
    func copyCurrentCollage() -> Bool {
        guard isSessionActive,
              selectedModule == .collage,
              let collagePreviewStore = ensureCollagePreviewStoreIfNeeded()
        else {
            return false
        }
        guard _collageSelectionPlan.selectedCueCount > 0 else {
            presentCollageFeedback?(.noCueSelected)
            return true
        }
        switch collagePreviewStore.actionReadiness() {
        case .emptySelection:
            presentCollageFeedback?(.noCueSelected)
        case .notReady:
            presentCollageFeedback?(.notReady)
        case .failed:
            presentCollageFeedback?(.copyFailed)
        case .ready:
            _ = collagePreviewStore.copyCurrentResult { [weak self] succeeded in
                self?.presentCollageFeedback?(
                    succeeded ? .copySucceeded : .copyFailed
                )
            }
        }
        return true
    }

    @discardableResult
    func exportCurrentCollage() -> Bool {
        guard isSessionActive,
              selectedModule == .collage,
              let collagePreviewStore = ensureCollagePreviewStoreIfNeeded()
        else {
            return false
        }
        guard _collageSelectionPlan.selectedCueCount > 0 else {
            presentCollageFeedback?(.noCueSelected)
            return true
        }
        switch collagePreviewStore.actionReadiness() {
        case .emptySelection:
            presentCollageFeedback?(.noCueSelected)
        case .notReady:
            presentCollageFeedback?(.notReady)
        case .failed:
            presentCollageFeedback?(.exportFailed)
        case .ready:
            _ = collagePreviewStore.exportCurrentResult(
                displayTitle: collageDisplayTitle
            ) { [weak self] succeeded in
                self?.presentCollageFeedback?(
                    succeeded ? .exportSucceeded : .exportFailed
                )
            }
        }
        return true
    }

    @discardableResult
    func toggleFocusedCollageCueSelection() -> SubtitleCollageSelectionMutation {
        guard let snapshot = collageSnapshot else {
            return .unchanged
        }
        return toggleCollageCueSelection(
            at: pendingKeyboardNavigationTargetOrdinal
                ?? snapshot.selectedOrdinal
        )
    }

    func cue(at ordinal: Int) -> SubtitleFocusCue? {
        if let completeCueBatch,
           completeCueBatch.cues.indices.contains(ordinal) {
            let cue = completeCueBatch.cues[ordinal]
            return cue.ordinal == ordinal ? cue : nil
        }
        if let cue = currentSnapshot?.cues.first(where: { $0.ordinal == ordinal }) {
            return cue
        }
        return collageSnapshot?.cues.first { $0.ordinal == ordinal }
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
        _collageSnapshot = snapshot
        var initialPlan = SubtitleCollageSelectionPlan()
        if let selectedCue = snapshot.selectedCue {
            _ = initialPlan.select(selectedCue)
        }
        _collageSelectionPlan = initialPlan
        if selectedModule == .collage {
            let previewStore = makeCollagePreviewStore()
            previewStore.update(plan: initialPlan)
            _collagePreviewStore = previewStore
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
        requestNavigation { current in
            direction == .backward ? current - 1 : current + 1
        }
    }

    /// A click on a Collage strip: the reel travels to that group's first cue
    /// the way a key would, under the same gate, and the selection plan is
    /// untouched. A strip whose cue is already the target asks for nothing.
    @discardableResult
    func jumpToCollageCue(ordinal: Int) -> Bool {
        guard selectedModule == .collage else {
            return false
        }
        return requestNavigation { _ in ordinal }
    }

    private func requestNavigation(
        to target: (_ current: Int) -> Int
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
        case .collage:
            guard let snapshot = collageSnapshot else {
                return false
            }
            currentTarget = pendingKeyboardNavigationTargetOrdinal
                ?? snapshot.selectedOrdinal
            totalCount = snapshot.totalCount
            contentDatasetID = nil
            contentGeneration = nil
            targetIdentity = nil
        case .playlist:
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
        }

        let targetOrdinal = target(currentTarget)
        guard targetOrdinal != currentTarget,
              targetOrdinal >= 0,
              targetOrdinal < totalCount,
              (selectedModule != .current && selectedModule != .collage)
                  || cue(at: targetOrdinal) != nil
        else {
            return false
        }
        let direction: SubtitleFocusNavigationDirection = targetOrdinal
            < currentTarget ? .backward : .forward
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
              let selectedModule,
              (selectedModule == .current || selectedModule == .collage),
              keyboardNavigationRequest == request,
              pendingKeyboardNavigationTargetOrdinal == request.targetOrdinal,
              activeKeyboardAction == nil,
              selectAvailableCue(ordinal: request.targetOrdinal, module: selectedModule)
        else {
            return false
        }
        pendingKeyboardNavigationTargetOrdinal = nil
        keyboardNavigationRequest = nil
        return true
    }

    @discardableResult
    func commitNativeReelSelection(ordinal: Int) -> Bool {
        guard let selectedModule else {
            return false
        }
        return commitNativeReelSelection(ordinal: ordinal, module: selectedModule)
    }

    @discardableResult
    func commitNativeReelSelection(
        ordinal: Int,
        module: PlaybackOverlayModule
    ) -> Bool {
        guard isSessionActive,
              selectedModule == module,
              (module == .current || module == .collage),
              activeKeyboardAction == nil,
              (pendingKeyboardAction == nil
                  || isCueReelMotionActive
                  || isScrollbarDragging),
              pendingKeyboardNavigationTargetOrdinal == nil
        else {
            return false
        }
        let activeSnapshot = module == .collage ? collageSnapshot : currentSnapshot
        if activeSnapshot?.selectedOrdinal == ordinal {
            return true
        }
        return selectAvailableCue(ordinal: ordinal, module: module)
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
            && !interfaceLayers.isCovered(.playbackOverlay)
            && pendingKeyboardAction == nil
            && activeKeyboardAction == nil
            && pendingKeyboardNavigationTargetOrdinal == nil
            && !isScrollbarDragging
    }

    func allowsNativeScrollbarInput() -> Bool {
        isSessionActive
            && !interfaceLayers.isCovered(.playbackOverlay)
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

    func showSubtitleLeftLibrary() {
        guard isSessionActive, state == .opening else {
            return
        }
        state = .subtitleLeftLibrary
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
        case .collage:
            return collageSnapshot?.selectedCue != nil
        case .playlist:
            let window = cueResultWindow(for: selectedModule)
            return window?.selectedOrdinal.flatMap {
                window?.item(at: $0)
            } != nil
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
        case .collage:
            return nil
        }
    }

    func cueResultWindow(
        for module: PlaybackOverlayModule
    ) -> PlaybackCueResultSessionWindowStore? {
        switch module {
        case .playlist:
            playlistWindow
        case .current, .collage:
            nil
        }
    }

    private func selectAvailableCue(
        ordinal: Int,
        module: PlaybackOverlayModule = .current
    ) -> Bool {
        let sourceSnapshot = module == .collage ? collageSnapshot : currentSnapshot
        guard let snapshot = sourceSnapshot,
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
        let updatedSnapshot = SubtitleFocusSnapshot(
            totalCount: snapshot.totalCount,
            selectedOrdinal: ordinal,
            cues: cues
        )
        if module == .collage {
            objectWillChange.send()
            _collageSnapshot = updatedSnapshot
        } else {
            state = .cueSelection(updatedSnapshot)
        }
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
        clearCollageEditingState()
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
        playlistWindow?.invalidate()
        playlistWindow = nil
        libraryStore?.invalidate()
        libraryStore = nil
        cancelKeyboardNavigationIntent()
        selectedModule = nil
        availableModules = []
        state = .closed
        return wasPlaying
    }

    private var collageDisplayTitle: String {
        openSnapshot.videoPresentation?.displayTitle
            ?? URL.fromMediaPath(openSnapshot.source.videoPath)
                .deletingPathExtension()
                .lastPathComponent
    }

    private var collageSubtitleSource: PlaybackSubtitleSource {
        let source = openSnapshot.source
        return openSnapshot.subtitleRenderSource
            ?? PlaybackSubtitleSource(
                url: URL.fromMediaPath(source.subtitlePath),
                format: source.subtitleFormat.usesASSSemantics ? .ass : .srt,
                matchedVideoURL: URL.fromMediaPath(source.videoPath),
                initialTimestampMilliseconds:
                    openSnapshot.timestampMilliseconds
            )
    }

    var collagePreviewStoreFactory: (() -> PlaybackCollagePreviewStore)?

    private func makeCollagePreviewStore() -> PlaybackCollagePreviewStore {
        if let collagePreviewStoreFactory {
            return collagePreviewStoreFactory()
        }
        return PlaybackCollagePreviewStore(
            videoURL: URL.fromMediaPath(openSnapshot.source.videoPath),
            subtitleSource: collageSubtitleSource,
            srtSubtitleStyle: srtSubtitleStyle
        )
    }

    private func clearCollageEditingState() {
        _collagePreviewStore?.invalidate()
        _collagePreviewStore = nil
        _collageSnapshot = nil
        _collageSelectionPlan = SubtitleCollageSelectionPlan()
    }
}
