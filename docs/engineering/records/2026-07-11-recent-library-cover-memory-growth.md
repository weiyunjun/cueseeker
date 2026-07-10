# Recent and Library Cover Memory Growth

## Requirement

- `docs/human/requirements/20260711-Bug-Recent Library Cover Memory Growth.md`

## Scope

Reduce stable Activity Monitor memory growth caused by Recent and Library cover
loading, route switching, scrolling, and window resizing while preserving the
original-resolution cover master.

The accepted display rendition keeps the source aspect ratio, fits within a
`512 x 288` pixel bounding box without cropping, stretching, or padding, and is
stored as a high-quality JPEG. Window resizing changes only presentation size;
it must not create a new rendition or decoded-image identity.

## Baseline

The production debug app was inspected while the current Recent page contained
19 distinct folder covers.

- Search launch observed by the owner: approximately 26 MB.
- Repeated Search and Recent navigation observed by the owner: approximately
  66 MB.
- Recent window resize observed by the owner: approximately 140 MB.
- `vmmap -summary` at the reproduced stable state reported a 140.3 MB physical
  footprint and a 162.1 MB peak.
- The same snapshot contained 45.2 MB of `CG raster data` and 46.8 MB of
  `CoreAnimation` regions.
- Heap inspection found 166 `NSImage` objects, 164
  `NSCGImageSnapshotRep` objects, and 19 active SwiftUI optional-image state
  slots.
- `leaks -quiet` reported zero ordinary leaked allocations.

This evidence identifies retained size variants and their render surfaces as
the primary resize multiplier rather than an ordinary retain-cycle leak.

## Planned Steps

1. Separate original-resolution masters from bounded display renditions in the
   cover data model and migration path.
2. Generate and backfill aspect-preserving high-quality JPEG display
   renditions.
3. Replace geometry-keyed image loading with one stable rendition identity,
   bounded decoded-image caching, duplicate-request coalescing, bounded decode
   concurrency, and stale-result protection.
4. Integrate the stable loader into Recent, Library folder, and Library episode
   views and release offscreen view ownership.
5. Avoid rebuilding unchanged Recent and Library presentation snapshots during
   route-only navigation.
6. Run automated coverage, inspect live VM categories, and hand the complete
   owner-authored Activity Monitor flow back for final end-to-end acceptance.

## Verification

Each implementation step will record its focused tests here. Final automated
verification must include the full Swift test suite and a debug build. Runtime
verification must inspect physical footprint, decoded raster regions, render
surfaces, cache accounting, in-flight decode count, and ordinary leaks.

Data-model verification:

- `swift test --filter libraryCoverRecordsStoreVideoSnapshotAndFolderReference`
  passed.
- `swift test --filter migrationAddsDisplayCoverFieldsWithoutReplacingMaster`
  passed, including a repeated migration call.
- `swift test --filter libraryCover` passed with three selected tests.
- The focused test build compiled the complete macOS application and test
  targets successfully.

The owner will perform the final Activity Monitor UI acceptance flow. Its final
stable physical footprint must not exceed 75 MB, with no more than 5 MB growth
after repeated Library navigation and no more than 10 MB growth after window
resize relative to the first completed flow.

## Outcome

The diagnostic baseline and implementation boundaries were recorded before
code changes.

Schema version 27 now separates the existing original-resolution master path
from an optional display-cover path and profile version. The migration preserves
all legacy master and folder-cover rows and deliberately leaves display fields
empty so a master can never be mistaken for a bounded display rendition. The
database API validates that display path and profile version are stored or
cleared together.
