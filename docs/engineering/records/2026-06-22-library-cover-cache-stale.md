# Library Cover Cache Stale Bug

Human requirement:

- `docs/human/requirements/20260622-Bug-Library Cover Cache Stale.md`

## Scope

Fixed stale downsampled Library cover rendering when an indexed cover is
regenerated at the same filesystem path.

## Classification

- Platform UI/UX: Test Library downsampled cover rendering.
- Runtime caching: in-memory cover image cache key versioning.

## Changes

- Added cover file version metadata to the downsampled cover request.
- Changed the in-memory cover cache key from path and max pixel size only to
  path, max pixel size, file byte count, and file modification timestamp.
- Kept the image loading path and downsample behavior unchanged; only cache
  identity now changes when a regenerated cover overwrites the same file path.

## Verification

- `swift test --filter completeLibrary` passed.
- `swift test --quiet` passed: 321 Swift tests plus 7 XCTest cases.

## Outcome

Regenerated Library covers should no longer keep displaying the old downsampled
`NSImage` from memory after the cover file changes at the same path.
