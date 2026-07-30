# Playback Current Collage Editor Step 6

## Requirement

- `docs/human/requirements/20260730-Feature-Playback Current Collage Editor.md`
- `docs/human/design/UI.md`

## Scope

Complete Step 6 by verifying the refresh boundaries for the Collage checkbox,
Current subtitle Reel, live preview canvas, and Playback host. This step does
not change the table Collage flow, Context, or visible UI behavior.

## Steps

1. Audited the existing ownership boundaries: Collage selection remains in the
   Current Reel, while preview publication remains inside the preview branch.
2. Added scoped invalidation probes for Collage selection updates, full Reel
   invalidation, changed-row invalidation, and native preview updates.
3. Locked the ordinary selection path to changed visible rows and verified
   that only the 50-item availability transition invalidates the full Reel.
4. Verified that preview publication refreshes the preview owner and native
   canvas without refreshing the Playback root or its sibling branch.
5. Kept the existing implementation because the audited refresh boundaries
   were already correct; no additional cache, state owner, or render path was
   introduced.

## Verification

- Ran the two new refresh-boundary tests: both passed.
- Ran 147 related Playback Current, virtual Reel, Collage preview, export, and
  pasteboard tests: all passed.
- Ran the complete 918-test suite. It reported 18 issues across 10 unrelated
  media playback, Shiori, search refresh, and database tests under parallel
  execution; all 10 affected tests passed when rerun serially.
- Verified that ordinary Collage selection preserves focus, Reel placements,
  and the text measurement cache while invalidating only the changed row.
- Verified that preview publication stays within the preview branch.
- Confirmed that no table Collage or Context implementation was changed.
- Confirmed that the user-owned `docs/human/design/UI.md` change remains
  unstaged and is not part of this implementation.

## Outcome

The Collage editor refreshes only the UI branch required by each state change:
ordinary selection updates the affected Reel row, the selection-limit boundary
updates the Reel availability state, and completed renders update only the live
preview branch. No stable UI specification change is required for Step 6.
