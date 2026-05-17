import SwiftUI

struct PlaybackPageView: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppState
    let onClose: () -> Void
    @State private var activePanel: PlaybackDrawerKind = .results

    var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = playbackSidebarWidth(
                totalWidth: geometry.size.width,
                isVisible: appState.isPlaybackSidePanelVisible
            )
            let stageWidth = max(0, geometry.size.width - sidebarWidth)

            HStack(spacing: 0) {
                PlaybackVideoStage(
                    playbackSurface: playbackSurface,
                    appState: appState,
                    onClose: onClose
                )
                .frame(width: stageWidth, height: geometry.size.height)

                if sidebarWidth > 0 {
                    PlaybackSidebarShell(
                        appState: appState,
                        activePanel: $activePanel
                    )
                    .frame(width: sidebarWidth, height: geometry.size.height)
                    .transition(.opacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
        .background(Color.black)
        .onAppear {
            refreshSidebarData()
            if let request = appState.playbackDrawerRequest {
                activePanel = request.drawer
            }
        }
        .onChange(of: appState.playbackDrawerRequest?.id) { _ in
            guard let request = appState.playbackDrawerRequest else {
                return
            }

            activePanel = request.drawer
            refreshSidebarData()
        }
        .onChange(of: appState.currentPlaybackSubtitlePath) { _ in
            refreshSidebarData()
        }
    }

    private func refreshSidebarData() {
        appState.refreshSearchNavigationSnapshot()
        appState.refreshCurrentSubtitleEntries()
    }

    private func playbackSidebarWidth(totalWidth: CGFloat, isVisible: Bool) -> CGFloat {
        guard isVisible else {
            return 0
        }

        let maximumPanelWidth: CGFloat = 380
        let minimumPanelWidth: CGFloat = 320
        let minimumStageWidth: CGFloat = 520
        let availablePanelWidth = totalWidth - minimumStageWidth

        guard availablePanelWidth >= minimumPanelWidth else {
            return 0
        }

        return min(maximumPanelWidth, availablePanelWidth)
    }
}

private struct PlaybackVideoStage: View {
    let playbackSurface: AnyView
    @ObservedObject var appState: AppState
    let onClose: () -> Void

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

                PlaybackCloseButton(action: onClose)
                    .offset(x: frame.minX + 18, y: frame.minY + 18)

                if case .failed(let message) = appState.playbackStatus {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .offset(x: frame.minX + 18, y: frame.minY + 72)
                }

                PlaybackChromeShell()
                    .frame(
                        width: max(0, stageSize.width - PlaybackPageMetrics.chromeHorizontalInset * 2),
                        height: PlaybackPageMetrics.chromeHeight
                    )
                    .position(
                        x: stageSize.width / 2,
                        y: max(
                            PlaybackPageMetrics.chromeHeight / 2,
                            stageSize.height - PlaybackPageMetrics.chromeBottomInset - PlaybackPageMetrics.chromeHeight / 2
                        )
                    )
            }
            .frame(width: stageSize.width, height: stageSize.height)
            .clipped()
        }
    }

    private var videoAspectRatio: CGFloat {
        let ratio = CGFloat(appState.playbackViewModel?.videoAspectRatio ?? 16 / 9)
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

private struct PlaybackCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))

                Text("Close")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(height: 42)
            .padding(.leading, 13)
            .padding(.trailing, 16)
            .contentShape(Capsule())
        }
        .buttonStyle(PlaybackCloseButtonStyle())
        .accessibilityLabel("Close video")
    }
}

private struct PlaybackCloseButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .background(.ultraThinMaterial, in: Capsule())
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        Color.white.opacity(isHovered ? 0.24 : 0.16),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.42), radius: 20, y: 12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.72), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return Color(red: 0.14, green: 0.14, blue: 0.17).opacity(0.78)
        }
        if isHovered {
            return Color(red: 0.16, green: 0.16, blue: 0.19).opacity(0.72)
        }
        return Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.58)
    }
}

private struct PlaybackChromeShell: View {
    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.18))
                .frame(height: 4)
                .padding(.horizontal, 34)

            HStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 34, height: 34)

                Spacer()

                HStack(spacing: 18) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index == 2 ? Color.white.opacity(0.32) : Color.white.opacity(0.18))
                            .frame(width: index == 2 ? 42 : 34, height: index == 2 ? 42 : 34)
                    }
                }

                Spacer()

                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 160, height: 34)
            }
            .padding(.horizontal, 28)
        }
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.48))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.36), radius: 26, y: 14)
        .allowsHitTesting(false)
    }
}

private struct PlaybackSidebarShell: View {
    @ObservedObject var appState: AppState
    @Binding var activePanel: PlaybackDrawerKind

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
                        .fill(Color.black.opacity(0.06))
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
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 0.5)
            }

            Spacer(minLength: 0)
        }
        .background(
            Color(red: 0.972, green: 0.972, blue: 0.98).opacity(0.55)
                .background(.ultraThinMaterial)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 0.5)
        }
    }

    private func sidebarTab(_ panel: PlaybackDrawerKind, title: String) -> some View {
        Button {
            activePanel = panel
            switch panel {
            case .results:
                appState.refreshSearchNavigationSnapshot()
            case .subtitles:
                appState.refreshCurrentSubtitleEntries()
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: activePanel == panel ? .semibold : .medium))
                .foregroundStyle(activePanel == panel ? Color.primary.opacity(0.9) : Color.primary.opacity(0.48))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(activePanel == panel ? Color.white.opacity(0.85) : Color.clear)
                        .shadow(color: .black.opacity(activePanel == panel ? 0.08 : 0), radius: 2, y: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        switch activePanel {
        case .results:
            let groupedCount = appState.searchNavigationResultGroups.reduce(0) { $0 + $1.results.count }
            let fallbackCount = appState.searchResultTotalCount > 0
                ? appState.searchResultTotalCount
                : appState.searchResults.count
            let count = appState.searchNavigationSnapshot?.totalCount
                ?? (groupedCount > 0 ? groupedCount : fallbackCount)
            return "\(count) \(count == 1 ? "result" : "results")"
        case .subtitles:
            let count = appState.currentSubtitleEntries.count
            return "\(count) \(count == 1 ? "subtitle" : "subtitles")"
        }
    }
}

private enum PlaybackPageMetrics {
    static let chromeHorizontalInset: CGFloat = 20
    static let chromeBottomInset: CGFloat = 20
    static let chromeHeight: CGFloat = 106
}
