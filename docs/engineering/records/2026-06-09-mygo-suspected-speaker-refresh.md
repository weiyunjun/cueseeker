# MyGO Suspected Speaker Refresh

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Refresh only MyGO suspected speaker labels from:

- `/Users/weiyunjun/Documents/mygo/mygo_ecapa_main_speaker_matches.txt`

## Source Validation

- Source file rows: 239 including header.
- Suspected speaker data rows: 238.
- Episode labels: EP01 through EP13.
- Column count, timestamp format, and required fields passed validation.
- Dry-run matched suspected rows: 238/238.
- Matched non-`Dial_JP` rows: 0.

## Database Operation

- Backup created:
  `/private/tmp/CueSeeker-before-suspected-speaker-refresh-20260609.sqlite`
- Deleted existing MyGO suspected speaker labels: 301.
- Inserted refreshed MyGO suspected speaker labels: 238.
- Preserved existing non-suspected MyGO speaker labels: 3928.

## Verification

- Final MyGO suspected speaker labels: 238.
- Final MyGO non-suspected speaker labels: 3928.
- All refreshed suspected speaker labels are attached to `Dial_JP`.
- Sample EP01 `0:01:27.39-0:01:30.52`:
  `Dial_JP` now has `疑似长崎素世,高松灯`.
