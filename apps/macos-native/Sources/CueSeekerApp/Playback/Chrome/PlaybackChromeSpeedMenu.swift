import AppKit
import SwiftUI

struct PlaybackChromeSpeedMenuOverlay: View {
    @ObservedObject var playback: PlaybackStore
    @ObservedObject var viewModel: PlaybackViewModel
    let buttonFrame: CGRect
    let suppressesInteraction: Bool

    var body: some View {
        GeometryReader { proxy in
            let bounds = PlaybackChromeMoreMenuOverlay.bounds(
                stageSize: proxy.size,
                buttonFrame: buttonFrame
            )
            let maximumHeight = min(MenuMetrics.maximumHeight, bounds.height)
            let menuView = PlaybackChromeSpeedMenu(
                selectedSpeed: viewModel.playbackSpeed,
                maximumHeight: maximumHeight,
                suppressesInteraction: suppressesInteraction,
                highlight: playback.speedMenuHighlight,
                onSelect: { speed in
                    viewModel.setSpeed(speed)
                    playback.closeSpeedMenu()
                }
            )
            let menuSize = NSHostingView(rootView: menuView).fittingSize
            let menuFrame = MenuPlacement.openingFrame(
                anchor: buttonFrame,
                menuSize: menuSize,
                in: bounds,
                gap: PlaybackChromeMetrics.speedMenuGap
            )

            ZStack(alignment: .topLeading) {
                MenuGateClientView(
                    gate: playback.interfaceLayers.menuGate,
                    owner: .playbackPage,
                    kind: .playerSpeedMenu,
                    menuFrame: menuFrame,
                    // A press on the speed button is left to the button,
                    // which toggles the menu itself.
                    anchorFrame: buttonFrame,
                    handleKey: { keyCode, isRepeat in
                        playback.handleSpeedMenuKey(
                            keyCode,
                            isRepeat: isRepeat
                        )
                    },
                    dismiss: { _ in
                        DispatchQueue.main.async {
                            playback.closeSpeedMenu()
                        }
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(false)

                PlaybackMoreMenuHost(content: AnyView(menuView))
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .offset(x: menuFrame.minX, y: menuFrame.minY)

                Color.clear
                    .frame(width: menuFrame.width, height: menuFrame.height)
                    .playerInteractiveRegion()
                    .offset(x: menuFrame.minX, y: menuFrame.minY)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct PlaybackChromeSpeedMenu: View {
    let selectedSpeed: Double
    var maximumHeight: CGFloat = MenuMetrics.maximumHeight
    var suppressesInteraction = false
    @ObservedObject var highlight: MenuHighlightModel
    let onSelect: (Double) -> Void

    var body: some View {
        WorkbenchPopoverPanel(
            surface: .playerChrome,
            maximumHeight: maximumHeight,
            highlight: highlight
        ) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(
                    Array(PlaybackViewModel.speedPresets.enumerated()),
                    id: \.element
                ) { position, speed in
                    Button {
                        guard !suppressesInteraction else {
                            return
                        }
                        onSelect(speed)
                    } label: {
                        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
                            AppIconImage(
                                .check,
                                size: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                            )
                            .opacity(abs(selectedSpeed - speed) < 0.01 ? 1 : 0)
                            .frame(
                                width: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS,
                                height: WorkbenchControlMetrics.redesignMenuItemSymbolFontSizeMacOS
                            )

                            Text(PlaybackViewModel.formatSpeed(speed))
                                .font(.system(
                                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                                    weight: .medium
                                ))
                                .monospacedDigit()

                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(PlaybackTheme.textPrimary)
                        .padding(.horizontal, WorkbenchControlMetrics.redesignMenuItemHorizontalPadding)
                        .frame(maxWidth: .infinity)
                        .frame(height: WorkbenchControlMetrics.redesignMenuItemHeight)
                        .contentShape(
                            RoundedRectangle(
                                cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(
                        PlaybackChromeMenuButtonStyle(
                            isHighlighted: highlight.isSelected(position),
                            isHovered: highlight.isHovered(position),
                            suppressesInteraction: suppressesInteraction,
                            onHoverChange: { isHovered in
                                highlight.noteHover(isHovered, at: position)
                            }
                        )
                    )
                    .focusable(false)
                    .id(position)
                }
            }
        }
    }
}

struct PlaybackChromeMenuButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    var isHovered: Bool = false
    let suppressesInteraction: Bool
    let onHoverChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(
                    cornerRadius: WorkbenchControlMetrics.redesignMenuItemRadius,
                    style: .continuous
                )
                .fill(backgroundColor)
            )
            .onHover { isHovered in
                onHoverChange(suppressesInteraction ? false : isHovered)
            }
            .onChange(of: suppressesInteraction) { isSuppressed in
                if isSuppressed {
                    onHoverChange(false)
                }
            }
    }

    private var backgroundColor: Color {
        guard !suppressesInteraction else {
            return .clear
        }
        if isHighlighted || isHovered {
            return PlaybackTheme.menuItemHoverBackground
        }
        return .clear
    }
}
