# Library Cover Editing Implementation

## Requirement

- `docs/human/requirements/20260722-Feature-Library Cover Editing.md`
- `docs/human/design/UI.md`

## Status

In progress.

## Scope

- Persist user-selected Library video and folder covers independently from
  Index-generated covers.
- Import and validate JPEG, JPG, PNG, and GIF sources up to
  20 x 1,024 x 1,024 bytes (20,971,520 bytes), rather than the decimal byte
  count displayed by macOS Finder.
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
2. Added binary 20 MB source validation, supported-type ImageIO decoding, GIF
   first-frame selection, opaque sRGB white Matte compositing, exact 512 x 288
   JPEG 0.90 crop export, rollback-safe file replacement, and old-path-only
   decoded-image cache invalidation.
3. Added the fixed 16:9 crop geometry and SwiftUI interaction surface with the
   largest initial crop, bounded movement, minimum-size resizing from four
   corner handles, a system Accent border, a surface-token handle fill, and a
   system Shadow Matte that updates with the crop rectangle.
4. Pending: add Finder selection and the Edit Cover dialog workflow.
5. Pending: connect the shared Library card context menus.
6. Pending: complete targeted refresh integration and full verification.

## Verification

- User-cover precedence, Index isolation, and replacement persistence: 1 test
  passed.
- Existing Library cover and split folder/detail presentation selection: 18
  tests passed.
- Binary size limit, supported types, GIF first frame, transparency Matte,
  exact JPEG output, rollback safety, old-file removal, and targeted cache
  invalidation: 6 tests passed.
- Initial crop fitting, bounded movement, all four anchored corner resizes,
  minimum size, fixed aspect ratio, and system token bindings: 4 tests passed.
- Pending later-stage and full test runs.

## Outcome

Implementation is in progress.
