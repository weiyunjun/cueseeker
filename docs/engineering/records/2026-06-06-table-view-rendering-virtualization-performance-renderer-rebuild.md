# Table View Rendering Virtualization Performance - Renderer Rebuild

Date: 2026-06-06

Human requirement:

- `docs/human/requirements/20260606-Feature-Table View Rendering Virtualization Performance.md`

## Scope

Rebuild the test Search/Shiori table frontend renderer while preserving the
visible UI style. The rebuild replaces the previous `NSTableView` row/cell
management path with a self-drawn virtual document view.

## Goals

- Preserve the test table UI appearance: header, column widths, typography,
  separators, rounded container, and hover Play/Copy controls.
- Preserve first-screen behavior by seeding visible rows from the production
  Search/Shiori stores without waiting for every result.
- Keep the table's virtual row count authoritative and separate from hydrated
  visible pages.
- Support fast vertical scrolling and scrollbar dragging by rendering only the
  current viewport and hydrating missing rows asynchronously.

## Implementation

- Replaced `SubtitleTableView` internals with a custom virtual document view
  inside `NSScrollView`.
- Kept the public SwiftUI table API so the test Search/Shiori page layout and
  styling remain unchanged.
- Added sparse virtual row-height metadata for loaded rows.
- Preserved capped TextKit measurement and drawing for visible text only.
- Reused a single hover Play/Copy overlay instead of creating per-row controls.
- Prevented visible-page hydration from shrinking the authoritative total row
  count.

## Verification

- Passed: `swift test --filter SubtitleTableVirtualRow`
- Passed: `swift test --filter TableSandboxRowModelStore`
- Passed: `swift test --filter TableSandboxVisibleSearchHydrator`
- Passed: `swift test`

## Outcome

Focused verification and full test verification passed.
