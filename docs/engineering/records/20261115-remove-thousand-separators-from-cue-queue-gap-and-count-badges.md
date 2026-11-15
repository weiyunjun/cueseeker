# 2026-11-15 Remove Thousand Separators from Cue Queue Gap and Count Badges

- **Covering Requirement**: `docs/human/requirements/20261115-UI-Remove Thousand Separators From Cue Queue Gap And Count Badges.md`
- **Branch / Baseline**: `main` (`4cd0d06`)

## Summary of Changes

1. **Remove thousands commas from player cue queue control bar gap stepper (`C-12.7 Player Cue Queue Control Bar`)**
   - `apps/macos-native/Sources/CueSeekerApp/Playback/Chrome/PlaybackCueQueueControlBar.swift`: Constructed plain `String` value `gapText = "\(gapMilliseconds) ms"` in `PlaybackCueQueueGapStepper.body` and passed that `String` binding to both `Text` and `.accessibilityValue`, preventing SwiftUI `LocalizedStringKey` integer interpolation from inserting locale thousands separators (`1,000 ms` / `10,000 ms` now render as contiguous Arabic numerals `1000 ms` / `10000 ms`). Existing layout and style tokens (`cueQueueGapValueWidth`) remain unchanged.

2. **Remove thousands commas from count badges (`C-08.3 Information Badge` / `Task Count Badge`)**
   - `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskEntryButton.swift`: Replaced `Text("\(count)")` with `Text(String(count))` in `TaskCountBadge` (matching `CueFacetFilterChip`), covering main-window and playback topbar Task entry buttons, toolbar Filter buttons, and compact group badges in the Filter dialog so counts `>= 1000` render without thousands commas (e.g. `1000`). Existing sizing and style tokens remain unchanged.

3. **Scope check**
   - Added no standalone modules, shared formatting wrappers, intermediate models, UI token changes, playback volume percentage edits, `docs/human/design/` modifications, or production test backdoors.

## Compilation & Unit Test Verification

Executed after the final code edits:

1. **Build verification**:
   - `swift build --package-path apps/macos-native`: `Build complete!`.
2. **Targeted headless pure-logic tests (filtered, zero window popups)**:
   - `swift test --package-path apps/macos-native --filter "SettingsStorePlaybackTests|TaskQueueStoreTests|WorkbenchControlMetricsTests|PlaybackSegmentCompletionTests"`
   - Result: `93` Swift Testing cases passed (`0` failed, zero window popups).
3. **End-to-end acceptance**:
   - Visual presentation and interactive behavior across the playback page and main workbench window remain with the user for acceptance verification.
