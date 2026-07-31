import AppKit

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
        playback.requestPointerHide()
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
            let handled = handlePlaybackKeyDown(
                keyCode: keyCode,
                modifierFlagsRawValue: 0,
                isRepeat: isRepeat,
                textInputState: resolvedTextInputState
            )
            if handled {
                return true
            }
            guard resolvedTextInputState.isEditableFocused,
                  let nativeTextAction
            else {
                return false
            }
            return textActionHandler(nativeTextAction)
        }

        if case .direction(let direction, let source, let isRepeat) = input {
            if source == .leftThumbstick,
               isRepeat,
               !allowsControllerThumbstickRepeat(direction) {
                return false
            }
            return keyboardEquivalent(
                Self.keyCode(for: direction),
                isRepeat: isRepeat,
                nativeTextAction: Self.textAction(for: direction)
            )
        }

        guard case .button(let button) = input else {
            return false
        }
        switch button {
        case .south:
            let usesConfirmation = playback.commandPanelPresentation != nil
                || playback.subtitleFocusSession != nil
            return keyboardEquivalent(usesConfirmation ? 36 : 49)
        case .east:
            return keyboardEquivalent(53)
        case .west:
            if let session = playback.subtitleFocusSession,
               session.isEditingCollage {
                return session.copyCurrentCollage()
            }
            if playback.commandPanelPresentation?.page == .root {
                return textActionHandler(.deleteBackward)
            }
            return keyboardEquivalent(8, nativeTextAction: .insertText("c"))
        case .north:
            if let session = playback.subtitleFocusSession,
               session.isEditingCollage {
                return session.exportCurrentCollage()
            }
            if playback.commandPanelPresentation?.page == .root {
                return textActionHandler(.paste)
            }
            return keyboardEquivalent(1, nativeTextAction: .insertText("s"))
        case .auxiliaryLeft:
            return keyboardEquivalent(35)
        case .auxiliaryRight:
            return keyboardEquivalent(50, nativeTextAction: .insertText("`"))
        case .centerSurface:
            guard playback.commandPanelPresentation == nil,
                  playback.subtitleFocusSession == nil
            else {
                return false
            }
            return keyboardEquivalent(36)
        case .leftShoulder:
            return playback.subtitleFocusSession?.selectPreviousModule() == true
        case .rightShoulder:
            return keyboardEquivalent(48)
        case .leftTrigger:
            return keyboardEquivalent(0)
        case .rightTrigger:
            return keyboardEquivalent(2)
        case .leftThumbstick:
            return keyboardEquivalent(12)
        case .rightThumbstick:
            return keyboardEquivalent(3)
        }
    }

    func allowsControllerThumbstickRepeat(
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
