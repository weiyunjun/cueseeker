# The Selection Action Overlay becomes one row of shortcut action buttons

Human-owned documents:

- `docs/human/requirements/20260907-UI-Selection Action Overlay Shortcut Buttons.md`

## Why

The workbench Selection Action Overlay and the Playback Overlay's footer offered
the same kind of thing — a short list of actions on whatever is currently
selected — in two unrelated visual languages: 40pt bordered buttons with icons
on one side, borderless text plus a keycap on the other. The overlay also had no
keyboard entry at all, so the four actions were reachable only with the pointer.

Two names had drifted with them. `Shortcut Action Button` and `Keycap` each
carried two colour variants named after the interface that first used them,
`Playback Overlay` and `Command Panel`, when the real difference between the two
sets is the surface underneath: one sits on `--color-subtitle-focus-overlay-bg`,
the other on `--color-bg-popover`. With a second popover-surface user arriving,
the interface names stopped describing anything.

## What changed

**The overlay is one row.** The count sits on the left, the four buttons on the
right, `--spacing-4` between the two groups. There is no stretch to the
container's edges; the container is as wide as its content. The count carries an
extra `--spacing-3` of leading inset so that it starts where the first button's
own transparent padding starts, which is what keeps the two ends of the container
looking equally clear. Everything about the container itself — position, popover
background, border, radius, shadow, padding — is unchanged. The old two-row
structure and its Row Gap are gone.

**The buttons are text plus a keycap.** `Export to Anki` `A`, `Copy Deep Links`
`D`, `Copy Table` `T`, `Exit` `Esc`, in that order, with no icons, no border,
and only Default and Hover: no pressed state, no Disabled, no Open, and — the one
visible consequence worth naming — no Focused state either, so they no longer
take a Tab stop. Hovering a button reveals its background and deepens its keycap
one step at the same time.

This is a second implementation, not a shared one. `SchemaWorkbenchSelectionActionOverlay.swift`
carries the workbench's own button, keycap and action model. The two surfaces
share a visual language and their colour tokens, not their code, which is what
lets the workbench take its own metrics — `--spacing-3` / `--spacing-2` of button
padding against the playback footer's `--spacing-2` / `--spacing-1` — without
either surface constraining the other.

**The keys live and die with the overlay.** A local key monitor is mounted inside
the overlay itself, which exists only in Select Mode, so nothing outside has to
remember to switch it off. It answers only for its own window, so a key pressed
while another window is the key window — Settings, say — belongs to that window
and is passed straight through. It also stands down whenever the workbench page
is frozen, which is the single question that covers both "a higher layer is
open" and "a menu is open at or above this layer": with a dialog up, `A`, `D`,
`T` do nothing and `Esc` closes the dialog rather than Select Mode. An editable
text field holding focus stands it down too.

**The two colour variants are named after their surface.** `Playback Overlay`
became `Overlay Surface` and `Command Panel` became `Popover Surface`; the six
tokens follow the same rename. No colour value moved, so the playback footer and
the Command Panel look exactly as they did.

**The count says rows.** `table.selected_count` split into `.one` and `.other`,
matching the shape `table.result_count` next to it already used, so English reads
`1 row selected` rather than `1 rows selected`. Chinese does not distinguish.

## Verification

`swift build` clean. `swift test`: 1142 tests. Failing-test names were compared
against a `git archive` export of `a9450797` built with the same media runtime:
**no test fails here that does not also fail there**, and this tree has one fewer
failure than the baseline (`libraryFolderRemovalAndIndexingRejectEachOther`,
which is order-dependent and passes in a filtered rerun on both). The baseline
set is the same environment-bound one earlier records describe — native playback
media and presentation tests, the Debug E2E scene and window tests, three
`CueGroupRefreshScopeIntegrationTests`, and the shared-persistence migration test.

Debug E2E controller, `swift run CueSeeker --cueseeker-debug-e2e`, against the
real library:

1. Shiori list detail and Workbench Search, Select Mode: the overlay is one row
   reading `0 rows selected`, `Export to Anki A`, `Copy Deep Links D`,
   `Copy Table T`, `Exit Esc`. Both tables are identical.
2. Selecting one row reads `1 row selected`; two reads `2 rows selected`; the
   header's select-all reads `549 rows selected`.
3. `D` with the clipboard cleared beforehand leaves a `cueseeker://cue?id=…`
   markdown link on it; `T` leaves the TSV table with its header row.
4. Clicking `Copy Deep Links` and `Copy Table` puts the same content on the
   clipboard as their keys. Clicking `Exit` leaves Select Mode.
5. `Esc` leaves Select Mode: the checkboxes go, the `#` column returns, the
   overlay disappears.
6. Pointer over `Copy Table`: the button background appears and its keycap
   deepens. Holding the left button down on it changes nothing.
7. Task panel dialog open: `A`, `D` and `T` leave the clipboard untouched and
   `A` opens no save panel; the button's hover clears while the dialog is up and
   returns when it closes. `Esc` closes the dialog and leaves Select Mode on; a
   second `Esc` then leaves Select Mode.
8. Light and Dark both checked for the layout, the count and the hover.
9. Playback Overlay footer and Command Panel footer: unchanged, keycaps intact.

Five acceptance items could not be exercised and are listed below rather than
claimed.

## What the controller could not reach

- **A key pressed while another window is focused.** The controller stamps every
  injected key event with the main window's number, so the state where Settings
  is the key window cannot be constructed. The guarantee is the monitor's own
  window check; it is read from the code, not measured.
- **Simplified and Traditional Chinese counts.** The language setting is a native
  popup menu. Neither the controller's clicks nor its key events reach an
  `NSMenu`'s own tracking loop, so the menu opens and then ignores everything.
- **`Export to Anki`, by key or by click.** It opens a modal `NSSavePanel`, whose
  run loop blocks the controller's command loop; with no Accessibility grant on
  this machine the panel cannot be dismissed from outside either. That the action
  fires is known only from the block itself.
- **A row menu open over Select Mode.** Right-click opens no row menu in Select
  Mode, so the path does not exist. The same freeze was exercised through the
  Task panel dialog instead.
- **Letters typed into a focused search field.** The search field is disabled in
  Select Mode and cannot take focus. The editable-text guard therefore only
  covers fields inside dialogs, which the freeze already covers.

## The Tab stop that went away

In Select Mode the overlay's four buttons used to be Tab stops and drew the
focus ring; the baseline shows the ring on `Copy Deep Links` after three Tabs.
They are not focusable any more, which follows from the requirement giving the
button only Default and Hover. Keyboard users reach the same four actions
through `A`, `D`, `T` and `Esc` instead. The table's own Tab, Space and arrow
handling was not touched.
