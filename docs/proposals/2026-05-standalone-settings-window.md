# Standalone Settings Window

Status: Accepted

## Background

CueSeeker currently treats Settings as a main-window app section next to Search.
That was sufficient for the minimal native loop, but it is no longer the right
information architecture as the product moves toward a player-first workspace.

The main window should be optimized for watching, precise content navigation,
search, queue building, and learning sessions. Settings are local app
configuration and should not compete with those workspace surfaces. On macOS,
the app menu is the expected formal entry point for app settings.

## Goals

- Move the formal Settings entry to the macOS menu bar under
  `CueSeeker > Settings...`.
- Present Settings in an independent settings window instead of a main-window
  sidebar section.
- Use a simple two-column Settings layout: a left category list and right
  category content.
- Keep the Settings left column visually consistent with the current quiet gray
  settings/navigation background.
- Keep the Settings content area visually consistent with the current white
  content surface.
- Define only the current Settings categories: `Library` and `Decode`.
- Preserve the accepted player-first Search layout: Playback Area on the left,
  collapsible Search Panel on the right.

## Non-goals

- Implement the code change in this proposal.
- Add new Settings categories beyond `Library` and `Decode`.
- Redesign the future main-window Library browser.
- Change folder indexing semantics.
- Change the available decode modes.
- Change Search result layout, Search Panel collapse behavior, or playback
  engine behavior.

## UX Model

Settings should behave like an app-level macOS configuration surface.

Entry:

- The primary entry is `CueSeeker > Settings...` in the app menu.
- The app may also expose the standard macOS `Command-,` shortcut if practical.
- Selecting the command opens the Settings window or focuses the existing
  Settings window if it is already open.

Window structure:

```text
Settings Window
Left Settings Category List
Right Settings Content
```

Category list:

- Uses the current quiet gray background treatment.
- Shows only `Library` and `Decode` for now.
- Allows one selected category at a time.
- Does not behave like the main app workspace sidebar.

Content area:

- Uses the current white content background treatment.
- Shows the controls for the selected Settings category.
- Should remain functional and native before visual polish is expanded.

Opening, focusing, or closing Settings must not switch the main workspace away
from Search, pause playback, collapse the Search Panel, clear the selected
result, or otherwise mutate playback review state.

## Library Settings

`Library` is the Settings home for the current Subtitle Folders behavior.

Required controls:

- List configured subtitle folders.
- Add a local subtitle folder with the native macOS folder picker.
- Run an all-folder `Index Now` action.
- Remove a folder through a confirmation dialog that makes clear local files
  are not deleted.
- Show indexing status and folder-related errors when relevant.

This Settings category manages the indexed source folders. It is separate from
the future main-window Library browser, which will browse playable videos and
known content.

## Decode Settings

`Decode` is the Settings home for playback decode mode.

Required controls:

- Choose the persisted playback decode mode.
- Supported modes remain `hardware`, `software`, and `auto`.
- The control should avoid unnecessary native menu helper services during
  ordinary Settings window navigation.

## Architecture Notes

The main AppShell sidebar should no longer own Settings navigation. It should
remain available for true main-window app sections such as Search and future
workspace-level destinations.

Settings still needs access to shared app state for configured folders,
indexing commands, indexing status, and decode mode. That shared access should
not couple Settings window presentation to Search workspace pane state.

Native folder selection may temporarily create AppKit helper services. That is
acceptable for explicit folder-picking actions and should not be optimized away
by replacing the native picker.

## Acceptance Criteria

- Documentation states that Settings opens from `CueSeeker > Settings...`.
- Documentation states that Settings is an independent window, not a main
  workspace sidebar section.
- Documentation defines the Settings window as a two-column layout with a gray
  category list and white content area.
- Documentation defines only `Library` and `Decode` as current categories.
- Documentation maps current Subtitle Folders behavior to `Library`.
- Documentation maps current Decode Settings behavior to `Decode`.
- Documentation states that opening or closing Settings must not pause playback
  or change Search workspace state.

## Decision

Accepted.

CueSeeker should move Settings out of the main-window AppShell sidebar and into
a standard macOS settings entry under `CueSeeker > Settings...`. The Settings
window should use a compact two-column layout with `Library` and `Decode`
categories. This proposal supersedes earlier references to Settings as an
AppShell sidebar section while leaving the accepted player-first Search
workspace and future content/learning panel model intact.
