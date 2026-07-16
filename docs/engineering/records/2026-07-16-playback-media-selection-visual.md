# Playback Media Selection Visual

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Make Playback Media Selection reuse the existing Workbench card Hover regions
and visuals without adding a focus ring, selected border, or independent
selected background.

## Steps

1. Removed the Selected focus-ring overlays from the shared Recent Watching,
   Library Folder, and Library Episode card layouts.
2. Made Recent Watching and Library Folder Selected state activate the existing
   full-card Hover background and cover-scale effect.
3. Made Library Episode Selected state activate the existing Cover Region Hover
   background and cover-scale effect only.
4. Left Workbench behavior unchanged because Workbench does not provide a
   persistent `selectedItemID` to these shared grids.

## Verification

- Focused Playback Recent, Library, and Media Selection tests passed: 14 tests.
- The macOS application and test targets compiled successfully.
- `git diff --check` passed.

## Outcome

Playback selection is now a stateful reuse of each card layout's established
Hover visual, with no Playback-only selection decoration or color token.
