# Icon buttons answer the pointer again, and the open state stops being accent

Human-owned documents:

- `docs/human/requirements/20260905-UI-Icon Button Hover And Open Background.md`

## Why

Icon-only buttons had no hover response at all: the pointer could rest on the back button, the task entry or the filter button and nothing on screen moved, which reads as "not clickable". The two buttons that do have an open state answered with the macOS accent colour and a white glyph, which is louder than anything else in the same row — the Toolbar Button next to the filter button (`Select`) has used the neutral `--color-bg-hover` for both hover and open since it was written.

Both were deliberate: `20260901-UI-Icon Button Color Weight And Hover Removal.md` §5 removed hover and §6 kept the accent open state. The new requirement supersedes exactly those two sections and leaves that document's colour, weight and size rules in force.

## What changed

One model now covers hover and open for every icon-only button outside the player: the button box fills with `--color-bg-hover`, the glyph keeps `--color-text-secondary`, and nothing else about the button moves. Disabled buttons never fill.

- `WorkbenchIconButton` gained `isHovered` fed by the shared `onPointerHover` modifier, and its background became `isEnabled && (isHovered || isMenuOpen)` — the same expression `WorkbenchToolbarButton` already used. Its icon colour no longer branches on the open state. This one component carries the top bar Back, the task entry, the filter button, the dialog close buttons, the task panel close button and the task card remove and delete buttons.
- The sidebar toggle, the search field's inline clear button and the Command Panel secondary Back each paint the same fill behind their own box, keeping their own radius: `--radius-control` for the first and last, the fully round inline-clear radius for the clear button.
- `iconButtonOpenBg` and `iconButtonOpenContent` lost their only caller and are gone from the token file. `iconOnDark`, which the second one aliased, still serves the sidebar selection, the library cover edit overlay and the task count badge.

`onPointerHover` rather than a bare `onHover` is the load-bearing choice: it is where "a menu open over a layer stops every surface on that layer from answering the pointer" lives (`UI Application Rules.md` 菜单模态 4), so the new hover obeys that rule without a single extra branch, and a pointer that walked away while a menu was up does not leave a button lit.

The size-transition freeze needed no code. `isFrozen` disables the button from inside its own body, so `isEnabled` still reports what the caller asked and the painted appearance cannot flip when the freeze starts; and the two controls that freeze — Back and the sidebar toggle — sit against the window's leading edge, so a resize does not slide them out from under a stationary pointer.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`

## Verification

Debug E2E controller, main window 1445×821, run once per appearance with `-appAppearanceMode` passed in the argument domain so the owner's stored preference was read but never rewritten (checked before and after: still `dark`).

Filter button with its menu open, which no dialog dimming covers, is the exact measurement:

- Light: the button box reads `#F3F4F5`–`#F4F5F6` against `--color-bg-hover` `#F3F4F6`, with a dark glyph.
- Dark: the box reads `#333336`. The capture applies one consistent transfer to dark neutrals — `--color-app-topbar-bg` `#18181B` reads `#202024`, `--color-bg-popover` `#1C1C1F` reads `#252529`, `--color-app-sidebar-bg` `#202024` reads `#2B2B30` — and `#27272A` maps to `#333336` under the same curve, so the fill is `--color-bg-hover`.

Task entry with the task panel open, both appearances: a neutral grey box with the secondary glyph, no accent and no white glyph anywhere on it (the dialog dims the whole window, so this frame proves the colour family, not the exact token). Escape closes the panel and the fill goes with it. The resting Workbench and the resting search row are unchanged: no fill behind the back button, the sidebar toggle, the task entry, the filter button or the inline clear button.

`swift test`: 1132 tests, 24 issues, all in the families the earlier records already list as failing on this tree — native playback timeline and audio, library folder removal, cue group refresh scope, subtitle-focus Shiori saves, and the Debug E2E window-geometry cases. No test reads an icon button's colours, and this change adds no logic.

## Known limits

The hover fill itself could not be verified automatically. `docs/engineering/08_end_to_end_testing.md` §1.1 records why: `mouseMove` is a synthesized AppKit event and never reaches SwiftUI's `.onHover`, so every surface whose hover comes from that modifier — which is all of these — stays a manual acceptance step. Automating it would need pointer capability the project does not have; the owner was told rather than the test infrastructure grown.

The filter button's click coordinate was derived ad hoc for this run and is not an accepted procedure coordinate; the In-App E2E preconditions still list none for it.

`UI Design System.md` still describes the icon button's open state as accent and lists no hover for it or for the sidebar toggle. Per the owner's instruction the design documents are updated after this round of UI tuning is accepted, so that gap is expected until then.
