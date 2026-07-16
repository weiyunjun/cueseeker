# Playback Library Card Menu Capability

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Keep the shared Recent and Library card context-menu implementation while
removing the Workbench-only `Context` action from Playback.

## Steps

1. Added one `showsContextMenuItem` host capability to the shared Recent and
   Library Episode grid/card layouts, defaulting to the existing Workbench
   behavior.
2. Configured Playback Recent and Playback Library Episode hosts with that
   capability disabled.
3. Left Library Folder unchanged because its shared menu has no `Context`
   action.
4. Retained the existing shared menu host, action closures, right-click anchor,
   visible-area clamping, outside-click dismissal, and arrow-free presentation.
   The active menu continues to retain the items and actions created for the
   right-clicked card, which locks that card as the action target until close.

## Verification

- Focused Playback Recent, Library, Media Selection, and Workbench Library
  tests passed: 14 tests.
- The macOS application and test targets compiled successfully.
- `git diff --check` passed.

## Outcome

Workbench retains its complete card menus. Playback reuses the same layouts,
menu presentation, and state-changing actions while omitting only the
Workbench-only `Context` capability.
