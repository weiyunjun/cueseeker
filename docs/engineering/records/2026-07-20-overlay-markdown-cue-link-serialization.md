# Overlay Markdown Cue Link Serialization Implementation

## Requirement

- `docs/human/requirements/20260720-Bug-Overlay Markdown Cue Link Serialization.md`

## Status

Completed.

## Scope

- Normalize Playback Overlay Markdown Cue-link labels into one physical line.
- Backslash-escape the requirement's CommonMark/GFM-sensitive characters.
- Preserve exact multiline text for the separate plain-text copy action.
- Synchronize the stable product, URL Scheme, testing, and changelog contracts.

## Steps

1. Added a pure Markdown Cue-link serializer beside the existing AppKit
   pasteboard writer. It validates the positive CueID before constructing the
   link.
2. Split Cue text with Foundation's newline character set, trimmed horizontal
   whitespace from each line, removed empty lines, and joined the remainder
   with one ASCII space. A missing normalized label now becomes
   `Cue #{CueID}`.
3. Escaped `\\`, `[`, `]`, `<`, `>`, `*`, `_`, backtick, `~`, `&`, and `|`
   through one character pass before inserting the label into the fixed
   `cueseeker://cue?id={CueID}` destination.
4. Routed Markdown clipboard copy through the serializer without changing the
   exact plain-text clipboard path or its source line breaks.
5. Updated direct serializer, pasteboard, Current, Playlist, Shiori, feedback,
   and Overlay Search exclusion expectations.

## Verification

- Focused Markdown-copy and Overlay routing selection: 6 tests passed. The
  selection covered LF and empty lines, CRLF, CR, Unicode newline characters,
  horizontal trimming, every required backslash escape, the visible empty-label
  fallback, exact plain-string pasteboard output without HTML/RTF, Current,
  Playlist, Shiori, feedback, and the Overlay Search exclusion.
- Full `swift test --package-path apps/macos-native`: all 7 CASS tests passed;
  the Swift Testing run executed 796 tests and reported six load-sensitive
  timing or database-isolation failures with nine issues. The new serializer
  test passed; one existing Playlist integration test timed out under the full
  load after passing in the focused selection. The reported failures were:
  `nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`,
  `subtitleFocusDownThenShioriSavesTheFinalSettledCue`,
  `playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue`,
  `playbackRecentPointerDispatcherUsesSharedWorkbenchItem`,
  `nativePlaybackNotifiesNaturalCompletionAfterAudioDrain`, and
  `nativeAutoStopKeepsSessionAliveAndResumesFromBoundary`.
- Nonparallel isolated rerun of all six reported failures: 6 tests passed. The
  Playlist Markdown-copy test had also passed in the initial focused selection.
- Pandoc CommonMark and GFM parser probes each resolved the fully escaped sample
  as one link with the literal source label and the exact
  `cueseeker://cue?id=42` destination.
- `git diff --check`: passed.

## Outcome

Playback Overlay Markdown Cue links now remain parseable for multiline and
Markdown-sensitive subtitle text while the separate plain-text copy action
continues to preserve exact source line breaks.
