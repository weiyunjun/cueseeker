# Requirement

- `docs/human/requirements/20260811-Engineering-Debug End-to-End In-App Keyboard Event Interaction.md`

# Scope

- Add a Debug E2E command for one in-app, non-repeating keyboard press.
- Preserve the current key window, first responder, AppKit shortcut path, scene-token contract, and Release isolation.
- Do not add system-wide event injection, permission requirements, or shortcut-specific product commands.

# Steps

- Added `keyPress` parsing with a required key, modifier list, and current `sceneID`.
- Mapped the accepted letters, digits, navigation keys, and modifiers to complete AppKit keyboard event data.
- Posted key-down and key-up events to the current visible CueSeeker key window through the application event queue.
- Reused the existing scene revision and response metadata after each successful keyboard interaction.
- Added explicit unsupported-key, unsupported-modifier, unavailable-key-window, stale-scene, and event-creation failures.
- Updated the Debug E2E procedure and testing rules for shortcut-driven flows.

# Verification

- `swift test --filter DebugE2EControllerTests` passed all 6 focused tests for command parsing, supported key and modifier mapping, rejected values, and first-responder delivery.
- `swift test --no-parallel --skip sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` passed all 975 remaining tests. The skipped pre-existing order-dependent migration test passed when run alone.
- A live Debug run used coordinate clicks to open `BanG Dream! - 12`, then `keyPress` with `enter` followed the existing shortcut path and opened the actual Cue Reel UI. The in-app capture contained that visible result, and the successful interaction returned a fresh `sceneID`.
- Live commands using the previous `sceneID` and an unsupported `f13` key returned `sceneChanged` and `unsupportedKey` respectively.
- `swift build -c release --product CueSeeker` passed. The Release executable contains neither the Debug E2E flag nor the `keyPress` command string, and does not link Carbon or ScreenCaptureKit.

# Outcome

- Debug E2E tests can exercise existing CueSeeker shortcuts without Accessibility, Input Monitoring, global event injection, or product-action backdoors.

# Follow-ups

- Feature-specific E2E procedures should use `keyPress` when an accepted flow requires an existing CueSeeker shortcut.
