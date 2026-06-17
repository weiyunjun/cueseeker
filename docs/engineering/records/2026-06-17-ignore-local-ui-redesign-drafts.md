# Ignore Local UI Redesign Drafts

Human requirement:

- `docs/human/requirements/20260615-Feature-UI Redesign.md`

## Scope

This record covers restoring local UI redesign draft files that were accidentally committed and later removed from the working tree during reset operations, then explicitly excluding those local draft paths from future commits.

## Changes

- Restored local-only files from commit `f705b5ff`:
  - `docs/human/design/UI Redesign.md`
  - `docs/human/design/assets/20260613/`
- Updated `.gitignore` to explicitly ignore those restored local draft paths.

## Notes

- The restored draft files are intentionally not tracked by Git.
- The canonical requirement source remains `docs/human/requirements/20260615-Feature-UI Redesign.md`.
