# Shiori Tag Popover Interactions

## Human-Owned Source

- `docs/human/requirements/20260708-Feature-Shiori Tag Column And Popover.md`
- `docs/human/design/UI.md`

## Scope

Wire the documented Shiori Tags cell left-click behavior to a native tag
popover. This step covers the popover UI, local input behavior, tag association
commands, global tag deletion confirmation, and visible-cell patch refreshes.

## Classification

- Product semantics: applies the documented add, create, association removal,
  and global tag deletion behavior.
- Platform UI/UX: adds the Tag Composer field, global tag pool, Create row, and
  Delete Tag confirmation dialog.
- Platform integration: routes popover commands through existing AppCoordinator
  database access and patches visible Shiori tag cells through the row model
  store.
- Playback execution: unchanged.

## Changes

- Added a reusable Shiori tag popover view with a Tag Composer field, current
  tag chips, filtered global tag pool, and Create row.
- Added local composer input rules for the 20-character cap and forbidden
  control/format characters.
- Added popover delete confirmation content using the existing workbench dialog
  button styles and the documented Delete Tag text.
- Added AppCoordinator tag methods to load popover state, assign existing tags,
  create and assign tags, remove current-cue tag associations, and delete tags
  globally.
- Added a `cells` table-row update kind so tag association changes can redraw
  only the affected `Tags` cells.
- Connected Shiori Tags cell left-click to the same overlay positioning and
  clamping path used by the row action menu.
- Kept Tags cell right-click disabled.

## Verification

- `swift test --filter TableSandboxRowModelStoreTests`
  - Passed. Verified local Tags cell patch updates, affected visible-row
    deletion patching, neutral Shiori tag mapping, and composer input
    truncation/invalid-character filtering.
- `swift test --filter SubtitleTableVirtualRowTests`
  - Passed. Verified Tags left-click opens the popover, Tags right-click does
    not open a row menu, and existing virtual table interaction behavior still
    passes.
- `swift test --filter ShioriPresentationTests`
  - Passed. Verified existing Shiori presentation and playback-save behavior
    after adding tag command entry points to AppCoordinator.

## Outcome

The Shiori Tags column can now open a local tag popover, add existing tags,
create new tags, remove current-cue tag associations, and confirm global tag
deletion while preserving the documented refresh-scope contract for visible
table cells and the popover overlay.
