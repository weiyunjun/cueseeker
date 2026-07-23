# Weighted Table Column Width and Dynamic Row Height

## Human-Owned Source

- `docs/human/requirements/20260723-Feature-Weighted Table Column Width And Dynamic Row Height.md`
- `docs/human/design/UI.md`

## Scope

Apply the accepted weighted column-width and dynamic row-height rules to the
shared native Search, Shiori, and Search-hosted Context table in independently
verified Git steps.

## Step 1 Changes

- Generalized table row-measurement cache identity from the Cues text width to
  the complete visible-column width layout.
- Generalized viewport-width reflow detection, scroll-anchor preservation,
  visible-column invalidation, and Header refresh so they no longer assume that
  Cues is the only changing column.
- Preserved the existing column-width behavior in this step so the cache and
  invalidation change can be verified independently before enabling weighted
  sizing.

## Step 1 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTableRowHeightCache|subtitleTableColumnLayoutMeasurementKey|subtitleTableViewUsesTallestVisibleColumn|subtitleTableViewResolvesDocumentedDynamicRowHeights|subtitleTableViewPreservesPrimaryCueAnchor'`
  - Passed all 11 selected Swift Testing tests.
- `swift test --filter 'SubtitleTableVirtualRow|SubtitleTableRowHeightCache'`
  - Passed all 91 selected Swift Testing tests.
- `git diff --check`
  - Passed.

## Step 2 Changes

- Added a shared minimum-constrained weighted-width resolver and applied it to
  the native Search, Shiori, and Search-hosted Context table layouts.
- Preserved the existing equal-extra-width behavior for any table that still
  uses only the legacy flexible-width mode.
- Kept the Checkbox column fixed at 50 points and excluded it from weighted
  allocation.
- Applied the accepted non-checkbox weights and minimums:
  - Display Title: weight 3, minimum 180 points.
  - Cues: weight 6, minimum 240 points.
  - Tags: weight 2, minimum 140 points.
  - Time Range: weight 2, minimum 140 points.
  - Date Added: weight 2, minimum 120 points.
  - Speaker: weight 2, minimum 140 points when visible.
  - Language: weight 2, minimum 120 points when visible.
- Excluded hidden columns from both minimum-width totals and proportional
  allocation. When the viewport is narrower than the visible minimum-width
  total, the table document expands and uses horizontal scrolling.
- Kept the legacy non-redesign table sizing path unchanged.

## Step 2 Verification

- `swift build`
  - Passed.
- `swift test --filter 'subtitleTableColumnLayout|schemaWorkbenchTablesUseDocumentedColumnWeightsAndMinimums|subtitleTableViewExpandsRedesignDocumentWidthForHorizontalScrolling|subtitleTableViewCueTextHitTestingUsesTextFragmentsOnly'`
  - Passed all 9 selected tests.
- `swift test --filter 'SubtitleTableVirtualRow|SubtitleTableRowHeightCache|SchemaWorkbenchCountSummary'`
  - Passed all 102 selected tests.
- `swift test`
  - Ran 836 Swift Testing tests plus 7 XCTest tests.
  - The full concurrent workload did not pass because unrelated media-timeline,
    database I/O, and asynchronous timeout tests became unstable under suite
    load. No table test failed.
- Individual reruns of the five failures remaining in the second full-suite run:
  - `failedLibraryFolderRemovalPreservesFolderAndPresentationState`
  - `nativePlaybackUsesCommonTimelineWhenVideoTrackStartsAfterAudio`
  - `nativePlaybackNotifiesNaturalCompletionAfterAudioDrain`
  - `nativeAutoStopKeepsSessionAliveAndResumesFromBoundary`
  - `nativePlaybackRebuildsAudioOutputAndContinuesInCurrentSession`
  - Passed all 5 tests.

## Outcome

- The accepted weighted-width and dynamic row-height behavior is implemented.
- Focused and complete table verification matched expectations.
- Full-suite unrelated load-sensitive failures remain visible in this record;
  every failure remaining in the second run passed when rerun individually.
