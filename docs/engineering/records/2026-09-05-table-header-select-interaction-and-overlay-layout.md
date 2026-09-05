# The header becomes the select-all target, the overlay stacks, the filter menu stops overhanging

Human-owned documents:

- `docs/human/requirements/20260905-UI-Table Header Select Interaction And Overlay Layout.md`

## Why

Three unrelated faults in the same screen.

The header greyed out on entering Select mode. Nothing about selection makes a column title unavailable — the header simply reused the table's own "enabled" flag, which the Select mode had been folded into, so every column title dropped to the Disabled colour for the whole selection. The state change was visible where nothing had changed.

The Selection Action Overlay put the count and three actions on one line, so the bar grew sideways with every action, and it offered no way out of Select mode: leaving meant travelling back up to the toolbar button that turned it on.

The filter menu hung off the filter button and was kept inside the page, not inside the page's content column. The page reserves 32pt on the leading side and 48pt on the trailing side (padding plus the vertical Scrollbar channel) for the toolbar and the table, so a menu clamped to the page itself sat 48pt further right than the row dividers under it.

## What changed

- The header's column titles no longer read Select mode. `updateHeaderHost` asks only whether the table is enabled, so the labels keep `--color-text-secondary` in both modes. The `#` column still swaps to the select-all Checkbox.
- The header view claims clicks while Select mode is on. `hitTest` routes everything except the Checkbox host to the header itself, and the toggle runs on mouse-up, which is where every other control in the App commits. The Checkbox keeps its own click, hover and focus handling. `acceptsSelectModeHeaderClick` carries the same guards the row Checkboxes use — enabled, in Select mode, rows present, no menu open, not covered by a higher layer — so a header click is inert under an open menu or a dialog. Header text selection was already off in Select mode, so nothing competes for the press.
- `SchemaWorkbenchSelectionActionOverlay` stacks the count over the actions and owns an Exit button (`xmark`, `Exit`) that calls the shell's existing selection-mode toggle. Placing it in the shell rather than in the two callers' action lists keeps one implementation for Search and Shiori. The recorded spacing — `--spacing-2` between rows, `--spacing-3` inside the action row, Padding Inline `--spacing-3` / Padding Block `--spacing-2` — is what the component already used; the design document's older single `--spacing-3` Padding and `--spacing-2` Content Gap never matched it, and the requirement's §5 has that correction waiting for the document pass.
- `filterMenuBounds(in:)` hands `MenuPlacement.openingFrame` the page's content column instead of the page. `openingFrame` takes one `edgeInset` for all four sides, which would have inset the vertical edges too, so the box is built directly from the two page paddings and keeps the host's full height.
- New string `table.toolbar.exit` in the three localisations.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/{en,zh-Hans,zh-Hant}.lproj/Localizable.strings`

## Verification

Debug E2E controller, main window 1280×821, Shiori list detail and Search, Light and Dark.

- Header colour: the header band excluding the index column is byte-identical between normal mode and Select mode, in both themes.
- Header click: a click on empty header space selects all 397 rows (Shiori) and 549 rows (Search); a second click clears them, and the resulting capture is byte-identical to the pre-click Select-mode capture.
- Overlay: renders as two rows with the count left-aligned to the Anki button and Exit last in the action row, in both themes.
- Filter menu: the table's row dividers end at pixel x=2463 and the menu's right border occupies x=2462–2463 — Shiori and Search, Light and Dark. At a 1000pt window, where the page scrolls sideways and the dividers run off-screen, the menu stays inside the visible page by the same trailing padding.

Full `swift test`: 1132 tests, 23 issues, in the families the earlier records list as failing on the baseline tree — native playback timeline and audio, library folder removal, cue group refresh scope, the Debug E2E window-geometry cases, persistence migration. The unmodified tree was run for comparison and failed in the same families; the two families differ only in which flaky cases happened to fail in each run.

## Known limits

The Exit button's action could not be verified through the controller. Its synthesized clicks do not activate any button in this overlay: `Copy Table` was clicked at its measured centre on the **unmodified** tree and left the clipboard untouched, so this is a pre-existing bound of the controller on this surface, not something the change introduced. Acceptance point 5's "click Exit and the selection clears" stays a manual check. No test infrastructure was added for it.

`SubtitleVirtualTableHeaderView` tracks a hover state (`isHeaderHovered`) that the redesign draw path never reads. It predates this change and is left alone.
