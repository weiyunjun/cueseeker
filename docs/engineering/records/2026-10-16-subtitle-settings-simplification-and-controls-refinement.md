# 2026-10-16 Subtitle Settings Simplification And Controls Refinement

## Requirement Source
- [`docs/human/requirements/20261016-UI-Subtitle Settings Simplification And Controls Refinement.md`](../../human/requirements/20261016-UI-Subtitle%20Settings%20Simplification%20And%20Controls%20Refinement.md)

## Summary of Changes
1. **SRT Subtitle Style & Renderer (`CueSeekerPlayback`)**
   - Simplified `SRTSubtitleStyle.BorderType` to `.outline` and `.backgroundBox` (with legacy `"opaqueBox"` decoding fallback to `.backgroundBox`).
   - Updated `SRTSubtitleStyle.referenceHeight` to `1080` (`1080p` baseline) and updated defaults to `size = 28`, `lineSpacing = 6`, `outlineWidth = 2`.
   - Updated `SRTFontCache` so `Size` maps 1:1 to `CTFont` `pointSize` at `1080p` (`pointSize = lineHeight`), and kept drop shadow rendering active in both `.outline` and `.backgroundBox` modes.
2. **Subtitle Settings UI & Custom Controls (`CueSeekerApp`)**
   - Reordered `SettingsSubtitleCategory` sections to `Text` → `Position` → `Border` → `Shadow` with `Restore Defaults` at the bottom.
   - Replaced static disabled rows in `Border` with dynamic row visibility (`Outline`: `Type`, `Outline Color`, `Outline Width`, `Blur`; `Background Box`: `Type`, `Background Color`, `Background Opacity`, `Blur`) and kept `Shadow` (`Shadow Color`, `Shadow Opacity`, `Shadow Offset`) active in both modes.
   - Implemented `SettingsSubtitleFontTrigger` and `SettingsSubtitleFontMenu` with `WorkbenchSearchField`, `MenuHighlightModel` defaulting to index `0` on open and query change, `↑`/`↓` highlight navigation while keeping search input focus, `Return` selection, `Esc`/outside-click dismissal, and `No Results` empty state.
   - Implemented `SettingsSubtitleColorField` and `SettingsSubtitleColorPresetsPopover` (borderless solid rounded swatch + fixed `#` prefix + 3-digit / 6-digit hex input with 4–5 digit truncation to 3 digits on blur, 0–2 digit restore on blur, `#` stripping and `.` / newline truncation on paste, and a 6×2 preset color popover).
   - Refined `SettingsSubtitleNumberField` (no stepper arrows, integer `0-9` only, `%` unit suffix for opacity fields, immediate upper-bound clamping, `.` / newline truncation on input/paste, no action on `Return`, and lower-bound clamp / empty restore on blur).

## Verification
- `swift test --package-path apps/macos-native --filter "SRTSubtitleStyleRenderingTests|SettingsStorePlaybackTests|AppLocalizationTests|WorkbenchInputControlsTests"`
