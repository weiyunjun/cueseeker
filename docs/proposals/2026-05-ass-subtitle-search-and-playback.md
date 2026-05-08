# ASS Subtitle Search and Playback

Status: Accepted

Implementation status:

- First implementation completed in M2.
- Implemented `.ass` scanning, ASS dialogue parsing, cue group and cue line
  indexing, grouped search result display, and click-to-playback behavior.
- Source ASS subtitle rendering remains deferred.
- Verified with `swift test --package-path apps/macos-native`, passing 43 tests.

## Background

M1 is complete and accepted as the minimal native SRT search and playback loop.
The next M2 feature work expands supported external subtitle files from SRT-only
indexing to include ASS subtitle files.

ASS files can contain multiple `Dialogue` events at the same timestamp, separate
styles for bilingual lines, signs, titles, or staff text, and layout information
that is not equivalent to plain subtitle text. The search database therefore
needs a normalized cue model that can preserve grouped search moments without
trying to become a full ASS renderer.

## Goals

- Treat ASS support as M2 feature work.
- Scan `.ass` files alongside `.srt` files.
- Parse ASS `[Events]` `Dialogue` rows according to the active `Format:` field.
- Normalize parsed subtitles into cue groups and cue lines.
- Search cue groups while preserving the cue lines that belong to each matched
  group.
- Display all cue lines in a matched group without deduplication or a fixed line
  count cap.
- Open the matched video from an ASS search result and seek to the cue group's
  `start_ms`.
- Preserve durable user configuration while allowing derived subtitle index data
  to be rebuilt during the schema migration.

## Non-goals

- Source ASS subtitle rendering in the first implementation step.
- Selecting or bundling a dedicated ASS rendering dependency in the first
  implementation step.
- Embedded subtitle stream decoding.
- Line-level Shiori records.
- Fuzzy subtitle-to-video matching.
- Media library browsing.
- Remote subtitle indexing or remote video playback.

## User Flow

The first M2 ASS flow is:

```text
Open Search
Add or confirm a local subtitle folder
Index supported external subtitle files
Search text that may appear in SRT or ASS files
Review grouped results
Click a result
Playback Inspector opens or updates
Matched video opens or seeks to the cue group start timestamp
```

ASS search result selection should work even before source ASS subtitle rendering
exists. In that first step, playback is responsible for opening the matched video
and seeking to the cue group's start timestamp.

## UI/UX Impact

Search remains the primary workspace.

For grouped subtitle results:

- A matched cue group appears as one result.
- The result displays every cue line that belongs to the group.
- Cue lines are ordered by derived display order when possible.
- Cue lines are not deduplicated during indexing or result rendering.
- There is no fixed product-level line count cap for cue lines shown in a result.

The Playback Inspector should continue to show the selected result's metadata,
including start time, video path, and subtitle path.

## Data Model Impact

The database must evolve from the M1 subtitle-entry model toward first-class
subtitle files, video files, subtitle-to-video matches, cue groups, and cue
lines.

Expected migration approach:

- Preserve durable user configuration such as selected folders and playback
  settings.
- Rebuild derived subtitle index data from source subtitle files.
- Rebuild FTS rows from cue group search content.
- Preserve the rule that source subtitle files are the source of truth for
  searchable subtitle text.

ASS grouping rule:

- ASS `Dialogue` events are grouped only when they have the same source subtitle
  file, exact `start_ms`, and exact `end_ms`.
- Near-equal timestamps must not be grouped by tolerance in the first
  implementation.

Search matching rule:

- Search returns cue groups.
- A cue group matches when at least one cue line satisfies the query.
- A cue group must not match only because query terms are split across different
  cue lines.
- If any cue line in a group matches, the result displays the full cue group.

## Technical Risk

Risks:

- ASS parsing must honor the active `[Events]` `Format:` field rather than
  assuming a fixed column order.
- ASS override-tag cleaning and line-break normalization are intentionally
  limited to the documented rules until real data testing justifies more cases.
- Group-level FTS recall can accidentally create cross-line matches unless the
  implementation validates line-level match semantics before returning results.
- Schema migration must distinguish durable user configuration from rebuildable
  derived index data.
- Future source ASS rendering may require a dedicated native dependency and
  packaging review.

## Acceptance Criteria

- `.ass` files are discovered during subtitle scanning.
- SRT indexing remains supported.
- ASS `Dialogue` events are parsed through the active `Format:` mapping.
- ASS `Comment` events are not indexed as searchable subtitles.
- ASS override tags such as `{...}` are removed from searchable text.
- ASS line breaks such as `\N` are normalized for searchable text.
- ASS events with exact matching subtitle file, `start_ms`, and `end_ms` are
  grouped into one cue group.
- ASS events with near-equal but not exact timestamps are not grouped together.
- Cue lines inside a group are preserved without deduplication.
- Search returns cue groups instead of individual ASS lines.
- Query terms split only across different cue lines do not make the group match.
- A matched group displays all of its cue lines in derived display order.
- Clicking an ASS search result opens or updates playback for the matched video
  at the cue group's `start_ms`.
- The first implementation does not need to render the source ASS subtitle track
  during playback.
- Migration preserves durable configuration and rebuilds derived subtitle index
  data.

## Decision

Accepted for M2.

The first implementation step supports ASS indexing, grouped cue search results,
grouped result display, and click-to-playback behavior. Source ASS subtitle
rendering is deferred. When source ASS rendering is implemented later, playback
must render the source `.ass` file rather than reconstructing ASS visual
behavior from database cue projections.
