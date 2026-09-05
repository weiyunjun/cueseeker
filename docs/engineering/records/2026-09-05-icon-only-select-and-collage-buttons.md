# Select and Collage lose their labels, and the icon button's grey follows the surface

Human-owned documents:

- `docs/human/requirements/20260905-UI-Icon Only Select And Collage Buttons.md`

## Why

Two buttons still carried a bordered box and a text label while everything beside them had already become icon-only: `Select` sat next to the filter button in the search toolbar, and `Collage` sat alone in the Playback Overlay top bar. Both are mode switches, so the label was doing double duty — naming the action and announcing whether the mode was on (`Select` / `Exit Select`). Once the label goes, the open state has to carry that announcement on its own, which is exactly what the filter button's open background already does.

Removing the label exposed a second problem. The icon button's hover and open grey was a single token read against the Workbench's white surface. The Playback Overlay is not white: its surface is `--color-subtitle-focus-overlay-bg`, and `--color-bg-hover` sits three steps away from it — the Collage button's hover would have been invisible, and it would not have matched the `Save to Shiori` button directly below it, which has always used the overlay's own step. The requirement resolves this by making the grey relative to the surface rather than universal.

## What changed

The icon button now takes the fill it paints from its caller, defaulting to the Workbench step, and its open flag no longer claims to be about menus.

- `WorkbenchIconButton` renamed `isMenuOpen` to `isOpen` and gained `hoverBackground`, defaulting to `--color-bg-hover`. Hover and open still paint the same fill, so nothing about the Workbench buttons moves.
- The search toolbar's `Select` and the overlay top bar's `Collage` became `WorkbenchIconButton`. Each passes its mode flag as `isOpen` and keeps its former label as an accessibility label; `Collage` also keeps its two accessibility identifiers and passes the overlay's own grey.
- The Command Panel's secondary Back paints `--color-command-panel-shortcut-button-bg-hover`, the step that panel's own footer buttons use.

The surface rule is expressed as a colour the caller passes, not as a new surface type. Only one call site needs a value other than the default, and the Command Panel Back is hand-rolled rather than built on the component, so a shared enum would have been a type standing in for two literals.

`WorkbenchToolbarButton` now has no caller in the redesigned interface; its only remaining use is the legacy, non-redesign filter control bar. Per the requirement its design-system entry retires after acceptance, and the code is left alone.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskEntryButton.swift`

## Verification

Debug E2E controller, main window 1445×821, run once per appearance with `-appAppearanceMode` in the argument domain so the owner's stored preference was read but never rewritten (checked before and after: still `light`).

The open state is the measurement that matters, because it paints the same fill as hover and, unlike hover, it can be driven without a real pointer.

Shiori list detail, `Select` clicked into selection mode:

- Light: the button box reads `#F3F4F6` against a `#FFFFFF` page — `--color-bg-hover` exactly. Filter button beside it goes disabled, as before.
- Dark: `#27272A` against `#18181B` — again exact.

Playback Overlay / Current, `Collage` clicked into editing:

- Light: `#EDEEF2` against the overlay's `#F6F7F9` — `--color-playback-overlay-shortcut-button-bg-hover` exactly, the same step `Save to Shiori` uses in the footer below it.
- Dark: `#2C2C30` against `#242426` — exact.

At rest both buttons sample as the bare surface, so neither paints a fill it should not. Both render as borderless 32×32 boxes: `Select` sits flush beside the filter button in the toolbar row, `Collage` alone at the overlay top bar's trailing edge. On the Search page with no result set, `Select` renders in the disabled glyph colour.

`swift test`: 1132 tests, 24 issues, all in the families the earlier records already list as failing on this tree — native playback timeline and audio, cue group refresh scope, subtitle-focus Shiori saves, application persistence, and the Debug E2E window-geometry cases. No test reads a button's colours.

## Known limits

Hover itself is still not automatable, for the reason `docs/engineering/08_end_to_end_testing.md` §1.1 records: a synthesized `mouseMove` never reaches SwiftUI's `.onHover`. The open state proves the token for `Select` and `Collage` because both paint the identical fill, but the Command Panel Back has no open state, so its new grey remains a manual acceptance step. The owner was told rather than the test infrastructure grown.

Coordinates for the Shiori card, the `Select` button, the overlay tabs and the `Collage` button were derived ad hoc for this run and are not accepted procedure coordinates.

The Playback Overlay opens only while subtitles are on, and that setting persists between launches, so the sequence that reaches the overlay is not yet repeatable from a cold start without checking the current state first.

`UI Design System.md` still lists `Toolbar Button / Mode Toggle` for the search toolbar and `Button / Neutral` for the overlay top bar, and still describes the icon button's hover as one token. Per the owner's instruction the design documents are updated after this round of UI tuning is accepted, so that gap is expected until then.
