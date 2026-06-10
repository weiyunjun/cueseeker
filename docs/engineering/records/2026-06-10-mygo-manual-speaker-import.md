# MyGO Manual Speaker Import

Human requirement:

- `docs/human/requirements/20260609-Feature-Show Speaker in Subtitle Test.md`

## Scope

Replace existing MyGO speaker labels with the manually reviewed speaker file:

- `/Users/weiyunjun/Documents/mygo/mygo_speaker_manual_review.txt`

## Source Validation

- Source rows: 3923.
- Header: `集数`, `序号`, `时间戳`, `original`, `字幕`.
- Episode labels, sequence numbers, timestamps, required fields, and duplicate
  keys passed validation.
- All rows matched exactly one `Dial_JP` cue line in the database.
- Multi-speaker rows use `，` and split into separate speaker labels.

## Database Operation

- Backup created:
  `/private/tmp/CueSeeker-before-manual-speaker-import-20260610.sqlite`
- Deleted old MyGO speaker labels: 4166.
- Inserted manually reviewed MyGO speaker labels: 3934.

## Verification

- Final MyGO speaker cue lines by style: `Dial_JP` 3923, `Dial_CH` 0.
- Final MyGO speaker tags by style: `Dial_JP` 3934.
- Final suspected speaker labels: 0.
- Sample EP01 `0:01:27.39-0:01:30.52` now has `长崎素世` on `Dial_JP`.
