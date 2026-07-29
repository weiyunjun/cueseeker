# Playback Current Collage Editor Step 4

## Requirement

- `docs/human/requirements/20260730-Feature-Playback Current Collage Editor.md`
- `docs/human/design/UI.md`

## Scope

Implement the Step 4 live Collage preview without changing the human-owned
documents. The change covers the equal-width editor layout, fixed preview
header and action area, a continuous width-fitted Collage image with the shared
table scrollbar, incremental group rendering, and stale asynchronous result
rejection. Copy and Export behavior remains in Step 5.

## Steps

1. Reused the existing Current reel as the right editor column and added an
   equal-width preview host on the left so preview publications do not
   invalidate the reel subtree.
2. Added the fixed `Collage Preview` title and fixed Copy/Export action area,
   with a width-fitted continuous image as the only scrollable content.
3. Reused `TableScrollbarOverlayView` and disabled native scrollbars for the
   preview image viewport.
4. Split the existing Collage exporter into reusable group-render and compose
   operations while keeping full Collage export on the same execution path.
5. Added a preview store that reuses unchanged leading and trailing rendered
   groups, renders only the changed range, cancels superseded work, and accepts
   results only from the current request generation.
6. Preserved the resolved playback subtitle render source so the preview uses
   the existing ASS/SRT and render-cache configuration.

## Verification

- Ran 143 related Playback Current, virtual Reel, Collage semantics, preview,
  and exporter tests: all passed.
- Verified incremental preview rendering, obsolete-result rejection,
  equal-width columns, width-fitted image sizing, custom scrollbar visibility,
  and reusable Collage composition with focused tests.
- Ran `git diff --check`: passed.
- Confirmed the user-owned `docs/human/design/UI.md` change remains unstaged and
  is not part of this implementation.

## Outcome

The Step 4 implementation matches the committed requirement. The left preview
renders one continuous Collage from the current selection, updates only changed
groups, rejects stale asynchronous work, and scrolls only the image while the
title and action area remain fixed. Copy and Export actions are intentionally
disabled until Step 5.

## Follow-ups

- Implement Copy Collage and Export Collage against the current composed image
  in Step 5.
- Perform the final refresh-scope and integrated UI review in Step 6.
