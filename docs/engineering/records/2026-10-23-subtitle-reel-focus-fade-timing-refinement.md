# 2026-10-23 Subtitle Reel Focus Fade Timing Refinement

## Requirement Reference
- `docs/human/requirements/20261023-UI-Subtitle Reel Focus Fade Timing Refinement.md`

## Summary of Changes
1. **Subtitle Focus Motion Timing Tokens (`PlaybackTheme.swift`)**:
   - Updated `PlaybackSubtitleFocusMetrics.focusFadeOutDuration` (`--duration-subtitle-focus-fade-out`) from `0.26` to `0.30`.
   - Updated `PlaybackSubtitleFocusMetrics.focusFadeInDelay` (`--delay-subtitle-focus-fade-in`) from `0.18` to `0.10`.
   - Updated `PlaybackSubtitleFocusMetrics.focusFadeInDuration` (`--duration-subtitle-focus-fade-in`) from `0.22` to `0.30`.
   - Kept `reelTransitionDuration` (`0.40`), `scrollEasing`, and `focusFadeEasing` unchanged so `0.10s` delay + `0.30s` fade-in aligns with the `0.40s` single-step scroll completion.

## Verification
- Updated timing assertions in `PlaybackSubtitleFocusLayoutTests.swift` and verified `PlaybackSubtitleFocusLayoutTests` passes.
