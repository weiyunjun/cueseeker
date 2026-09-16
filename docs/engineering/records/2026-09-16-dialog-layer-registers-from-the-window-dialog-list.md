# Dialog layer registers from the window dialog list

Human-owned documents:

- `docs/human/requirements/20260916-Engineering-Dialog Layer Registers From The Window Dialog List.md`
- `docs/human/design/UI Application Rules.md` (界面层级, 更高层界面的屏蔽)
- `docs/human/requirements/20260911-UI-In-Window Dialogs And Only Confirmation Blocks Closing.md`
- `docs/human/requirements/20260916-Bug-Export To Anki Dialog Leaves Page Unable To Take Input.md`

## Why

Which dialogs count as the dialog layer was written twice: the window's list of dialogs to draw, and a Combine chain in the coordinator that watched the same stores and told the registry. A dialog added to the first without the second compiled and drew, and failed only in coverage and focus, which is how the Export to Anki dialog left the page unable to take input. The owner asked for one list: the layer is open while the window has a dialog to draw, and closed once it has none.

Classified as platform UI. No product semantics change; no dialog looks or behaves differently.

## What changed

- The dialog layer view registers the layer itself, the way the Search view registers the playback page: on appearing and whenever its dialog list goes between empty and non-empty, it tells the registry the dialog layer is open or closed. A dialog added to the window's list needs nothing else.
- The page giving its focus up as a dialog opens moved from the coordinator's chain into the registry, on the dialog layer opening: the next turn, and only while the page still holds the focus, so a dialog that focuses its own field on appearing keeps it. It runs after the store keeps the open state, as the 2026-09-15 fix required, because the layer reports from the view update that draws the dialog in.
- The coordinator's chain over the seven dialog sessions and its focus-owner helper are gone. What stays of its observer is the Confirmation rule for the window's close button.
- Tests: the two coordinator tests that opened the Task panel and the Anki session on a coordinator are replaced by one that hosts the dialog layer with a registry and drives its list: empty is closed; one dialog opens the layer and covers the page; a second dialog stacked on it keeps it open; empty again closes it and clears the kept dialog size. Without the layer's registration the test fails on all four expectations.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchDialogLayer.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/InterfaceLayerRegistry.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchDialogLayerTests.swift` (new)
- `apps/macos-native/Tests/CueSeekerAppTests/TaskQueueStoreTests.swift`

No changelog entry: an internal refactor with no behavior change.

## Verification

- `swift test --filter` over the new test, `InterfaceLayerFreezeTests` and `TaskQueueStoreTests`: 25 tests pass. With the dialog layer change stashed, the new test fails with four issues; restored, it passes.
- Full `swift test`: 1231 tests, 28 issues in 14 tests: native playback (6), `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, Debug E2E scene and width (2), `libraryFolderRemovalAndIndexingRejectEachOther`, `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt`, `progressiveSearchProjectionRefreshesOnlyMountedTable` and `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces`. The last of these and the Library folder removal test are not in the run before this change but are in the environment-sensitive set of the records since August, and both pass when run alone; the rest are the set the 2026-09-16 records list. None opens a dialog. The XCTest suites pass.
- In the App: not driven here. The owner verifies acceptance items 1 and 2 by hand, per the requirement.

## Known limits

- The layer reports from the SwiftUI update that draws a dialog in or out, so the registry follows the store by one view update rather than at once, as the Combine chain did. Nothing reads the registry between the two.
