# Playlist Cue Auto Stop And Overlay Focus Synchronization

## Requirement

- `docs/human/requirements/20260718-Feature-Playlist Cue Auto Stop And Overlay Focus Synchronization.md`

## Status

Implementation in progress.

## Scope

- Rename and migrate the Playlist Cue stopping preference.
- Replace range-limited Cue playback with a resumable automatic pause boundary.
- Keep Auto Switch as a Gap-delayed extension of the completed automatic pause.
- Open Overlay Playlist on the logical Playlist item without adding full-dataset
  indexing, loading, or presentation memory.
- Build and package the completed application for owner end-to-end acceptance.

## Implementation Steps

1. Renamed the setting to `Auto Stop After a Cue Finishes`, migrated the former
   persisted preference without overwriting an already stored new preference,
   and retained the accepted on/on, on/off, and off/off state normalization.
2. Replaced Playlist Cue segment termination with a resumable native auto-stop
   boundary. The boundary excludes video frames at or beyond Cue End, trims
   audio to Cue End, retains the final presented picture and active decode
   session, and resumes through an in-session seek from Cue End when playback
   is continued manually.
3. Restricted Auto Switch scheduling to a consumed Auto Stop event from Search
   or Shiori playback. The delayed task now validates the playback generation,
   source, paused state, and both settings before advancing; manual resume,
   source replacement, or disabling Auto Switch cancels the pending task.

## Verification

- The focused SettingsStore selection passed six tests covering defaults,
  three-state normalization, old-key migration, new-key precedence, legacy
  coupled-setting migration, Gap clamping, and persistence.
- The focused playback selection passed seventeen coordinator/player tests for
  boundary creation, callback handling, subtitle retention, resume behavior,
  zero and positive Gap behavior, task invalidation, navigation, and
  disabled-setting behavior.
- A real generated audio/video fixture verified that auto-stop presents no
  frame at or beyond Cue End, keeps the native session alive, and resumes with
  an in-session seek rather than reopening the media.
- Pending focused Overlay verification.
- Pending full regression verification.
- Pending packaged application verification.

## Outcome

Pending implementation and owner end-to-end acceptance.
