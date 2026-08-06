# Indexing Pipeline Rule Compliance

## Requirement

- `docs/human/requirements/20260806-Bug-Indexing Pipeline Rule Compliance.md`
- `docs/human/design/Data.md`
- `docs/human/design/Cue Parsing.md`

## Scope

Correct the seven confirmed indexing lifecycle defects without changing the
permitted parent-child Library overlap behavior or its path-prefix cleanup.

## Steps

1. Centralized referenced-Cue snapshotting in the subtitle retirement path and
   added schema 42 protection against deleting a referenced live Cue or its only
   Tombstone. The migration repairs existing dangling Shiori with an
   intentionally content-free `cue_missing` placeholder that retains CueID.
2. Deferred Library identity, path rebinding, media backfill, replacement, and
   retirement until the core publication transaction. A scan lease may retain a
   selected path as configuration, but an incomplete scan cannot publish it as
   the successful Library binding.
3. Made subtitle metadata, bytes, parsed content, content fingerprint, and
   platform identity one prepared observation. A changed or unreadable file is
   kept at its last successful state while successfully prepared sibling files
   continue to publish.
4. Made video directory and supported-candidate metadata failures explicit
   incomplete-scan errors so they cannot be interpreted as an empty video set.
5. Cleared unavailable Library platform identity instead of retaining stale
   identity, while preserving the LibraryID path fallback.
6. Changed SRT logical deduplication and ASS Cue Group keys to normalized start
   and end milliseconds while retaining a deterministic source time string for
   format fidelity.

## Verification

- The focused schema 36-38 migration set passed: 3 tests.
- All new and affected indexing, database, video matching, SRT, and ASS
  regression tests passed in the complete serial run.
- The complete serial run executed 964 tests and reported one unrelated
  `ApplicationPersistenceTests` issue caused by shared `UserDefaults` suite
  state. That test passed when rerun alone.
- `swift build` and `git diff --check` passed.

## Outcome

Every current Cue retirement entry now protects persistent references, and the
database supplies a backstop against future dangling Shiori. Library and media
identity changes publish only after a complete scan, per-file subtitle failures
are isolated, video scan failures remain failures, and equivalent parsed times
now share one logical identity.

## Follow-ups

The explicitly excluded parent-child Library overlap cleanup remains unchanged.
