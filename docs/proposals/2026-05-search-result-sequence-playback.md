# Search Result Sequence Playback

Status: Accepted

## Background

Search-result playback previously treated a clicked result as a jump into the
matched video. That made it easy to inspect the selected timestamp, but it did
not provide a bounded review flow through the remaining results of a committed
Search query.

## Goals

- Play a clicked Search result only for that cue group's timestamp window.
- Fade picture and sound out over one second before advancing when a transition
  is needed.
- Advance automatically through the committed Search result sequence while
  keeping row selection synchronized with the currently playing result.
- Keep Search editing stable by separating the Search field draft from the
  committed query and visible result set.
- Stop automatic advancement after a new query is committed during active
  sequence playback.

## Non-goals

- General playlist management.
- Queue persistence.
- Cross-file continuity based on video identity.
- A new media playback backend.
- Replacing source-faithful ASS rendering.

## User Flow

The user types a Search query, presses Return, and receives the committed
results. Clicking any result starts a playback sequence from that row through
the remaining committed results. The selected row tracks the currently playing
result.

Each result normally plays from `start_ms` through `end_ms`. At `end_ms`, the
current video continues for one second while the Playback Area fades to black
and audio fades to silence. After that transition, the next result opens or
seeks and becomes selected. After the final result, playback remains black and
silent.

If adjacent results belong to the same subtitle filename and their windows are
`[a,b]` and `[c,d]`, playback remains continuous when
`0ms <= b - c <= 1000ms`. In that case, no fade is scheduled, playback keeps
running, and selection changes when playback reaches `c`.

Editing the Search field does not change the committed results. Pressing Escape
restores the field to the current committed query. Pressing Return commits the
draft and replaces the result area. If Return commits a new query while a
sequence is playing, the current result still finishes and fades out, but the
sequence then stops on black instead of advancing.

## UI/UX Impact

Search results no longer update on each keystroke. This protects active review
from accidental result-set churn and makes Return the explicit search action.

The transition itself is playback-surface feedback, not a new Search row state.
The Search row selection remains the primary indication of which result is
playing.

## Data Model Impact

No database schema change is required. The sequence is derived from the
committed in-memory Search result snapshot and the persisted subtitle timing
already returned by Search.

## Technical Risk

The main risk is coordinating product-level sequence intent with native playback
execution without embedding durable Search semantics inside the playback
backend. Sequence identity and invalidation should stay in the product-domain
state coordinator. Native playback should only execute open, seek, pause,
volume, and overlay commands.

## Acceptance Criteria

- Return commits a Search field draft and runs Search.
- Escape restores uncommitted Search field edits to the current committed query.
- Typing without Return does not change visible results or the active playback
  sequence.
- A clicked result plays from `start_ms` through `end_ms`, then fades picture
  and audio out for one second before advancing.
- Same-subtitle-filename adjacent results skip the fade only when
  `0ms <= b - c <= 1000ms`.
- If a new query is committed during active sequence playback, the current
  result finishes and fades out, then playback remains black and silent.

## Decision

Accepted for the native macOS workbench. Stable conclusions are reflected in
the product Search and playback documents before implementation.
