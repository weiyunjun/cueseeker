import AppKit
import CueSeekerCore
import SwiftUI

struct PlaybackSubtitleFocusReelRepresentable: NSViewRepresentable {
    let cues: [SubtitleFocusCue]
    let totalCount: Int
    let selectedOrdinal: Int
    let displayTitle: String
    let contentGeneration: Int
    let uiProbeScope: String?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let reducesMotion: Bool
    let isInteractionEnabled: Bool
    let cancelsWheelMotion: Bool
    let collageSelectedCueIDs: Set<Int64>?
    let collageCanSelectAnotherCue: Bool
    let onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool
    let onCommitNativeReelSelection: (Int) -> Bool
    let onToggleCollageCueSelection: (Int) -> Void
    let onCopySelectedText: (String) -> Void
    let onSearchSelectedText: (String) -> Void
    let allowsNativeWheelInput: () -> Bool
    let allowsNativeScrollbarInput: () -> Bool
    let onScrollbarDraggingChanged: (Bool) -> Void
    let onNativeMotionGateChanged: (Bool) -> Void
    let onKeyboardMotionChanged: (Bool) -> Void
    var interfaceLayers: InterfaceLayerRegistry?
    var isCoveredByHigherLayer = false

    func makeNSView(context: Context) -> PlaybackSubtitleFocusReelContainerView {
        UIInvalidationProbe.count(
            "playback.subtitle_focus.native_make",
            scope: uiProbeScope
        )
        let view = PlaybackSubtitleFocusReelContainerView()
        update(view)
        return view
    }

    func updateNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        context: Context
    ) {
        UIInvalidationProbe.count(
            "playback.subtitle_focus.native_update",
            scope: uiProbeScope
        )
        update(nsView)
    }

    static func dismantleNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        coordinator: Void
    ) {
        nsView.invalidate()
    }

    private func update(_ view: PlaybackSubtitleFocusReelContainerView) {
        view.uiProbeScope = uiProbeScope
        view.onCommitKeyboardNavigation = onCommitKeyboardNavigation
        view.onCommitNativeReelSelection = onCommitNativeReelSelection
        view.onToggleCollageCueSelection = onToggleCollageCueSelection
        view.onCopySelectedText = onCopySelectedText
        view.onSearchSelectedText = onSearchSelectedText
        view.allowsNativeWheelInput = allowsNativeWheelInput
        view.allowsNativeScrollbarInput = allowsNativeScrollbarInput
        view.onScrollbarDraggingChanged = onScrollbarDraggingChanged
        view.onNativeMotionGateChanged = onNativeMotionGateChanged
        view.onKeyboardMotionChanged = onKeyboardMotionChanged
        view.interfaceLayers = interfaceLayers
        view.isCoveredByHigherLayer = isCoveredByHigherLayer
        view.update(
            cues: cues,
            totalCount: totalCount,
            selectedOrdinal: selectedOrdinal,
            displayTitle: displayTitle,
            contentGeneration: UInt64(max(0, contentGeneration)),
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion,
            collageSelectedCueIDs: collageSelectedCueIDs,
            collageCanSelectAnotherCue: collageCanSelectAnotherCue
        )
    }
}

final class PlaybackSubtitleFocusReelContainerView: NSView {
    private struct ContentToken: Equatable {
        let datasetID: AnyHashable
        let generation: UInt64
    }

    var uiProbeScope: String? {
        didSet {
            documentView.uiProbeScope = uiProbeScope
        }
    }
    var onCommitKeyboardNavigation: (PlaybackSubtitleFocusKeyboardNavigationRequest) -> Bool = {
        _ in false
    }
    var onCommitNativeReelSelection: (Int) -> Bool = { _ in false }
    var onToggleCollageCueSelection: (Int) -> Void = { _ in }
    var onCopySelectedText: (String) -> Void = { _ in }
    var onSearchSelectedText: (String) -> Void = { _ in }
    var onCommitVirtualReelSelection: ((PlaybackVirtualReelSelectionCommit) -> Bool)?
    var allowsNativeWheelInput: () -> Bool = { false }
    var allowsNativeScrollbarInput: () -> Bool = { false }
    var onScrollbarDraggingChanged: (Bool) -> Void = { _ in }
    var onNativeMotionGateChanged: (Bool) -> Void = { _ in }
    var onKeyboardMotionChanged: (Bool) -> Void = { _ in }
    /// The registry whose gate handles the selected-text menu's events, and
    /// which layer this reel's menu belongs to: the Playback Overlay for the
    /// overlay's reels, the Command Panel for the panel's.
    var interfaceLayers: InterfaceLayerRegistry?
    var menuOwner: InterfaceLayer = .playbackOverlay
    /// True while a higher surface covers this reel. Its menu keeps its place
    /// on screen and stops answering keys and presses: those belong to whatever
    /// is on top. Hit testing already stops at the covering surface, but an
    /// `NSEvent` monitor never sees hit testing, so the reel is told directly.
    var isCoveredByHigherLayer = false

    private let scrollView = PlaybackSubtitleFocusNativeScrollView()
    private let documentView = PlaybackSubtitleFocusReelDocumentView()
    private let scrollbarView = PlaybackSubtitleFocusNativeScrollbarView()
    private let currentCueAdapter = PlaybackSubtitleFocusCueReelAdapter()
    private var selectedTextMenuHost: MenuHostingView?
    /// What the selected-text menu settled on when it opened: the cue it hangs
    /// off, where inside that cue, how big it is, and the offset that carries it
    /// along. Nothing here is recomputed while the menu is open.
    private struct SelectedTextMenuPlacement {
        let ordinal: Int
        let pointInCue: CGPoint
        let menuSize: CGSize
        let offset: CGSize
    }

    private var selectedTextMenuPlacement: SelectedTextMenuPlacement?
    private var menuGateSession: MenuGate.Session?
    private let selectedTextMenuHighlight = MenuHighlightModel()
    private var selectedTextMenuActions: [() -> Void] = []
    private var mountedContentAdapter:
        (any PlaybackVirtualReelContentAdapter)?
    private var contentSnapshot: PlaybackVirtualReelSnapshot?
    private var totalCount = 0
    private var selectedOrdinal: Int?
    private var fractionalOrdinal: CGFloat = 0
    private var hasInitializedPosition = false
    private var loadedOrdinalRange: Range<Int> = 0..<0
    private var isInteractionEnabled = true
    private var reducesMotion = false
    private var hasCompleteItemCollection = false
    private var lastViewportSize: CGSize = .zero
    private var lastHandledKeyboardSequence = 0
    private var lastHandledGeneratedKeyboardToken: ContentToken?
    private var lastHandledGeneratedKeyboardSequence = 0
    private var activeKeyboardRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    private var activeKeyboardContentGeneration: UInt64?
    private var isKeyboardMotionActive = false
    private var activeWheelTargetOrdinal: Int?
    private var activeWheelContentGeneration: UInt64?
    private var hasUncommittedScrollbarPreview = false
    private var preciseGestureStartOrdinal: Int?
    private var wheelState = PlaybackSubtitleFocusNativeWheelState()
    private var preciseSettleTask: Task<Void, Never>?
    nonisolated(unsafe) private var eventMonitor: Any?
    private var isWheelMotionActive = false
    private var isScrollbarDragging = false
    private var isScrollbarMotionActive = false
    private var reportedNativeMotionActive = false
    private var motionCallbackGeneration = 0
    private var motionCallbackTask: Task<Void, Never>?
    private lazy var keyboardAnimator = PlaybackSubtitleFocusReelPositionAnimator(
        onUpdate: { [weak self] position in
            self?.setFractionalOrdinal(position)
        },
        onCompletion: { [weak self] in
            self?.completeKeyboardMotion()
        }
    )
    private lazy var wheelAnimator = PlaybackSubtitleFocusReelPositionAnimator(
        onUpdate: { [weak self] position in
            self?.setFractionalOrdinal(position)
        },
        onCompletion: { [weak self] in
            self?.completeWheelMotion()
        }
    )

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.autohidesScrollers = true
        scrollView.documentView = documentView
        addSubview(scrollView)

        documentView.onToggleCollageCueSelection = { [weak self] ordinal in
            self?.onToggleCollageCueSelection(ordinal)
        }
        documentView.onPresentSelectedTextActions = { [weak self] text, ordinal, pointInCue in
            self?.presentSelectedTextActions(
                text: text,
                ordinal: ordinal,
                pointInCue: pointInCue
            )
        }
        documentView.onDismissSelectedTextActions = { [weak self] in
            self?.dismissSelectedTextActions()
        }

        scrollbarView.appearanceMode = .inherited
        scrollbarView.presentationProvider = { [weak self] in
            self?.scrollbarMetrics.presentation
        }
        scrollbarView.allowsInteraction = { [weak self] in
            self?.allowsNativeScrollbarInput() == true
        }
        scrollbarView.onDrag = { [weak self] event in
            self?.handleScrollbarDrag(event)
        }
        scrollbarView.onDragStateChanged = { [weak self] isDragging in
            self?.handleScrollbarDraggingChanged(isDragging)
        }
        addSubview(scrollbarView)

    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        let nextViewportSize = bounds.size
        if isScrollbarDragging,
           lastViewportSize != .zero,
           nextViewportSize != lastViewportSize {
            cancelActiveScrollbarDrag()
        }
        if lastViewportSize != .zero,
           nextViewportSize != lastViewportSize,
           !hasActiveNativeMotion,
           let selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
        }
        if lastViewportSize != .zero,
           nextViewportSize != lastViewportSize {
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.reflow",
                scope: uiProbeScope,
                details: "width=\(nextViewportSize.width) height=\(nextViewportSize.height)"
            )
        }
        lastViewportSize = nextViewportSize
        scrollView.frame = bounds
        scrollbarView.frame = bounds
        updateDocumentGeometry()
        if !hasActiveNativeMotion {
            synchronizeFractionalOrdinalIfIdle()
        }
        updateScrollbarPresentation()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeEventMonitor()
            NotificationCenter.default.removeObserver(
                self,
                name: .cueSeekerClearTextSelection,
                object: nil
            )
            dismissSelectedTextActions()
            resetWheelInteraction(requiresNewGesture: true)
        } else {
            installEventMonitorIfNeeded()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appClearTextSelection),
                name: .cueSeekerClearTextSelection,
                object: nil
            )
        }
    }

    /// A menu opening anywhere in the App takes every selection with it, so the
    /// reel drops its own — and the menu hanging off it — when one does.
    @objc private func appClearTextSelection(_ notification: Notification) {
        dismissSelectedTextActions()
    }

    func update(
        cues: [SubtitleFocusCue],
        totalCount: Int,
        selectedOrdinal: Int,
        displayTitle: String = "",
        contentGeneration: UInt64 = 0,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool,
        isInteractionEnabled: Bool,
        cancelsWheelMotion: Bool,
        collageSelectedCueIDs: Set<Int64>? = nil,
        collageCanSelectAnotherCue: Bool = true
    ) {
        currentCueAdapter.update(
            cues: cues,
            totalCount: totalCount,
            displayTitle: displayTitle,
            generation: contentGeneration
        )
        update(
            contentAdapter: currentCueAdapter,
            selectedOrdinal: selectedOrdinal,
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion,
            collageSelectedCueIDs: collageSelectedCueIDs,
            collageCanSelectAnotherCue: collageCanSelectAnotherCue
        )
    }

    func update(
        contentAdapter: any PlaybackVirtualReelContentAdapter,
        selectedOrdinal: Int?,
        keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool,
        isInteractionEnabled: Bool,
        cancelsWheelMotion: Bool,
        collageSelectedCueIDs: Set<Int64>? = nil,
        collageCanSelectAnotherCue: Bool = true
    ) {
        let snapshot = contentAdapter.snapshot
        if let contentSnapshot,
           contentSnapshot.datasetID == snapshot.datasetID,
           (snapshot.generation < contentSnapshot.generation
               || (snapshot.generation == contentSnapshot.generation
                   && (
                       snapshot.revision < contentSnapshot.revision
                           || (snapshot.revision == contentSnapshot.revision
                               && snapshot != contentSnapshot)
                           || snapshot.totalCount != contentSnapshot.totalCount
                   ))) {
            rejectIncomingContentAdapter(contentAdapter)
            return
        }
        guard snapshot.isValid else {
            rejectIncomingContentAdapter(contentAdapter)
            return
        }
        let previousSnapshot = contentSnapshot
        let changesDataset = previousSnapshot.map {
            !$0.belongsToSameDataset(as: snapshot)
        } ?? false
        let activeTargetOrdinal = activeKeyboardRequest?.targetOrdinal
            ?? activeWheelTargetOrdinal
            ?? preciseGestureStartOrdinal
        let removesActiveTarget = activeTargetOrdinal.map {
            !snapshot.loadedOrdinalRange.contains($0)
        } ?? false
        if changesDataset || removesActiveTarget {
            cancelMotionForContentReplacement()
        }
        if changesDataset {
            contentAdapter.invalidateMeasurements()
            hasInitializedPosition = false
        }
        contentSnapshot = snapshot
        mountedContentAdapter = contentAdapter
        self.totalCount = snapshot.totalCount
        let previousSelectedOrdinal = self.selectedOrdinal
        if let selectedOrdinal, snapshot.totalCount > 0 {
            let resolvedSelectedOrdinal = min(
                max(0, selectedOrdinal),
                snapshot.totalCount - 1
            )
            if snapshot.loadedOrdinalRange.contains(resolvedSelectedOrdinal) {
                self.selectedOrdinal = resolvedSelectedOrdinal
            } else {
                self.selectedOrdinal = nil
            }
        } else {
            self.selectedOrdinal = nil
        }
        loadedOrdinalRange = snapshot.loadedOrdinalRange
        hasCompleteItemCollection = snapshot.isComplete
        self.reducesMotion = reducesMotion
        let wasInteractionEnabled = self.isInteractionEnabled
        self.isInteractionEnabled = isInteractionEnabled
        let wasInitialized = hasInitializedPosition
        let willBeginKeyboardNavigation = hasUnhandledKeyboardNavigationRequest(
            keyboardNavigationRequest
        )
        // A keyboard motion already in flight owns the reel: wheel and
        // scrollbar input are gated off, and repeating the cancel would put
        // the highlight back on the committed row mid-motion.
        if cancelsWheelMotion, !isKeyboardMotionActive {
            cancelActiveScrollbarDrag()
            resetWheelInteraction(
                requiresNewGesture: true,
                restoresSelectionImmediately: !willBeginKeyboardNavigation
            )
        } else if wasInteractionEnabled, !isInteractionEnabled {
            suspendWheelInputForSuppression()
        }
        documentView.updateContent(contentAdapter)
        documentView.updateCollageSelection(
            selectedCueIDs: collageSelectedCueIDs,
            canSelectAnotherCue: collageCanSelectAnotherCue
        )
        if !hasInitializedPosition,
           let selectedOrdinal = self.selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
            hasInitializedPosition = true
        } else if previousSelectedOrdinal != self.selectedOrdinal,
                  !hasActiveNativeMotion,
                  !willBeginKeyboardNavigation,
                  let selectedOrdinal = self.selectedOrdinal {
            fractionalOrdinal = CGFloat(selectedOrdinal)
        }
        fractionalOrdinal = boundedLoadedFractionalOrdinal(fractionalOrdinal)
        updateDocumentGeometry()
        updateScrollbarPresentation()
        if changesDataset || !wasInitialized {
            documentView.setImmediateSelection(self.selectedOrdinal)
        } else if isScrollbarDragging, hasUncommittedScrollbarPreview {
            documentView.updateSelection(currentLayout.nearestOrdinal)
        } else if !hasActiveNativeMotion, !willBeginKeyboardNavigation {
            documentView.updateSelection(self.selectedOrdinal)
            synchronizeFractionalOrdinalIfIdle()
        }
        handleKeyboardNavigation(
            keyboardNavigationRequest,
            reducesMotion: reducesMotion
        )
    }

    private func rejectIncomingContentAdapter(
        _ contentAdapter: any PlaybackVirtualReelContentAdapter
    ) {
        if let mountedContentAdapter,
           mountedContentAdapter === contentAdapter {
            resetForInvalidContent(contentAdapter)
        } else {
            contentAdapter.invalidate()
        }
    }

    private func resetForInvalidContent(
        _ contentAdapter: any PlaybackVirtualReelContentAdapter
    ) {
        cancelMotionForContentReplacement()
        if let mountedContentAdapter,
           mountedContentAdapter !== contentAdapter {
            contentAdapter.invalidate()
        }
        contentSnapshot = nil
        mountedContentAdapter = nil
        totalCount = 0
        selectedOrdinal = nil
        fractionalOrdinal = 0
        loadedOrdinalRange = 0..<0
        hasCompleteItemCollection = false
        hasInitializedPosition = false
        documentView.invalidate()
        updateDocumentGeometry()
        updateScrollbarPresentation()
    }

    private func cancelMotionForContentReplacement() {
        keyboardAnimator.cancel()
        wheelAnimator.cancel()
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
        wheelState.reset(requiresNewGesture: true)
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        hasUncommittedScrollbarPreview = false
        preciseGestureStartOrdinal = nil
        documentView.setImmediateSelection(selectedOrdinal)
        if isScrollbarDragging {
            isScrollbarDragging = false
            onScrollbarDraggingChanged(false)
        }
        isKeyboardMotionActive = false
        isWheelMotionActive = false
        isScrollbarMotionActive = false
        motionCallbackGeneration += 1
        motionCallbackTask?.cancel()
        motionCallbackTask = nil
        if reportedNativeMotionActive {
            reportedNativeMotionActive = false
            onNativeMotionGateChanged(false)
            onKeyboardMotionChanged(false)
        }
    }

    func invalidate() {
        if reportedNativeMotionActive {
            onNativeMotionGateChanged(false)
        }
        motionCallbackGeneration += 1
        motionCallbackTask?.cancel()
        motionCallbackTask = nil
        onCommitKeyboardNavigation = { _ in false }
        onCommitNativeReelSelection = { _ in false }
        onToggleCollageCueSelection = { _ in }
        onCopySelectedText = { _ in }
        onSearchSelectedText = { _ in }
        onCommitVirtualReelSelection = nil
        allowsNativeWheelInput = { false }
        allowsNativeScrollbarInput = { false }
        if isScrollbarDragging {
            onScrollbarDraggingChanged(false)
        }
        onScrollbarDraggingChanged = { _ in }
        onNativeMotionGateChanged = { _ in }
        onKeyboardMotionChanged = { _ in }
        keyboardAnimator.cancel()
        wheelAnimator.cancel()
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
        dismissSelectedTextActions()
        removeEventMonitor()
        wheelState.reset()
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        hasUncommittedScrollbarPreview = false
        preciseGestureStartOrdinal = nil
        scrollbarView.onDrag = { _ in }
        scrollbarView.onDragStateChanged = nil
        scrollbarView.presentationProvider = { nil }
        scrollbarView.allowsInteraction = { false }
        scrollbarView.isPresented = false
        isScrollbarDragging = false
        isKeyboardMotionActive = false
        isWheelMotionActive = false
        isScrollbarMotionActive = false
        lastViewportSize = .zero
        reportedNativeMotionActive = false
        contentSnapshot = nil
        mountedContentAdapter = nil
        selectedOrdinal = nil
        fractionalOrdinal = 0
        loadedOrdinalRange = 0..<0
        totalCount = 0
        hasCompleteItemCollection = false
        hasInitializedPosition = false
        lastHandledKeyboardSequence = 0
        lastHandledGeneratedKeyboardToken = nil
        lastHandledGeneratedKeyboardSequence = 0
        isInteractionEnabled = false
        documentView.invalidate()
        scrollView.documentView = nil
    }

    private func presentSelectedTextActions(
        text: String,
        ordinal: Int,
        pointInCue: CGPoint
    ) {
        tearDownSelectedTextMenu()
        // The Scrollbar is outside the menu, so it stops answering the pointer
        // for as long as the menu is up.
        scrollbarView.isInteractionFrozen = true

        selectedTextMenuActions = [
            { [weak self] in
                self?.dismissSelectedTextActions()
                self?.onCopySelectedText(text)
            },
            { [weak self] in
                self?.dismissSelectedTextActions()
                self?.onSearchSelectedText(text)
            },
        ]
        selectedTextMenuHighlight.open(
            selectablePositions: Array(selectedTextMenuActions.indices)
        )

        let menu = PlaybackSelectedTextMenu(
            highlight: selectedTextMenuHighlight,
            items: [
                PlaybackSelectedTextMenu.Item(
                    title: L("playback.copy_selected_text"),
                    icon: .copy
                ),
                PlaybackSelectedTextMenu.Item(
                    title: L("playback.search_selected_text"),
                    icon: .magnifyingGlass
                ),
            ],
            onActivate: { [weak self] position in
                self?.activateSelectedTextAction(at: position)
            }
        )
        let host = MenuHostingView(rootView: AnyView(menu))
        host.translatesAutoresizingMaskIntoConstraints = true
        selectedTextMenuHost = host
        addSubview(host)
        host.layoutSubtreeIfNeeded()

        // Measured, placed once, and the offset kept — the same order every
        // other menu in the App follows. Afterwards the menu only translates.
        let menuSize = host.fittingSize
        let anchor = selectedTextAnchor(ordinal: ordinal, pointInCue: pointInCue)
            ?? .zero
        let openingFrame = selectedTextMenuFrame(anchor: anchor, size: menuSize)
        selectedTextMenuPlacement = SelectedTextMenuPlacement(
            ordinal: ordinal,
            pointInCue: pointInCue,
            menuSize: menuSize,
            offset: MenuPlacement.offset(
                from: CGRect(origin: anchor, size: .zero),
                to: openingFrame
            )
        )
        host.frame = openingFrame
        openMenuGateSession()
    }

    /// Where the menu hangs off, in this view's coordinates, as the reel lays
    /// its cues out now.
    private func selectedTextAnchor(
        ordinal: Int,
        pointInCue: CGPoint
    ) -> CGPoint? {
        guard let cueOrigin = documentView.cueContentOrigin(at: ordinal) else {
            return nil
        }
        return convert(
            CGPoint(
                x: cueOrigin.x + pointInCue.x,
                y: cueOrigin.y + pointInCue.y
            ),
            from: documentView
        )
    }

    /// Pure translation, run whenever the reel moves. The side was chosen when
    /// the menu opened and is never revisited. A cue carried outside the
    /// laid-out window leaves the menu where it last was, on its way out.
    private func repositionSelectedTextMenu() {
        guard let host = selectedTextMenuHost,
              let placement = selectedTextMenuPlacement,
              let anchor = selectedTextAnchor(
                  ordinal: placement.ordinal,
                  pointInCue: placement.pointInCue
              )
        else {
            return
        }
        host.frame = MenuPlacement.followingFrame(
            anchor: CGRect(origin: anchor, size: .zero),
            offset: placement.offset,
            menuSize: placement.menuSize
        )
    }

    func selectedTextMenuFrame(
        anchor: CGPoint,
        size: CGSize
    ) -> CGRect {
        MenuPlacement.openingFrame(
            anchor: CGRect(origin: anchor, size: .zero),
            menuSize: size,
            in: bounds,
            gap: WorkbenchControlMetrics.redesignSpacing1
        )
    }

    /// Closes the menu and takes the selection it hangs off with it. Clearing
    /// here does not report back, because a report is what asks for this in the
    /// first place.
    private func dismissSelectedTextActions() {
        tearDownSelectedTextMenu()
        documentView.discardTextSelection()
    }

    /// Removes the menu and leaves the selection alone, for the open path,
    /// which tears down any previous menu before putting up the one belonging
    /// to the selection just made.
    private func tearDownSelectedTextMenu() {
        selectedTextMenuHost?.removeFromSuperview()
        selectedTextMenuHost = nil
        selectedTextMenuPlacement = nil
        selectedTextMenuHighlight.close()
        selectedTextMenuActions = []
        menuGateSession?.close()
        menuGateSession = nil
        scrollbarView.isInteractionFrozen = false
    }

    /// Arrow keys, Enter and Escape for the open menu. Reported as handled so
    /// the playback page does not also navigate cues or seek.
    private func handleSelectedTextMenuKey(_ keyCode: UInt16) -> Bool {
        guard selectedTextMenuHost != nil else {
            return false
        }
        // Every arrow and Enter belongs to the open menu; the reel and the
        // page under it must not respond to any of them.
        switch keyCode {
        case 53:
            dismissSelectedTextActions()
            return true
        case 126:
            _ = selectedTextMenuHighlight.moveHighlight(by: -1)
            return true
        case 125:
            _ = selectedTextMenuHighlight.moveHighlight(by: 1)
            return true
        case 123, 124:
            return true
        case 36, 76:
            _ = activateHighlightedSelectedTextAction()
            return true
        default:
            return false
        }
    }

    private func activateSelectedTextAction(at position: Int) {
        guard selectedTextMenuActions.indices.contains(position) else {
            return
        }
        selectedTextMenuActions[position]()
    }

    /// Enter runs whatever the highlight currently sits on, so the keyboard and
    /// the pointer commit through one path.
    private func activateHighlightedSelectedTextAction() -> Bool {
        guard let position = selectedTextMenuHighlight.highlightedPosition
        else {
            return false
        }
        activateSelectedTextAction(at: position)
        return true
    }

    /// Hands the open selected-text menu to the menu gate, which owns the
    /// outside press, the whole-window scroll ban, and the menu's keys. The
    /// overlay's menu also receives its keys through the gate's route: the
    /// playback key owner sees keys first and offers them to the gate.
    private func openMenuGateSession() {
        guard menuGateSession == nil else {
            return
        }
        menuGateSession = interfaceLayers?.menuGate.open(
            MenuGate.Client(
                owner: menuOwner,
                kind: .selectedTextMenu,
                window: { [weak self] in self?.window },
                isPointerOnMenu: { [weak self] event in
                    guard let host = self?.selectedTextMenuHost else {
                        return false
                    }
                    return host.bounds.contains(
                        host.convert(event.locationInWindow, from: nil)
                    )
                },
                handleKey: { [weak self] keyCode, _ in
                    self?.handleSelectedTextMenuKey(keyCode) ?? false
                },
                dismiss: { [weak self] _ in
                    // The press that closes the menu is spent on closing it.
                    // It does not also land on the subtitle text underneath.
                    self?.dismissSelectedTextActions()
                }
            )
        )
    }

    var fractionalOrdinalForTesting: CGFloat {
        fractionalOrdinal
    }

    var selectedTextMenuFrameForTesting: CGRect? {
        selectedTextMenuHost?.frame
    }

    var documentViewForTesting: PlaybackSubtitleFocusReelDocumentView {
        documentView
    }

    var selectedOrdinalForTesting: Int {
        selectedOrdinal ?? 0
    }

    var optionalSelectedOrdinalForTesting: Int? {
        selectedOrdinal
    }

    var displayedSelectedOrdinalForTesting: Int? {
        documentView.selectedOrdinalForTesting
    }

    func toggleCollageCueForTesting(at ordinal: Int) -> Bool {
        documentView.toggleCollageCueForTesting(at: ordinal)
    }

    func toggleCollageCueForTesting(at point: CGPoint) -> Bool {
        documentView.toggleCollageCueForTesting(at: point)
    }

    func collageCheckboxRectForTesting(at ordinal: Int) -> CGRect? {
        documentView.collageCheckboxRectForTesting(at: ordinal)
    }

    func cueContentRectForTesting(at ordinal: Int) -> CGRect? {
        documentView.cueContentRectForTesting(at: ordinal)
    }

    var cueTimelineConnectorRectsForTesting: [CGRect] {
        documentView.cueTimelineConnectorRectsForTesting
    }

    func isCueHighlightedForTesting(at ordinal: Int) -> Bool {
        documentView.isCueHighlightedForTesting(at: ordinal)
    }

    func cueSelectionProgressForTesting(at ordinal: Int) -> CGFloat {
        documentView.cueSelectionProgressForTesting(at: ordinal)
    }

    var isFocusFadeInDebouncingForTesting: Bool {
        documentView.isFocusFadeInDebouncingForTesting
    }

    func advanceFocusTransitionForTesting(by deltaSeconds: TimeInterval) {
        documentView.advanceFocusTransitionForTesting(by: deltaSeconds)
    }

    func isCollageCueEnabledForTesting(at ordinal: Int) -> Bool {
        documentView.isCollageCueEnabledForTesting(at: ordinal)
    }

    var placementsForTesting: [PlaybackSubtitleFocusCuePlacement] {
        documentView.placements
    }

    var measuredOrdinalsForTesting: Set<Int> {
        documentView.measuredOrdinals
    }

    var measurementCacheCountForTesting: Int {
        documentView.measurementCacheCount
    }

    var scrollbarPresentationForTesting: TableScrollbarPresentation {
        scrollbarMetrics.presentation
    }

    var acceptsScrollbarInteractionForTesting: Bool {
        scrollbarView.acceptsInteraction && allowsNativeScrollbarInput()
    }

    func applyPreciseWheelDeltaForTesting(_ deltaY: CGFloat) {
        handlePreciseWheel(
            deltaY: deltaY,
            beginsGesture: preciseGestureStartOrdinal == nil
        )
    }

    func applyDiscreteWheelForTesting(
        direction: SubtitleFocusNavigationDirection,
        stepCount: Int = 1
    ) {
        handleDiscreteWheel(direction: direction, stepCount: stepCount)
    }

    func settlePreciseWheelForTesting() {
        settlePreciseWheel()
    }

    private func updateDocumentGeometry() {
        let layout = PlaybackSubtitleFocusVirtualReelLayout(
            viewportSize: scrollView.contentSize,
            totalCount: totalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            fractionalOrdinal: fractionalOrdinal,
            usesFullWidth: documentView.isEditingCollage
        )
        documentView.updateLocalLayout(layout)
        if documentView.frame.size != layout.viewportSize {
            documentView.frame = CGRect(origin: .zero, size: layout.viewportSize)
        }
        if scrollView.contentView.bounds.origin != .zero {
            scrollView.contentView.scroll(to: .zero)
        }
        repositionSelectedTextMenu()
    }

    private func synchronizeFractionalOrdinalIfIdle() {
        guard !keyboardAnimator.isRunning,
              !wheelAnimator.isRunning,
              preciseGestureStartOrdinal == nil,
              let selectedOrdinal
        else {
            return
        }
        setFractionalOrdinal(CGFloat(selectedOrdinal))
    }

    private var currentLayout: PlaybackSubtitleFocusVirtualReelLayout {
        PlaybackSubtitleFocusVirtualReelLayout(
            viewportSize: scrollView.contentSize,
            totalCount: totalCount,
            loadedOrdinalRange: loadedOrdinalRange,
            fractionalOrdinal: fractionalOrdinal,
            usesFullWidth: documentView.isEditingCollage
        )
    }

    private var scrollbarMetrics: PlaybackSubtitleFocusNativeScrollbarMetrics {
        PlaybackSubtitleFocusNativeScrollbarMetrics(
            totalCount: totalCount,
            fractionalOrdinal: fractionalOrdinal,
            visibleCueCapacity: documentView.visibleCueCenterCapacity
        )
    }

    private func updateScrollbarPresentation() {
        scrollbarView.isPresented = scrollbarMetrics.presentation.vertical != nil
        updateScrollbarInteractionAvailability()
        scrollbarView.scrollbarMetricsDidChange()
    }

    private func updateScrollbarInteractionAvailability() {
        scrollbarView.acceptsInteraction = isInteractionEnabled
            && hasCompleteItemCollection
            && selectedOrdinal != nil
            && !isKeyboardMotionActive
            && !isWheelMotionActive
    }

    private func cancelActiveScrollbarDrag() {
        guard isScrollbarDragging else {
            return
        }
        let restoresPresentation = scrollbarMetrics.presentation.vertical != nil
        scrollbarView.isPresented = false
        if isScrollbarDragging {
            handleScrollbarDrag(TableScrollbarDragEvent(
                axis: .vertical,
                phase: .cancelled,
                positionFraction: scrollbarMetrics.presentation.vertical?
                    .positionFraction ?? 0
            ))
            handleScrollbarDraggingChanged(false)
        }
        scrollbarView.isPresented = restoresPresentation
    }

    private func setFractionalOrdinal(
        _ position: CGFloat,
        refreshesScrollbar: Bool = true
    ) {
        let boundedPosition = boundedLoadedFractionalOrdinal(position)
        guard abs(fractionalOrdinal - boundedPosition) > 0.000_001 else {
            if refreshesScrollbar {
                scrollbarView.scrollbarMetricsDidChange()
            }
            return
        }
        fractionalOrdinal = boundedPosition
        updateDocumentGeometry()
        if refreshesScrollbar {
            scrollbarView.scrollbarMetricsDidChange()
        }
    }

    private func hasUnhandledKeyboardNavigationRequest(
        _ request: PlaybackSubtitleFocusKeyboardNavigationRequest?
    ) -> Bool {
        guard let request else {
            return false
        }
        if let requestGeneration = request.contentGeneration {
            guard let contentSnapshot,
                  let contentDatasetID = request.contentDatasetID,
                  AnyHashable(contentDatasetID) == contentSnapshot.datasetID,
                  requestGeneration == contentSnapshot.generation
            else {
                return false
            }
            let token = ContentToken(
                datasetID: contentSnapshot.datasetID,
                generation: requestGeneration
            )
            let lastSequence = lastHandledGeneratedKeyboardToken == token
                ? lastHandledGeneratedKeyboardSequence
                : 0
            guard request.sequence > lastSequence else {
                return false
            }
        } else {
            guard request.sequence > lastHandledKeyboardSequence else {
                return false
            }
        }
        return request.targetOrdinal >= 0
            && request.targetOrdinal < totalCount
            && loadedOrdinalRange.contains(request.targetOrdinal)
    }

    private func handleKeyboardNavigation(
        _ request: PlaybackSubtitleFocusKeyboardNavigationRequest?,
        reducesMotion: Bool
    ) {
        guard let request else {
            return
        }
        if let requestGeneration = request.contentGeneration {
            guard let contentSnapshot,
                  let contentDatasetID = request.contentDatasetID,
                  AnyHashable(contentDatasetID) == contentSnapshot.datasetID,
                  requestGeneration == contentSnapshot.generation
            else {
                return
            }
            let token = ContentToken(
                datasetID: contentSnapshot.datasetID,
                generation: requestGeneration
            )
            if lastHandledGeneratedKeyboardToken != token {
                lastHandledGeneratedKeyboardToken = token
                lastHandledGeneratedKeyboardSequence = 0
            }
            guard request.sequence > lastHandledGeneratedKeyboardSequence else {
                return
            }
            lastHandledGeneratedKeyboardSequence = request.sequence
        } else {
            guard request.sequence > lastHandledKeyboardSequence else {
                return
            }
            lastHandledKeyboardSequence = request.sequence
        }
        guard request.targetOrdinal >= 0,
              request.targetOrdinal < totalCount,
              loadedOrdinalRange.contains(request.targetOrdinal)
        else {
            return
        }
        UIInvalidationProbe.mark(
            "ACTION playback.subtitle_focus.keyboard_navigation",
            scope: uiProbeScope,
            details: "target=\(request.targetOrdinal)"
        )
        activeKeyboardRequest = request
        activeKeyboardContentGeneration = contentSnapshot?.generation
        documentView.beginNavigationSelection(
            request.targetOrdinal,
            reducesMotion: reducesMotion
        )
        setKeyboardMotionActive(true)
        keyboardAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(request.targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func completeKeyboardMotion() {
        guard let request = activeKeyboardRequest,
              activeKeyboardContentGeneration == contentSnapshot?.generation
        else {
            return
        }
        let didCommit: Bool
        if let onCommitVirtualReelSelection {
            didCommit = selectionCommit(for: request.targetOrdinal).map(
                onCommitVirtualReelSelection
            ) ?? false
        } else {
            didCommit = onCommitKeyboardNavigation(request)
        }
        guard didCommit else {
            activeKeyboardRequest = nil
            activeKeyboardContentGeneration = nil
            documentView.setImmediateSelection(selectedOrdinal)
            setKeyboardMotionActive(false)
            synchronizeFractionalOrdinalIfIdle()
            return
        }
        activeKeyboardRequest = nil
        activeKeyboardContentGeneration = nil
        selectedOrdinal = request.targetOrdinal
        setKeyboardMotionActive(false)
    }

    func handleScrollbarDraggingChanged(_ isDragging: Bool) {
        guard isScrollbarDragging != isDragging else {
            return
        }
        if isDragging {
            guard scrollbarView.acceptsInteraction else {
                return
            }
            guard allowsNativeScrollbarInput() else {
                return
            }
            resetWheelInteraction(requiresNewGesture: true)
            hasUncommittedScrollbarPreview = false
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.scrollbar_drag",
                scope: uiProbeScope,
                details: "phase=began"
            )
            isScrollbarDragging = true
            onScrollbarDraggingChanged(true)
            setScrollbarMotionActive(true)
        } else {
            isScrollbarDragging = false
            onScrollbarDraggingChanged(false)
            setScrollbarMotionActive(false)
            if hasUncommittedScrollbarPreview {
                restoreSelectedSelection()
            }
            updateScrollbarInteractionAvailability()
            scrollbarView.scrollbarMetricsDidChange()
        }
    }

    func handleScrollbarDrag(_ event: TableScrollbarDragEvent) {
        guard event.axis == .vertical,
              hasCompleteItemCollection,
              isScrollbarDragging
        else {
            return
        }

        switch event.phase {
        case .began:
            break
        case .changed:
            if applyScrollbarPositionFraction(
                event.positionFraction,
                refreshesScrollbar: false
            ) {
                hasUncommittedScrollbarPreview = true
            }
        case .ended:
            hasUncommittedScrollbarPreview = false
            if applyScrollbarPositionFraction(
                event.positionFraction,
                refreshesScrollbar: true
            ) {
                settleScrollbarDrag()
            }
        case .cancelled:
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            activeWheelContentGeneration = nil
            restoreSelectedSelection()
        }
    }

    private func applyScrollbarPositionFraction(
        _ positionFraction: CGFloat,
        refreshesScrollbar: Bool
    ) -> Bool {
        let metrics = scrollbarMetrics
        let position = metrics.fractionalOrdinal(for: positionFraction)
        let targetOrdinal = min(
            max(0, Int(position.rounded())),
            max(0, totalCount - 1)
        )
        guard loadedOrdinalRange.contains(targetOrdinal) else {
            return false
        }
        let previousFractionalOrdinal = fractionalOrdinal
        setFractionalOrdinal(position, refreshesScrollbar: refreshesScrollbar)
        let didMove = abs(fractionalOrdinal - previousFractionalOrdinal) > 0.000_001
        if didMove {
            documentView.beginNavigationSelection(
                currentLayout.nearestOrdinal,
                reducesMotion: reducesMotion
            )
        } else {
            documentView.updateSelection(currentLayout.nearestOrdinal)
        }
        return true
    }

    private func restoreSelectedSelection() {
        hasUncommittedScrollbarPreview = false
        guard let targetOrdinal = selectedOrdinal,
              loadedOrdinalRange.contains(targetOrdinal)
        else {
            selectedOrdinal = nil
            documentView.setImmediateSelection(nil)
            updateScrollbarPresentation()
            return
        }
        fractionalOrdinal = CGFloat(targetOrdinal)
        hasInitializedPosition = true
        documentView.setImmediateSelection(targetOrdinal)
        updateDocumentGeometry()
        updateScrollbarPresentation()
    }

    private func settleScrollbarDrag() {
        let targetOrdinal = currentLayout.nearestOrdinal
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(targetOrdinal)
        setWheelMotionActive(true)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func installEventMonitorIfNeeded() {
        guard eventMonitor == nil else {
            return
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window
            else {
                return event
            }
            let point = self.convert(event.locationInWindow, from: nil)
            let isInside = self.bounds.contains(point)
            // An open menu hands the wheel to the menu gate, which bans
            // scrolling for the whole window and leaves the menu its own. The
            // reel must not spend the wheel first: this monitor was installed
            // before the gate's, so it sees the event first. Every menu the
            // gate holds counts, not only this reel's own: the footer's
            // `Save to Excerpt` menu is opened by another surface, and a reel
            // that recognised only its own selected-text menu went on scrolling
            // under it. A menu the gate reports as covered bans nothing — the
            // surface above it decides.
            if self.interfaceLayers?.menuGate.bansScrolling == true {
                return event
            }
            guard self.allowsNativeWheelInput() else {
                if self.isWheelMotionActive {
                    self.suspendWheelInputForSuppression()
                    return nil
                }
                // A reel that is not taking wheel input must not swallow it
                // either. Its rectangle still covers whatever is stacked on
                // top, so swallowing here would starve the overlay above it;
                // passing the event on lets that surface's own monitor take it.
                return event
            }
            let sample = PlaybackSubtitleFocusScrollSample(
                deltaY: event.scrollingDeltaY,
                isPrecise: event.hasPreciseScrollingDeltas,
                phase: Self.scrollPhase(from: event.phase),
                momentumPhase: Self.scrollPhase(from: event.momentumPhase),
                isInside: isInside
            )
            let output = self.wheelState.consume(
                sample,
                isEnabled: self.isInteractionEnabled
            )
            guard output.shouldConsume else {
                return event
            }
            let isWindowFocused = (window as? CueSeekerWindow)?.isFocusedForHover
                ?? (NSApp.isActive && window.isKeyWindow)
            if isWindowFocused {
                PointerHoverScrollState.shared.noteScrolled()
            }
            self.handleWheelOutput(output)
            return nil
        }
    }

    private func removeEventMonitor() {
        guard let eventMonitor else {
            return
        }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func handleWheelOutput(
        _ output: PlaybackSubtitleFocusNativeWheelOutput
    ) {
        switch output.mode {
        case .none:
            break
        case .discrete(let direction, let stepCount):
            handleDiscreteWheel(direction: direction, stepCount: stepCount)
        case .precise(let deltaY, let beginsGesture):
            handlePreciseWheel(deltaY: deltaY, beginsGesture: beginsGesture)
        }

        switch output.settleDirective {
        case .none:
            break
        case .cancel:
            cancelPreciseSettle()
        case .debounce:
            schedulePreciseSettle()
        case .immediate:
            settlePreciseWheel()
        }
    }

    private func handleDiscreteWheel(
        direction: SubtitleFocusNavigationDirection,
        stepCount: Int
    ) {
        cancelPreciseSettle()
        wheelState.finishPreciseGesture()
        guard let startOrdinal = activeWheelTargetOrdinal ?? selectedOrdinal else {
            return
        }
        let delta = direction == .backward ? -stepCount : stepCount
        let targetOrdinal = min(
            max(0, startOrdinal + delta),
            max(0, totalCount - 1)
        )
        guard targetOrdinal != startOrdinal,
              loadedOrdinalRange.contains(targetOrdinal)
        else {
            return
        }
        UIInvalidationProbe.mark(
            "ACTION playback.subtitle_focus.wheel",
            scope: uiProbeScope,
            details: "mode=discrete target=\(targetOrdinal)"
        )

        preciseGestureStartOrdinal = nil
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.beginNavigationSelection(
            targetOrdinal,
            reducesMotion: reducesMotion
        )
        setWheelMotionActive(true)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func handlePreciseWheel(
        deltaY: CGFloat,
        beginsGesture: Bool
    ) {
        guard selectedOrdinal != nil,
              totalCount > 0,
              !loadedOrdinalRange.isEmpty
        else {
            return
        }
        if beginsGesture || preciseGestureStartOrdinal == nil {
            cancelPreciseSettle()
            wheelAnimator.cancel()
            activeWheelTargetOrdinal = nil
            activeWheelContentGeneration = nil
            preciseGestureStartOrdinal = currentLayout.nearestOrdinal
            UIInvalidationProbe.mark(
                "ACTION playback.subtitle_focus.wheel",
                scope: uiProbeScope,
                details: "mode=precise"
            )
        }

        let previousFractionalOrdinal = fractionalOrdinal
        let position = documentView.fractionalOrdinal(
            afterMovingBy: -deltaY,
            from: fractionalOrdinal
        )
        setFractionalOrdinal(position)
        let didMove = abs(fractionalOrdinal - previousFractionalOrdinal) > 0.000_001
        if didMove {
            documentView.beginNavigationSelection(
                currentLayout.nearestOrdinal,
                reducesMotion: reducesMotion
            )
        } else {
            documentView.updateSelection(currentLayout.nearestOrdinal)
        }
        setWheelMotionActive(true)
    }

    private func schedulePreciseSettle() {
        preciseSettleTask?.cancel()
        let generation = contentSnapshot?.generation
        preciseSettleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.contentSnapshot?.generation == generation
            else {
                return
            }
            self.preciseSettleTask = nil
            self.settlePreciseWheel()
        }
    }

    private func cancelPreciseSettle() {
        preciseSettleTask?.cancel()
        preciseSettleTask = nil
    }

    private func settlePreciseWheel() {
        cancelPreciseSettle()
        wheelState.finishPreciseGesture()
        guard selectedOrdinal != nil,
              !loadedOrdinalRange.isEmpty,
              preciseGestureStartOrdinal != nil
        else {
            return
        }

        let targetOrdinal = currentLayout.nearestOrdinal

        preciseGestureStartOrdinal = nil
        activeWheelTargetOrdinal = targetOrdinal
        activeWheelContentGeneration = contentSnapshot?.generation
        documentView.updateSelection(targetOrdinal)
        wheelAnimator.retarget(
            from: fractionalOrdinal,
            to: CGFloat(targetOrdinal),
            duration: PlaybackSubtitleFocusMetrics
                .resolvedReelTransitionDuration(reducesMotion: reducesMotion)
        )
    }

    private func completeWheelMotion() {
        guard let targetOrdinal = activeWheelTargetOrdinal,
              activeWheelContentGeneration == contentSnapshot?.generation
        else {
            return
        }
        let didCommit: Bool
        if let onCommitVirtualReelSelection {
            didCommit = selectionCommit(for: targetOrdinal).map(
                onCommitVirtualReelSelection
            ) ?? false
        } else {
            didCommit = onCommitNativeReelSelection(targetOrdinal)
        }
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        if didCommit {
            selectedOrdinal = targetOrdinal
        } else if selectedOrdinal != nil {
            documentView.setImmediateSelection(selectedOrdinal)
        } else {
            restoreSelectedSelection()
        }
        setWheelMotionActive(false)
        if !didCommit, selectedOrdinal != nil {
            synchronizeFractionalOrdinalIfIdle()
        }
    }

    private func resetWheelInteraction(
        requiresNewGesture: Bool,
        restoresSelectionImmediately: Bool = true
    ) {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: requiresNewGesture)
        wheelAnimator.cancel()
        activeWheelTargetOrdinal = nil
        activeWheelContentGeneration = nil
        preciseGestureStartOrdinal = nil
        if restoresSelectionImmediately {
            documentView.setImmediateSelection(selectedOrdinal)
        }
        setWheelMotionActive(false)
        if restoresSelectionImmediately {
            synchronizeFractionalOrdinalIfIdle()
        }
    }

    private func suspendWheelInputForSuppression() {
        cancelPreciseSettle()
        wheelState.reset(requiresNewGesture: true)
        if preciseGestureStartOrdinal != nil {
            settlePreciseWheel()
        }
    }

    private func selectionCommit(
        for ordinal: Int
    ) -> PlaybackVirtualReelSelectionCommit? {
        guard let contentSnapshot,
              contentSnapshot.loadedOrdinalRange.contains(ordinal)
        else {
            return nil
        }
        return PlaybackVirtualReelSelectionCommit(
            datasetID: contentSnapshot.datasetID,
            generation: contentSnapshot.generation,
            ordinal: ordinal
        )
    }

    private func boundedLoadedFractionalOrdinal(_ ordinal: CGFloat) -> CGFloat {
        PlaybackSubtitleFocusVirtualReelLayout.clampedFractionalOrdinal(
            ordinal,
            to: loadedOrdinalRange
        )
    }

    private static func scrollPhase(
        from phase: NSEvent.Phase
    ) -> PlaybackSubtitleFocusScrollSample.Phase {
        if phase.contains(.began) {
            return .began
        }
        if phase.contains(.changed)
            || phase.contains(.mayBegin)
            || phase.contains(.stationary) {
            return .changed
        }
        if phase.contains(.ended) {
            return .ended
        }
        if phase.contains(.cancelled) {
            return .cancelled
        }
        return .none
    }

    private func setKeyboardMotionActive(_ isActive: Bool) {
        guard isKeyboardMotionActive != isActive else {
            return
        }
        isKeyboardMotionActive = isActive
        updateScrollbarInteractionAvailability()
        updateReportedNativeMotion()
    }

    private func setWheelMotionActive(_ isActive: Bool) {
        guard isWheelMotionActive != isActive else {
            return
        }
        isWheelMotionActive = isActive
        updateScrollbarInteractionAvailability()
        updateReportedNativeMotion()
    }

    private func setScrollbarMotionActive(_ isActive: Bool) {
        guard isScrollbarMotionActive != isActive else {
            return
        }
        isScrollbarMotionActive = isActive
        updateReportedNativeMotion()
    }

    private var hasActiveNativeMotion: Bool {
        isKeyboardMotionActive
            || isWheelMotionActive
            || activeKeyboardRequest != nil
            || activeWheelTargetOrdinal != nil
            || preciseGestureStartOrdinal != nil
            || isScrollbarDragging
            || keyboardAnimator.isRunning
            || wheelAnimator.isRunning
    }

    private func updateReportedNativeMotion() {
        let isActive = isKeyboardMotionActive
            || isWheelMotionActive
            || isScrollbarMotionActive
        guard reportedNativeMotionActive != isActive else {
            return
        }
        reportedNativeMotionActive = isActive
        onNativeMotionGateChanged(isActive)
        motionCallbackGeneration += 1
        let generation = motionCallbackGeneration
        motionCallbackTask?.cancel()
        motionCallbackTask = Task { @MainActor [weak self] in
            guard let self,
                  !Task.isCancelled,
                  self.motionCallbackGeneration == generation,
                  self.reportedNativeMotionActive == isActive
            else {
                return
            }
            self.motionCallbackTask = nil
            self.onKeyboardMotionChanged(isActive)
        }
    }
}

typealias PlaybackVirtualReelContainerView =
    PlaybackSubtitleFocusReelContainerView

private final class PlaybackSubtitleFocusNativeScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }
}

private final class PlaybackSubtitleFocusNativeScrollbarView:
    TableScrollbarOverlayView
{
    var allowsInteraction: () -> Bool = { false }
    var acceptsInteraction = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard acceptsInteraction, allowsInteraction() else {
            return nil
        }
        return super.hitTest(point)
    }
}
