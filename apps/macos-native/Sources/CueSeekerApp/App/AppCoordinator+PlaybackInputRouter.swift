import AppKit
import Foundation
import CueSeekerCore
import CueSeekerPlayback

struct PlaybackKeyboardTextInputState: Equatable, Sendable {
    let isEditableFocused: Bool
    let hasMarkedText: Bool
}

@MainActor
extension AppCoordinator {
    @discardableResult
    func handlePlaybackKeyDown(
        keyCode: UInt16,
        modifierFlagsRawValue: UInt,
        isRepeat: Bool = false
    ) -> Bool {
        handlePlaybackKeyDown(
            keyCode: keyCode,
            modifierFlagsRawValue: modifierFlagsRawValue,
            isRepeat: isRepeat,
            textInputState: PlaybackKeyboardTextInputState(
                isEditableFocused: Self.isEditableTextInputFocused(),
                hasMarkedText: Self.hasMarkedTextInFocusedEditor()
            )
        )
    }

    /// Applies whatever the speed-menu highlight sits on, so Enter and a click
    /// commit through one path.
    ///
    /// Rebindable keys are read from `shortcuts`, the user's keymap unless the
    /// caller passes another: a game controller presses the default keys.
    @discardableResult
    func handlePlaybackKeyDown(
        keyCode: UInt16,
        modifierFlagsRawValue: UInt,
        isRepeat: Bool = false,
        textInputState: PlaybackKeyboardTextInputState,
        shortcuts: PlaybackShortcutKeymap? = nil
    ) -> Bool {
        let isPlaybackInterfaceVisible = currentPlaybackVideoPath != nil || playbackFullscreenManager.isFullscreen

        guard isPlaybackInterfaceVisible else {
            return false
        }

        guard currentPlaybackVideoPath != nil,
              let viewModel = playback.playbackViewModel
        else {
            return Self.handlePlaybackFullscreenEscape(
                keyCode: keyCode,
                isRepeat: isRepeat,
                isFullscreen: playbackFullscreenManager.isFullscreen,
                exitFullscreen: exitPlaybackFullscreenFromUser
            )
        }

        dropCoveredFirstResponderIfNeeded()

        let modifierFlags = NSEvent.ModifierFlags(
            rawValue: modifierFlagsRawValue
        )
        let shortcuts = shortcuts ?? settings.playbackShortcuts.keymap
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shortcutKey = PlaybackShortcutKey(
            keyCode: keyCode,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift)
        )

        if handlePlaybackMenuKeyDown(
            keyCode: keyCode,
            modifierFlags: modifierFlags,
            isRepeat: isRepeat
        ) {
            return true
        }

        // The cue action the press runs where the Playback Overlay and the
        // Command Panel's search results offer Save to Excerpt, Copy Cue Text
        // and Copy Deep Link.
        let cueShortcutAction: PlaybackSubtitleFocusAction? = shortcuts
            .action(for: shortcutKey, in: .overlay)
            .flatMap(Self.cueAction(for:))

        if let commandPanel = playback.commandPanelPresentation {
            if shortcuts.effectiveKey(for: .openCommandPanel) == shortcutKey,
               !textInputState.isEditableFocused {
                if !isRepeat {
                    _ = presentPlaybackCommandPanel()
                }
                return true
            }
            return handlePlaybackCommandPanelKeyDown(
                commandPanel,
                keyCode: keyCode,
                modifierFlags: modifierFlags,
                isRepeat: isRepeat,
                textInputState: textInputState,
                cueShortcutAction: cueShortcutAction
            )
        }

        if let subtitleFocusSession = playback.subtitleFocusSession,
           subtitleFocusSession.isEditingCollage {
            return handlePlaybackCollageKeyDown(
                subtitleFocusSession,
                keyCode: keyCode,
                modifierFlags: modifierFlags,
                isRepeat: isRepeat,
                shortcutKey: shortcutKey,
                shortcuts: shortcuts
            )
        }

        if shortcuts.effectiveKey(for: .openCommandPanel) == shortcutKey,
           !textInputState.isEditableFocused {
            if !isRepeat {
                _ = presentPlaybackCommandPanel()
            }
            return true
        }

        if let subtitleFocusSession = playback.subtitleFocusSession {
            return handlePlaybackSubtitleFocusKeyDown(
                subtitleFocusSession,
                keyCode: keyCode,
                modifierFlags: modifierFlags,
                isRepeat: isRepeat,
                textInputState: textInputState,
                shortcutKey: shortcutKey,
                shortcuts: shortcuts,
                cueShortcutAction: cueShortcutAction
            )
        }

        return handlePlaybackStageKeyDown(
            viewModel: viewModel,
            keyCode: keyCode,
            isRepeat: isRepeat,
            textInputState: textInputState,
            shortcutKey: shortcutKey,
            shortcuts: shortcuts
        )
    }

    /// An open menu owns the keyboard: the arrows, Enter, Esc and the key
    /// that opened it go to the menu, and every other in-app function is
    /// spent here, so nothing underneath answers a key the menu did not
    /// want. Only a press held with ⌘ travels on. The gate skips
    /// covered menus, so a menu below the Command Panel stays on screen and
    /// takes nothing while the panel is open. See
    /// `docs/human/requirements/20260912-UI-Open Menu Blocks In-App
    /// Shortcuts.md`.
    func handlePlaybackMenuKeyDown(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool
    ) -> Bool {
        guard interfaceLayers.hasUncoveredOpenMenu,
              !modifierFlags.contains(.command)
        else {
            return false
        }
        if !modifierFlags.contains(.shift) {
            _ = interfaceLayers.menuGate.routeKey(keyCode, isRepeat: isRepeat)
        }
        return true
    }

    func handlePlaybackCollageKeyDown(
        _ subtitleFocusSession: PlaybackSubtitleFocusSessionStore,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool,
        shortcutKey: PlaybackShortcutKey,
        shortcuts: PlaybackShortcutKeymap
    ) -> Bool {
        if shortcuts.effectiveKey(for: .editCollage) == shortcutKey {
            if !isRepeat {
                _ = subtitleFocusSession.toggleEditingCollage()
            }
            return true
        }
        if let collageShortcut = shortcuts.action(for: shortcutKey, in: .collage) {
            if !isRepeat {
                switch collageShortcut {
                case .copyCollage:
                    _ = subtitleFocusSession.copyCurrentCollage()
                case .exportCollage:
                    _ = subtitleFocusSession.exportCurrentCollage()
                default:
                    break
                }
            }
            return true
        }
        let editingCollageModifiers: NSEvent.ModifierFlags = [
            .command,
            .control,
            .option,
            .shift,
        ]
        guard modifierFlags.intersection(editingCollageModifiers).isEmpty
        else {
            return false
        }

        switch keyCode {
        case 53:
            if !isRepeat {
                _ = subtitleFocusSession.toggleEditingCollage()
            }
            return true
        case 36, 76:
            if !isRepeat {
                _ = subtitleFocusSession.toggleFocusedCollageCueSelection()
            }
            return true
        case 126:
            _ = subtitleFocusSession.requestKeyboardNavigation(.backward)
            return true
        case 125:
            _ = subtitleFocusSession.requestKeyboardNavigation(.forward)
            return true
        case 123, 124:
            return true
        default:
            return true
        }
    }

    func handlePlaybackCommandPanelKeyDown(
        _ commandPanel: PlaybackCommandPanelPresentation,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool,
        textInputState: PlaybackKeyboardTextInputState,
        cueShortcutAction: PlaybackSubtitleFocusAction?
    ) -> Bool {
        let disallowedModifiers: NSEvent.ModifierFlags = [
            .command,
            .control,
            .option,
        ]
        if keyCode == 53,
           modifierFlags.intersection(disallowedModifiers).isEmpty {
            guard !isRepeat else {
                return true
            }
            if commandPanel.page == .root {
                return dismissPlaybackCommandPanelFromUser()
            }
            return returnPlaybackCommandPanelToRoot()
        }

        if commandPanel.page == .root,
           textInputState.isEditableFocused {
            guard !textInputState.hasMarkedText else {
                return false
            }
            guard modifierFlags.intersection(disallowedModifiers).isEmpty
            else {
                return false
            }
            switch keyCode {
            case 126:
                _ = movePlaybackCommandPanelSelection(-1)
                return true
            case 125:
                _ = movePlaybackCommandPanelSelection(1)
                return true
            case 36, 76:
                if !isRepeat {
                    _ = openSelectedPlaybackCommandPanelItem()
                }
                return true
            default:
                return false
            }
        }
        if let cueShortcutAction {
            if commandPanel.page == .searchResults, !isRepeat {
                _ = requestPlaybackCommandPanelSearchAction(cueShortcutAction)
            }
            return true
        }
        guard modifierFlags.intersection(disallowedModifiers).isEmpty else {
            return true
        }
        switch keyCode {
        case 123 where commandPanel.page.showsRecentCardGrid:
            _ = movePlaybackCommandPanelRecentCardSelection(.left)
        case 124 where commandPanel.page.showsRecentCardGrid:
            _ = movePlaybackCommandPanelRecentCardSelection(.right)
        case 126:
            if commandPanel.page.showsRecentCardGrid {
                _ = movePlaybackCommandPanelRecentCardSelection(.up)
            } else {
                _ = movePlaybackCommandPanelSelection(-1)
            }
        case 125:
            if commandPanel.page.showsRecentCardGrid {
                _ = movePlaybackCommandPanelRecentCardSelection(.down)
            } else {
                _ = movePlaybackCommandPanelSelection(1)
            }
        case 36, 76:
            if !isRepeat {
                _ = openSelectedPlaybackCommandPanelItem()
            }
        default:
            break
        }
        return true
    }

    func handlePlaybackSubtitleFocusKeyDown(
        _ subtitleFocusSession: PlaybackSubtitleFocusSessionStore,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        isRepeat: Bool,
        textInputState: PlaybackKeyboardTextInputState,
        shortcutKey: PlaybackShortcutKey,
        shortcuts: PlaybackShortcutKeymap,
        cueShortcutAction: PlaybackSubtitleFocusAction?
    ) -> Bool {
        let disallowedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        let moduleSwitchModifiers: NSEvent.ModifierFlags = [
            .command,
            .control,
            .option,
        ]

        if shortcuts.effectiveKey(for: .editCollage) == shortcutKey {
            if !isRepeat,
               subtitleFocusSession.selectedModule == .current {
                _ = subtitleFocusSession.toggleEditingCollage()
            }
            return true
        }

        if keyCode == 48,
           modifierFlags.intersection(moduleSwitchModifiers).isEmpty {
            if !isRepeat {
                if modifierFlags.contains(.shift) {
                    _ = subtitleFocusSession.selectPreviousModule()
                } else {
                    _ = subtitleFocusSession.selectNextModule()
                }
            }
            return true
        }

        if keyCode == 53,
           modifierFlags.intersection(disallowedModifiers).isEmpty {
            guard !isRepeat else {
                return true
            }
            return dismissPlaybackSubtitleFocusFromUser()
        }

        let usesMediaPlaylist =
            subtitleFocusSession.selectedModule == .playlist
            && subtitleFocusSession.libraryStore != nil
        if usesMediaPlaylist {
            guard !textInputState.isEditableFocused else {
                return false
            }

            let mediaActionModifiers: NSEvent.ModifierFlags = [
                .command,
                .control,
                .option,
                .shift,
            ]
            guard modifierFlags.intersection(mediaActionModifiers).isEmpty else {
                return false
            }

            switch keyCode {
            case 123:
                _ = subtitleFocusSession.requestMediaSelectionNavigation(.left)
            case 124:
                _ = subtitleFocusSession.requestMediaSelectionNavigation(.right)
            case 126:
                _ = subtitleFocusSession.requestMediaSelectionNavigation(.up)
            case 125:
                _ = subtitleFocusSession.requestMediaSelectionNavigation(.down)
            case 36, 76:
                if !isRepeat {
                    _ = requestPlaybackLibraryPrimaryAction()
                }
            default:
                break
            }
            return true
        }

        guard !textInputState.isEditableFocused else {
            return false
        }

        if let cueShortcutAction {
            guard !isRepeat else {
                return true
            }
            if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                == true {
                _ = requestPlaybackSubtitleFocusAction(cueShortcutAction)
            }
            return true
        }

        guard modifierFlags.intersection(disallowedModifiers).isEmpty else {
            return false
        }

        switch keyCode {
        case 126:
            if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                == true {
                _ = subtitleFocusSession.requestKeyboardNavigation(.backward)
            }
            return true
        case 125:
            if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                == true {
                _ = subtitleFocusSession.requestKeyboardNavigation(.forward)
            }
            return true
        case 36, 76:
            guard !isRepeat else {
                return true
            }
            if subtitleFocusSession.selectedModule?.usesSharedCueShortcuts
                == true {
                _ = requestPlaybackSubtitleFocusAction(.playFromThisCue)
            }
            return true
        case 49:
            return true
        default:
            return true
        }
    }

    func handlePlaybackStageKeyDown(
        viewModel: PlaybackViewModel,
        keyCode: UInt16,
        isRepeat: Bool,
        textInputState: PlaybackKeyboardTextInputState,
        shortcutKey: PlaybackShortcutKey,
        shortcuts: PlaybackShortcutKeymap
    ) -> Bool {
        if Self.handlePlaybackFullscreenEscape(
            keyCode: keyCode,
            isRepeat: isRepeat,
            isFullscreen: playbackFullscreenManager.isFullscreen,
            exitFullscreen: exitPlaybackFullscreenFromUser
        ) {
            return true
        }

        guard !textInputState.isEditableFocused else {
            return false
        }

        let playbackShortcut = shortcuts.action(for: shortcutKey, in: .playback)

        if playback.isTimelineScrubbing {
            return playbackShortcut != nil
        }

        switch playbackShortcut {
        case .previous:
            goPrevious()
            return true
        case .next:
            goNext()
            return true
        case .toggleSubtitles:
            viewModel.toggleSubtitles()
            return true
        case .repeatCue:
            if !isRepeat {
                _ = repeatCurrentPlaylistCue()
            }
            return true
        case .copyScreenshot:
            viewModel.copyCurrentFrameScreenshot()
            return true
        case .toggleFullscreen:
            togglePlaybackFullscreenFromUser()
            return true
        case .playPause:
            togglePlaybackFromUser()
            return true
        case .openPlaybackOverlay:
            guard !isRepeat else {
                return true
            }
            return openPlaybackSubtitleFocusFromUser()
        case .seekBackward:
            viewModel.seekRelative(by: -5)
            return true
        case .seekForward:
            viewModel.seekRelative(by: 5)
            return true
        case .volumeUp:
            viewModel.adjustVolume(by: 5)
            return true
        case .volumeDown:
            viewModel.adjustVolume(by: -5)
            return true
        case .speedDown:
            viewModel.adjustSpeed(by: -0.25)
            return true
        case .speedUp:
            viewModel.adjustSpeed(by: 0.25)
            return true
        case .openCommandPanel, .saveToExcerpt, .copyCueText, .copyDeepLink,
             .editCollage, .copyCollage, .exportCollage, nil:
            return false
        }
    }

    private func dropCoveredFirstResponderIfNeeded() {
        // If a covered view somehow holds first responder, drop the orphaned focus
        // so covered fields cannot receive keystrokes.
        let activeWindow = NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first { $0 is CueSeekerMainWindow }
        if let window = activeWindow as? CueSeekerMainWindow,
           let view = window.firstResponder as? NSView,
           window.isWorkbenchCovered(),
           !window.isUncovered(view) {
            _ = window.makeFirstResponder(nil)
        }
    }

    static func handlePlaybackFullscreenEscape(
        keyCode: UInt16,
        isRepeat: Bool,
        isFullscreen: Bool,
        exitFullscreen: () -> Void
    ) -> Bool {
        guard keyCode == 53, isFullscreen else {
            return false
        }
        if !isRepeat {
            exitFullscreen()
        }
        return true
    }

    /// The cue action behind an Overlay shortcut, for the three the Playback
    /// Overlay and the Command Panel's search results share.
    static func cueAction(
        for shortcut: PlaybackShortcutAction
    ) -> PlaybackSubtitleFocusAction? {
        switch shortcut {
        case .saveToExcerpt:
            .excerpt
        case .copyCueText:
            .copyCueText
        case .copyDeepLink:
            .copyCueMarkdownLink
        default:
            nil
        }
    }

    static func isEditableTextInputFocused() -> Bool {
        let activeWindow = NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first { $0 is CueSeekerMainWindow }
        guard let firstResponder = activeWindow?.firstResponder else {
            return false
        }

        if let view = firstResponder as? NSView {
            if let window = view.window as? CueSeekerMainWindow,
               window.isWorkbenchCovered(),
               !window.isUncovered(view) {
                return false
            }
        }

        if let textView = firstResponder as? NSTextView {
            return textView.isEditable
        }

        if let textField = firstResponder as? NSTextField {
            return textField.isEditable
        }

        if let view = firstResponder as? NSView {
            return view.ancestorOrSelfContainsEditableTextInput
        }

        return false
    }

    static func hasMarkedTextInFocusedEditor() -> Bool {
        let activeWindow = NSApplication.shared.keyWindow
            ?? NSApplication.shared.windows.first { $0 is CueSeekerMainWindow }
        guard let textView = activeWindow?.firstResponder
            as? NSTextView
        else {
            return false
        }
        if let window = textView.window as? CueSeekerMainWindow,
           window.isWorkbenchCovered(),
           !window.isUncovered(textView) {
            return false
        }
        return textView.hasMarkedText()
    }
}

private extension NSView {
    var ancestorOrSelfContainsEditableTextInput: Bool {
        if let textView = self as? NSTextView {
            return textView.isEditable
        }

        if let textField = self as? NSTextField {
            return textField.isEditable
        }

        var ancestor = superview
        while let current = ancestor {
            if let textView = current as? NSTextView {
                return textView.isEditable
            }

            if let textField = current as? NSTextField {
                return textField.isEditable
            }
            ancestor = current.superview
        }

        return false
    }
}
