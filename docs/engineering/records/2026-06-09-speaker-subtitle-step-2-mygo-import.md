# Speaker Subtitle Step 2 MyGO Import

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Step 2 adds and runs a focused command-line importer for the MyGO speaker test
data. It does not add Settings UI or playback subtitle speaker display.

## Implementation

- Added the `SpeakerImport` executable target.
- The importer reads the 13 `mygo_epNN_Dial_JP_speakers.txt` TSV files and
  `mygo_ecapa_main_speaker_matches.txt`.
- The importer matches indexed MyGO `.scjp.ass` cue lines by episode, timestamp,
  and subtitle text.
- Suspected speaker rows append `疑似...` speaker labels to the same cue-line
  speaker set instead of replacing the current speaker.
- The importer defaults to dry-run; `--apply` clears and replaces speaker data
  for the 13 indexed MyGO subtitle files.

## Verification

- Passed: `swift build --product SpeakerImport`
- Passed dry-run:
  - base rows matched: `3923/3923`
  - suspected rows matched: `230/230`
  - cue lines assigned: `3923`
  - speaker tags: `4197`
- Applied import with:
  `swift run SpeakerImport --database "$HOME/Library/Application Support/CueSeeker/CueSeeker.sqlite" --source-dir /Users/weiyunjun/Documents/mygo --apply`
- Database verification after apply:
  - MyGO speaker tags: `4197`
  - suspected speaker tags: `274`
  - EP01 `0:01:27.39-0:01:30.52` has both `高松灯` and `疑似长崎素世`.
  - EP13 `0:00:01.98-0:00:08.59` applies `疑似丰川祥子` to both covered cue lines.

## Outcome

The current CueSeeker application database now has MyGO speaker tags loaded as
speaker string sets. Test Search 2 can hydrate these tags through the existing
speaker column path.
