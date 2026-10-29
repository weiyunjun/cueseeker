# 2026-10-29 Playback Progress Initialization, Seek Feedback, and Loading Spinner

## Requirement Reference
- `docs/human/requirements/20261029-UI-Playback Progress Initialization Seek Feedback And Loading Spinner.md`

## Summary of Changes
1. **Playback Feedback Spinner Tokens (`PlaybackTheme.swift`, `WorkbenchSpinner.swift`, `PlaybackFeedbackOverlay.swift`)**:
   - Added `--size-playback-feedback-spinner: 23px` (`PlaybackChromeMetrics.feedbackSpinnerSize`), `--color-playback-feedback-spinner-track: rgba(255,255,255,0.24)` (`PlaybackTheme.feedbackSpinnerTrack`), and `--color-playback-feedback-spinner-indicator: rgba(255,255,255,0.80)` (`PlaybackTheme.feedbackSpinnerIndicator`).
   - Updated `--delay-playback-loading-feedback` from `150ms` to `300ms` (`PlaybackChromeMetrics.loadingFeedbackDelay` / `loadingFeedbackDelayMilliseconds`).
   - Extended `WorkbenchSpinner` with configurable `trackColor` and `indicatorColor` (defaulting to the standard Workbench spinner tokens) and wired `PlaybackFeedbackOverlay` to render the `23px` high-contrast spinner inside the `52×52px` loading capsule.
2. **Post-HUD Relay Timing for Loading Spinner (`PlaybackViewModel.swift`, `PlaybackViewModel+Feedback.swift`)**:
   - Updated `scheduleLoadingFeedback` and `showFeedback` so that when an action HUD (`Next Video`, `Next Result`, seek step, etc.) is active, the loading feedback timer is cancelled and only begins counting the `300ms` (`--delay-playback-loading-feedback`) threshold after the action HUD finishes playing if the target video presentation is still pending.

## Verification
- Updated and ran `PlaybackPresentationTransitionTests` (`swift test --filter PlaybackPresentationTransitionTests`), verifying the `23px` spinner size token, `300ms` delay token, immediate vs. delayed loading spinner visibility, post-HUD `300ms` relay timing, and immediate dismissal upon frame commit.
- Outcome matched expectations.
