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

## Outcome

- Pending completion of the accepted implementation steps.
