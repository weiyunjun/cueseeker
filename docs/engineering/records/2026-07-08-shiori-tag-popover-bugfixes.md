# Shiori Tag Popover Bugfixes

## Human-Owned Source

- `docs/human/requirements/20260708-Feature-Shiori Tag Column And Popover.md`
- `docs/human/design/UI.md`

## Scope

Fix the first end-to-end Shiori tag popover issues found during manual testing:
popover inside clicks must not dismiss the popover, Tags must sit immediately
after Cues in the Shiori table, and typing a non-matching tag must expose the
Create row instead of being clipped by the original popover measurement.

## Classification

- Product semantics: unchanged.
- Platform UI/UX: fixes Shiori table column order, Tags cell hit testing, and
  tag popover interaction/measurement behavior.
- Platform integration: unchanged.
- Playback execution: unchanged.

## Changes

- Moved the Shiori `Tags` column after `Cues` in the schema-driven Shiori
  column list and table layout fallback order.
- Kept Tags cell left-click hit testing on the full Tags data cell area,
  including empty space.
- Added popover overlay passthrough for the active menu host so clicks inside
  the popover are not treated as outside-dismiss clicks.
- Added menu host intrinsic-size invalidation handling and an explicit popover
  layout request callback so local content changes can remeasure and reclamp
  the open popover.
- Rendered the Create option as its own global-pool row and gave the pool a
  content-driven minimum height so a valid non-matching input can show the
  Create row.

## Verification

- `swift test --filter SchemaWorkbenchFilterRulesTests`
  - Passed. Verified Search columns stay unchanged and Shiori column menu order
    is `Display Title`, `Cues`, `Tags`, `Time`, `Date Added`.
- `swift test --filter SubtitleTableVirtualRowTests`
  - Passed. Verified Tags after Cues in explicit layout, Tags empty-cell
    clicks open the popover, and points inside the menu host are recognized as
    inside clicks.
- `swift test --filter SubtitleTableClipboardTests`
  - Passed. Verified visible tag columns still copy as text after the column
    order fix.
- `swift test --filter TableSandboxRowModelStoreTests`
  - Passed. Verified tag row patching and existing Shiori row-store behavior.
- `swift test --filter shioriTag`
  - Passed. Verified tag API validation and composer input rules after the UI
    fix.

## Outcome

The Shiori tag popover now keeps internal clicks inside the popover, can
remeasure when typing changes its local content, and presents the Shiori `Tags`
column immediately after `Cues` as documented.
