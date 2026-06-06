# Table View Rendering Virtualization Performance - Step 2

Date: 2026-06-06

Human-owned requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Limit the test Search/Shiori table main view so very long subtitle/effect cells
cannot force unbounded row heights.

## Implementation

- Added a table metric for a maximum of six body text lines.
- Applied the maximum line count to the shared TextKit layout used by both
  measurement and drawing.
- Left full row text available to selection/copy/play logic; this step only caps
  main-table rendering height.

## Verification

- Added TextKit layout tests with 20-line test data.
- Verified that the 20-line body text is capped below uncapped height and within
  the six-line expected maximum.
- Verified that two-line body text remains unchanged.

## Outcome

Main table row height is now bounded by six rendered body lines per cell. The
next steps still need to virtualize result data, row models, and visible text
hydration for very large result sets.
