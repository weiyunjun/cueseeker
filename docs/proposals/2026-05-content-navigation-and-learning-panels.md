# Content Navigation and Learning Panels

Status: Accepted

## Background

CueSeeker is moving toward a player-first workspace: playback is the central
experience, Search is a functional right-side panel, and the leftmost AppShell
sidebar provides main-window navigation such as `Search`.

Future product work will add Library, Favorites, playback queue, learning
sessions, and more precise subtitle navigation. These features need a stable
information architecture before implementation starts, otherwise CueSeeker may
drift toward an IDE-like collection of generic tool panes instead of a media
learning workspace.

The intended model is not copied from VS Code. CueSeeker should keep a stable
desktop workbench structure while assigning product-specific responsibilities
to each side of the playback surface.

## Goals

- Define a durable workspace responsibility model.
- Keep playback as the central experience.
- Treat the left-side content panel as a precise content-navigation surface.
- Treat the right-side panel as a search, aggregation, queue, and learning
  workflow surface.
- Provide a future home for Favorites without making Favorites only a search
  result action.
- Provide a future home for playback queue and configurable learning sessions.
- Keep the accepted player-first Search workspace layout intact.

## Non-goals

- Change the accepted player-first Search workspace decision.
- Define the Settings window. Settings is handled by the standalone Settings
  window proposal.
- Define final visual design for Library, Timeline, Favorites, Queue, or
  Learning Session.
- Define database schema for Favorites or queue persistence.
- Implement autoplay or learning-session behavior.
- Replace Theater Mode fullscreen.

## Workspace Model

The stable workspace model is:

```text
Leftmost AppShell sidebar
Left Content Panel
Playback Area
Right Learning Panel
```

Responsibilities:

- `Leftmost AppShell sidebar`: main-window app navigation such as `Search`.
- `Left Content Panel`: known-content navigation and precise location.
- `Playback Area`: video playback, subtitle display, and playback controls.
- `Right Learning Panel`: active search, result aggregation, queue building,
  and learning-session configuration.

The left and right panels should not be symmetric generic drawers. They have
different product meanings.

## Left Content Panel

The Left Content Panel is for known content and precise location.

Accepted future panel modes:

- `Library`: browse indexed videos and folders.
- `Timeline`: browse the current video's time-ordered subtitle cues.
- `Favorites`: browse stable saved subtitle moments or saved videos when that
  product behavior is accepted.

Library direction:

- The Library should be video-first, not subtitle-file-first.
- Library rows should represent playable videos when possible.
- Subtitle files are metadata or resources attached to videos, not duplicate
  top-level video rows.
- The Library should reuse the grouped, flattened, collapsible presentation
  pattern from Search result groups.
- The first Library implementation should group videos by immediate parent
  folder only, with no nested folder tree.
- Folder groups and video rows should use Finder-like natural ordering.
- Folder groups should be expanded by default and controlled by a
  `Collapse All` / `Expand All` action.
- Video names should use friendly display titles comparable to the accepted
  Search group title rules, using `Parent Folder Name - NN  extension`, with
  raw filenames retained for identity and diagnostics.
- Video rows should show indexed duration on the right.
- Clicking a video should open or update playback from `0` for the first
  implementation and should not require the user to keep attending to the Left
  Content Panel.

Timeline direction:

- The Timeline should show the current video's subtitles in timestamp order.
- Timeline rows should support precise jumps within the currently loaded video.
- Timeline navigation is a content-location feature, not a search-result
  aggregation feature.

Favorites direction:

- Favoriting is an action that may appear in Search results, Timeline rows, the
  current playback subtitle, contextual menus, and future hover controls.
- Browsing and managing Favorites belongs primarily to the Left Content Panel
  because Favorites are durable saved content, not only transient search output.
- Favorites may also be used by right-side learning workflows, such as adding
  saved items to a queue or searching within saved items.

## Right Learning Panel

The Right Learning Panel is for active learning workflows.

Accepted future panel modes:

- `Search`: search indexed subtitle content and review aggregated matches.
- `Queue`: collect videos or subtitle moments for sequential playback.
- `Learning Session`: configure how queued or selected items are played.

Search direction:

- Search remains a right-side panel in the player-first workspace.
- Search results should continue to focus on readable subtitle text, useful
  grouping, match highlighting, and timestamps.
- Search results may add contextual actions such as hover buttons and right-click
  menus.
- A hover `Add to Queue` action on each result is an accepted future interaction
  direction.

Queue direction:

- The queue is user-assembled learning material, not the source media library.
- Search results, Favorites, Timeline rows, and Library videos may all become
  queue inputs.
- The Queue should support quick collection while the user scrolls through
  Search results.
- The Queue belongs on the right because it is a user-authored learning plan
  derived from search and selection activity.

Learning Session direction:

- Learning Session should configure how queued or selected material plays.
- Future configuration may include context size around the target timestamp,
  repeat count, randomization, looping, and whether to play only selected cue
  windows or broader surrounding context.
- These rules should be documented in more detail before implementation because
  they affect playback behavior, keyboard interaction, queue identity, and
  possibly persistence.

## Fullscreen Panel Access

Theater Mode fullscreen may provide temporary access to left or right panels.

Rules:

- Fullscreen panel access must preserve the same side responsibilities:
  left-side surfaces navigate known content and precise timeline locations,
  while right-side surfaces support Search, Queue, and Learning Session actions.
- Temporary fullscreen panels must not create a second playback render context.
- Temporary fullscreen panels must not change the meaning of Library, Timeline,
  Favorites, Search, Queue, or Learning Session.
- Fullscreen panel access should remain optional and should not make fullscreen
  feel like a general desktop workspace.

## Relationship To Player-first Layout

This proposal does not change the accepted player-first Search workspace plan.

The accepted immediate direction remains:

```text
Playback Area on the left
Search Panel on the right
Search Panel can collapse without pausing playback
```

This proposal extends that direction by defining future left and right panel
responsibilities around the central Playback Area.

## Acceptance Criteria

- Documentation distinguishes the leftmost AppShell sidebar from the future
  Left Content Panel.
- Documentation does not require Settings to remain in the leftmost AppShell
  sidebar.
- Documentation states that the Left Content Panel owns Library, Timeline, and
  Favorites-style known-content navigation.
- Documentation states that the Right Learning Panel owns Search, Queue, and
  Learning Session-style active learning workflows.
- Documentation records that Search result hover actions may add items to a
  future Queue.
- Documentation records that future learning-session playback modes require
  more detailed design before implementation.
- Documentation states that this model does not supersede the player-first
  Search workspace swap.

## Decision

Accepted.

CueSeeker should evolve into a media learning workspace with a stable center
Playback Area, a left content-navigation panel for known content and precise
location, and a right learning panel for Search, Queue, and Learning Session
workflows.

The model preserves the accepted player-first Search workspace plan while
leaving Settings to the standalone Settings window direction. It gives future
Library, Timeline, Favorites, Queue, and learning-session work a clear place
without making CueSeeker behave like a generic IDE.
