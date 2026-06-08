# Speaker Column Test

Human-owned requirement:

- `docs/human/requirements/20260608-Feature-Speaker Column Test.md`

## Scope

Implement the Test Search 2 Speaker-column validation path:

- allow Test Search 2 to show all cue rows when the search query is empty;
- add a Speaker string-set field and table column;
- support Speaker Filter Set rules;
- keep the playback Search Results list bound to Speaker-filtered Test Search 2
  results;
- import the local MyGO Speaker test data into the local CueSeeker SQLite
  database for validation.

## Implementation

1. Added `subtitle_cue_line_speakers` as schema version 18 data, keyed by cue
   line and normalized speaker key, with cue-group and speaker lookup indexes.
2. Added `speakers` to `SubtitleSearchResult` and loaded cue-group speaker
   sets for search pages, indexed visible windows, and the Test Search 2
   all-cues visible-window path.
3. Added `speaker` to the schema-workbench Filter Set field mapping as a
   string-set field, using the same operators as Language.
4. Added an all-cues database page path for Test Search 2. It preserves default
   cue order, applies Filter Set rules in the database layer, and only hydrates
   cue lines for rows in the requested visible window.
5. Added a Speaker column to the AppKit virtual table and mapped Speaker values
   to purple workbench tags.
6. Fed the Test Search 2 all-cues page into the global Search context so the
   playback Search Results sidebar and adjacent-result navigation can use the
   Speaker-filtered result set even when the search query is empty.
7. Imported `/Users/weiyunjun/Documents/work/mygo_speaker_export/final`
   Speaker data into the local app database
   `/Users/weiyunjun/Library/Application Support/CueSeeker/CueSeeker.sqlite`.

## Verification

- Read-only import dry run assigned all 3,923 MyGO `Dial_JP` database cue lines
  to Speaker records. EP12 contains one exported record that maps to two
  same-timestamp `Dial_JP` rows; both rows received the same Speaker.
- Local database import result:
  - `subtitle_cue_line_speakers`: 3,923 rows
  - distinct speaker keys: 46
  - `speaker = '高松灯'`: 517 cue groups
  - per-episode imported row counts match the database `Dial_JP` row counts.
- Focused tests passed:
  - `swift test --filter 'SubtitleSearchFilterSet|SchemaWorkbenchFilterRules|TableSandboxRowModelStore|SubtitleTableVirtualRow|allCueGroupsVisiblePageReturnsDefaultOrderAndSpeakers'`
  - `swift test --filter 'SearchStore|TableSandbox|allCueGroupsVisiblePageReturnsDefaultOrderAndSpeakers'`
- Full package tests passed:
  - `swift test` (258 Swift Testing tests and 7 XCTest tests passed)

## Outcome

The implementation matched the requirement. Test Search 2 can now use an empty
search query to browse cue rows, and Speaker can be displayed and filtered as a
string-set column.
