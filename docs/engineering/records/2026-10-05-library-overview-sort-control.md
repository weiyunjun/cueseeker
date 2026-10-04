# Library Overview Sort Control

Human-owned documents:

- `docs/human/requirements/20261005-UI-Library Overview Sort Control.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

1. **Folder Organization & Discoverability**:
   - Provide sorting capabilities on the Library Overview (Level 1) view so users can sort folders by default order, latest added, or oldest added.
   - Maintain folder indexing timestamp (`MIN(sf.indexed_at)`) for accurate historical order.

2. **UI & Design System Compliance**:
   - Place the sorting button in the top-right toolbar area above the folder grid, right-aligned with the main content area / grid container boundary.
   - Use Phosphor `funnel-simple` icon and display the active sort option label.
   - Highlight the button with `--color-bg-active` (`isOpen = true`) while the popover menu is active.
   - Implement single-choice radio menu using `WorkbenchPopoverPanel` and `WorkbenchPopoverRow` with `showsCheckmarkSlot: true`.
   - Adhere to popover menu conventions: highlight first option by default, support keyboard navigation (Up, Down, Esc, Enter) and mouse outside-click dismissal (`MenuGateClientView`).
   - Persist user sort preference across app restarts via `UserDefaults`.

## What changed

1. **Icons & Assets**:
   - Created Phosphor master stroke SVG `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/funnel-simple.svg` (256x256, `stroke-width="16"`, `fill="none"`, `stroke="currentColor"`).
   - Added `case funnelSimple = "funnel-simple"` to `AppIcon.swift`.

2. **Core Presentation & Database Layer**:
   - In `CompleteLibraryFolderSummaryPresentation`, added `indexedAt: String?` property with backward-compatible initializer defaulting to `nil`.
   - In `LibraryDatabase+Presentation.swift`, updated the folder summary query to retrieve `MIN(sf.indexed_at) AS first_indexed_at` and pass it to presentation models.
   - Created `LibrarySortOrder` enum (`default`, `latestAdded`, `oldestAdded`).
   - Added `Array<CompleteLibraryFolderSummaryPresentation>.sorted(by:)` sorting implementation with tie-breaking by folder title (`localizedStandardCompare`) and folder path.

3. **Store & Persistence**:
   - In `LibraryStore.swift`, added `sortOrder: LibrarySortOrder` backed by `UserDefaults` key `library_overview_sort_order`.
   - Added computed property `sortedCompleteLibraryFolderSummaries` which sorts `completeLibraryFolderSummaries` according to `sortOrder`.
   - Added localized title mapping for `LibrarySortOrder`.

4. **Workbench Controls & Library View**:
   - In `WorkbenchControls.swift`, updated `WorkbenchButton` to accept `isOpen: Bool`, applying active background color `--color-bg-active` when true.
   - In `WorkbenchTestLibraryView.swift`:
     - Added a top toolbar row containing the sorting button, right-aligned with the card grid.
     - Added popover menu state (`LibrarySortMenuState`), popover view (`LibrarySortMenuPopover`), and `MenuGateClientView` for click-outside dismissal and keyboard navigation.
     - Switched the grid rendering from raw summaries to `library.sortedCompleteLibraryFolderSummaries`.

5. **Localization**:
   - Added localized keys `library.sort.default`, `library.sort.latest_added`, and `library.sort.oldest_added` in `zh-Hans`, `zh-Hant`, and `en`.

6. **Tests**:
   - Created `CueSeekerCoreTests/LibrarySortTests.swift` verifying:
     - Default title-based sorting.
     - Latest-added sorting with title tie-breaker.
     - Oldest-added sorting with title tie-breaker.

## Verification

- Automated tests:
  - `swift test --filter LibrarySortTests`: 3/3 passed.
  - `swift test --filter LibraryDatabaseTests`: 22/22 passed.
