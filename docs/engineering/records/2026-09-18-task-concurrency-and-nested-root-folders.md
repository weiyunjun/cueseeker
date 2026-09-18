# Task concurrency and nested root folders

Human-owned documents:

- `docs/human/requirements/20260918-Feature-Task Concurrency And Nested Root Folders.md`
- `docs/human/design/Data.md`, `docs/human/design/UI Design System.md`

## Why

The first attempt at this area (`ae8c276d`..`9fbeb307`, reset to `23bafb49` by the owner) let Index, root removal and the renames queue behind each other. A queued task held the root list or the paths it was given when it was queued, so an Index queued behind a removal re-indexed the removed root and left data no root owned. A removed Index also kept running through the whole cover stage, the Remove Task dialog showed an empty name with export wording, and adding a parent of an existing root was either refused or duplicated its child's data. The new requirement replaces all of that: library tasks never queue, Add Folder can be undone, and nested roots are handled by their outermost folder.

Classified as product semantics (the queue rules, the root grouping, the Library ownership in the indexing database) with platform UI following them.

## What changed

- **Two categories.** An Anki export is one category and may queue. Index Now, Add Folder, Remove Folder and the two renames are the library category: at most one exists at a time and none queues. `TaskQueueStore` refuses a second library task itself; the File page's disabled controls only show the rule. One export and one library task run side by side.
- **Conflicts both ways.** A rename that starts while an export (running or queued) holds its files goes to Incomplete, as before. An export that starts while a running rename moves its files now goes to Incomplete with `A rename task is moving these files`.
- **Index Now, Add Folder and Remove Folder are tasks.** Index Now indexes the outermost root of every group in group order. Add Folder indexes the new folder and adds it to the root list only when its task completes; a folder a root already holds adds nothing to index and completes at once. Remove Folder keeps its confirmation before the task and removes the root from the list when the task completes.
- **Stopping.** A running Index Now or Add Folder can be removed; Remove Folder and the renames cannot. Every stage now observes cancellation: the scan and the video matcher per file and folder, subtitles and video info per file, and cover generation starts no further cover. Before a folder's subtitles are published a removed task leaves the folder as it was; after that the remaining stages are skipped rather than reported as failures — the cancelled cover stage used to surface as a bogus "cover generation failed" line — and the folder's presentation is still refreshed so the pages show what was published. A removed or failed Add Folder takes back what it indexed; one cut short by quitting is taken back at the next launch, before any page reads the library. Removed tasks record `Cancelled by user`.
- **Add Folder refreshes the pages once the folder joins the list.** The Index publishes and refreshes before the folder is in the root list the Library pages read, so the pages are refreshed again after it joins.
- **Nested roots.** `LibraryRootGroups` groups roots that hold each other and names the outermost as the group's representative; a group stands where its earliest-added root stands. The indexing database keeps a Library only for representatives: binding an outer root folds the Libraries inside it into it, moving file, folder and cover rows without parsing anything again, and `removeIndexedFolder(_:keepingNestedRoots:)` hands the files of the roots that stay back to Libraries of their own before deleting the rest, in one transaction. Removing a root another root still holds only changes the list. The File page's Edit tree orders its roots by group order.
- **Playback stops only for a video that left the library.** Clearing search and playback state under a folder — after an Index or Add Folder publishes, after a rename, after a removal — used to clear the selection and stop playback whenever the selected video sat under that folder. It now does so only when that video is no longer in the library: outside every root, or without an active subtitle match in the database. Changed subtitles or metadata, a removed parent whose kept root holds the video, and a Rename Files of another video in the same folder all leave it playing. Requirement §4.8; `Data.md`, 永久身份与路径分离 7.
- **Cards and dialogs.** Index and Add Folder cards show the folders, the four-stage progress line and bar, and the indexed-subtitle count when finished; Remove Folder shows no progress. Remove Task wording is per type (Index Now, Add Folder with the folder name); Delete Record wording for everything but an export no longer mentions exported files or an empty name.

Files:

- `apps/macos-native/Sources/CueSeekerCore/LibraryRootGroups.swift` (new), `IndexingDatabase.swift`, `TaskRecordDatabase.swift`, `SubtitleIndexer.swift`, `SubtitleFileScanner.swift`, `VideoMatcher.swift`
- `apps/macos-native/Sources/CueSeekerPlayback/PlaybackVideoMetadataIndexer.swift`, `LibraryCoverIndexer.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskQueueStore.swift`, `TaskPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Indexing.swift`, `AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/Indexing/IndexingStore.swift`, `LibraryFolderRemovalExecutor.swift`
- `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/*.lproj/Localizable.strings`

## Verification

- `swift build`: compiles with no warning in a changed file.
- New tests: root grouping and whole-component path comparison; an outer root adopting an indexed inner root with the same subtitle row and then handing it back on removal; the queue running an export beside an Index, refusing every library task while one exists, the rename/export conflict in both directions, which running tasks can be removed, the indexed count reaching the record, and the relaunch handing back unfinished Add Folders; Add Folder joining the list on completion, a held folder completing at once, a removed Add Folder leaving nothing, an interrupted one taken back at launch, Index Now indexing each group once in group order; a running Remove Folder refusing other library tasks and not being removable; removing a held root changing nothing indexed; removing a root keeping the roots it holds; cover generation stopping after a cancel; removing a parent keeping the selection of a video in the root that stays while a video only in the removed part is cleared; an Index that rewrites a video's subtitle keeping it selected and one that removes its subtitle clearing it. The last two fail against the previous clearing rule and pass with the new one.
- Changed tests: the tests that awaited `indexingTask` or `folderRemovalTask` await the queue. `failedFolderIndexRestartsInvalidatedActiveSearch` became `failedFolderAdditionLeavesActiveSearchAlone`, because a failed Add Folder no longer enters the root list and so no longer changes the search scope. `addingEmptyFolderRestartsInvalidatedActiveSearch` starts its search as the index completes, which is now when the scope changes. The single-folder `indexFolder` entry is gone, so the notice and unchanged-index tests use Index Now.
- `swift test`: 1281 tests. The failures are the environment-sensitive set earlier records name — native playback timeline, audio and presentation, the auto-pause boundary, the two Debug E2E scene-geometry cases, the Excerpt remount and the scoped-invalidation wait — none of which touches code changed here. `sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues` failed in one of three full runs and passes alone; it does not touch code changed here. Every suite touched here passes.

## Known limits

- The cards, the progress line and the disabled controls have not been seen in the App; they are left to the owner's acceptance.
