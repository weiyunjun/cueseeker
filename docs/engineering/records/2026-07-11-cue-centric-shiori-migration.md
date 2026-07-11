# Cue-Centric Shiori Migration

## Human-Owned Source

- `docs/human/requirements/20260710-Feature-Cue-Centric Search Shiori Context Playback And Export.md`
- `docs/human/design/UI.md`

## Scope

Implement schema version 28 for durable single-Cue Shiori identity. This step
covers the Core schema, legacy Shiori migration, single-Cue selection and
Shiori persistence APIs, ID-based deletion, migration tests, and the matching
database/data-model rules. Cue-centric Search, Context, Subtitle Focus data
loading, exports, and table presentation remain separate implementation steps.

## Classification

- Product semantics: one Shiori represents one Cue, including a Cue whose text
  contains source line breaks.
- Durable user state: Shiori row IDs, validity, creation timestamps, content
  snapshots, and tag assignments must survive migration.
- Derived index binding: Cue Group and Cue Line row IDs remain rebuildable;
  durable identity uses subtitle path, source event index, and Cue timing.

## Implementation

- Advanced `PRAGMA user_version` from 27 to 28.
- Added nullable `cue_event_index` and `cue_display_order` fields to `shioris`.
- Replaced Cue-Group time uniqueness with
  `(subtitle_path, cue_event_index, start_ms, end_ms)` so same-time sibling Cues
  can be saved independently.
- Rebuilt legacy `shioris` transactionally while retaining explicit row IDs.
  Existing tag-assignment rows remain attached to the same Shiori IDs, and the
  migration runs `PRAGMA foreign_key_check` before commit.
- Resolved legacy rows against their matching indexed Cue Group. Migration
  prefers Japanese Cues, chooses the physically bottommost Japanese Cue when
  several match, and falls back to the physically bottommost Cue when language
  cannot be identified.
- Preserved unindexed legacy rows as unresolved snapshots with nullable Cue
  identity instead of deleting them.
- Changed `SubtitleCueTextSelection` to carry one Cue's exact content and Cue
  identity metadata. The timestamp selection path now chooses the physically
  bottommost Cue from the selected Cue Group.
- Changed Shiori deletion to use durable Shiori row ID, avoiding ambiguous
  same-time deletion.

## Transitional Compatibility

Subtitle Focus and legacy playback-navigation payloads still request a Shiori
by subtitle path and time range because their Cue identity migration belongs to
later accepted steps. A read-only compatibility lookup remains for those two
call paths and deterministically returns the physically bottommost matching
Shiori. It does not participate in writes or uniqueness. Remove this overload
after Subtitle Focus and navigation payloads carry source Cue event identity.

## Verification

- `swift test --filter Shiori` passed all 19 selected tests.
- `swift test --filter shiori` passed all 13 selected lower-case Shiori API,
  paging, filtering, tag, and navigation tests.
- Focused migration coverage passed for Japanese preference, the bottommost
  Japanese tie-break, the bottommost unknown-language fallback, repeat
  migration, preserved row metadata, preserved tag assignments, and unindexed
  unresolved snapshots.
- Focused persistence coverage passed for two same-time sibling Cues, duplicate
  suppression for one Cue identity, and ID-based deletion.
- `swift test --filter cueTextSelection` passed all 3 selected tests.
- `swift test --filter migratesFreshDatabaseToCurrentSchemaVersion` passed the
  fresh-schema parity check at version 28.
- `swift test --filter migration` passed all 11 selected migration regression
  tests, including every earlier-version fixture.
- `swift test` passed the complete 492-test package regression suite.
- `git diff --check` passed before final verification.

## Outcome

Schema version 28 stores and migrates Shiori as individual Cues without losing
durable user state. Same-time sibling Cues no longer collapse into one Shiori,
while unavailable legacy sources remain recoverable as unresolved snapshots.
