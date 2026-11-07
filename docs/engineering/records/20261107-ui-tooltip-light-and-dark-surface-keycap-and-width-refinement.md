# Tooltip Light And Dark Surface, Keycap, And Width Refinement

## Summary

- Requirement: `docs/human/requirements/20261107-UI-Tooltip Light And Dark Surface Keycap And Width Refinement.md`
- Refined `C-08.6 Tooltip` in `WorkbenchRedesignTokens.swift` and `Tooltip.swift`:
  - Aligned Tooltip container background (`--color-bg-popover`: Light `#FFFFFF`, Dark `#36363B`), border (`--color-border-control`: Light `#E5E7EB`, Dark `#4A4A52`, width `1px`), and label color (`--color-text-secondary`: Light `#494949`, Dark `#B9B9B9`) with Toast across Light and Dark modes, and removed the hardcoded dark material backdrop.
  - Enforced Dark Mode appearance for Tooltips triggered on the video playback page itself (`Player Chrome`, i.e. `layerContext.layer == .playbackPage`), while Tooltips on Workbench, Settings, Dialogs, `Playback Overlay`, and `Command Panel` follow the App's effective Light / Dark Mode.
  - Updated Tooltip shortcuts to render as `C-08.9 Keycap / Popover Surface` items (`PlaybackCueFooterKeycapView` with `--color-popover-surface-keycap-bg` background and `--color-text-muted` label/icon), splitting modifiers (`⌃`, `⌥`, `⇧`, `⌘`) and primary keys into individual keycaps separated by `--spacing-1` (`4px`).
  - Added `TooltipWrappingTextLayout` so truncated-text tooltips (`wrapsText: true`) shrink-wrap to their natural single-line width when the container width is at or below `--width-tooltip-max` (`280px`), and lock the container width at `280px` (`252px` inner text width plus `2 × 14px` horizontal padding) with multi-line wrapping only when the single-line width exceeds `280px`.

## Verification

- `swift test --package-path apps/macos-native --filter "TooltipTests|ToastTests"`
