# Playback Current Collage Editor Step 1

## Human-Owned Source

- `docs/human/requirements/20260730-Feature-Playback Current Collage Editor.md`

## Scope

Implement the first requirement step: establish the product-domain Collage
selection and timestamp-grouping semantics, then add a playback execution path
that renders only the selected subtitles and composes the documented Collage
shape. This step does not add or modify UI.

## Architecture Classification

- Product semantics: `CueSeekerCore` owns the 50-Cue selection limit,
  identical-timestamp normalization, stable ordering, 100ms group rule,
  intersection midpoint, and incremental group changes.
- Playback execution: `CueSeekerPlayback` owns frame extraction, selected ASS
  or SRT rendering, subtitle-band cropping, and final image composition.
- Platform UI/UX and platform integration: unchanged.

## Changes

1. Added a Collage selection plan that groups identical timestamps, evaluates
   each new timestamp against the current group's common intersection, and
   reports the minimal old and new group ranges changed by a selection update.
2. Limited selection to 50 Cues while preserving deselection and deterministic
   Cue ordering.
3. Recomputed grouping from the adjacent affected group and reused the stable
   suffix as soon as a newly computed group matched the previous plan.
4. Added a selected-Cue Collage renderer that uses each group's intersection
   midpoint, filters ASS Dialogue events by their indexed event identity, and
   supplies only selected SRT Cues to the shared SRT drawing core.
5. Reused the existing first-full-frame, later-subtitle-band crop, and vertical
   composition path without changing the existing table Collage behavior.

## Verification

- `swift test --package-path apps/macos-native --filter SubtitleCollage`
  passed 8 tests, including 200 deterministic incremental mutations compared
  with a complete rebuild after every mutation.
- Focused Subtitle Screenshot and selected ASS/composition tests passed 17
  tests in total.
- `swift test --package-path apps/macos-native` built all targets and ran 908
  Swift Testing tests plus 7 XCTest tests. Concurrent execution reported 20
  issues across 11 unrelated playback timing, Shiori timing, and refresh-scope
  tests, alongside temporary disk-I/O failures.
- Each of those 11 failed tests passed when rerun individually without any code
  change, confirming concurrent test interference rather than a Collage
  regression.
- `git diff --check` passed before commit.

## Outcome

The repository now has one Core-owned Collage plan and one Playback-owned
selected-subtitle rendering path ready for later Editing Collage UI steps.
No Playback UI, table Collage action, Context behavior, or `UI.md` rule changed.
