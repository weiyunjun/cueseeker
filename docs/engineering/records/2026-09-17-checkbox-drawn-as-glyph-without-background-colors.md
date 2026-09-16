# Checkbox: a glyph without background colours

Human-owned documents:

- `docs/human/requirements/20260917-UI-Checkbox Drawn As Glyph Without Background Colors.md`
- `docs/human/design/UI Design System.md` (Core Tokens / Control; Selection Controls / Checkbox; updated by the owner in the same session)

## Why

The design document described the checkbox as a box with a background and a separately coloured mark, but every checkbox has always been drawn as one monochrome Phosphor glyph: an outline circle unchecked, a filled circle with a cut-out check or dash otherwise. The unchecked background and the mark colour were never read. The owner kept the glyph, the MUI way of drawing a checkbox, and dropped the two colours.

Classified as platform UI.

## What changed

- Removed `bgCheckboxUnchecked` and `checkboxIcon` from the AppKit and SwiftUI token sets; nothing read them.
- The checkbox drawing is unchanged: unchecked uses `--color-border-checkbox`, checked and mixed use `--color-bg-checkbox-checked`, disabled uses `--color-text-disabled`.
- `docs/human/design/archive/UI.md` still names both colours; it is the archived design document and stays as it was.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`

## Verification

- `swift build`: passes.
- `swift test --filter 'Checkbox|checkbox|PlaybackCueResultLayoutTests'`: 28 tests pass.
- Appearance is unchanged by construction: no drawing path read either colour.
