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

## Verification

- The focused SettingsStore selection passed six tests covering defaults,
  three-state normalization, old-key migration, new-key precedence, legacy
  coupled-setting migration, Gap clamping, and persistence.
- Pending focused playback and Overlay verification.
- Pending full regression verification.
- Pending packaged application verification.

## Outcome

Pending implementation and owner end-to-end acceptance.
