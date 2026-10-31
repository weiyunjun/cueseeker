import AppKit
import Carbon.HIToolbox

enum PlaybackControllerTextAction: Equatable {
    case deleteBackward
    case paste
    case moveUp
    case moveDown
    case moveLeft
    case moveRight
    case insertText(String)
}

@MainActor
extension AppCoordinator {
    @discardableResult
    func handlePlaybackControllerInput(_ input: ControllerInput) -> Bool {
        handlePlaybackControllerInput(
            input,
            textInputState: nil,
            textActionHandler: Self.performControllerTextAction
        )
    }

    @discardableResult
    func handlePlaybackControllerInput(
        _ input: ControllerInput,
        textInputState: PlaybackKeyboardTextInputState? = nil,
        textActionHandler: (PlaybackControllerTextAction) -> Bool
    ) -> Bool {
        guard isPlaybackPageVisible || playbackFullscreenManager.isFullscreen else {
            return false
        }
        if interfaceLayers.hasUncoveredOpenMenu {
            return routeControllerInputToMenuGate(input, menuGate: interfaceLayers.menuGate)
        }
        reconcilePlaybackAccessibilityFocus()
        let resolvedTextInputState = textInputState
            ?? PlaybackKeyboardTextInputState(
                isEditableFocused: Self.isEditableTextInputFocused(),
                hasMarkedText: Self.hasMarkedTextInFocusedEditor()
            )
        func keyboardEquivalent(
            _ keyCode: UInt16,
            isRepeat: Bool = false,
            nativeTextAction: PlaybackControllerTextAction? = nil
        ) -> Bool {
            // The controller presses the default keys, whatever the keyboard
            // has been rebound to.
            let handled = handlePlaybackKeyDown(
                keyCode: keyCode,
                modifierFlagsRawValue: 0,
                isRepeat: isRepeat,
                textInputState: resolvedTextInputState,
                shortcuts: .defaults
            )
            if handled {
                return true
            }
            guard resolvedTextInputState.isEditableFocused
                    || workbenchAccessibility.focusedPlaybackTarget == .commandPanelSearchField,
                  let nativeTextAction
            else {
                return false
            }
            return textActionHandler(nativeTextAction)
        }

        if case .direction(let direction, _, let isRepeat) = input {
            return keyboardEquivalent(
                Self.keyCode(for: direction),
                isRepeat: isRepeat,
                nativeTextAction: Self.textAction(for: direction)
            )
        }

        guard case .button(let button, let isRepeat) = input else {
            return false
        }

        switch button {
        case .leftShoulder:
            return movePlaybackAccessibilityFocus(forward: false)
        case .rightShoulder:
            return movePlaybackAccessibilityFocus(forward: true)
        default:
            break
        }

        if let commandPanel = playback.commandPanelPresentation,
           let handled = handlePlaybackCommandPanelControllerButton(
               commandPanel,
               button: button,
               isRepeat: isRepeat,
               textActionHandler: textActionHandler
           ) {
            return handled
        }

        if let session = playback.subtitleFocusSession,
           session.isEditingCollage,
           let handled = handlePlaybackCollageControllerButton(
               session,
               button: button,
               isRepeat: isRepeat
           ) {
            return handled
        }

        return handlePlaybackStageControllerButton(
            button,
            isRepeat: isRepeat,
            keyboardEquivalent: keyboardEquivalent
        )
    }

    private func handlePlaybackCollageControllerButton(
        _ session: PlaybackSubtitleFocusSessionStore,
        button: ControllerButton,
        isRepeat: Bool
    ) -> Bool? {
        switch button {
        case .west:
            guard !isRepeat else {
                return false
            }
            return session.copyCurrentCollage()
        case .north:
            guard !isRepeat else {
                return false
            }
            return session.exportCurrentCollage()
        default:
            return nil
        }
    }

    private func handlePlaybackCommandPanelControllerButton(
        _ commandPanel: PlaybackCommandPanelPresentation,
        button: ControllerButton,
        isRepeat: Bool,
        textActionHandler: (PlaybackControllerTextAction) -> Bool
    ) -> Bool? {
        guard commandPanel.page == .root else {
            return nil
        }
        switch button {
        case .west:
            return textActionHandler(.deleteBackward)
        case .north:
            guard !isRepeat else {
                return false
            }
            return textActionHandler(.paste)
        default:
            return nil
        }
    }

    private func handlePlaybackStageControllerButton(
        _ button: ControllerButton,
        isRepeat: Bool,
        keyboardEquivalent: (UInt16, Bool, PlaybackControllerTextAction?) -> Bool
    ) -> Bool {
        let hasActiveOverlayOrCommandPanel =
            playback.commandPanelPresentation != nil
            || playback.subtitleFocusSession != nil

        switch button {
        case .south:
            return keyboardEquivalent(
                hasActiveOverlayOrCommandPanel ? 36 : 49,
                isRepeat,
                nil
            )
        case .east:
            return keyboardEquivalent(53, isRepeat, nil)
        case .west:
            return keyboardEquivalent(
                8,
                isRepeat,
                .insertText("c")
            )
        case .north:
            return keyboardEquivalent(
                hasActiveOverlayOrCommandPanel ? 1 : UInt16(kVK_ANSI_R),
                isRepeat,
                .insertText("s")
            )
        case .auxiliaryLeft:
            return keyboardEquivalent(35, isRepeat, nil)
        case .auxiliaryRight:
            return keyboardEquivalent(UInt16(kVK_ANSI_K), isRepeat, nil)
        case .centerSurface:
            guard !hasActiveOverlayOrCommandPanel else {
                return false
            }
            return keyboardEquivalent(36, isRepeat, nil)
        case .leftShoulder:
            return movePlaybackAccessibilityFocus(forward: false)
        case .rightShoulder:
            return movePlaybackAccessibilityFocus(forward: true)
        case .leftTrigger:
            return keyboardEquivalent(0, isRepeat, nil)
        case .rightTrigger:
            return keyboardEquivalent(2, isRepeat, nil)
        case .leftThumbstick:
            return keyboardEquivalent(12, isRepeat, nil)
        case .rightThumbstick:
            return keyboardEquivalent(3, isRepeat, nil)
        }
    }

    private static func keyCode(for direction: ControllerDirection) -> UInt16 {
        switch direction {
        case .up:
            126
        case .down:
            125
        case .left:
            123
        case .right:
            124
        }
    }

    private static func textAction(
        for direction: ControllerDirection
    ) -> PlaybackControllerTextAction {
        switch direction {
        case .up:
            .moveUp
        case .down:
            .moveDown
        case .left:
            .moveLeft
        case .right:
            .moveRight
        }
    }

    private static func performControllerTextAction(
        _ action: PlaybackControllerTextAction
    ) -> Bool {
        let selector: Selector
        switch action {
        case .deleteBackward:
            selector = #selector(NSResponder.deleteBackward(_:))
        case .paste:
            selector = #selector(NSText.paste(_:))
        case .moveUp:
            selector = #selector(NSResponder.moveUp(_:))
        case .moveDown:
            selector = #selector(NSResponder.moveDown(_:))
        case .moveLeft:
            selector = #selector(NSResponder.moveLeft(_:))
        case .moveRight:
            selector = #selector(NSResponder.moveRight(_:))
        case .insertText(let text):
            return NSApplication.shared.sendAction(
                #selector(NSText.insertText(_:)),
                to: nil,
                from: text as NSString
            )
        }
        return NSApplication.shared.sendAction(selector, to: nil, from: nil)
    }
}
