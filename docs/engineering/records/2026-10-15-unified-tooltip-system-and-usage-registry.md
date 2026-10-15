# Implementation Record: Unified Tooltip System And Usage Registry

- **Date**: 2026-10-16
- **Requirement**: `docs/human/requirements/20261015-UI-Unified Tooltip System And Usage Registry.md`
- **Design References**:
  - `docs/human/design/ui/Tooltip Usage Registry.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Domain.md`
  - `docs/human/design/ui/UI Interaction Rules.md`

## Summary of Changes

1. **Unified Tooltip System & Token Alignment (`Tooltip.swift`, `WorkbenchControls.swift`)**:
   - Implemented `TooltipCenter`, `TooltipGeometry`, `TooltipOverlayView`, `TooltipStandardBubbleView`, `TooltipSurfaceBackground`, and `.workbenchTooltip(...)` / `.workbenchTruncatedTextTooltip(...)` modifiers.
   - Aligned tooltip container metrics and typography with `Neutral Button` (`C-03.1`):
     - Container background `--color-toast-bg`, border `--color-toast-border` with line width `--border-width-control` (`1px`), shadow `--shadow-popover`, corner radius `--radius-control` (`8px`).
     - Horizontal padding `--padding-control-x` (`14px`), vertical padding derived from `(--height-control - singleLineHeight) / 2` (`WorkbenchControlMetrics.redesignTooltipVerticalPadding`) so single-line tooltips are exactly `36px` (`--height-control`) tall and wrapped tooltips preserve identical top/bottom padding.
     - Primary label and inline shortcut text both use `--font-size-control` (`14px`) / `--font-weight-control` (`500`), separated by `--spacing-2` (`8px`).
     - Truncated text max width uses `--width-tooltip-max` (`280px`, `WorkbenchControlMetrics.redesignTooltipMaxWidth`) and default hover delay uses `--delay-tooltip-hover` (`1s`, `WorkbenchControlMetrics.redesignTooltipHoverDelay`), eliminating all hardcoded constants in `Tooltip.swift`.
   - Simplified table cue state tooltips (Scenario 24 `table.cue_state.content_changed` and Scenario 25 `table.cue_state.unavailable`) to reuse `TooltipStandardBubbleView` as single-line reason tooltips without titles, multi-row cards, or trailing periods.
   - **AttributeGraph Re-entrancy Crash Fix**: Removed the synchronous offscreen `NSHostingView` + `layoutSubtreeIfNeeded()` fallback from `TooltipOverlayView` and scoped `@State private var measuredSize` per target in `TooltipActiveBubbleView` so tooltip bubble sizing uses only SwiftUI's `GeometryReader` + `TooltipMeasuredSizeKey` pipeline without re-entering `AttributeGraph` during view evaluation.

2. **36 Registry Scenarios & Copy/Interaction Updates**:
   - Wired all 36 scenarios from `Tooltip Usage Registry.md` across Workbench topbar, playback chrome, command panel, inputs, settings, dialogs, cover summary cards, and table cue state indicators in English, Simplified Chinese, and Traditional Chinese.
   - Removed the `Esc` shortcut from `PlaybackReturnButton` (`player.topbar.return`).
   - Dynamic playback shortcut resolution reads `PlaybackShortcutKeymap.effectiveKey(for:)`, updating live when modified and omitting shortcuts when cleared or conflicted.
   - Updated Simplified/Traditional Chinese `topbar.back` (`后退` / `後退`) and renamed `Repeat` to `Replay Current Cue / 重播当前台词 / 重播目前台詞` while removing the playback HUD feedback on repeat cue.
   - Removed the redundant saving-state disable on dialog close buttons.

## Verification

- Verified unit and hosting-view layout regression tests in `TooltipTests` and `SubtitleTableRowActionMenuTests` (`swift test --package-path apps/macos-native --filter "TooltipTests|subtitleTableUnavailableExcerptActionsFollowResourceAvailability|subtitleTableChangedExcerptRemainsAvailable"`), including verifying that single-line `TooltipStandardBubbleView` fitting height equals `36px` (`--height-control`).
