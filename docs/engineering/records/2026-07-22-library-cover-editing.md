# Library Cover Editing Implementation

## Requirement

- `docs/human/requirements/20260722-Feature-Library Cover Editing.md`
- `docs/human/design/UI.md`

## Status

In progress.

## Scope

- Persist user-selected Library video and folder covers independently from
  Index-generated covers.
- Import and validate JPEG, JPG, PNG, and GIF sources up to 20,000,000 bytes.
- Provide the fixed 16:9 Edit Cover crop workflow and shared Library card
  context-menu entry.
- Save only a 512 x 288 JPEG display rendition and refresh the affected cover
  presentations without rebuilding the full interface.

## Engineering Decisions

- User video and folder cover relationships use dedicated database tables.
  Presentation queries prefer a user cover and fall back to the existing Index
  cover; Index records and files remain untouched by user edits.
- PNG transparency and the first decoded GIF frame are composited in sRGB over
  an opaque white matte before preview and JPEG encoding. The matte is stable
  across appearance and accent-color changes, and the preview matches the saved
  result.

## Steps

1. Added user video and folder cover persistence, schema migration, and
   user-first presentation resolution while preserving Index cover records.
2. Pending: add import validation, crop export, atomic replacement, and targeted
   decoded-image cache invalidation.
3. Pending: add fixed-ratio crop geometry and AppKit interaction.
4. Pending: add Finder selection and the Edit Cover dialog workflow.
5. Pending: connect the shared Library card context menus.
6. Pending: complete targeted refresh integration and full verification.

## Verification

- User-cover precedence, Index isolation, and replacement persistence: 1 test
  passed.
- Existing Library cover and split folder/detail presentation selection: 18
  tests passed.
- Pending later-stage and full test runs.

## Outcome

Implementation is in progress.
