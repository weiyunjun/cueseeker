import CueSeekerCore
import SwiftUI

enum PlaybackSubtitleFocusClipboard {
    static func copy(
        _ text: String,
        to pasteboard: NSPasteboard
    ) -> Bool {
        guard !text.isEmpty else {
            return false
        }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}

enum PlaybackSubtitleFocusAction: CaseIterable, Equatable, Identifiable, Sendable {
    case shiori
    case copyCueText
    case playFromThisCue

    var id: Self { self }
}

enum PlaybackSubtitleFocusShioriAvailability: Equatable, Sendable {
    case checking
    case available
    case alreadySaved
    case unavailable
}

struct PlaybackSubtitleFocusActionContext: Equatable, Sendable {
    let source: SubtitleFocusSourceIdentity
    let cue: SubtitleFocusCue

    var cueTextSelection: SubtitleCueTextSelection {
        SubtitleCueTextSelection(
            cueGroupID: cue.id,
            startMilliseconds: cue.startMilliseconds,
            endMilliseconds: cue.endMilliseconds,
            lines: cue.lines
        )
    }
}

struct PlaybackSubtitleFocusActionExecution: Equatable, Sendable {
    let action: PlaybackSubtitleFocusAction
    let context: PlaybackSubtitleFocusActionContext
    let menuGeneration: Int
}

struct PlaybackSubtitleFocusShioriLookupRequest: Equatable, Sendable {
    let context: PlaybackSubtitleFocusActionContext
    let menuGeneration: Int
}

struct PlaybackSubtitleFocusActionMenuState: Equatable, Sendable {
    let context: PlaybackSubtitleFocusActionContext
    let generation: Int
    private(set) var shioriAvailability: PlaybackSubtitleFocusShioriAvailability
    private(set) var selectedAction: PlaybackSubtitleFocusAction
    private(set) var isPerforming = false
    private var hasUserSelectedAction = false

    init(
        context: PlaybackSubtitleFocusActionContext,
        shioriAvailability: PlaybackSubtitleFocusShioriAvailability = .checking,
        generation: Int
    ) {
        self.context = context
        self.shioriAvailability = shioriAvailability
        self.generation = generation
        selectedAction = shioriAvailability == .available ? .shiori : .copyCueText
    }

    var isShioriSaved: Bool {
        shioriAvailability == .alreadySaved
    }

    func isAvailable(_ action: PlaybackSubtitleFocusAction) -> Bool {
        action != .shiori || shioriAvailability == .available
    }

    func isInteractive(_ action: PlaybackSubtitleFocusAction) -> Bool {
        !isPerforming && isAvailable(action)
    }

    func label(for action: PlaybackSubtitleFocusAction) -> String {
        switch action {
        case .shiori:
            return shioriAvailability == .alreadySaved
                ? "Shiori Already Saved"
                : "Shiori"
        case .copyCueText:
            return "Copy Cue Text"
        case .playFromThisCue:
            return "Play From This Cue"
        }
    }

    func systemImage(for action: PlaybackSubtitleFocusAction) -> String {
        switch action {
        case .shiori:
            return shioriAvailability == .alreadySaved
                ? "bookmark.fill"
                : "bookmark"
        case .copyCueText:
            return "doc.on.doc"
        case .playFromThisCue:
            return "play.fill"
        }
    }

    mutating func moveSelection(
        _ direction: SubtitleFocusNavigationDirection
    ) -> Bool {
        guard !isPerforming else {
            return false
        }
        let enabledActions = PlaybackSubtitleFocusAction.allCases.filter(isAvailable)
        guard let currentIndex = enabledActions.firstIndex(of: selectedAction) else {
            selectedAction = enabledActions.first ?? .copyCueText
            hasUserSelectedAction = !enabledActions.isEmpty
            return !enabledActions.isEmpty
        }
        let nextIndex = direction == .backward
            ? currentIndex - 1
            : currentIndex + 1
        guard enabledActions.indices.contains(nextIndex) else {
            return false
        }
        selectedAction = enabledActions[nextIndex]
        hasUserSelectedAction = true
        return true
    }

    mutating func select(_ action: PlaybackSubtitleFocusAction) -> Bool {
        guard isInteractive(action) else {
            return false
        }
        selectedAction = action
        hasUserSelectedAction = true
        return true
    }

    mutating func resolveShioriAvailability(
        _ availability: PlaybackSubtitleFocusShioriAvailability
    ) -> Bool {
        guard !isPerforming,
              shioriAvailability == .checking,
              availability != .checking
        else {
            return false
        }
        shioriAvailability = availability
        if !hasUserSelectedAction {
            selectedAction = availability == .available ? .shiori : .copyCueText
        } else if selectedAction == .shiori, !isAvailable(.shiori) {
            selectedAction = .copyCueText
        }
        return true
    }

    mutating func beginExecution(
        action requestedAction: PlaybackSubtitleFocusAction? = nil
    ) -> PlaybackSubtitleFocusAction? {
        guard !isPerforming else {
            return nil
        }
        if let requestedAction, !select(requestedAction) {
            return nil
        }
        guard isAvailable(selectedAction) else {
            return nil
        }
        isPerforming = true
        return selectedAction
    }

    mutating func finishFailedExecution() {
        isPerforming = false
    }

    mutating func markShioriSaved() {
        shioriAvailability = .alreadySaved
    }
}

enum PlaybackSubtitleFocusActionMenuMetrics {
    static let width = PlaybackChromeMetrics.speedMenuWidth
    static let itemHeight = PlaybackChromeMetrics.speedMenuItemHeight
    static let padding = PlaybackChromeMetrics.speedMenuPadding
    static let itemHorizontalPadding = PlaybackChromeMetrics.speedMenuItemHorizontalPadding
    static let itemVerticalGap = PlaybackChromeMetrics.speedMenuItemVerticalGap
    static let itemWidth = PlaybackChromeMetrics.speedMenuItemWidth
    static let menuRadius = PlaybackChromeMetrics.speedMenuRadius
    static let itemRadius = PlaybackChromeMetrics.speedMenuItemRadius
    static let fontSize = PlaybackChromeMetrics.speedMenuItemFontSize
    static let iconSize: CGFloat = 16
    static let iconTextGap: CGFloat = 8
    static let cueGap: CGFloat = 12
    static let height = padding * 2
        + itemHeight * CGFloat(PlaybackSubtitleFocusAction.allCases.count)
        + itemVerticalGap * CGFloat(PlaybackSubtitleFocusAction.allCases.count - 1)
}

enum PlaybackSubtitleFocusActionMenuPlacement {
    static func origin(
        cueFrame: CGRect,
        overlayBounds: CGRect
    ) -> CGPoint {
        let maximumX = max(
            overlayBounds.minX,
            overlayBounds.maxX - PlaybackSubtitleFocusActionMenuMetrics.width
        )
        let x = min(max(cueFrame.minX, overlayBounds.minX), maximumX)

        let belowY = cueFrame.maxY + PlaybackSubtitleFocusActionMenuMetrics.cueGap
        let aboveY = cueFrame.minY
            - PlaybackSubtitleFocusActionMenuMetrics.cueGap
            - PlaybackSubtitleFocusActionMenuMetrics.height
        let y: CGFloat
        if belowY + PlaybackSubtitleFocusActionMenuMetrics.height <= overlayBounds.maxY {
            y = belowY
        } else if aboveY >= overlayBounds.minY {
            y = aboveY
        } else {
            let maximumY = max(
                overlayBounds.minY,
                overlayBounds.maxY - PlaybackSubtitleFocusActionMenuMetrics.height
            )
            y = min(max(belowY, overlayBounds.minY), maximumY)
        }
        return CGPoint(x: x, y: y)
    }
}

struct PlaybackSubtitleFocusActionMenu: View {
    let state: PlaybackSubtitleFocusActionMenuState
    let onHover: (PlaybackSubtitleFocusAction) -> Void
    let onExecute: (PlaybackSubtitleFocusAction) -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: PlaybackSubtitleFocusActionMenuMetrics.itemVerticalGap
        ) {
            ForEach(PlaybackSubtitleFocusAction.allCases) { action in
                PlaybackSubtitleFocusActionMenuItem(
                    action: action,
                    label: state.label(for: action),
                    systemImage: state.systemImage(for: action),
                    isSelected: state.selectedAction == action,
                    isEnabled: state.isInteractive(action),
                    onHover: onHover,
                    onExecute: onExecute
                )
            }
        }
        .padding(PlaybackSubtitleFocusActionMenuMetrics.padding)
        .frame(width: PlaybackSubtitleFocusActionMenuMetrics.width)
        .background(
            RoundedRectangle(cornerRadius: PlaybackSubtitleFocusActionMenuMetrics.menuRadius)
                .fill(PlaybackTheme.menuBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PlaybackSubtitleFocusActionMenuMetrics.menuRadius)
                .strokeBorder(PlaybackTheme.textTertiary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(
            color: PlaybackTheme.overlayShadowColor,
            radius: PlaybackTheme.overlayShadowRadius,
            y: PlaybackTheme.overlayShadowYOffset
        )
        .contentShape(
            RoundedRectangle(cornerRadius: PlaybackSubtitleFocusActionMenuMetrics.menuRadius)
        )
        .onTapGesture {}
    }
}

private struct PlaybackSubtitleFocusActionMenuItem: View {
    let action: PlaybackSubtitleFocusAction
    let label: String
    let systemImage: String
    let isSelected: Bool
    let isEnabled: Bool
    let onHover: (PlaybackSubtitleFocusAction) -> Void
    let onExecute: (PlaybackSubtitleFocusAction) -> Void

    var body: some View {
        Button {
            guard isEnabled else {
                return
            }
            onExecute(action)
        } label: {
            HStack(spacing: PlaybackSubtitleFocusActionMenuMetrics.iconTextGap) {
                Image(systemName: systemImage)
                    .font(.system(
                        size: PlaybackSubtitleFocusActionMenuMetrics.iconSize,
                        weight: .medium
                    ))
                    .frame(
                        width: PlaybackSubtitleFocusActionMenuMetrics.iconSize,
                        height: PlaybackSubtitleFocusActionMenuMetrics.iconSize
                    )

                Text(label)
                    .font(.system(
                        size: PlaybackSubtitleFocusActionMenuMetrics.fontSize,
                        weight: .medium
                    ))
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.92)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isEnabled ? PlaybackTheme.textPrimary : PlaybackTheme.textTertiary)
            .padding(.horizontal, PlaybackSubtitleFocusActionMenuMetrics.itemHorizontalPadding)
            .frame(
                width: PlaybackSubtitleFocusActionMenuMetrics.itemWidth,
                height: PlaybackSubtitleFocusActionMenuMetrics.itemHeight
            )
            .contentShape(
                RoundedRectangle(cornerRadius: PlaybackSubtitleFocusActionMenuMetrics.itemRadius)
            )
        }
        .buttonStyle(PlaybackSubtitleFocusActionMenuButtonStyle(
            isSelected: isSelected,
            isEnabled: isEnabled
        ))
        .disabled(!isEnabled)
        .overlay {
            if !isEnabled {
                Color.clear
                    .contentShape(
                        RoundedRectangle(
                            cornerRadius: PlaybackSubtitleFocusActionMenuMetrics.itemRadius
                        )
                    )
                    .onTapGesture {}
            }
        }
        .onHover { isInside in
            guard isInside else {
                NSCursor.arrow.set()
                return
            }
            guard isEnabled else {
                NSCursor.arrow.set()
                return
            }
            NSCursor.pointingHand.set()
            onHover(action)
        }
        .onDisappear {
            NSCursor.arrow.set()
        }
        .accessibilityLabel(label)
    }
}

private struct PlaybackSubtitleFocusActionMenuButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: PlaybackSubtitleFocusActionMenuMetrics.itemRadius)
                    .fill(
                        isEnabled && (isSelected || configuration.isPressed)
                            ? PlaybackTheme.menuItemHoverBackground
                            : .clear
                    )
            )
            .scaleEffect(isEnabled && configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
