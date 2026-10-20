import SwiftUI

struct PlaybackVideoStage: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    /// A playback layer is open above the stage. The window controls stay
    /// shown for it even while the Player UI is hidden.
    let isLayerOpen: Bool
    let onClose: () -> Void
    @EnvironmentObject private var playback: PlaybackStore
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @Environment(\.isDialogOpen) private var isDialogOpen
    @StateObject private var chrome = PlaybackChromeVisibilityModel()

    var body: some View {
        GeometryReader { geometry in
            let stageSize = geometry.size
            let frame = aspectFitFrame(
                containerSize: stageSize,
                aspectRatio: videoAspectRatio
            )
            let chromeSnapshot = playback.chromeSnapshot
            let isFullscreenToggleDisabled = !chromeSnapshot.hasPlaybackSelection
                || layoutState.isVideoSizeTransitionInProgress
                || fullscreenManager.isTransitioning
            // Fullscreen keeps the bar; only the window controls leave, to the
            // system titlebar.
            let isTopBarVisible = chrome.isPlayerUIVisible
            let isBottomChromeVisible = chrome.isPlayerUIVisible
            let areWindowControlsVisible = chrome.isPlayerUIVisible || isLayerOpen
            let isSameWindowLayerOpen = isLayerOpen || isDialogOpen
            let stageTapRect = PlaybackChromeMetrics.stageTapInteractiveRect(
                stageSize: stageSize,
                isPlayerUIVisible: chrome.isPlayerUIVisible
            )

            ZStack(alignment: .topLeading) {
                Color.black

                playbackSurface
                    .frame(width: frame.width, height: frame.height)
                    .background(Color.black)
                    .position(x: frame.midX, y: frame.midY)
                    .allowsHitTesting(false)

                Button {
                    appState.workbenchLayout.clearSearchFocus()
                    appState.togglePlaybackFromUser()
                } label: {
                    Color.clear
                        .frame(width: stageTapRect.width, height: stageTapRect.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(StaticButtonStyle())
                .focusable(false)
                .position(x: stageTapRect.midX, y: stageTapRect.midY)

                LiquidGlassVideoTopBar(
                    title: chromeSnapshot.displayTitle,
                    onReturn: onClose
                )
                .frame(
                    width: stageSize.width,
                    height: WorkbenchControlMetrics.redesignAppTopbarHeight
                )
                .position(
                    x: stageSize.width / 2,
                    y: WorkbenchControlMetrics.redesignAppTopbarHeight / 2
                )
                .opacity(isTopBarVisible ? 1 : 0)
                .allowsHitTesting(isTopBarVisible)
                .accessibilityHidden(!isTopBarVisible)
                .environment(\.isPlayerUIVisible, isTopBarVisible)

                if let viewModel = playback.playbackViewModel {
                    PlaybackChromeView(
                        playback: playback,
                        viewModel: viewModel,
                        timeline: playback.timeline,
                        controls: .appState(
                            appState,
                            snapshot: chromeSnapshot,
                            isFullscreen: fullscreenManager.isFullscreen,
                            isFullscreenToggleDisabled: isFullscreenToggleDisabled
                        )
                    )
                    .frame(
                        width: max(0, stageSize.width - PlaybackChromeMetrics.horizontalInset * 2),
                        height: PlaybackChromeMetrics.interactiveHeight,
                        alignment: .bottom
                    )
                    .position(
                        x: stageSize.width / 2,
                        y: max(
                            PlaybackChromeMetrics.interactiveHeight / 2,
                            stageSize.height - PlaybackChromeMetrics.bottomInset - PlaybackChromeMetrics.interactiveHeight / 2
                        )
                    )
                    .opacity(isBottomChromeVisible ? 1 : 0)
                    .allowsHitTesting(isBottomChromeVisible)
                    .accessibilityHidden(!isBottomChromeVisible)
                    .environment(\.isPlayerUIVisible, isBottomChromeVisible)
                }

                PlaybackChromeTrackingView(
                    onViewChanged: { chrome.updatePlayerAreaView($0) },
                    onEntered: { chrome.pointerEnteredPlayerArea(view: $0) },
                    onMoved: { chrome.pointerMovedInPlayerArea(view: $0) },
                    onExited: { chrome.pointerExitedPlayerArea(view: $0) }
                )
                .frame(width: stageSize.width, height: stageSize.height)
                .allowsHitTesting(false)
            }
            .frame(width: stageSize.width, height: stageSize.height)
            .clipped()
            // Laid over the whole stage, ahead of the clickable controls'
            // report below, so its items report among them.
            .overlayPreferenceValue(PlaybackMoreButtonAnchorKey.self) { anchor in
                moreMenuOverlay(anchor: anchor)
            }
            // The clickable controls report their frames: the pointer resting
            // on one keeps the Player UI.
            .overlayPreferenceValue(PlayerInteractiveRegionKey.self) { anchors in
                GeometryReader { proxy in
                    let frames = anchors.map { proxy[$0] }
                    Color.clear
                        .onAppear { chrome.setInteractiveFrames(frames) }
                        .onChange(of: frames) { chrome.setInteractiveFrames($0) }
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                chrome.enterVideoPage()
                chrome.setLayerOpen(isSameWindowLayerOpen)
                playback.pointerVisibility.setVisible(chrome.isPointerVisible)
                AppWindowControls.place(.playback(isVisible: areWindowControlsVisible))
                appState.playbackPageDidAppear()
            }
            .onChange(of: playback.playbackStatus) { status in
                // The More menu lists the open video's tracks; another video
                // opening takes the menu with it.
                if status.isOpening {
                    playback.closeMoreMenu()
                }
            }
            .onDisappear {
                playback.closeMoreMenu()
                chrome.leaveVideoPage()
                playback.pointerVisibility.setVisible(false)
                AppWindowControls.place(.workbench)
            }
            .onChange(of: areWindowControlsVisible) { isVisible in
                AppWindowControls.place(.playback(isVisible: isVisible))
            }
            .onChange(of: isSameWindowLayerOpen) { isOpen in
                chrome.setLayerOpen(isOpen)
            }
            .onReceive(playback.timeline.$isScrubbing) { isScrubbing in
                chrome.setDragging(isScrubbing || playback.timeline.isDraggingVolume)
            }
            .onReceive(playback.timeline.$isDraggingVolume) { isDraggingVolume in
                chrome.setDragging(playback.timeline.isScrubbing || isDraggingVolume)
            }
            .onChange(of: chrome.isPlayerUIVisible) { isVisible in
                // A hidden Player UI takes its menus and tooltips with it.
                if !isVisible {
                    playback.closeSpeedMenu()
                    playback.closeMoreMenu()
                    TooltipCenter.shared.dismiss()
                }
            }
            .onReceive(playback.pointerHideRequests) {
                chrome.pointerHideRequested()
            }
            .onChange(of: chrome.isPointerVisible) { isVisible in
                playback.pointerVisibility.setVisible(isVisible)
            }
            .onChange(of: fullscreenManager.state) { newState in
                if newState == .enteringSystemFullscreen || newState == .activeFullscreen {
                    chrome.enteringFullscreen()
                }
            }
        }
    }

    @ViewBuilder
    private func moreMenuOverlay(anchor: Anchor<CGRect>?) -> some View {
        if let menu = playback.moreMenu, let anchor {
            GeometryReader { proxy in
                PlaybackChromeMoreMenuOverlay(
                    playback: playback,
                    submenuState: playback.moreSubmenuState,
                    menu: menu,
                    buttonFrame: proxy[anchor],
                    suppressesInteraction: playback.timeline.isScrubbing
                        || playback.interfaceLayers.isOpen(.commandPanel),
                    onSelect: { submenu, index in
                        switch submenu {
                        case .audioTrack:
                            appState.selectPlaybackAudioTrack(index)
                        case .subtitle:
                            appState.selectPlaybackSubtitle(index)
                        case .defaultAudioTrack:
                            appState.setPlaybackDefaultAudioTrack(index)
                        case .defaultSubtitle:
                            appState.setPlaybackDefaultSubtitle(index)
                        }
                    }
                )
            }
        }
    }

    private var videoAspectRatio: CGFloat {
        let ratio = CGFloat(playback.playbackViewModel?.videoAspectRatio ?? 16 / 9)
        return ratio.isFinite && ratio > 0 ? ratio : 16 / 9
    }

    private func aspectFitFrame(containerSize: CGSize, aspectRatio: CGFloat) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let containerRatio = containerSize.width / containerSize.height
        let frameSize: CGSize
        if containerRatio > aspectRatio {
            let height = containerSize.height
            frameSize = CGSize(width: height * aspectRatio, height: height)
        } else {
            let width = containerSize.width
            frameSize = CGSize(width: width, height: width / aspectRatio)
        }

        return CGRect(
            x: (containerSize.width - frameSize.width) / 2,
            y: (containerSize.height - frameSize.height) / 2,
            width: frameSize.width,
            height: frameSize.height
        )
    }
}
