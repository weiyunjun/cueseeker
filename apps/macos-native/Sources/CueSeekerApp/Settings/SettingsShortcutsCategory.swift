import AppKit
import Carbon.HIToolbox
import SwiftUI

enum SettingsShortcutsMetrics {
    /// --width-shortcut-field: room for ⇧ and a key, or the recording
    /// placeholder and its Inline Clear.
    static let fieldWidth: CGFloat = 144
}

/// Settings / Shortcuts. See `docs/human/requirements/20260912-Feature-Playback
/// Keyboard Shortcut Rebinding.md`.
struct SettingsShortcutsCategory: View {
    // Observed so the copy below is re-read when the language changes.
    @EnvironmentObject private var localization: AppLocalizationStore
    @EnvironmentObject private var shortcuts: PlaybackShortcutStore
    @StateObject private var recorder = PlaybackShortcutRecorder()

    var body: some View {
        WorkbenchScrollView {
            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing6) {
                Text(L("settings.category.shortcuts"))
                    .font(.title2)
                    .fontWeight(.semibold)

                // The names share one column, as wide as the longest of them.
                Grid(
                    alignment: .topLeading,
                    horizontalSpacing: WorkbenchControlMetrics.redesignSpacing6,
                    verticalSpacing: 0
                ) {
                    row(.openCommandPanel)
                    sectionTitle(L("settings.shortcuts.section.playback"))
                    ForEach(actions(in: .playback)) { action in
                        row(action)
                    }
                    sectionTitle(L("settings.shortcuts.section.overlay"))
                    ForEach(actions(in: .overlay)) { action in
                        row(action)
                    }
                }
            }
            .padding(WorkbenchControlMetrics.redesignSpacing6)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WorkbenchRedesignColors.bgSurface)
        // A key reaches a recording shortcut one of two ways: the App menu's
        // shortcuts go to the window as key equivalents before any key-down
        // monitor sees them, and every other key comes through the monitor.
        .background(WindowKeyDownMonitor { recorder.handleKey($0) })
        .background(PlaybackShortcutKeyEquivalentCatcher { recorder.handleKey($0) })
        .onDisappear {
            recorder.stop()
        }
    }

    private func actions(in group: PlaybackShortcutGroup) -> [PlaybackShortcutAction] {
        PlaybackShortcutAction.allCases.filter { $0.group == group }
    }

    private func sectionTitle(_ title: String) -> some View {
        GridRow {
            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeSectionTitle,
                    weight: .semibold
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                .padding(.top, WorkbenchControlMetrics.redesignSpacing4)
                .padding(.bottom, WorkbenchControlMetrics.redesignSpacing3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gridCellColumns(2)
                .gridCellUnsizedAxes(.horizontal)
        }
    }

    /// The name, the key field with its Restore Default button, and below the
    /// field the one line its message is kept in, which also spaces the rows.
    private func row(_ action: PlaybackShortcutAction) -> some View {
        let keymap = shortcuts.keymap
        let isRecording = recorder.recordingAction == action
        let message = isRecording
            ? recorder.rejection?.message
            : conflictMessage(keymap.conflicts(for: action))

        return GridRow {
            Text(action.title)
                .font(.headline)
                .frame(height: WorkbenchControlMetrics.redesignFieldHeight)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                    PlaybackShortcutField(
                        key: keymap.key(for: action),
                        isRecording: isRecording,
                        hasError: message != nil,
                        onStart: { anchor in
                            recorder.start(action, anchor: anchor) { key in
                                shortcuts.set(key, for: action)
                            }
                        },
                        onClear: {
                            recorder.stop()
                            shortcuts.set(nil, for: action)
                        }
                    )

                    WorkbenchIconButton(
                        icon: .arrowCounterClockwise,
                        isRedesign: true
                    ) {
                        recorder.stop()
                        shortcuts.reset(action)
                    }
                    .disabled(keymap.isDefault(action))
                }

                WorkbenchValidationMessage(text: message)
            }
        }
    }

    private func conflictMessage(_ conflicts: [PlaybackShortcutAction]) -> String? {
        guard !conflicts.isEmpty else {
            return nil
        }
        let names = conflicts
            .map { L("settings.shortcuts.quoted_name", $0.title) }
            .joined(separator: L("settings.shortcuts.name_separator"))
        return L("settings.shortcuts.conflict", names)
    }
}

/// The key field: the shortcut's keycaps, or while recording the placeholder
/// and an Inline Clear. It wears Text Field's container, with recording as its
/// Focused state.
private struct PlaybackShortcutField: View {
    let key: PlaybackShortcutKey?
    let isRecording: Bool
    let hasError: Bool
    let onStart: (MenuAnchorHandle) -> Void
    let onClear: () -> Void

    @State private var anchor = MenuAnchorHandle()

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                onStart(anchor)
            } label: {
                // The box keeps its size when a cleared shortcut leaves it empty.
                Color.clear
                    .frame(
                        width: SettingsShortcutsMetrics.fieldWidth,
                        height: WorkbenchControlMetrics.redesignFieldHeight
                    )
                    .overlay(alignment: .leading) {
                        content
                            .padding(
                                .horizontal,
                                WorkbenchControlMetrics.redesignFieldPaddingX
                            )
                    }
                    .workbenchFormFieldChrome(
                        hasError: hasError,
                        isFocused: isRecording
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(StaticButtonStyle())
            .focusable(false)

            // Laid over the field rather than inside its button, so a press on
            // it clears instead of starting the recording again. Its glyph
            // lines up with the field's own content inset.
            if isRecording {
                WorkbenchInlineClearButton(action: onClear)
                    .padding(
                        .trailing,
                        WorkbenchControlMetrics.redesignFieldPaddingX
                            - (WorkbenchControlMetrics.redesignInlineClearButtonSize
                                - WorkbenchControlMetrics.inlineClearIconSize) / 2
                    )
            }
        }
        .background(MenuAnchorProbe(handle: anchor))
    }

    @ViewBuilder
    private var content: some View {
        if isRecording {
            Text(L("settings.shortcuts.placeholder"))
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeControl,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.textPlaceholder)
                .lineLimit(1)
        } else if let key {
            HStack(spacing: WorkbenchControlMetrics.redesignSpacing1) {
                ForEach(key.keycaps.indices, id: \.self) { index in
                    PlaybackCueFooterKeycapView(
                        keycap: key.keycaps[index],
                        background: WorkbenchRedesignColors.popoverSurfaceKeycapBg
                    )
                }
            }
            .foregroundStyle(WorkbenchRedesignColors.textMuted)
        }
    }
}

/// Records one shortcut at a time. While it records, every key pressed in the
/// Settings window is its own — the App menu's shortcuts too — and a press
/// anywhere but the field ends the recording, as Esc does, without a change.
@MainActor
final class PlaybackShortcutRecorder: ObservableObject {
    @Published private(set) var recordingAction: PlaybackShortcutAction?
    @Published private(set) var rejection: PlaybackShortcutRejection?

    private var anchor: MenuAnchorHandle?
    private var record: ((PlaybackShortcutKey) -> Void)?
    private var pressMonitor: Any?
    private var resignKeyObserver: NSObjectProtocol?

    func start(
        _ action: PlaybackShortcutAction,
        anchor: MenuAnchorHandle,
        record: @escaping (PlaybackShortcutKey) -> Void
    ) {
        stop()
        recordingAction = action
        self.anchor = anchor
        self.record = record

        pressMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handlePress(event)
            }
            return event
        }
        // Leaving the window — another App, another window, closing it — ends
        // the recording too.
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: anchor.view?.window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }
    }

    func stop() {
        if let pressMonitor {
            NSEvent.removeMonitor(pressMonitor)
        }
        pressMonitor = nil
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        resignKeyObserver = nil
        anchor = nil
        record = nil
        if recordingAction != nil {
            recordingAction = nil
        }
        if rejection != nil {
            rejection = nil
        }
    }

    /// Takes a key pressed in the Settings window while a shortcut records:
    /// Esc cancels, an allowed key is written, any other key says why not.
    /// Returns whether the key was spent.
    func handleKey(_ event: NSEvent) -> Bool {
        guard let action = recordingAction,
              let window = anchor?.view?.window,
              event.window === window
        else {
            return false
        }
        if Int(event.keyCode) == kVK_Escape {
            stop()
            return true
        }
        switch action.recordedKey(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ) {
        case .success(let key):
            record?(key)
            stop()
        case .failure(let reason):
            rejection = reason
        }
        return true
    }

    private func handlePress(_ event: NSEvent) {
        guard recordingAction != nil else {
            return
        }
        if let view = anchor?.view,
           event.window === view.window,
           let frame = anchor?.windowFrame,
           frame.contains(event.locationInWindow) {
            return
        }
        stop()
    }
}

/// Offers the window's key equivalents to `handle` before the App menu gets
/// them. A key it does not spend goes on as usual.
private struct PlaybackShortcutKeyEquivalentCatcher: NSViewRepresentable {
    let handle: (NSEvent) -> Bool

    func makeNSView(context _: Context) -> CatcherView {
        CatcherView()
    }

    func updateNSView(_ nsView: CatcherView, context _: Context) {
        nsView.handle = handle
    }

    final class CatcherView: NSView {
        var handle: ((NSEvent) -> Bool)?

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            handle?(event) ?? false
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}
