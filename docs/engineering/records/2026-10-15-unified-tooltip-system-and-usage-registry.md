# Implementation Record: Unified Tooltip System And Usage Registry

- **Date**: 2026-10-16
- **Requirement**: `docs/human/requirements/20261015-UI-Unified Tooltip System And Usage Registry.md`
- **Design References**:
  - `docs/human/design/ui/Tooltip Usage Registry.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/UI Interaction Rules.md`

## Summary of Changes

1. **Unified Tooltip System (`Tooltip.swift`)**:
   - Implemented `TooltipCenter`, `TooltipGeometry`, `TooltipOverlayView`, `TooltipStandardBubbleView`, `TooltipSurfaceBackground`, and `.workbenchTooltip(...)` / `.workbenchTruncatedTextTooltip(...)` modifiers.
   - Unified all tooltips (including table cue state indicators) under the dark frosted container (`--color-toast-bg`, `1px` `--color-toast-border`, `--shadow-popover`), `--font-size-control` (`14px`) / `--font-weight-control` (`500`) for both primary label and inline shortcut text, 1.0s hover delay, top-centered placement with bottom flip and horizontal 8px window-margin shift, and immediate dismissal on pointer exit, mouse down, scroll, key press, or window/dialog transitions.
   - Simplified table cue state tooltips (Scenario 24 `table.cue_state.content_changed` and Scenario 25 `table.cue_state.unavailable`) to reuse `TooltipStandardBubbleView` as single-line reason tooltips without titles, multi-row cards, or trailing periods.
   - **AttributeGraph Re-entrancy Crash Fix**: Removed the synchronous offscreen `NSHostingView` + `layoutSubtreeIfNeeded()` fallback from `TooltipOverlayView` and scoped `@State private var measuredSize` per target in `TooltipActiveBubbleView` so tooltip bubble sizing uses only SwiftUI's `GeometryReader` + `TooltipMeasuredSizeKey` pipeline without re-entering `AttributeGraph` during view evaluation.

2. **36 Registry Scenarios & Copy/Interaction Updates**:
   - Wired all 36 scenarios from `Tooltip Usage Registry.md` across Workbench topbar, playback chrome, command panel, inputs, settings, dialogs, cover summary cards, and table cue state indicators in English, Simplified Chinese, and Traditional Chinese.
   - Removed the `Esc` shortcut from `PlaybackReturnButton` (`player.topbar.return`).
   - Dynamic playback shortcut resolution reads `PlaybackShortcutKeymap.effectiveKey(for:)`, updating live when modified and omitting shortcuts when cleared or conflicted.
   - Updated Simplified/Traditional Chinese `topbar.back` (`后退` / `後退`) and renamed `Repeat` to `Replay Current Cue / 重播当前台词 / 重播目前台詞` while removing the playback HUD feedback on repeat cue.
   - Removed the redundant saving-state disable on dialog close buttons.

## Verification

- Verified unit and hosting-view layout regression tests in `TooltipTests` and `SubtitleTableRowActionMenuTests` (`swift test --package-path apps/macos-native --filter "TooltipTests|subtitleTableUnavailableExcerptActionsFollowResourceAvailability|subtitleTableChangedExcerptRemainsAvailable"`).
