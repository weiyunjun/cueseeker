# ASS Primary Style Playback Finish

Human requirement:

- `docs/human/requirements/20260704-Feature-Ass Primary Style Playback Finish.md`

Implementation:

- Added indexed playback finish metadata for each subtitle file, including primary ASS styles, the last primary-style cue end, and the last subtitle cue end.
- Updated ASS/SRT indexing so unchanged-file checks require current playback finish metadata and the subtitle cue indexing algorithm version advances to 3.
- Replaced Library playback completion with the new indexed finish point rules: primary style end after 80%, otherwise last subtitle end after 80%, otherwise video end.
- Removed reliance on the previous 95% / last-second completion rule while preserving existing `completed_at` data.

Verification:

- Added Core tests for Primary Style metadata generation and finish point fallback behavior.
- Added App tests for Library playback completion at the subtitle-derived point and for the video-end fallback when subtitles end before 80%.
- Ran `swift test` from `apps/macos-native`; all tests passed.
