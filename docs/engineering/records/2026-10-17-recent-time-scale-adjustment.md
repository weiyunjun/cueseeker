# Implementation Record: Recent Time Scale Adjustment

- **Requirement**: `docs/human/requirements/20261017-UI-Recent Time Scale Adjustment.md`
- **Date**: 2026-10-17

## Summary of Changes

1. **Product Semantics (`RecentTimeSection`)**:
   - Updated `RecentTimeSection` in `apps/macos-native/Sources/CueSeekerCore/LibraryDatabaseModels.swift` from five buckets (`today`, `yesterday`, `last7Days`, `earlier`, `neverPlayed`) to four buckets (`last7Days`, `last30Days`, `earlier`, `neverPlayed`).
   - Updated `RecentTimeSection.classify(timestamp:relativeTo:calendar:)` to partition played timestamps by local calendar midnight $T_0$:
     - `last7Days`: $t \ge T_0 - 6\text{d}$
     - `last30Days`: $T_0 - 29\text{d} \le t < T_0 - 6\text{d}$
     - `earlier`: $t < T_0 - 29\text{d}$
     - `neverPlayed`: nil or empty timestamp

2. **Localization & UI Presentation**:
   - Replaced `recent.section.today` and `recent.section.yesterday` with `recent.section.last_30_days` across `en.lproj`, `zh-Hans.lproj`, and `zh-Hant.lproj` `Localizable.strings` (`Last 30 Days` / `最近 30 天` / `最近 30 天`).
   - Updated `RecentTimeSection.localizedTitle` in `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestLibraryView.swift`.

## Verification

- Automated unit & integration tests (`swift test --package-path apps/macos-native --filter recentTimeSectionClassifiesAndGroupsByLocalCalendarDayBoundaries` and full `CueSeekerApp` build):
  - `LibraryDatabaseTests.recentTimeSectionClassifiesAndGroupsByLocalCalendarDayBoundaries` passed.
