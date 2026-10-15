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
   - Implemented `TooltipCenter`, `TooltipGeometry`, `TooltipOverlayView`, `TooltipStandardBubbleView`, `TooltipCueStateBubbleView`, `TooltipSurfaceBackground`, and `.workbenchTooltip(...)` / `.workbenchTruncatedTextTooltip(...)` modifiers.
   - Unified all standard tooltips and `Cue State Tip` under the dark frosted container (`--color-toast-bg`, `1px` `--color-toast-border`, `--shadow-popover`), 1.0s hover delay, top-centered placement with bottom flip and horizontal 8px window-margin shift, and immediate dismissal on pointer exit, mouse down, scroll, key press, or window/dialog transitions.
   - **AttributeGraph Re-entrancy Crash Fix**: Removed the synchronous offscreen `NSHostingView` + `layoutSubtreeIfNeeded()` fallback (`fallbackSize(for:)`) from `TooltipOverlayView` and scoped `@State private var measuredSize` per target in `TooltipActiveBubbleView` so tooltip bubble sizing uses only SwiftUI's `GeometryReader` + `TooltipMeasuredSizeKey` pipeline without re-entering `AttributeGraph` during view evaluation.

2. **36 Registry Scenarios & Copy/Interaction Updates**:
   - Wired all 36 scenarios from `Tooltip Usage Registry.md` across Workbench topbar, playback chrome, command panel, inputs, settings, dialogs, cover summary cards, and table cue state indicators in English, Simplified Chinese, and Traditional Chinese.
   - Dynamic playback shortcut resolution reads `PlaybackShortcutKeymap.effectiveKey(for:)`, updating live when modified and omitting shortcuts when cleared or conflicted.
   - Updated Simplified/Traditional Chinese `topbar.back` (`后退` / `後退`) and renamed `Repeat` to `Replay Current Cue / 重播当前台词 / 重播目前台詞` while removing the playback HUD feedback on repeat cue.
   - Removed the redundant saving-state disable on dialog close buttons.

## Verification

- Verified unit and hosting-view layout regression tests in `TooltipTests` (`swift test --package-path apps/macos-native --filter TooltipTests`), including `tooltipOverlayViewRendersActiveItemInHostingViewWithoutReentrancyCrash`.
