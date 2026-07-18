# Library Watch-State Synchronization

## Requirement

- `docs/human/requirements/20260718-Bug-Library Watch State Synchronization And Refresh Scope.md`

## Scope

Synchronize playback-history writes with the shared Library, Recent, and
watch-state-scoped Search presentations. Keep the existing folder-detail
snapshot visible while only the affected detail data reloads, avoiding a
page-level loading transition after a manual watch-state change.

## Steps

1. Replaced the single deferred-refresh flag with a set of affected video paths
   and added a playback-history writer queue barrier before publishing state.
2. Flushed pending playback-history presentation updates after pausing for an
   Overlay and whenever Playback closes, including after switching from Library
   to Search or Shiori.
3. Published affected changes to the shared Recent collection, cached Library
   folder details, and watch-state-scoped Search results. Search with the `All`
   scope remains unchanged.
4. Added per-folder request identities and snapshot-preserving detail reloads so
   an affected folder retains its current content and completion status until
   the replacement snapshot is ready.
5. Removed playback-history revision changes from the Workbench folder-detail
   task identity and removed the Playback Library Overlay's redundant refresh
   hook. Both surfaces now observe the shared detail snapshot replacement.
6. Added regressions for deferred publication, closing after changing Playback
   source, watch-state-scoped Search, completion milestones, and detail snapshot
   preservation.

## Verification

- Four focused synchronization regressions passed.
- Forty-one related Library, Recent, Playback, and Search tests passed.
- The bounded single-worker full run passed with 741 tests.
- Earlier default full runs exposed existing non-deterministic media-frame and
  shared-test-resource timeouts; the affected tests passed when isolated, and
  the failing test names varied between runs.
- `swift build` passed.
- `git diff --check` passed.

## Outcome

Playback-history persistence and shared presentation publication now have an
explicit ordering boundary. Library and Recent no longer retain stale watch
state when an Overlay opens or Playback closes from another source, and
watch-state-scoped Search is refreshed at the same publication boundary.
Manual watch-state changes update only affected cached folder details while the
current page remains visible.
