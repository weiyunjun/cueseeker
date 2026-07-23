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

## Step 2 Changes

- Changed transitional Save Shiori behavior to use the first list in the
  documented creation-time order.
- Added explicit list-scoped Shiori save, lookup, snapshot, count, and resolved
  item queries.
- Added atomic Move and Duplicate operations. Both preserve the Shiori creation
  time and tag assignments; Move deletes the source only after the destination
  relation and tags have been written.
- Added stable errors for unavailable destinations and duplicate CueIDs in a
  destination list.

## Step 2 Verification

- Selected list-scoped save, Move, Duplicate, metadata preservation, validation,
  and existing Shiori persistence tests passed (4 tests).
- `git diff --check` passed.

## Outcome

- Implementation is in progress. Steps 1 and 2 matched the accepted persistence,
  validation, list scope, and transfer requirements.
