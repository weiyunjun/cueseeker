# Shiori Tag Backend Schema

## Human-Owned Source

- `docs/human/requirements/20260708-Feature-Shiori Tag Column And Popover.md`
- `docs/human/design/UI.md`

## Scope

Add the durable backend foundation for Shiori tag management before wiring the
table and popover UI. This step covers schema, migration, tag validation, and
database APIs only.

## Classification

- Product semantics: Shiori tag identity, text validation, assignment, and
  deletion semantics.
- Platform UI/UX: unchanged in this step.
- Platform integration: unchanged in this step.
- Playback execution: unchanged.

## Changes

- Bumped the native SQLite schema from version `25` to `26`.
- Added `shiori_tags` for the global Shiori tag pool.
- Added `shiori_tag_assignments` for many-to-many Shiori/tag associations.
- Added Core value types for Shiori tags and tag deletion results.
- Added tag validation for trim, 20-character limit, case-sensitive identity,
  and forbidden control/format characters.
- Added Core database APIs to list, create, assign, unassign, and delete Shiori
  tags.
- Made global tag deletion report affected Shiori IDs so later UI work can
  patch affected visible rows without rebuilding the whole Shiori table.
- Updated database engineering and product data-model documents for schema
  version `26`.

## Verification

- `swift test --filter ShioriTag`
  - Passed. Verified the schema migration creates the Shiori tag tables and
    migrating a version `25` database keeps existing Shiori rows.
- `swift test --filter shioriTag`
  - Passed. Verified tag creation, case-sensitive identity, assignment,
    duplicate assignment no-op behavior, assignment removal, global deletion,
    affected Shiori ID reporting, and text validation.
- `swift test --filter SubtitleDatabaseTests`
  - Passed. Verified the database regression suite after the schema bump and
    new tag APIs.

## Outcome

Backend tag storage and APIs are ready for the later Shiori table and popover
UI steps. The UI-facing delete API reports affected Shiori IDs so the table can
refresh only visible rows that actually lost the deleted tag.
