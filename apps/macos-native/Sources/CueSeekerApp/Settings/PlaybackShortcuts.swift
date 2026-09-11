import AppKit
import Carbon.HIToolbox

// The keyboard shortcuts of the video page, the Playback Overlay and the
// Command Panel that Settings / Shortcuts can rebind. Keys that are not listed
// here — Esc, Tab, and the arrows and Return where they move and confirm — stay
// fixed. See `docs/human/requirements/20260912-Feature-Playback Keyboard
// Shortcut Rebinding.md`.
//
// Only the keyboard reads these bindings: a game controller keeps pressing the
// default keys.

/// One key, optionally with ⇧. Return and the keypad's Enter are one key.
struct PlaybackShortcutKey: Codable, Hashable, Sendable {
    let keyCode: UInt16
    let shift: Bool

    init(keyCode: UInt16, shift: Bool = false) {
        self.keyCode = keyCode == UInt16(kVK_ANSI_KeypadEnter)
            ? UInt16(kVK_Return)
            : keyCode
        self.shift = shift
    }

    /// Return and the arrows, which confirm and move in the Playback Overlay
    /// and the Command Panel.
    var isNavigationKey: Bool {
        switch Int(keyCode) {
        case kVK_Return, kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow:
            true
        default:
            false
        }
    }

    /// What the key is drawn as: ⇧ and the key itself, each on its own keycap.
    @MainActor
    var keycaps: [PlaybackCueFooterKeycap] {
        guard let main = Self.keycap(forKeyCode: keyCode) else {
            return []
        }
        return shift ? [.text("⇧"), main] : [main]
    }

    /// The key's own keycap, or nil for a key that is not supported as a
    /// shortcut: function keys, Home, End, Page Up, Page Down, and any other
    /// key that types nothing.
    @MainActor
    static func keycap(forKeyCode keyCode: UInt16) -> PlaybackCueFooterKeycap? {
        switch Int(keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            .returnKey
        case kVK_Space:
            .text("Space")
        case kVK_Delete:
            .text("⌫")
        case kVK_ForwardDelete:
            .text("⌦")
        case kVK_LeftArrow:
            .text("←")
        case kVK_RightArrow:
            .text("→")
        case kVK_UpArrow:
            .text("↑")
        case kVK_DownArrow:
            .text("↓")
        default:
            typedCharacter(forKeyCode: keyCode).map { .text($0.uppercased()) }
        }
    }

    /// The character the key types in the current keyboard layout without any
    /// modifier, so a key is labelled the way it is printed on the keyboard.
    @MainActor
    private static func typedCharacter(forKeyCode keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?
                .takeRetainedValue(),
              let property = TISGetInputSourceProperty(
                source,
                kTISPropertyUnicodeKeyLayoutData
              )
        else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(property)
            .takeUnretainedValue() as Data
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layoutData.withUnsafeBytes { buffer -> OSStatus in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self)
                .baseAddress
            else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else {
            return nil
        }
        let text = String(utf16CodeUnits: characters, count: length)
        let typesSomething = text.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
                && !CharacterSet.whitespacesAndNewlines.contains(scalar)
                // AppKit's private-use range for function and cursor keys.
                && !(0xF700...0xF8FF).contains(scalar.value)
        }
        return typesSomething ? text : nil
    }
}

/// Where a shortcut answers. Two shortcuts may share a key only when they never
/// answer in the same place.
enum PlaybackShortcutGroup: Sendable {
    /// Open Command Panel, which answers on the video page and in the Playback
    /// Overlay alike.
    case global
    /// The video page with nothing open over it.
    case playback
    /// The Playback Overlay and the Command Panel.
    case overlay
}

/// Every rebindable shortcut, in the order Settings lists them.
enum PlaybackShortcutAction: String, CaseIterable, Identifiable, Sendable {
    case openCommandPanel
    case playPause
    case seekBackward
    case seekForward
    case volumeUp
    case volumeDown
    case speedDown
    case speedUp
    case previous
    case next
    case toggleSubtitles
    case repeatCue
    case copyScreenshot
    case toggleFullscreen
    case openPlaybackOverlay
    case saveToShiori
    case copyCueText
    case copyDeepLink
    case editCollage

    var id: String { rawValue }

    var title: String {
        L("settings.shortcuts.action.\(rawValue)")
    }

    var group: PlaybackShortcutGroup {
        switch self {
        case .openCommandPanel:
            .global
        case .saveToShiori, .copyCueText, .copyDeepLink, .editCollage:
            .overlay
        default:
            .playback
        }
    }

    /// Whether the two shortcuts can answer in the same place, so a shared key
    /// is a conflict.
    func sharesPlace(with other: Self) -> Bool {
        group == other.group || group == .global || other.group == .global
    }

    var defaultKey: PlaybackShortcutKey {
        switch self {
        case .openCommandPanel:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_K))
        case .playPause:
            PlaybackShortcutKey(keyCode: UInt16(kVK_Space))
        case .seekBackward:
            PlaybackShortcutKey(keyCode: UInt16(kVK_LeftArrow))
        case .seekForward:
            PlaybackShortcutKey(keyCode: UInt16(kVK_RightArrow))
        case .volumeUp:
            PlaybackShortcutKey(keyCode: UInt16(kVK_UpArrow))
        case .volumeDown:
            PlaybackShortcutKey(keyCode: UInt16(kVK_DownArrow))
        case .speedDown:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_Comma), shift: true)
        case .speedUp:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_Period), shift: true)
        case .previous:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_A))
        case .next:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_D))
        case .toggleSubtitles:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_Q))
        case .repeatCue:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_R))
        case .copyScreenshot:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_P))
        case .toggleFullscreen:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_F))
        case .openPlaybackOverlay:
            PlaybackShortcutKey(keyCode: UInt16(kVK_Return))
        case .saveToShiori:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_S))
        case .copyCueText:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_C))
        case .copyDeepLink:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_X))
        case .editCollage:
            PlaybackShortcutKey(keyCode: UInt16(kVK_ANSI_P))
        }
    }

    /// The key a press records for this shortcut, or why it cannot be one.
    /// Esc is not asked about: it cancels the recording.
    @MainActor
    func recordedKey(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Result<PlaybackShortcutKey, PlaybackShortcutRejection> {
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.intersection([.command, .control, .option]).isEmpty else {
            return .failure(.modifier)
        }
        let key = PlaybackShortcutKey(
            keyCode: keyCode,
            shift: flags.contains(.shift)
        )
        if Int(key.keyCode) == kVK_Tab
            || (group != .playback && key.isNavigationKey) {
            return .failure(.reserved)
        }
        guard PlaybackShortcutKey.keycap(forKeyCode: key.keyCode) != nil else {
            return .failure(.unsupported)
        }
        return .success(key)
    }
}

enum PlaybackShortcutRejection: Error, Equatable {
    case modifier
    case reserved
    case unsupported

    var message: String {
        switch self {
        case .modifier:
            L("settings.shortcuts.rejection.modifier")
        case .reserved:
            L("settings.shortcuts.rejection.reserved")
        case .unsupported:
            L("settings.shortcuts.rejection.unsupported")
        }
    }
}

/// Every shortcut's key: the default, unless the user changed or cleared it.
struct PlaybackShortcutKeymap: Equatable, Sendable {
    /// The user's changes. A nil key is a cleared shortcut; a shortcut that is
    /// not listed keeps its default key.
    private(set) var overrides: [PlaybackShortcutAction: PlaybackShortcutKey?] = [:]

    static let defaults = PlaybackShortcutKeymap()

    func key(for action: PlaybackShortcutAction) -> PlaybackShortcutKey? {
        overrides[action] ?? action.defaultKey
    }

    func isDefault(_ action: PlaybackShortcutAction) -> Bool {
        !overrides.keys.contains(action)
    }

    mutating func set(
        _ key: PlaybackShortcutKey?,
        for action: PlaybackShortcutAction
    ) {
        if key == action.defaultKey {
            overrides.removeValue(forKey: action)
        } else {
            overrides.updateValue(key, forKey: action)
        }
    }

    mutating func reset(_ action: PlaybackShortcutAction) {
        overrides.removeValue(forKey: action)
    }

    /// The shortcuts that share this one's key in a place where both answer.
    func conflicts(for action: PlaybackShortcutAction) -> [PlaybackShortcutAction] {
        guard let key = key(for: action) else {
            return []
        }
        return PlaybackShortcutAction.allCases.filter { other in
            other != action
                && other.sharesPlace(with: action)
                && self.key(for: other) == key
        }
    }

    /// The key the shortcut answers to right now: nil while it is cleared or
    /// while its key is in conflict, when the key does nothing for any side.
    func effectiveKey(for action: PlaybackShortcutAction) -> PlaybackShortcutKey? {
        conflicts(for: action).isEmpty ? key(for: action) : nil
    }

    /// The shortcut in `group` that a press of `key` runs.
    func action(
        for key: PlaybackShortcutKey,
        in group: PlaybackShortcutGroup
    ) -> PlaybackShortcutAction? {
        PlaybackShortcutAction.allCases.first { action in
            action.group == group && effectiveKey(for: action) == key
        }
    }
}

/// The keymap as Settings changes it, kept across launches.
@MainActor
final class PlaybackShortcutStore: ObservableObject {
    private static let userDefaultsKey = "playbackShortcutOverrides"

    @Published private(set) var keymap: PlaybackShortcutKeymap

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        self.keymap = Self.load(from: userDefaults)
    }

    func set(_ key: PlaybackShortcutKey?, for action: PlaybackShortcutAction) {
        keymap.set(key, for: action)
        save()
    }

    func reset(_ action: PlaybackShortcutAction) {
        keymap.reset(action)
        save()
    }

    private func save() {
        let stored = Dictionary(
            uniqueKeysWithValues: keymap.overrides.map { ($0.key.rawValue, $0.value) }
        )
        guard !stored.isEmpty,
              let data = try? JSONEncoder().encode(stored)
        else {
            userDefaults.removeObject(forKey: Self.userDefaultsKey)
            return
        }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    private static func load(from userDefaults: UserDefaults) -> PlaybackShortcutKeymap {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
              let stored = try? JSONDecoder().decode(
                [String: PlaybackShortcutKey?].self,
                from: data
              )
        else {
            return .defaults
        }
        var keymap = PlaybackShortcutKeymap()
        for (rawValue, key) in stored {
            if let action = PlaybackShortcutAction(rawValue: rawValue) {
                keymap.set(key, for: action)
            }
        }
        return keymap
    }
}
