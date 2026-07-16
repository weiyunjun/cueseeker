# Playback Pointer and Media Selection

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Apply the reviewed Playback Pointer Visibility rules to the existing Player
cursor owner and connect visible-pointer card hover to the existing Playback
Media Selection stores.

## Steps

1. Kept `PlaybackChromeVisibilityModel` as the only native cursor owner and
   changed Playback Page initialization to hidden Pointer state.
2. Routed every Playback Page key-down event through a lightweight hide request
   published by `PlaybackStore`; Wheel input has no Pointer-show path.
3. Published the current logical Pointer visibility to Playback overlays through
   a SwiftUI environment value.
4. Added optional hover-selection callbacks to the shared Recent, Library
   Folder, and Library Episode card layouts. Workbench keeps the default
   behavior; Playback enables the callbacks only while Pointer is visible.
5. Added a no-scroll pointer-selection operation to
   `PlaybackMediaSelectionStore`, retaining its existing availability checks,
   refresh fallback, keyboard movement, and scroll ownership.

## Verification

- Focused Pointer, Media Selection, Recent, Library, and normal Playback
  shortcut tests passed: 16 tests.
- The tests cover hidden initialization, movement-only restoration, key-down
  hide requests, unavailable-item rejection, and hover selection without an
  extra scroll request.
- `git diff --check` passed.

## Outcome

Playback Pointer visibility now gates card-hover selection without creating a
second card implementation or a second selection state. Static hidden Pointer
hits cannot change selection; once Pointer movement restores visibility, the
shared card hover path can update the session-local Playback selection.
