# Playback Cue Repeat And Auto Pause Feedback

## Requirement

- `docs/human/requirements/20260801-Feature-Playback Cue Repeat And Auto Pause Feedback.md`
- `docs/human/design/Controller.md`

## Scope

Add one-shot Cue Repeat to the normal video playback page, expose it through a
disabled-state-aware bottom-player button, bare `R`, and DualSense Triangle,
and add centered feedback for successful Repeat and automatic Cue pauses.

## Steps

1. Added one derived Playback Store boolean for Repeat availability. The native
   playback clock updates it only when the exact eligibility result changes, so
   the button follows the inclusive Cue time range without publishing the full
   playback clock at frame cadence.
2. Resolved Repeat from the active Search or Shiori Cue target, the current
   Cue's effective Auto Switch setting, and the inclusive playback timestamp.
   The command reuses the existing `playFromCue` execution path, including the
   existing Auto Pause boundary, then publishes centered Repeat feedback.
3. Added the `repeat` button immediately before Screenshot and routed bare `R`
   and normal-video DualSense Triangle to the same command. Existing Triangle
   behavior in Playback Overlay, Command Panel, and Collage remains unchanged.
4. Published centered `pause.fill` / `Auto Pause` feedback only after the
   existing accepted Auto Pause boundary callback succeeds.
5. Updated playback requirements, Liquid Glass mappings, and the changelog for
   the accepted user-visible behavior.

## Verification

- Passed 69 focused tests selected by:
  `swift test --package-path apps/macos-native --filter 'PlaybackNormalShortcutTests|PlaybackSegmentCompletionTests|PlaybackSubtitleFocusKeyboardActionTests'`.
- The focused coverage verifies inclusive start and end timestamps, Auto Switch
  rejection, derived button state, silent unavailable `R` and Triangle input,
  existing controller routing in other video interfaces, and exact feedback
  icon/text values.
- The unfiltered suite built successfully. Its 7 CASS XCTest cases passed; the
  Swift Testing run executed 954 cases and reported 22 issues outside the
  changed feature paths. No Repeat or controller test failed. Seven reported
  native media timing tests all passed when rerun serially. Two of three
  reported UI tests passed when rerun in isolation; the unrelated Display Title
  row-menu coordinate test remained failing.
- `git diff --check` passed.

## Outcome

The implementation matches the requirement: Repeat is available only for the
normal Cue Playlist video state with Auto Switch off and an inclusive target
Cue timestamp, all three inputs share one execution path, invalid attempts are
silent, and Repeat and Auto Pause use the required centered feedback.

## Follow-ups

- Physical DualSense and native visual acceptance remain manual checks.
- The unrelated Display Title row-menu coordinate failure is outside this
  requirement and was left unchanged.
