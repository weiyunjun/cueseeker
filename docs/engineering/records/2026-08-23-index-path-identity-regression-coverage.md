# Index path identity regression coverage

Human-owned documents:

- `docs/human/design/Data.md`
- `docs/human/requirements/20260823-Bug-Index Path Identity And Missing Resource Forgetting.md`

## Why

The accepted rule needed tests that pin it down, above all the reported P0 itself:
a Library that had been removed once could never be added again.

## What changed

`IndexPathIdentityTests` covers, against a real temporary directory and a real
SQLite database:

1. A Library that was removed can be added again at the same path.
2. A folder that disappears and later returns restores no cover, no watch state
   and no progress, and its video gets a new VideoID.
3. A scan that fails leaves the previous index untouched.
4. The same path and file name keep their permanent IDs when the content changes.
5. A Cue held by a Shiori is tombstoned when its Library is removed.
6. The current schema keeps no identity, binding state or path-keyed watch data.

Test 2 exposed two real defects, both fixed here:

- A folder that lost all of its content kept its row and its user cover, because
  only Library removal deleted folders. Publishing an index now also deletes
  folders that no longer hold any indexed file, together with their covers.
- Looking a folder up by absolute path compared the Library root, which is stored
  standardized, against a caller path that was not, so a cover could be stored
  without ever binding to its folder. The lookup standardizes its argument now.

## Verification

- The six new tests pass.
- Full `swift test` (1019 tests): compared against a captured baseline run of the
  unmodified tree, the only difference is one native playback timing test, which
  belongs to the same device-dependent family that already fails on the baseline
  and passes in isolation. No failure is caused by this change.

## Outcome

Matched expectations, and the new coverage found two defects that the earlier
commits had left behind.
