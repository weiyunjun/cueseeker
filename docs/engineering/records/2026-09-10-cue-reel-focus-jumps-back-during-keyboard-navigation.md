# The cue reel keeps its highlight on the keyboard target while a refresh lands mid-motion

Human-owned documents:

- `docs/human/requirements/20260910-Bug-Cue Reel Focus Jumps Back During Keyboard Navigation.md`

## Why

An arrow key moves the reel's highlight (the bright cue text and the timeline dot) to the target cue at once and eases that row to the Focus Anchor over 0.22 s. The reel's committed selection stays on the old cue until the motion completes and the session accepts the commit.

A shortcut pressed during that motion is deferred by the session and published as a pending action; Return in the Collage editor publishes the changed selection plan. Either publish makes SwiftUI refresh the overlay, and the reel receives its state again with the same navigation request still outstanding. On that refresh the reel repeated its "cancel wheel motion" step, and that step re-applies the committed ordinal to the document view. The highlight went back to the old cue and stayed there until the motion completed and the commit's own refresh put it on the target again. The reel position was never affected: the idle re-sync is guarded by the animator's running flag, so only the highlight flickered.

The cancel step was written for the moment a keyboard request takes over from wheel or scrollbar input, and it was correct on the refresh that carries a new request. It was never meant to run again on the refreshes that arrive while the keyboard motion is in flight.

## What changed

The wheel cancel in the reel container's state update now runs only while no keyboard motion is active. Once the keyboard motion is running, wheel and scrollbar input are already gated off by the session and by the container's own interaction flag, so there is nothing to cancel and the highlight stays where the request put it. A second arrow press while the first motion is still travelling retargets the running motion and skips the cancel for the same reason.

Position, transition duration and easing, the deferred-action gate and the wheel and scrollbar gates are unchanged.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusReel.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusLayoutTests.swift`

## Verification

Unit: `subtitleFocusRefreshDuringKeyboardMotionKeepsDisplayedHighlightOnTarget` sends a request from cue 12 to cue 13, checks the displayed highlight is on 13, then repeats the same update with the committed ordinal still 12 the way a mid-motion refresh does, and asserts the displayed highlight is still 13 while the committed ordinal is still 12. Before the fix the second assertion failed with the highlight back on 12; after the fix it passes.

`swift test --filter ubtitleFocus` passes, 143 tests. The full `CueSeekerAppTests` target runs 802 tests with 9 issues in `DebugE2EControllerTests`, `CueGroupRefreshScopeIntegrationTests` and `LibraryFolderRemovalTests`. The first two reproduce with this change stashed; the `LibraryFolderRemovalTests` pair passed when rerun in isolation. None of them involves the reel.

Visual acceptance in the app is left to the human owner as the requirement states; the Debug E2E controller was not extended for it.
