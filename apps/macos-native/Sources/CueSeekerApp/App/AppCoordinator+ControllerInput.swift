import AppKit

enum PlaybackControllerTextAction: Equatable {
    case deleteBackward
    case paste
}

@MainActor
extension AppCoordinator {
    @discardableResult
    func handlePlaybackControllerInput(_ input: ControllerInput) -> Bool {
        handlePlaybackControllerInput(
            input,
            textActionHandler: Self.performControllerTextAction
        )
    }

    @discardableResult
    func handlePlaybackControllerInput(
        _ input: ControllerInput,
        textActionHandler: (PlaybackControllerTextAction) -> Bool
    ) -> Bool {
        guard isPlaybackPageVisible || playbackFullscreenManager.isFullscreen else {
            return false
        }
        playback.requestPointerHide()

        if case .direction(let direction, let source, let isRepeat) = input {
            if source == .leftThumbstick,
               isRepeat,
               !allowsControllerThumbstickRepeat(direction) {
                return false
            }
            return handlePlaybackKeyDown(
                keyCode: Self.keyCode(for: direction),
                modifierFlagsRawValue: 0,
                isRepeat: isRepeat
            )
        }

        guard case .button(let button) = input else {
            return false
        }
        switch button {
        case .south:
            let usesConfirmation = playback.commandPanelPresentation != nil
                || playback.subtitleFocusSession != nil
            return handleControllerKeyboardEquivalent(
                keyCode: usesConfirmation ? 36 : 49
            )
        case .east:
            return handleControllerKeyboardEquivalent(keyCode: 53)
        case .west:
            if let session = playback.subtitleFocusSession,
               session.isEditingCollage {
                return session.copyCurrentCollage()
            }
            if playback.commandPanelPresentation?.page == .root {
                return textActionHandler(.deleteBackward)
            }
            return handleControllerKeyboardEquivalent(keyCode: 8)
        case .north:
            if let session = playback.subtitleFocusSession,
               session.isEditingCollage {
                return session.exportCurrentCollage()
            }
            if playback.commandPanelPresentation?.page == .root {
                return textActionHandler(.paste)
            }
            return handleControllerKeyboardEquivalent(keyCode: 1)
        case .auxiliaryLeft:
            return handleControllerKeyboardEquivalent(keyCode: 35)
        case .auxiliaryRight:
            return handleControllerKeyboardEquivalent(keyCode: 50)
        case .centerSurface:
            guard playback.commandPanelPresentation == nil,
                  playback.subtitleFocusSession == nil
            else {
                return false
            }
            return handleControllerKeyboardEquivalent(keyCode: 36)
        case .leftShoulder:
            return playback.subtitleFocusSession?.selectPreviousModule() == true
        case .rightShoulder:
            return handleControllerKeyboardEquivalent(keyCode: 48)
        case .leftTrigger:
            return handleControllerKeyboardEquivalent(keyCode: 0)
        case .rightTrigger:
            return handleControllerKeyboardEquivalent(keyCode: 2)
        case .leftThumbstick:
            return handleControllerKeyboardEquivalent(keyCode: 12)
        case .rightThumbstick:
            return handleControllerKeyboardEquivalent(keyCode: 3)
        }
    }

    private func handleControllerKeyboardEquivalent(keyCode: UInt16) -> Bool {
        handlePlaybackKeyDown(
            keyCode: keyCode,
            modifierFlagsRawValue: 0,
            isRepeat: false
        )
    }

    private func allowsControllerThumbstickRepeat(
        _ direction: ControllerDirection
    ) -> Bool {
        let hasModalPlaybackInterface = playback.commandPanelPresentation != nil
            || playback.subtitleFocusSession != nil
        if hasModalPlaybackInterface {
            return direction == .up || direction == .down
        }
        return direction == .left || direction == .right
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

    private static func performControllerTextAction(
        _ action: PlaybackControllerTextAction
    ) -> Bool {
        let selector: Selector
        switch action {
        case .deleteBackward:
            selector = #selector(NSResponder.deleteBackward(_:))
        case .paste:
            selector = #selector(NSText.paste(_:))
        }
        return NSApplication.shared.sendAction(selector, to: nil, from: nil)
    }
}
