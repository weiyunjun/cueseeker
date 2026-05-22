import AppKit
import CueSeekerCore
import SwiftUI

struct PlaybackPageView: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppCoordinator
    let onClose: () -> Void
    @State private var activePanel: PlaybackDrawerKind = .results
    @EnvironmentObject private var playback: PlaybackStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var shiori: ShioriStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            // The video stage fills the whole window. The overlay panel floats
            // above it (centered, prototype geometry) and never squeezes it, so
            // toggling the panel cannot resize the video stage or disturb seek.
            ZStack(alignment: .top) {
                PlaybackVideoStage(
                    playbackSurface: playbackSurface,
                    appState: appState,
                    fullscreenManager: appState.playbackFullscreenManager,
                    onClose: onClose
                )
                .frame(width: geometry.size.width, height: geometry.size.height)

                overlayPanel(in: geometry.size)

                // The feedback HUD renders above the overlay panel and is
                // centered within the full-window black video base
                // (doc 12 §11/§13.4). It is the SwiftUI feedback layer only;
                // the native render/seek path is untouched.
                if let viewModel = playback.playbackViewModel {
                    PlaybackFeedbackLayer(viewModel: viewModel)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .onAppear {
            refreshSidebarData()
        }
        .onChange(of: appState.currentPlaybackSubtitlePath) { _ in
            refreshSidebarData()
        }
    }

    @ViewBuilder
    private func overlayPanel(in size: CGSize) -> some View {
        let visible = playback.isPlaybackSidePanelVisible
        let panelWidth = min(
            PlaybackOverlayPanelMetrics.maxWidth,
            max(0, size.width - PlaybackOverlayPanelMetrics.horizontalMargin * 2)
        )
        let panelHeight = max(
            0,
            size.height
                - PlaybackOverlayPanelMetrics.topInset
                - PlaybackOverlayPanelMetrics.bottomInset
        )

        PlaybackSidebarShell(appState: appState, activePanel: $activePanel)
            .frame(width: panelWidth, height: panelHeight)
            .background(overlayPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(overlayPanelBorder, lineWidth: 0.5)
            )
            .shadow(color: overlayPanelShadow, radius: 28, x: 0, y: 16)
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.98)
            .position(
                x: size.width / 2,
                y: PlaybackOverlayPanelMetrics.topInset + panelHeight / 2
            )
            .offset(y: visible ? 0 : 10)
            .allowsHitTesting(visible)
            .animation(.easeInOut(duration: 0.18), value: visible)
    }

    private var overlayPanelBackground: Color {
        colorScheme == .dark
            ? Color(red: 36 / 255, green: 34 / 255, blue: 43 / 255)
            : Color(red: 246 / 255, green: 246 / 255, blue: 247 / 255)
    }

    private var overlayPanelBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.10)
    }

    private var overlayPanelShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.65)
            : Color.black.opacity(0.45)
    }

    private func refreshSidebarData() {
        appState.refreshSearchNavigationSnapshot()
        appState.refreshCurrentSubtitleEntries()
    }
}

private struct PlaybackVideoStage: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var fullscreenManager: PlaybackFullscreenManager
    let onClose: () -> Void
    @EnvironmentObject private var playback: PlaybackStore
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var shiori: ShioriStore
    @EnvironmentObject private var layoutState: WorkbenchLayoutState
    @StateObject private var chrome = PlaybackChromeVisibilityModel()

    var body: some View {
        GeometryReader { geometry in
            let stageSize = geometry.size
            let frame = aspectFitFrame(
                containerSize: stageSize,
                aspectRatio: videoAspectRatio
            )

            ZStack(alignment: .topLeading) {
                Color.black

                playbackSurface
                    .frame(width: frame.width, height: frame.height)
                    .background(Color.black)
                    .position(x: frame.midX, y: frame.midY)

                if chrome.isPlayerUIVisible, !fullscreenManager.isFullscreen {
                    LiquidGlassVideoTopBar(
                        title: appState.currentPlaybackDisplayTitle,
                        onClose: onClose,
                        onMinimize: { appState.minimizePlaybackWindowFromUser() },
                        onZoom: { appState.togglePlaybackFullscreenFromUser() }
                    )
                    .frame(
                        width: stageSize.width,
                        height: PlaybackChromeMetrics.videoTopBarHeight
                    )
                    .position(
                        x: stageSize.width / 2,
                        y: PlaybackChromeMetrics.videoTopBarHeight / 2
                    )
                }

                if case .failed(let message) = playback.playbackStatus {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .offset(x: frame.minX + 18, y: frame.minY + 72)
                }

                if chrome.isPlayerUIVisible, let viewModel = playback.playbackViewModel {
                    PlaybackChromeView(
                        viewModel: viewModel,
                        controls: .appState(appState)
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
            .onAppear {
                chrome.enterVideoPage()
            }
            .onDisappear {
                chrome.leaveVideoPage()
            }
            .onChange(of: fullscreenManager.state) { newState in
                if newState == .enteringSystemFullscreen || newState == .activeFullscreen {
                    chrome.enteringFullscreen()
                }
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


/// The overlay-panel Subtitles tab: the current subtitle file in timestamp
/// order. Observes the view model so the active-cue selection follows the
/// rate-limited displayed time (not the frame-cadence clock).
struct PlaybackSubtitlesList: View {
    @ObservedObject var appState: AppCoordinator
    @ObservedObject var viewModel: PlaybackViewModel
    @EnvironmentObject private var playback: PlaybackStore

    private var orderedEntries: [SubtitleDatabaseEntry] {
        playback.currentSubtitleEntries
    }

    /// The cue active at the current displayed time: the entry that contains
    /// it, otherwise the last entry that has already started (handles gaps).
    private var activeEntryID: Int64? {
        let ms = Int((viewModel.displayedCurrentTime * 1_000).rounded(.down))
        return playback.currentSubtitleEntryLookup.activeEntryID(atMilliseconds: ms)
    }

    var body: some View {
        let entries = orderedEntries
        let activeID = activeEntryID
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(entries, id: \.id) { entry in
                        PlaybackSidebarSubtitleRow(
                            entry: entry,
                            isSelected: entry.id == activeID,
                            onSeek: {
                                appState.seekCurrentPlayback(
                                    toMilliseconds: entry.startMilliseconds
                                )
                            }
                        )
                        .id(entry.id)
                    }
                }
                .padding(EdgeInsets(top: 6, leading: 8, bottom: 14, trailing: 8))
            }
            .onAppear { scrollActiveIntoView(proxy, id: activeID) }
            .onChange(of: activeID) { newValue in
                scrollActiveIntoView(proxy, id: newValue)
            }
        }
    }

    private func scrollActiveIntoView(_ proxy: ScrollViewProxy, id: Int64?) {
        guard let id else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}

/// One Subtitles row, mirroring the prototype `.sidebar-row`: a timestamp meta
/// line above the cue lines. No rank and no keyword highlight (doc 12 §11).
private struct PlaybackSidebarSubtitleRow: View {
    let entry: SubtitleDatabaseEntry
    let isSelected: Bool
    let onSeek: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: onSeek) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTimestamp(entry.startMilliseconds))
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(metaColor)

                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(lineColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? selectedRingColor : Color.clear, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var displayLines: [String] {
        subtitleDisplayLines(content: entry.content, cueLines: [])
    }

    private var lineColor: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color(red: 248 / 255, green: 246 / 255, blue: 251 / 255)
                : Color(red: 10 / 255, green: 20 / 255, blue: 38 / 255)
        }
        return Color.primary.opacity(0.86)
    }

    private var metaColor: Color {
        isSelected ? accentColor : Color.primary.opacity(0.45)
    }

    private var accentColor: Color {
        colorScheme == .dark
            ? Color(red: 110 / 255, green: 166 / 255, blue: 255 / 255)
            : Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    }

    private var selectedRingColor: Color {
        accentColor.opacity(colorScheme == .dark ? 0.52 : 0.55)
    }

    private var rowBackground: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.85)
        }
        if isHovered {
            return colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.55)
        }
        return Color.clear
    }
}

