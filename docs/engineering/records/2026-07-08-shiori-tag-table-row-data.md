# Shiori Tag Table Row Data

## Human-Owned Source

- `docs/human/requirements/20260708-Feature-Shiori Tag Column And Popover.md`
- `docs/human/design/UI.md`

## Scope

Thread durable Shiori tag data into the existing Shiori table row model before
rendering the new `Tags` column.

## Classification

- Product semantics: unchanged from the schema/API step.
- Platform UI/UX: prepares Shiori row view-model data for the documented Tags
  column.
- Platform integration: queries the current Shiori page's tag assignments in
  one batch.
- Playback execution: unchanged.

## Changes

- Added separate Shiori tag chip data to `SubtitleTableRow` so Language tags
  and Shiori tags remain distinct.
- Added Shiori tags to `TableSandboxShioriRowSource`.
- Loaded tag assignments for the current Shiori table page with
  `shioriTagsByShioriID(forShioriIDs:)`.
- Mapped Shiori tags to neutral `.gray` workbench chips, matching the
  documented neutral Shiori tag style.

## Verification

- `swift test --filter TableSandboxRowModelStoreTests`
  - Passed. Verified existing row-store behavior and the new Shiori tag mapping
    to neutral chip data.

## Outcome

Shiori table rows now carry durable tag chip data independently from Language
tags. The next step can render the fixed-width `Tags` column without changing
the page-loading contract.
