# Export to Anki dialog leaves the page unable to take input

Human-owned documents:

- `docs/human/requirements/20260916-Bug-Export To Anki Dialog Leaves Page Unable To Take Input.md`
- `docs/human/design/UI Application Rules.md` (界面层级, 更高层界面的屏蔽)
- `docs/human/requirements/20260911-UI-In-Window Dialogs And Only Confirmation Blocks Closing.md`

## Why

After an Export to Anki dialog closed, by Export or by Cancel, the Search and Excerpt tables still lit rows on hover but no click played one, and the search field took no click either; Library and Recent Videos cards still opened playback. While the dialog was open, the page under it kept its hover and the playback shortcuts still fired.

The dialog layer's open state is a list of the stores' dialog sessions that the coordinator watches (2026-09-11). The Export to Anki dialog (2026-09-12) was added to the window's dialog list but not to that watched list, so the registry never counted it as open: nothing under it was covered, and the page never gave its focus up. Every dialog also reports its size to the registry when it appears, so the main window can keep the keyboard inside it; that size is cleared only when the registry counts the dialog layer as closed. The Anki dialog's size was therefore never cleared, and after it closed the window kept refusing the keyboard to every view outside where the dialog had been. The search field cannot edit without it. SwiftUI buttons, the Library and Recent cards, do not ask for it, so they kept working.

Classified as platform UI. No product semantics change.

## What changed

- The coordinator's dialog-layer observer now includes the Anki export session beside Edit Cover, the Excerpt List Editor, Rename, Filter, the Task panel and Confirmation. Opening the dialog registers the layer, which covers and freezes the page and lets it give its focus up; closing it unregisters the layer, which clears the kept dialog size, so the window hands the keyboard out again.
- A test opens and closes an Anki export session on a coordinator and expects the dialog layer to open and close with it. Without the fix it fails on both open expectations.
- Changelog: the Export to Anki entry gains the fix.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/TaskQueueStoreTests.swift`
- `docs/changelog.md`

## Verification

- `swift test --filter openingTheExportToAnkiDialogOpensTheDialogLayer|openingTheTaskPanelOpensTheDialogLayer`: both pass. With the coordinator change stashed, the new test fails with two issues (`isOpen(.dialog)` and `isCovered(.workbenchPage)` after the session is set); restored, it passes.
- Full `swift test`: 1232 tests, 26 issues in 14 tests: native playback (6), `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, Debug E2E scene and width (2), `libraryFolderRemovalPublishesProgressWithoutBlockingMainActor`, `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt`, `progressiveSearchProjectionRefreshesOnlyMountedTable` and `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`. All of them are in the environment-sensitive set the 2026-09-15 and 2026-09-16 records list for the tree before this change; none opens a dialog. The XCTest suites pass.
- In the App: not driven here. The owner verifies acceptance items 1 to 3 by hand, per the requirement.

## Known limits

- The dialog list still lives in three places: the window's dialog list, the coordinator's watched list, and the size each dialog reports. A dialog added to the first without the second reproduces this class of bug. Folding the watched list into the window's list is a separate change.
