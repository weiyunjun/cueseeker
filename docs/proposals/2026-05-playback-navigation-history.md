# Implementation Plan: Playback Navigation History

Status: Proposal

## Background

Playback Quick Search exposes `/back` and `/forward` commands that walk a
bounded, persisted history of recent playback targets. Product rules for this
feature are already specified in:

- `docs/proposals/2026-05-playback-quick-search-overlay.md` — Data Model
  Impact section, persistent playback navigation state.
- `docs/proposals/2026-05-playback-ai-chunking.md` — UI/UX Behavior
  section, navigation command row and search result recovery for playback
  navigation, centered text-only feedback.

This document records the agreed implementation breakdown for that feature. It
does not introduce new product rules.

## Bounded History Limit

The persisted navigation history keeps the most recent 10,000 entries. Older
entries are pruned automatically when this limit is exceeded.

The history payload schema is expected to evolve while the feature matures, so
this limit is an initial value rather than a long-term contract.

## Implementation Steps

The feature is implemented in six commit-sized steps. Each step is independently
reviewable and ships with tests for the behavior it introduces.

### Step 1 — Persistent storage for playback navigation history

Add a bounded history store in the Core data layer holding compact playback
entries plus a current-position pointer and an index revision counter.

Behavior:

- Append a new entry, update an existing entry, delete entries after a given
  entry, and prune to the bounded limit.
- Read the full history in order; read or set the current-position pointer.
- Read the index revision counter; any operation that changes searchable
  content increments the counter automatically.

Verification:

- Unit tests cover append, update, delete-after, prune, current-pointer
  read/write, and index revision auto-increment on indexed-content changes.

### Step 2 — Record an entry when playback starts

When playback begins for a library video, a subtitle search result, or a
Shiori bookmark, write a corresponding history entry.

Behavior:

- Same-source successive playback replaces the head entry rather than stacking
  new entries.
- Starting playback past a non-latest history position truncates the future
  branch ahead of the current-position pointer.
- The bounded prune from Step 1 keeps the table within the limit.

Verification:

- Unit tests cover append, replace-on-same-kind, future-truncate when
  starting playback past a non-tail position, and prune when entries exceed the
  limit.

### Step 3 — Show the `/back` `/forward` row in Quick Search

When the overlay opens and the current-position pointer can move backward or
forward, display a navigation row between the cached-chunks row and the
"current sentence / chunks" row.

Behavior:

- If neither direction is available, the row is hidden entirely.
- If only one direction is available, only that command is shown.
- Up and Down move logical focus through input, chunks row, navigation row,
  "current sentence / chunks" row, and back, following the existing Quick
  Search focus rules.
- The selected command uses the existing Quick Search row highlight.

Verification:

- UI or unit tests cover row visibility under each availability combination
  and the expected vertical focus order.

### Step 4 — Horizontal cycling in multi-item option rows

Left and Right within a focused multi-item option row cycle the selected item
and wrap at both ends.

Behavior:

- Applies to the cached-chunks row and the `/back` `/forward` row consistently.
- Vertical focus behavior between rows is unchanged.

Verification:

- Unit tests cover wrap-from-last-to-first and wrap-from-first-to-last on
  both rows.

### Step 5 — Execute `/back` and `/forward`

Pressing Return on the selected navigation command resumes the target history
entry through its origin's existing playback path and moves the
current-position pointer to that entry.

Behavior:

- Library and Shiori entries resume through the existing library and Shiori
  playback paths.
- Search-origin entries restore through the existing Quick Search / Search
  flow:
  - If the entry's recorded index revision matches the current index
    revision, the existing flow may satisfy the request from the current
    result cache.
  - If the entry's recorded index revision differs from the current index
    revision, the saved query and scope are re-run against the current index.
    If the rerun has results, the first refreshed result plays.

Verification:

- Tests cover library resume, Shiori resume, search resume with unchanged
  index revision, and search resume with changed index revision producing
  refreshed results.

### Step 6 — Centered text feedback for empty result

When a search produces no local results, reuse the playback page's existing
centered text feedback animation instead of changing the overlay surface.

Behavior:

- Direct Quick Search submission with no local results shows the centered
  text feedback; the overlay's current option interface stays visible.
- Search-origin `/back` or `/forward` whose refreshed rerun returns no results
  shows the centered text feedback; playback does not change and the overlay's
  current option interface stays visible.

Verification:

- Tests cover the centered text feedback for both empty-direct-search and
  empty-refreshed-search cases, and confirm that playback state is unchanged
  in the refreshed empty case.

## Dependencies between steps

- Step 2 depends on Step 1.
- Step 3 depends on Step 2.
- Step 5 depends on Steps 1, 2, and 3.
- Steps 4 and 6 are independent of each other; both are intended to land after
  Step 3 so they can be tested together with the navigation row.

## Decision

Pending implementation.
