import SwiftUI

struct PlaybackCueResultOverlay: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    @ObservedObject var windowStore: PlaybackCueResultSessionWindowStore
    let module: PlaybackOverlayModule
    let showsSequenceNumber: Bool
    var contentTopInset = PlaybackSubtitleFocusMetrics.contentInset
    var contentBottomInset = PlaybackSubtitleFocusMetrics.contentInset
    let uiProbeScope: String?
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool

    @EnvironmentObject private var cueGroupPresentation: CueGroupPresentationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let viewportSize = geometry.size
            let reelViewportHeight = max(
                0,
                viewportSize.height - contentTopInset - contentBottomInset
            )
            let blocksInteraction = session.pendingKeyboardAction != nil
                || session.activeKeyboardAction != nil
                || session.keyboardNavigationRequest != nil

            ZStack(alignment: .top) {
                PlaybackTheme.subtitleFocusOverlayBackground

                PlaybackCueResultReelRepresentable(
                    windowStore: windowStore,
                    showsCueGroup: cueGroupPresentation.isEnabled,
                    showsSequenceNumber: showsSequenceNumber,
                    selectedOrdinal: windowStore.selectedOrdinal,
                    uiProbeScope: uiProbeScope,
                    keyboardNavigationRequest: session.keyboardNavigationRequest,
                    reducesMotion: reduceMotion,
                    isInteractionEnabled: !blocksInteraction,
                    cancelsWheelMotion: session.keyboardNavigationRequest != nil,
                    onCommitSelection: commitReelSelection,
                    allowsNativeWheelInput: session.allowsNativeWheelInput,
                    allowsNativeScrollbarInput: session.allowsNativeScrollbarInput,
                    onScrollbarDraggingChanged: { isDragging in
                        session.noteScrollbarDragging(isDragging, module: module)
                        if !isDragging {
                            executeDeferredActionIfReady()
                        }
                    },
                    onNativeMotionGateChanged: handleReelMotionChanged,
                    onKeyboardMotionChanged: handleReelMotionChanged
                )
                .id("\(module.rawValue):\(windowStore.reelDatasetID ?? "empty")")
                .frame(
                    width: viewportSize.width,
                    height: reelViewportHeight,
                    alignment: .top
                )
                .offset(y: contentTopInset)
            }
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipped()
            .contentShape(Rectangle())
        }
        .onDisappear {
            session.noteCueReelMotion(false, module: module)
            session.noteScrollbarDragging(false, module: module)
        }
        .onChange(of: windowStore.snapshot) { _ in
            Task { @MainActor in
                executeDeferredActionIfReady()
            }
        }
    }

    private func handleReelMotionChanged(_ isActive: Bool) {
        session.noteCueReelMotion(isActive, module: module)
        if !isActive {
            executeDeferredActionIfReady()
        }
    }

    private func commitReelSelection(
        _ commit: PlaybackVirtualReelSelectionCommit
    ) -> Bool {
        let didCommit = session.commitVirtualReelSelection(
            commit,
            module: module
        )
        if didCommit {
            Task { @MainActor in
                executeDeferredActionIfReady()
            }
        }
        return didCommit
    }

    private func executeDeferredActionIfReady() {
        guard let execution = session.consumeDeferredKeyboardActionIfReady(
            module: module
        ) else {
            return
        }
        _ = onExecuteAction(execution)
    }
}

@MainActor
private struct PlaybackCueResultReelRepresentable: NSViewRepresentable {
    @MainActor
    final class Coordinator {
        let adapter: PlaybackCueResultReelAdapter

        init(
            windowStore: PlaybackCueResultSessionWindowStore,
            showsCueGroup: Bool,
            showsSequenceNumber: Bool
        ) {
            adapter = PlaybackCueResultReelAdapter(
                windowStore: windowStore,
                showsCueGroup: showsCueGroup,
                showsSequenceNumber: showsSequenceNumber
            )
        }
    }

    let windowStore: PlaybackCueResultSessionWindowStore
    let showsCueGroup: Bool
    let showsSequenceNumber: Bool
    let selectedOrdinal: Int?
    let uiProbeScope: String?
    let keyboardNavigationRequest: PlaybackSubtitleFocusKeyboardNavigationRequest?
    let reducesMotion: Bool
    let isInteractionEnabled: Bool
    let cancelsWheelMotion: Bool
    let onCommitSelection: (PlaybackVirtualReelSelectionCommit) -> Bool
    let allowsNativeWheelInput: () -> Bool
    let allowsNativeScrollbarInput: () -> Bool
    let onScrollbarDraggingChanged: (Bool) -> Void
    let onNativeMotionGateChanged: (Bool) -> Void
    let onKeyboardMotionChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            windowStore: windowStore,
            showsCueGroup: showsCueGroup,
            showsSequenceNumber: showsSequenceNumber
        )
    }

    func makeNSView(context: Context) -> PlaybackSubtitleFocusReelContainerView {
        UIInvalidationProbe.count(
            "playback.cue_result.native_make",
            scope: uiProbeScope
        )
        let view = PlaybackSubtitleFocusReelContainerView()
        update(view, adapter: context.coordinator.adapter)
        return view
    }

    func updateNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        context: Context
    ) {
        UIInvalidationProbe.count(
            "playback.cue_result.native_update",
            scope: uiProbeScope
        )
        update(nsView, adapter: context.coordinator.adapter)
    }

    static func dismantleNSView(
        _ nsView: PlaybackSubtitleFocusReelContainerView,
        coordinator: Coordinator
    ) {
        nsView.invalidate()
    }

    private func update(
        _ view: PlaybackSubtitleFocusReelContainerView,
        adapter: PlaybackCueResultReelAdapter
    ) {
        _ = adapter.setShowsCueGroup(showsCueGroup)
        view.uiProbeScope = uiProbeScope
        view.onCommitVirtualReelSelection = onCommitSelection
        view.allowsNativeWheelInput = allowsNativeWheelInput
        view.allowsNativeScrollbarInput = allowsNativeScrollbarInput
        view.onScrollbarDraggingChanged = onScrollbarDraggingChanged
        view.onNativeMotionGateChanged = onNativeMotionGateChanged
        view.onKeyboardMotionChanged = onKeyboardMotionChanged
        view.update(
            contentAdapter: adapter,
            selectedOrdinal: selectedOrdinal,
            keyboardNavigationRequest: keyboardNavigationRequest,
            reducesMotion: reducesMotion,
            isInteractionEnabled: isInteractionEnabled,
            cancelsWheelMotion: cancelsWheelMotion
        )
    }
}
