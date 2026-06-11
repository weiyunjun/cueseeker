# Remove Playback Sidebar Step 2

Human requirement:

- `docs/human/requirements/20260611-Feature-Remove Playback Sidebar Performance Regression.md`

## Scope

This record covers step 2 of the playback sidebar removal: removing the runtime
UI entry points for the video-internal sidebar while leaving sidebar data tasks
and virtual-list cleanup for the later scoped steps.

## Changes

- Removed playback page construction of the right-side sidebar overlay.
- Removed the Results panel button from the playback chrome.
- Removed the playback side-panel toggle action from the app coordinator.
- Stopped restoring and persisting the side-panel visible state from
  `UserDefaults`.

## Verification

- `swift build --product CueSeeker`

## Outcome

- The playback page no longer exposes a UI path that can show the video-internal
  sidebar.
- Search result previous/next controls remain wired through the normal playback
  navigation controls.
