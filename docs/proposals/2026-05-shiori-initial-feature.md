# Shiori Initial Feature

Status: Accepted

## Background

CueSeeker needs a lightweight saved-subtitle workflow that lets the user collect
useful subtitle moments while watching local video. The accepted user-facing
name is Shiori.

## Goals

- Use Shiori as the product, UI, and code-domain name for saved subtitle cues.
- Replace the current right-side saved-content placeholder with a Shiori panel.
- Add a playback Shiori button immediately to the left of the pencil-tip
  current-subtitle copy button.
- Support `S` as the playback shortcut for the same Shiori command.
- Persist Shiori as durable local user state.
- Store the real-world save timestamp when a Shiori record is created.
- Present Shiori rows in a grouped list similar to Search results.

## Non-goals

- Saving whole videos as Shiori.
- Line-level Shiori records inside a multi-line ASS cue group.
- Queue or Learning Session integration.
- Sync, cloud storage, or remote sharing.
- Showing the saved-at timestamp in the initial Shiori panel.

## User Flow

When playback is active, the user can press the playback Shiori button or press
`S`. CueSeeker resolves the current subtitle cue from the current playback
subtitle file and playback timestamp, using the same indexed cue-selection
semantics as current-subtitle copy.

If the cue is not saved, CueSeeker saves it and shows a transient playback
feedback overlay with the Shiori icon and `Shiori Saved`.

If the cue is already saved, CueSeeker asks whether to remove it. Suggested
English confirmation copy is:

```text
Title: Remove Shiori?
Message: This subtitle is already saved. Remove it from Shiori?
Confirm: Remove
Cancel: Cancel
```

After confirmed removal, CueSeeker shows a transient playback feedback overlay
with the Shiori icon and `Shiori Removed`.

## UI/UX Impact

The right-side saved-content mode becomes Shiori. The titlebar mode icon should
use a saved-content shape and the visible name should be `Shiori`.

The Shiori panel should show:

- `<count> shioris in <count> files`.
- A fixed `Collapse All` control.
- Subtitle-file groups expanded by default.
- Rows containing saved subtitle text and the subtitle start timestamp.

The `Collapse All` control intentionally does not become `Expand All`, so a
collapsed Shiori list can be expanded group-by-group without forcing large row
batches to render at once.

## Data Model Impact

The first Shiori implementation should add a local durable table named
`shioris`.

Expected fields:

- `id`
- `subtitle_path`
- `subtitle_format`
- `start_ms`
- `end_ms`
- `video_path`
- `video_name`
- `content`
- `created_at`

Shiori identity should be based on `subtitle_path`, `start_ms`, and `end_ms`,
not on volatile indexed row IDs. `created_at` stores the real-world save
timestamp. Duplicate saves for the same cue identity should be treated as an
existing Shiori record.

## Technical Risk

- Shiori must remain durable user state even when derived index rows are
  removed, rebuilt, or temporarily unavailable.
- Shiori save must not depend only on the visible subtitle overlay text because
  the current copy command uses database cue selection by subtitle file and
  playback timestamp.
- The `S` shortcut must not intercept editable text input or modified shortcuts.
- The grouped Shiori panel should preserve the existing workbench invalidation
  boundaries and avoid rebuilding unrelated Search or Library presentation
  rows.

## Acceptance Criteria

- The right-side saved-content mode is named Shiori.
- The playback Shiori button appears immediately to the left of the pencil-tip
  current-subtitle copy button.
- Pressing `S` triggers the same Shiori command when playback shortcuts are
  active.
- Saving a new current subtitle cue persists a Shiori record and shows
  `Shiori Saved`.
- Triggering Shiori on an already saved current subtitle cue asks for removal
  confirmation.
- Confirmed removal deletes the Shiori record and shows `Shiori Removed`.
- The Shiori panel shows `<count> shioris in <count> files`, a fixed
  `Collapse All` control, default-expanded groups, saved subtitle text, and
  start timestamps.
- Shiori records store a real-world creation timestamp even though the initial
  panel does not display it.

## Decision

Accepted for documentation. Implementation should update database migrations,
tests, playback controls, keyboard handling, and the right-side panel according
to the stable product and engineering documents.
