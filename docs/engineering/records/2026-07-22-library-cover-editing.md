# Library Cover Editing Implementation

## Requirement

- `docs/human/requirements/20260722-Feature-Library Cover Editing.md`
- `docs/human/design/UI.md`

## Status

Completed.

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
4. Added Finder selection with JPEG/PNG/GIF type filtering and delegate-based
   disabling of unsupported, oversized, or invalid image files. Added the
   Edit Cover sheet with the accepted title, crop editor, exact hint copy,
   Neutral Cancel action, Primary Save action, and asynchronous load/save
   orchestration.
5. Added `Change Cover` immediately below `Open Folder` with the
   `square.and.arrow.up` tray/share symbol for Recent video, Library folder,
   and Library episode cards. The existing shared card views carry the same
   actions into Playback without changing menu-item styling.
6. Returned the persisted cover revision from the save service and locally
   replaced only matching Recent, Library folder, and loaded Library episode
   presentation snapshots. The targeted update does not increment page-level
   revisions or trigger a full Library refresh.

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
- Edit-session initialization, accepted copy/content types, and Finder
  enablement for valid, unsupported, and oversized entries: 3 tests passed.
- Menu copy/icon selection and shared Playback Recent routing: 2 tests passed.
- Playback Library shared folder/episode hierarchy and refresh behavior: 5
  tests passed.
- Persisted revision handoff and targeted video/folder snapshot refresh without
  page-level revision changes: 3 tests passed.
- Complete cover-editing test filter: 35 tests passed.
- Full non-parallel package run: 834 tests completed with one unrelated
  shared-`UserDefaults` state failure; the failed persistence migration test
  passed in an isolated rerun (1 test passed).

## Outcome

Library video and folder covers can now be selected, cropped, saved, resolved
ahead of Index covers, and refreshed in place across the shared Library card
surfaces without overwriting Index output or retaining replaced user-cover
files.
