# UI Refresh Scope Contract Coverage

## Human-Owned Source

- `docs/human/requirements/20260708-Bug-UI Refresh Scope Contract Coverage.md`
- `docs/human/design/UI.md`

## Scope

Apply the expanded refresh-scope contract to the playback and Library surfaces
that still had broad invalidation paths after the initial table-focused fix.

## Changes

- Split playback timeline state into `PlaybackTimelineInteractionStore` and a
  nested scrub-time store so scrubbing activity no longer publishes through
  `PlaybackStore`, and scrub-time changes do not invalidate controls that only
  need scrubbing start/end state.
- Scoped playback render observation so `PlaybackRenderViewWrapper` is not
  hosted by a view that observes the full `PlaybackViewModel`.
- Scoped playback chrome observation into subcontrols for play/pause, progress,
  time, subtitles, volume, and speed instead of observing the whole playback
  model/store from the chrome shell.
- Deferred Library playback-history presentation refresh during playback entry.
  History is still recorded immediately, but recent/complete Library
  presentations refresh when playback closes instead of during playback entry.
- Removed per-card `AppCoordinator` subscriptions from Library cards by passing
  stable action handlers from the grid owner.
- Guarded Library context-menu size measurement so repeated identical
  measurements do not write state.
- Added a regression test that timeline interaction and scrub-time state do not
  invalidate `PlaybackStore`.

## Verification

- `swift build`

## Outcome

Playback entry and playback chrome interactions now have narrower rendering
owners. Timeline activity and scrub-time updates are isolated from the broad
playback store, the video render host is insulated from playback model ticks,
and Library card hover/right-click interactions no longer carry a per-card
global coordinator subscription.
