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

struct PlaybackChromeSpeedMenu: View {
    let selectedSpeed: Double
    let onSelect: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(PlaybackViewModel.speedPresets, id: \.self) { speed in
                Button {
                    onSelect(speed)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .opacity(abs(selectedSpeed - speed) < 0.01 ? 1 : 0)
                            .frame(width: 14)

                        Text(PlaybackViewModel.formatSpeed(speed))
                            .font(.system(size: 13, weight: abs(selectedSpeed - speed) < 0.01 ? .bold : .medium))
                            .monospacedDigit()

                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 8)
                    .frame(width: 160, height: 30)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlaybackChromeMenuButtonStyle(isSelected: abs(selectedSpeed - speed) < 0.01))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.86))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.42), radius: 24, y: 12)
    }
}

enum PlaybackChromeButtonKind {
    case circle
    case transport
    case primaryTransport

    var size: CGFloat {
        switch self {
        case .circle:
            return 32
        case .transport:
            return 40
        case .primaryTransport:
            return 44
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .circle:
            return 15
        case .transport:
            return 18
        case .primaryTransport:
            return 20
        }
    }
}

enum PlaybackChromeIcon {
    case system(String)
    case copy
}

struct PlaybackChromeIconButton: View {
    let icon: PlaybackChromeIcon
    var kind: PlaybackChromeButtonKind = .circle
    var isSelected = false
    var isDisabled = false
    let accessibilityLabel: String
    let action: () -> Void

    init(
        systemName: String,
        kind: PlaybackChromeButtonKind = .circle,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = .system(systemName)
        self.kind = kind
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    init(
        icon: PlaybackChromeIcon,
        kind: PlaybackChromeButtonKind = .circle,
        isSelected: Bool = false,
        isDisabled: Bool = false,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.kind = kind
        self.isSelected = isSelected
        self.isDisabled = isDisabled
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            PlaybackChromeIconView(icon: icon, size: kind.symbolSize)
                .frame(width: kind.size, height: kind.size)
                .contentShape(Circle())
        }
        .buttonStyle(PlaybackChromeIconButtonStyle(kind: kind, isSelected: isSelected))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.34 : 1)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PlaybackChromeIconView: View {
    let icon: PlaybackChromeIcon
    let size: CGFloat

    var body: some View {
        switch icon {
        case .system(let systemName):
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
        case .copy:
            PlaybackCopyGlyph()
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 17, height: 17)
        }
    }
}

struct PlaybackCopyGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 17
        let scaleY = rect.height / 17

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        func scaledRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
            CGRect(
                x: rect.minX + x * scaleX,
                y: rect.minY + y * scaleY,
                width: width * scaleX,
                height: height * scaleY
            )
        }

        var path = Path()
        path.addRoundedRect(
            in: scaledRect(x: 3.2, y: 5.2, width: 8.1, height: 9.2),
            cornerSize: CGSize(width: 1.2 * scaleX, height: 1.2 * scaleY)
        )
        path.move(to: point(6, 2.6))
        path.addLine(to: point(12.4, 2.6))
        path.addCurve(
            to: point(13.8, 4.0),
            control1: point(12.4, 2.6),
            control2: point(13.8, 2.6)
        )
        path.addLine(to: point(13.8, 11.2))
        return path
    }
}

private struct PlaybackChromeIconButtonStyle: ButtonStyle {
    let kind: PlaybackChromeButtonKind
    let isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .background(materialBackground(isPressed: configuration.isPressed))
            )
            .overlay(
                Circle()
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        guard isEnabled else {
            return .white.opacity(0.46)
        }
        return isSelected ? Color(red: 0.10, green: 0.10, blue: 0.12) : .white.opacity(0.96)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return .clear
        }
        if isSelected {
            return Color.white.opacity(isPressed ? 0.82 : 0.92)
        }
        if isHovered || isPressed {
            return Color.white.opacity(isPressed ? 0.14 : 0.18)
        }
        return .clear
    }

    @ViewBuilder
    private func materialBackground(isPressed: Bool) -> some View {
        if isEnabled && (isHovered || isSelected || isPressed) {
            Circle()
                .fill(.ultraThinMaterial)
        }
    }

    private var borderColor: Color {
        guard isEnabled else {
            return .clear
        }
        if isSelected {
            return Color.white.opacity(0.7)
        }
        return isHovered ? Color.white.opacity(0.10) : .clear
    }

    private var shadowColor: Color {
        isSelected ? Color.black.opacity(0.22) : Color.black.opacity(0)
    }

    private var shadowRadius: CGFloat {
        isSelected ? 4 : 0
    }

    private var shadowY: CGFloat {
        isSelected ? 1 : 0
    }
}

private struct PlaybackChromeMenuButtonStyle: ButtonStyle {
    let isSelected: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed || isHovered {
            return Color.white.opacity(0.14)
        }
        if isSelected {
            return Color.white.opacity(0.10)
        }
        return .clear
    }
}

struct PlaybackSidebarShell: View {
    @ObservedObject var appState: AppCoordinator
    @Binding var activePanel: PlaybackDrawerKind
    @EnvironmentObject private var search: SearchStore
    @EnvironmentObject private var playback: PlaybackStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 2) {
                    sidebarTab(.results, title: "Search Results")
                    sidebarTab(.subtitles, title: "Subtitles")
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(segmentedContainerColor)
                )

                Text(summaryText)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.42))
                    .monospacedDigit()
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(headerHairlineColor)
                    .frame(height: 0.5)
            }

            content
        }
        // The opaque rounded surface, border, and shadow are owned by the
        // floating container in PlaybackPageView. The shell only renders
        // content; it no longer draws the old squeeze-era background or the
        // left divider.
    }

    @ViewBuilder
    private var content: some View {
        if playback.isPlaybackSidePanelVisible {
            switch activePanel {
            case .results:
                searchResultsList
            case .subtitles:
                if let viewModel = playback.playbackViewModel {
                    PlaybackSubtitlesList(appState: appState, viewModel: viewModel)
                } else {
                    Spacer(minLength: 0)
                }
            }
        } else {
            Spacer(minLength: 0)
        }
    }

    private var searchResultsList: some View {
        let rows = flattenedResultRows
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows, id: \.result.entryID) { row in
                        PlaybackSidebarResultRow(
                            rank: row.rank,
                            result: row.result,
                            query: search.searchQuery,
                            isSelected: row.result.entryID
                                == search.selectedSearchResult?.entryID,
                            onOpen: { appState.openSearchResult(row.result) }
                        )
                        .id(row.result.entryID)
                    }
                }
                .padding(EdgeInsets(top: 6, leading: 8, bottom: 14, trailing: 8))
            }
            .onAppear { scrollSelectedIntoView(proxy) }
            .onChange(of: search.selectedSearchResult?.entryID) { _ in
                scrollSelectedIntoView(proxy)
            }
        }
    }

    private func scrollSelectedIntoView(_ proxy: ScrollViewProxy) {
        guard let id = search.selectedSearchResult?.entryID else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    /// The complete active Search result order, flattened across file groups
    /// with a global one-based rank to mirror the prototype `.sidebar-list`.
    /// Reads only the published navigation groups, so result-to-result jumps
    /// never clear the list while the current Search result list is valid.
    private var flattenedResultRows: [(rank: Int, result: SubtitleSearchResult)] {
        var rows: [(rank: Int, result: SubtitleSearchResult)] = []
        var rank = 1
        for group in search.searchNavigationResultGroups {
            for result in group.results {
                rows.append((rank: rank, result: result))
                rank += 1
            }
        }
        return rows
    }

    private func sidebarTab(_ panel: PlaybackDrawerKind, title: String) -> some View {
        let isActive = activePanel == panel
        return Button {
            activePanel = panel
            switch panel {
            case .results:
                appState.refreshSearchNavigationSnapshot()
            case .subtitles:
                appState.refreshCurrentSubtitleEntries()
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.primary.opacity(0.9) : Color.primary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isActive ? segmentedActiveColor : Color.clear)
                        .shadow(
                            color: isActive ? segmentedActiveShadow : .clear,
                            radius: 2,
                            y: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        switch activePanel {
        case .results:
            let groupedCount = search.searchNavigationResultGroups.reduce(0) { $0 + $1.results.count }
            let fallbackCount = search.searchResultTotalCount > 0
                ? search.searchResultTotalCount
                : search.searchResults.count
            let count = search.searchNavigationSnapshot?.totalCount
                ?? (groupedCount > 0 ? groupedCount : fallbackCount)
            return "\(count) \(count == 1 ? "result" : "results")"
        case .subtitles:
            let count = playback.currentSubtitleEntries.count
            return "\(count) \(count == 1 ? "subtitle" : "subtitles")"
        }
    }

    // Scheme-aware tokens mirroring the v6 prototype segmented control and
    // header hairline (doc 12 §11, doc 11 §5). Fixes the dark-mode misalignment
    // where the previous hardcoded light values left an opaque white pill and
    // invisible black hairlines.
    private var segmentedContainerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var segmentedActiveColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.85)
    }

    private var segmentedActiveShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.30) : Color.black.opacity(0.08)
    }

    private var headerHairlineColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }
}

/// One Search Results row in the overlay panel, mirroring the prototype
/// `.sidebar-row`: a meta line (global rank + timestamp) above the cue lines,
/// with query-match highlighting reused from the info-page Search renderer.
private struct PlaybackSidebarResultRow: View {
    let rank: Int
    let result: SubtitleSearchResult
    let query: String
    let isSelected: Bool
    let onOpen: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(rank)")
                    Text(formatTimestamp(result.startMilliseconds))
                }
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(metaColor)

                ForEach(Array(displayLines.enumerated()), id: \.offset) { _, line in
                    Text(highlightedContent(
                        line,
                        query: query,
                        textColor: lineColor,
                        state: highlightState
                    ))
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
        subtitleDisplayLines(content: result.content, cueLines: result.cueLines)
    }

    private var highlightState: SearchHighlightState {
        isSelected ? .selected : (isHovered ? .hover : .default)
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

/// The overlay-panel Subtitles tab: the current subtitle file in timestamp
/// order. Observes the view model so the active-cue selection follows the
/// rate-limited displayed time (not the frame-cadence clock).
private struct PlaybackSubtitlesList: View {
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

/// Hosts the playback feedback HUD above the centered overlay panel so command
/// feedback is never occluded by it (doc 12 §11/§13.4, doc 11 §6). This is the
/// v6 prototype `.sidebar` geometry: a centered floating overlay that never
/// squeezes the video — `top: 64px; bottom: 104px; left: 50%;
/// width: min(420px, calc(100% - 48px))`.
enum PlaybackOverlayPanelMetrics {
    static let topInset: CGFloat = 64
    static let bottomInset: CGFloat = 104
    static let horizontalMargin: CGFloat = 24
    static let maxWidth: CGFloat = 420
}
