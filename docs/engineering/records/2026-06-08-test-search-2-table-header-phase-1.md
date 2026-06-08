# Test Search 2 Table Header Phase 1

Human requirement:

- `docs/human/requirements/20260608-Feature-Test Search 2 Schema UI Shell.md`

## Scope

This record covers Phase 1 of the second Test Search 2 table UI stage:
aligning the AppKit virtual table header styling with the Test Search UI table
header.

This phase intentionally does not add table columns, language tags, filter
semantics, row-model fields, database fields, or any new materialization path.

## Changes

- Updated the AppKit virtual table header height to match the shared
  schema-driven SwiftUI table header height.
- Updated the AppKit virtual table header typography to use the same 13 pt
  semibold label styling as the Test Search UI table header.
- Added header-specific horizontal insets so header label placement matches the
  shared table header without changing body cell padding.
- Left row count, row provider, visible-row range calculation, row height,
  visible search hydration, and playback actions unchanged.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- `swift test --filter subtitleTableViewUsesVirtualRowCountWithoutMaterializingModels` succeeded.

## Outcome

Phase 1 is complete. The AppKit virtual table header is visually closer to the
Test Search UI table header while preserving the existing virtualized search
table behavior.
