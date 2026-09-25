# Filter Dialog keeps the folder of an unfinished Add Folder

Human-owned documents:

- `docs/human/requirements/20260925-Bug-Filter Dialog Keeps Folder Of Unfinished Add Folder.md`
- `docs/human/requirements/20260918-Feature-Task Concurrency And Nested Root Folders.md` (4. 任务行为 第 2、6 条)
- `docs/human/requirements/20260916-Feature-Filter Dialog Folder Group And Fixed Height.md` (2. Folder 组 第 2 条)

## Why

The Search and Excerpt Filter Dialogs list their options, the Folder group among them, from the counts the database keeps for all indexed content, read into Search once and read again whenever indexed content changes. An unfinished Add Folder is taken back in two places, and neither read them again afterwards:

- **At launch.** Search is set up, and reads the options, before the launch takes back what an Add Folder cut short by quitting had indexed. The database was right (checked read-only on the owner's database: no subtitle, count or root of the test folder was left), but the dialog kept the options read before the take-back until the next Index finished.
- **In the same run.** An Add Folder removed or failed after its subtitles were published reads the options again when its run ends, with its folders in them, and only then is taken back.

The File page and the Library read the root list, which the folder never joined, so only the dialogs showed it.

## What changed

- The launch take-back reads the options again once it is done. It still runs while the App is being set up, before any page is shown.
- An Add Folder that does not finish reads the options again after it has taken back what it indexed.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`
- Tests: `LibraryFolderAdditionTests`

## Verification

- `anUnfinishedFolderAdditionIsTakenBackAtLaunch` now also expects the dialogs to list only the kept root's folder. Before the change they listed the taken-back folder as well and the test failed.
- `aFolderAdditionRemovedAfterPublishingLeavesNoFolderInTheFilter` cancels an Add Folder as it enters Reading video info, after its subtitles are published, and expects no subtitle and no listed folder left. Before the change the dialogs listed both of its folders and the test failed.
- `swift test` (full, parallel): 1280 tests, 13 failing, none from this change: the same environment-sensitive set as the cover generation record of the same day (the eight native playback tests including `playbackPlayerKeepsAutoPauseBoundaryAcrossUserSeeks`, the two Debug E2E scene and width tests, `progressiveSearchProjectionRefreshesOnlyMountedTable`, `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt`); all eight `LibraryFolderAdditionTests` pass.
- In-App: acceptance items 1 and 2 are the owner's.

## Known limits

- In the same run, the pages an unfinished Add Folder refreshed when its subtitles were published are not refreshed again after the take-back. The pages that read the root list never showed the folder; an Excerpt that the publishing had matched to the folder's subtitles again would keep showing as available until the Excerpt page reloads. The requirement covers only the Filter Dialog; not changed here.
