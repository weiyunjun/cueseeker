# Implementation Record: File Page Episode Group Unified Card

- **Requirement**: `docs/human/requirements/20261017-UI-File Page Episode Group Unified Card.md`
- **Design References**:
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
- **Date**: 2026-10-17

## Scope

- Add `--color-file-group-header-bg` (`WorkbenchRedesignColors.fileGroupHeaderBg` / `WorkbenchRedesignColors.NS.fileGroupHeaderBg`: Light `#F8F9FB`, Dark `rgba(255,255,255,0.04)`).
- Replace the nested box-in-box episode group layout on the File page (`L-04.5` & `L-04.6`) with a single unified rounded card (`--color-table-bg`, `1px` `--color-border-control`, radius `--radius-settings-group: 10px`, `0px` outer padding, clipped).
- Render `Display Title` (`14px` Medium `--color-text-muted`) inside the card's top header bar (min height `36px`, horizontal padding `16px`, background `--color-file-group-header-bg`) with a full-width `1px` `--color-border-divider` below it and between every file row.

## Steps

1. Added `fileGroupHeaderBg` to `WorkbenchRedesignColors.NS` and `WorkbenchRedesignColors` in `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`.
2. Updated `episodeGroupsList` and `WorkbenchFileCard` (`showsCardChrome: Bool = true`) in `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift` so standalone folder cards retain their individual rounded borders while episode group video/subtitle rows render as flat full-bleed rows separated by full-width `1px` `--color-border-divider` lines inside the unified episode group card.
3. Added token color and alpha assertions for `fileGroupHeaderBg` in `apps/macos-native/Tests/CueSeekerAppTests/FileCardMenuTests.swift`.

## Verification

- `swift test --filter "FileCardMenuTests|FileRouteNavigationTests"` passed.

## Outcome

- Matched the requirement and design specifications.
