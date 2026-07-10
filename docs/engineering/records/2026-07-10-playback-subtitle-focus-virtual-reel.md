# Playback Subtitle Focus Virtual Reel

## Requirement

- `docs/human/requirements/20260710-Feature-Playback Subtitle Focus Virtual Reel Architecture.md`
- `docs/human/design/UI.md`

## Scope

Replace the bounded window-loading implementation with a complete current-video
cue collection and an AppKit virtual reel. Search and Shiori aggregate reels
remain out of scope.

## Steps

1. Kept the initial 6 + 1 + 3 snapshot as the first presentation and added a
   separately cancellable background read for the complete current-video cue
   collection.
2. Added strict session, source, total-count, ordinal-continuity, and initial-cue
   validation before publishing the complete collection.
3. Reused the existing stable database ordering and cue-line hydration path;
   short subtitle files whose initial snapshot is already complete avoid a
   second read.
4. Cancelled and released the complete collection task on dismissal, source
   replacement, and action completion. Late results cannot publish after the
   session token becomes invalid.
5. Replaced the rendered SwiftUI cue stack with one AppKit scroll view and one
   custom document view. The document view computes the visible ordinal range
   directly from fixed 104-point slots, 136-point pitch, and four-cue overscan.
6. Added virtual leading and trailing space so every cue, including the first
   and last, aligns to the same fixed center anchor. Pointer hover and text-only
   activation are handled locally and invalidate only the affected rows.
7. Reused one TextKit layout stack for visible cue drawing instead of creating
   one layout graph per cue view.
8. Corrected the transition boundary so complete-collection selection and
   scrollbar checks no longer consult the superseded bounded cache. Preserved
   negative row-top anchors for partially visible cues so pointer activation
   cannot shift the reel.
9. Replaced the keyboard direction queue with one cumulative target ordinal.
   A single AppKit timer now retargets the in-progress 220-millisecond motion
   from its current offset, while the Session publishes only the final settled
   selection.
10. Kept Enter deterministic during keyboard motion: the deferred menu remains
    blocked by the pending target and opens only after the latest target commits.
    Rejected stale animation completions retain motion ownership until the newer
    request arrives, and generation-gated motion callbacks cannot outlive the
    native reel.
11. Moved wheel ownership into the native reel. Discrete nonzero deltas now
    target at least one cue, while precise gestures update the clip offset
    continuously through phase and momentum events. A nonzero sub-pitch gesture
    settles one cue in its net direction, and Session receives one final ordinal
    only after snap completion. A synchronous motion gate keeps Enter and
    keyboard input aligned with the native presentation state. Precise gestures
    settle only after their active phase ends; detach, menu suppression, and the
    temporary SwiftUI scrollbar handoff cancel or finalize native ownership
    without leaving a stale target or motion gate. The initial ten-cue window
    also bounds precise offsets until the complete batch arrives. Keyboard,
    menu, and scrollbar ownership is arbitrated before a new wheel event starts,
    unresolved legacy scrollbar targets gate wheel takeover until their request
    resolves. If the complete batch wins that race, a released scrollbar target
    commits immediately while an active drag keeps its preview until mouse-up.
    Reduce Motion resolves all native alignment animations to zero duration.
12. Embedded the shared table scrollbar primitive directly above the reel's
    native scroll view. Drag updates now change only the clip offset and local
    cue highlight; mouse-up snaps once and publishes one final Session ordinal.
    The initial partial collection keeps the complete-document thumb visible
    but noninteractive until all current-video cues arrive. Resize and stale
    keyboard ownership cancel an active drag without a late commit. Removed the
    superseded SwiftUI scrollbar, debounce state, tests, and AppCoordinator
    entry points.

## Verification

- `swift test --filter SubtitleFocus`
  - Passed 83 tests after the data-loading step.
  - The 2,500-cue complete-collection database test passed in 0.099 seconds.
  - Passed 86 tests after the virtual-reel step.
  - Verified that first and last cues resolve to the same anchor and that a
    50,000-cue document still computes at most 15 visible-plus-overscan cues.
  - Passed 87 tests after complete-collection selection and negative-anchor
    boundary corrections.
  - Passed 90 tests after keyboard retargeting, including 100 repeated key
    requests held in constant pending state, queued-before-mount handling, and
    stale-completion protection for deferred Enter.
  - Passed 102 tests after native wheel migration, covering minimum discrete
    steps, precise momentum ownership, sub-pitch and boundary settlement,
    combined phase events, partial-window bounds, deferred Enter, suppression
    reset, Reduce Motion, and keyboard/wheel motion ownership.
  - Passed 102 tests after native scrollbar migration. A 1,000-update drag test
    published zero intermediate Session selections and exactly one mouse-up
    selection. Continuous fraction/offset mapping was also verified against a
    50,000-cue virtual document, with partial-to-complete enablement, stale
    keyboard ownership, and resize cancellation covered separately.
- `git diff --check`
  - Passed.

## Outcome

The initial ten-cue presentation remains independent from the complete current-
video read. Complete results are retained only by the matching active session,
and the measured full read did not introduce an opening-path regression because
it starts only after the initial presentation publishes. Rendering cost is now
bounded by the viewport rather than the complete cue count, and the reel uses
one immutable compact cue collection without creating a view per cue.

## Follow-ups

- Replace the SwiftUI cue stack with the AppKit virtual reel.
- Remove the superseded bounded cache, sequential prefetch, and target-window
  loading paths after the virtual reel owns navigation.
