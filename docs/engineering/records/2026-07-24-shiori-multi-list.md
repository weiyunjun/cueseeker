# Shiori Multi-List

## Human-Owned Source

- `docs/human/requirements/20260723-Feature-Shiori Multi-List.md`
- `docs/human/design/UI.md`
- `docs/human/design/Toast Usage Registry.md`

## Scope

Implement the accepted Shiori multi-list persistence, overview and detail
workflows, list editing, row transfer actions, and shared Toast presentation on
the native macOS app.

## Step 1 Changes

- Migrated database schema 33 to 34 without dropping the existing Shiori list
  or its entries.
- Added list name, normalized name, multiline description, optional cover
  path, creation order, and the initial `Default` list metadata.
- Added list validation, create, edit, delete, ordering, and last-list deletion
  protection to `CueSeekerCore`.
- Added per-list Cue counts and CueID-deduplicated overview counts.

## Step 1 Verification

- Selected schema migration, list CRUD and validation, sorting, delete
  protection, and overview count tests passed (4 tests).
- `git diff --check` passed.

## Outcome

- Implementation is in progress. Step 1 matched the accepted persistence and
  validation requirements.
