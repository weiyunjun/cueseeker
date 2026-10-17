# Implementation Record: Task History LIFO And Character Facet Width Rule

- **Requirement**: `docs/human/requirements/20261017-Feature-Task History LIFO And Character Facet Width Rule.md`
- **Date**: 2026-10-17

## Summary of Changes

1. **Task History LIFO Ordering (`Completed` & `Incomplete`)**:
   - Kept `Current` (`TaskQueueStore.current`) in FIFO order (`append`).
   - Updated `TaskQueueStore.moveToHistory` in `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskQueueStore.swift` to insert newly completed or incomplete tasks at index `0` (`completed.insert(record, at: 0)` / `incomplete.insert(record, at: 0)`), with monotonically increasing `stateChangedAt` timestamps.
   - Updated `TaskRecordDatabase.records()` in `apps/macos-native/Sources/CueSeekerCore/TaskRecordDatabase.swift` to order by `state_changed_at DESC, id DESC` and store/parse ISO-8601 timestamps with fractional seconds (retaining backward compatibility with non-fractional legacy timestamps), ensuring App restarts preserve the exact LIFO ordering.

2. **Unicode East Asian Width Calculation for `Characters` Facet**:
   - Added `CueCharacterFacet.characterWidth(of:)` and `CueCharacterFacet(content:)` in `apps/macos-native/Sources/CueSeekerCore/CueFacetFilter.swift`:
     - Trims leading and trailing whitespace scalars while keeping internal whitespace and punctuation.
     - Counts Unicode Standard Annex #11 `East_Asian_Width` `Wide (W)` and `Fullwidth (F)` scalars (including CJK unified ideographs, Japanese Hiragana/Katakana, Hangul syllables, fullwidth space `U+3000`, and fullwidth punctuation/alphanumerics) as `2`, and all other scalars (`N`, `H`, `Na`, `A`) as `1`.
   - Registered the deterministic SQLite scalar function `cue_character_width(text)` in `SQLiteDatabase.configureConnection` (`apps/macos-native/Sources/CueSeekerCore/SQLiteDatabase.swift`) and updated `CueFacetCountCache.rebuildCharacter` (`apps/macos-native/Sources/CueSeekerCore/CueFacetCountCache.swift`), `SearchDatabase` (`apps/macos-native/Sources/CueSeekerCore/SearchDatabase.swift`), and `ExcerptDatabase` (`apps/macos-native/Sources/CueSeekerCore/ExcerptDatabase.swift`) to share the exact same implementation.
   - Bumped `DatabaseBootstrap.currentSchemaVersion` to `56` in `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift` and added `migrateSchema55To56` to automatically rebuild `cue_facet_counts` for existing databases.

## Verification

- Automated unit & integration tests (`swift test --package-path apps/macos-native`):
  - `TaskRecordDatabaseTests`: `recordsComeBackNewestFirst`, `recordsOrderByLatestStateChangeBeforeID`, `unfinishedTasksFromAPreviousLaunchBecomeIncomplete`
  - `TaskQueueStoreTests`: verified LIFO ordering in runtime and across database relaunch for `Completed` and `Incomplete` tabs while keeping `Current` in FIFO order.
  - `CueFacetFilterTests`: `cueCharacterFacetWidthFollowsTrimmedEastAsianWidthRules`
  - `CueFacetCountCacheTests`: `characterFacetCountsMatchAcrossCountCacheSearchAndExcerptWithEastAsianWidth`
  - `DatabaseBootstrapTests`: `migratesSchema55ByRebuildingCharacterFacetCountsWithEastAsianWidthRule`
  - Outcome matched all requirement expectations.
