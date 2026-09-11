# Player UI and pointer visibility rules

Human-owned documents:

- `docs/human/requirements/20260912-UI-Player UI And Pointer Visibility Rules.md`
- `docs/human/design/UI Application Rules.md` and `docs/human/design/UI Design System.md` (to be updated by the owner after acceptance)

## Why

The video page hid its Player UI and the pointer three seconds after the pointer last moved, wherever the pointer was: resting on a button, on the progress bar, or on the open speed menu made no difference. The Playback Overlay, the Command Panel and the dialogs did not stop that countdown either, so a panel opened with two seconds gone came back to a hidden Player UI, and the Task and Settings entries on the top bar hid it outright. The owner rewrote the rules: only the pointer on a clickable control, a drag of the progress bar, or keyboard focus on a Player UI control holds the countdown; same-window layers show the pointer and freeze the Player UI; losing focus or leaving the window hides the Player UI and shows the pointer; a hidden pointer always means a hidden Player UI; and the three seconds become a design token.

Classified as platform UI and UX: pointer, cursor and window focus are macOS presentation and interaction. No product semantics move; nothing in `CueSeekerCore` changes.

## What changed

- The visibility model is rewritten around a condition instead of an event. The idle countdown runs while the window has focus, no same-window layer is open, the pointer is inside the player area and on no clickable control, no scrubbing is in progress, and there is still something to hide; it is cleared when any of those breaks and started over when they all hold again, and pointer movement restarts it. When it ends, the pointer and the Player UI hide together. The keyboard-focus condition of the requirement has no trigger today and is recorded in the product document only.
- Entering the video page shows both and starts the countdown. Losing focus or the pointer leaving the window hides the Player UI and shows the pointer. Opening the Playback Overlay, the Command Panel or an in-window dialog shows the pointer and freezes the Player UI and the countdown; closing one reads the conditions again. Entering fullscreen hides both. A game controller's input hides both while the model governs the pointer; the keyboard hides nothing. Clicks and the wheel remain no movement.
- The system cursor is hidden only while the model governs the pointer: the window has focus, no layer is open, and the pointer's live position is inside the player area. Leaving governance releases it, so the pointer is on screen wherever the requirement says it is shown.
- Clickable controls report their frames through one anchor preference, `playerInteractiveRegion()`, that the stage collects and hands to the model: every bottom-bar icon button, the speed button and each speed menu item, the progress scrubber's hit area, the volume control, the return button, and the Task and Settings entries. The window controls' frames are read from AppKit. A hidden Player UI's controls do not count. The tracking view is flipped so the pointer converts into the same top-left coordinates as the SwiftUI frames.
- A hidden Player UI closes the speed menu instead of leaving it open under a transparent bar.
- `--duration-player-ui-idle-hide` is `PlaybackChromeMetrics.idleHideDuration`, 3 s, read by the model in place of the former hard-coded constant.
- `docs/product/12_liquid_glass_ux_mapping.md` §10.4 mirrors the requirement as v5 and the fullscreen note follows it; `docs/changelog.md` records the change.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackChromeVisibilityModel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackVideoStage.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeTrackingView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeIconButton.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackChromeSpeedMenu.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackProgressScrubber.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackVolumeControl.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/PlaybackReturnButton.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/TopbarAppEntries.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackChromeVisibilityModelTests.swift` (new)
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackNormalShortcutTests.swift`
- `docs/product/12_liquid_glass_ux_mapping.md`
- `docs/changelog.md`

## Verification

Unit tests, new in `PlaybackChromeVisibilityModelTests`, drive the model through its focus and pointer seams with a real window and the flipped tracking view, and call the countdown's end instead of waiting: entry shows both and the countdown runs, its end hides both and hides the cursor, movement shows both again; the pointer on a control's frame or scrubbing stops the countdown and movement off it starts it; a hidden Player UI's frames do not stop it; a layer shows the pointer and freezes a visible or a hidden Player UI, a controller's request does nothing while it is open, and closing it starts the countdown over; losing focus hides the Player UI, shows the pointer and stops the countdown, regaining it starts the countdown, and leaving the window hides the Player UI with the pointer shown; entering fullscreen and a controller's input hide both. The superseded test that expected a hidden pointer on entry is removed. With the playback shortcut suite: 12 tests, all passing.

`swift test`: 1202 tests, 1187 passing. The 15 failures are the native playback timeline, audio, presentation and auto-pause boundary cases, the refresh-scope counts, and the Debug E2E scene-geometry case that fail on the baseline as well, plus two library-folder-removal tests that pass 2 of 2 when run alone. None reads the Player UI or the pointer.

In the App: Debug E2E controller, main window 1445×821 at 2×, the video opened from the first Recent Videos card. The controller cannot move the physical pointer or reach the tracking area, so it reports only the cursor's hidden state and captures; the physical pointer stayed wherever the owner's mouse was.

- Entry: 2.5 s after the click the capture shows the top bar, the bottom bar and the window controls, with the pointer shown. Before this change the pointer was hidden on entry.
- Command Panel opened with K after the first countdown had ended: the pointer is shown while the panel is open; after Escape the Player UI stays hidden and the pointer shown, and 3.5 s later the cursor is hidden again — the countdown started over when the panel closed.
- Command Panel opened with K 1.6 s after entry: after Escape the capture shows the Player UI still visible with the pointer shown, so the panel froze the Player UI instead of letting it hide. The countdown after that did not end in a hide within 3.5 s. The physical pointer was then measured at 748 points below the window's top edge, inside the progress scrubber's hit area (739 to 757), where the rules hold the countdown; the measurement was taken after the pass, and the pointer had moved by the next reading, so this pass proves the freeze and not the hide.
- A third pass found the window inactive at the card click and did not reach the video page; it is discarded.

Not verified here and left to the owner's acceptance list: the pointer resting on each control and on the window controls, the speed menu closing with the hide, the drag of the progress bar, the Task and Settings entries, switching Apps, and fullscreen. Every one of them needs the physical pointer, which the controller does not move; the E2E gap is as recorded in `docs/engineering/08_end_to_end_testing.md`, and no E2E facility was added.

Outcome matched expectations as far as the controller could observe. The design documents are updated by the owner after acceptance, so `UI Application Rules.md` and `UI Design System.md` do not yet carry the rules or the token.
