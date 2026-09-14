# Search Filter-First Execution — Step 8: No Projection After A Search With Two Or More Checked Cards

## Human-Owned Source

- `docs/human/requirements/20260914-Feature-Search Filter-First Execution And Ordered First Page.md` (sections 4.1, 4.3, 4.4)

## Starting Point (commit `4d9e0df9`, after Step 7 and the Search ordering rule in the design document)

The owner found a defect in Step 7 by reading the code: the count scans negate one card at a time, so after a search with two checked cards (say `English` and `31+`) the three scans read `English ∧ 31+`, `31+ ∧ ¬English` and `English ∧ ¬31+`, never the rows that are neither English nor 31+. The Store nevertheless marked the snapshot complete once the last scan landed and answered later selection changes from it. The counts for the two-card selection itself were right, because each card only needs the rows that satisfy the other card; the wrong numbers appeared one change later.

Reproduced in the App before the fix (`step8-before-*.png`): search `の` with `English` and `31+` checked (22 results, counts right), uncheck `English` → 2,766 rows, correct, but the Character card shows 431 / 378 / 107 for `1–10` / `11–20` / `21–30` instead of 15,669 / 39,980 / 18,730, because only English rows had been read; uncheck `31+` → 3,682 results instead of 77,145 (the 938 English rows plus the 2,766 long rows minus the 22 in both), with `Japanese 3471`.

Step 7's record also overstated its own test: the two-card assertion compared the joined rows with the unfiltered order restricted to those rows, not with every match. That sentence is corrected in the Step 7 record.

## Implementation

- The Store remembers, when a snapshot is built, whether the search that produced it can end with every match: an unfiltered search, or one with a single checked card. That flag is fixed at that moment and kept across projections, so a complete snapshot from a single-card search keeps answering selection changes even after it has been projected to two or more cards, while a snapshot from a two-card search is never treated as complete and every later change goes through the section 4.3 search. Nothing in the scans changes.
- The owner's alternative (an extra scan for the rows failing two or more cards) was not taken: it would add a scan and a more involved negation for a case whose fallback already exists.

## Verification

- New store test: a two-card search whose two count scans have landed keeps `isSearchFacetSnapshotComplete` false, refuses the projection and drops the snapshot on the next selection change, while its own counts are right. The existing projection test now also projects the single-card snapshot to a two-card selection and back, which stays a projection. The real-database test runs a two-card search after the projections and checks the projection is refused. The database test's two-card assertion now states what it checks: five of the eight matches are read, the three failing both cards are not, and sorting orders only the rows that were read.
- `swift test --filter "SearchDatabaseTests|SearchStoreTests|CueFacetCountCacheTests"`: 79 tests pass. Full `swift test`: 1231 tests, 29 issues in 16 tests; 14 are the pre-existing environment-sensitive set, one (`libraryFolderRemovalAndIndexingRejectEachOther`) failed the same way after Steps 3 and 4, and one (`sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`) read the live shared defaults that the E2E App had just written (`workbenchPanelMode` = `search`); both pass when run alone.
- App level after the fix, same flow (`step8-after-*.png`, JSONL): with `English` and `31+` checked, `の` completes in 673 / 557 ms with 22 results and its counts in 1976 / 1272 ms; unchecking `English` now runs a search (first page 99 / 66 ms, complete 748 / 606 ms, 2,766 results, counts 3128 / 2158 ms) and the Character card shows 15,669 / 39,980 / 18,730 / 2,766; unchecking `31+` is then a projection again (rows on screen 102 / 3 ms) because that search ran with a single card, and shows 77,145 with the unfiltered counts. The selection was left empty.

## Outcome

Requirement 4.4 now holds only where the data supports it: after an unfiltered or single-card search a selection change is answered from memory; after a search with two or more checked cards it searches again, which is section 4.3's path and gives the right rows and counts.

Superseded by Step 9 (2026-09-15): the owner rejected the restriction, since section 4.4 is unconditional. The count pass now reads every match outside the selection in one scan, the snapshot is complete after any search, and the flag added here is removed.
