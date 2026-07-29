# Unify Workbench Search And Shiori — Step 2

## Requirement

- `docs/human/requirements/20260729-Feature-Workbench Playback And Command Panel Shared UI.md`
- Step 2: align Shiori with Workbench Search automatic search, matching scope,
  and result count, and place Primary Cue above Cue Group context throughout
  Workbench Cue tables.

## Scope

- Replaced Shiori's submitted-query state with one live search draft and
  projected resident Shiori rows on every input change.
- Reused the Core Search query matcher against Primary Cue text only; Display
  Title and Cue Group context no longer participate in Shiori matching.
- Added the exact Shiori result count to the shared Workbench search shell.
- Reordered shared Workbench Cue-table display, selection, and copy text so the
  Primary Cue is above optional Cue Group context.
- Updated architecture, testing, end-to-end verification, and changelog records.
  Human-owned documents, including `docs/human/design/UI.md`, were not modified.

## Steps

1. Exposed Search's line-level query matcher through a small Core API and used
   it in the resident Shiori projection.
2. Removed the separate submitted search value and connected the Shiori search
   field directly to query projection without Return.
3. Reused the existing exact-result boundary to publish the Shiori row count.
4. Moved shared table geometry and text fragments to Primary Cue-first order,
   including selectable and copied text.
5. Added matcher, live Shiori projection, Display Title exclusion, geometry,
   hit-testing, selection, and clipboard coverage.

## Verification

- `swift build`: passed.
- The focused new-behavior run: 10 tests passed.
- `swift test --filter 'SubtitleTable|ShioriOverlay|SearchQueryPlanner'`: 173
  tests passed.
- `swift test`: all 891 tests compiled and ran; the parallel run reported 13
  issues across 8 existing persistence, folder-removal, refresh-scope,
  Shiori-save, and native-media timing tests.
- Each of those 8 full-run failures passed when rerun individually, confirming
  concurrent shared-resource or timing flakiness rather than a Step 2
  regression.
- `git diff --check`: passed.

## Outcome

- Step 2 matched the requirement. Shiori now searches Primary Cue text as the
  user types, excludes Display Title, exposes its exact result count, and uses
  the same Primary Cue-above-Cue Group presentation order as Search and Context.
