# File Edit tab and in-App rename

Human-owned documents:

- `docs/human/requirements/20260908-Feature-File Edit Tab And In-App Rename.md`
- `docs/human/design/Data.md` (Index flow, permanent identity)
- `docs/human/design/UI Design System.md` (Tabs, Context Menu, Dialog, Library File Tree Layout, File Page Layout, Task Card Layout)
- `docs/human/design/UI Application Rules.md` (menu modality, hover)

## Why

The index knows a file by its absolute path. Rename a folder in the Finder and
the next Index sees the old path vanish and a new one appear: new VideoIDs and
SubtitleIDs, watch state and progress reset, every Shiori on those cues turned
into a tombstone. The requirement adds a rename that the App performs itself,
so it can move the stored paths under the existing IDs and keep all of that.

The File page grows an Edit tab beside the existing Index tab. Edit lists
every indexed folder at its full path — which also removes the blank label a
root that holds pairs of its own used to get — and offers two context menu
actions: Rename Folder, and Rename Files for a video together with the
subtitles paired to it. Both run as tasks in the existing queue, in two
stages: a read-only conflict check, then the disk renames and one database
transaction that either both happen or neither does.

## What changed

### Core: the rename

`LibraryRename.swift` holds the request, the name rules the dialog applies, the
shared-base-name rules for a file group, and the `LibraryRenamer` that runs
the two stages. `IndexingDatabase+Rename.swift` is the database side: the
reads the conflict check needs, and the transaction that moves every stored
path and rebuilds the derived Search order and Library rows of the affected
folders.

The conflict check refuses, without changing anything, when: a file involved
is missing or its size or modification time differs from the index; the
folder's pairs on disk are not the pairs the database holds (an unindexed
pair, an edited file); the new name exists on disk or in the database; or, for
a file group, pairing the folder again with the new names would not give the
same pairs with only this group renamed — which is how a name that would adopt
an orphan subtitle is caught. Pairing is re-run through the real matcher: it
gained `matchingVideoNames(subtitleFileNames:among:)`, the same rules over a
list of names instead of a directory, so the check never has to restate them.

A destination that exists but is the source itself — what a case-insensitive
or normalization-insensitive volume answers for a case-only rename — is not a
conflict. Verified on this machine's APFS volume: the case-only rename goes
through and the listing shows the new case.

Execution renames on disk in order; a failure midway renames the finished
files back. The database update runs in one immediate transaction; if it
fails, every file is renamed back. `LibraryDatabase` gained an internal
initializer over a shared connection so the Library presentation rows are
rebuilt inside that same transaction rather than in a second one.

The index stores roots as given and files as the directory enumerator reports
them, and for `/var` those differ (`/private/var`). The rename compares and
rewrites paths through the same variant rule the folder-scoped queries already
use, so each row keeps the form it had. This only shows up under temporary
directories, which is where the tests live.

Files: `CueSeekerCore/LibraryRename.swift` (new),
`CueSeekerCore/IndexingDatabase+Rename.swift` (new),
`CueSeekerCore/IndexingDatabase.swift` (nine helpers opened from private to
internal), `CueSeekerCore/LibraryDatabase.swift`,
`CueSeekerCore/LibraryDatabase+Presentation.swift`,
`CueSeekerCore/VideoMatcher.swift`, `CueSeekerCore/SubtitleIndexer.swift`
(public initializer on the result).

### Core: task records

Two task kinds, `rename_folder` and `rename_files`, and two columns on
`task_records` — `old_paths` and `new_paths`, one path per line — so a rename's
history can name what it moved. Schema 46; the migration adds the columns only
when they are missing, the way 44 to 45 created its table only when missing,
because the migration tests re-run the chain over an already current file.

Files: `CueSeekerCore/DatabaseBootstrap.swift`,
`CueSeekerCore/TaskRecordDatabase.swift`.

### App: the File page

The page hosts the card context menu and shows `Index` / `Edit` Tabs under the
title, flush with the content. Index is the previous page unchanged. Edit is
the Library File tree in a new scope: every folder at its full path, no root
level, folders and objects collapsed by default, folder rows hoverable, and
the two context menus. The Tab choice lives on the route state beside the
Recent tab's, kept while the App runs.

Files: `Library/WorkbenchFileView.swift`, `Library/LibraryFileTree.swift`,
`App/WorkbenchLayoutState.swift`, `Search/SearchView.swift`.

### App: the dialog

`LibraryRenameSession` is presented by the window like the other dialog
sessions. The dialog is the Shiori List Editor's form column and footer with
no cover column: the current name as a line of text — the full path for a
folder, the shared base name for a group — then the New Name field, then
Cancel and Rename. The form column width became a token both dialogs read.
Name rules are applied on Rename and, from then on, on every keystroke.

Files: `Library/LibraryRenameDialog.swift` (new), `Library/LibraryStore.swift`,
`Workbench/ContentView.swift`, `Shared/WorkbenchControls/WorkbenchControls.swift`,
`Shiori/ShioriListEditor.swift`.

### App: the queue

The queue holds a rename as work like an export. The coordinator supplies the
runner, because it has to know what is playing and to refresh the pages
afterwards: it refuses when the video is the one playing, runs the two stages
off the main actor, then follows a renamed root in the root list and applies
the same refresh an Index of those folders applies. The queue itself refuses a
rename when an export waiting behind it holds the same files, and does not let
a running rename be removed. Cards show the old and new names or paths, the
stage and its half of the bar while running, and the error in Incomplete.

Files: `Tasks/TaskQueueStore.swift`, `Tasks/TaskPanel.swift`,
`App/AppCoordinator+LibraryRename.swift` (new), `App/AppCoordinator.swift`,
`App/AppCoordinator+Indexing.swift` (one method opened), `Indexing/IndexingStore.swift`.

### Strings

Nineteen keys in the three languages, as the requirement lists them.

## Verification

- `swift build` — clean.
- `swift test` — 1163 tests. The suites this change touches pass:
  `LibraryRenameTests` (12, new), `VideoMatcherTests`, `TaskRecordDatabaseTests`,
  `TaskQueueStoreTests` (4 new), `DatabaseBootstrapTests`, `CueFacetCountCacheTests`,
  `AppLocalizationTests`. The failures in the full run are the repository's
  environment-dependent set — native playback under load, the E2E scene tests
  that read the real screen, and two Shiori remount tests. This was confirmed
  rather than assumed: the two App suites were run at `ad4b01c` from a
  `git archive` export, and they fail the same tests there. The playback suites
  pass in isolation. One extra `ContentView.body` count that appeared once in
  the refresh-scope suite passes on two isolated reruns; it moves between tests
  with ordering and is not tied to this change.
- The new tests cover: folder rename keeping IDs and rewriting every stored
  path column and the derived rows; a root rename moving the library row; a
  group rename moving both files and shifting a sibling's Display Title;
  conflicts for an edited file, an added pair, an existing name, and a name
  that would adopt an orphan subtitle; disk failure midway restoring the
  finished files; database failure restoring everything; the case-only
  rename; the name rules; the shared-base-name rules; path-form rewriting;
  the queue refusing a rename behind an export of its files; a running rename
  not being removable; task records keeping their paths.
- `plutil -lint` on the three `Localizable.strings` files; the three languages
  carry identical key sets and the new keys are present.

Debug in-app E2E against the running App and the reader's own library, main
window `1445 × 821`, with the existing `click`, `rightClick`, `keyPress` and
`capture` commands. No E2E facility was added.

- **Tabs.** File opens on Index with the previous content. Edit shows every
  folder at its full path, collapsed; the folder under the pointer takes the
  row hover. Leaving to Library and returning lands on Edit again, with the
  tree back at its default.
- **Menus.** Right-click on a folder row opens a menu with Rename Folder; on a
  video row, Rename Files.
- **Dialog.** Rename Folder shows the full path, the New Name field prefilled
  with the folder name and focused, Cancel and Rename. Rename with the name
  unchanged shows `The name is unchanged` in the danger colour with the field
  outlined and the dialog held open; typing clears it; Escape closes it. Rename
  Files shows the shared base name with the format and language extensions
  removed. Return in the field does not press Rename, the same as the Shiori
  List Editor.
- **Queue.** After the cancelled dialogs the Task panel shows no task.

The on-disk rename itself was not run from the E2E session. The App has no
database or defaults override, so the only library the running App can rename
is the reader's own, and the requirement's acceptance steps 5 to 10 — the
rename going through, the pages updating, the next Index reporting nothing
changed, the conflict cases and the task cards — remain the reader's manual
acceptance on a folder they choose. The same paths are exercised end to end by
`LibraryRenameTests` against a real indexed temporary library, and the task
cards by `TaskQueueStoreTests`. Languages and Dark appearance were verified as
string data and tokens, not on screen, the known gap of earlier records.

Outcome matched expectations for everything verified.

## Follow-up: dialog width, Current Name label, task card lines

Requirement update: `63cb603`, which adds the Current Name label and the
single-column width rule to section 5.1 and the label's three strings to
section 7. Three defects the reader found on the first manual pass.

### Why

- **Width.** The rename dialog fixed only its form column at 340 and left its
  own width to the sheet, which came out about 80 points wider; the field sat
  on the left and the buttons on the right. The Shiori List Editor and the
  Edit Cover dialog do not have this problem because each fixes the whole
  dialog's width.
- **Label.** The current name had no label above it: the requirement said
  "static text" and listed no string for one.
- **Card lines.** The Rename Folder card numbered the old-name list and the
  new-name list separately before joining them, so both rows carried id 0.
  SwiftUI renders a duplicate id as the first row again, which is why the
  card showed the old name twice while the task record held the right pair
  (checked read-only in the reader's database: `非自然死亡测试2233` to
  `一个测试文件啊`). The Rename Files card numbered its four lines in one
  pass and was correct.

### What changed

- `Library/LibraryRenameDialog.swift`: the dialog's width is the form region
  width plus twice the dialog inset, both existing tokens, so the field's
  right edge is the last button's right edge; the inner form frame is gone.
  The current name sits under a `Current Name` label at `spacing-1`.
- `Shared/WorkbenchControls/WorkbenchFormControls.swift`: the form label is
  now `WorkbenchFormLabel`, used by the field container and the rename dialog,
  so the label's tokens exist once.
- `Tasks/TaskPanel.swift`: one numbering over old lines then new lines for
  both rename kinds; the folder kind maps each path to its last component.
- `Resources/*/Localizable.strings`: `rename.current_name` in the three
  languages as the requirement lists them.

### Verification

- `swift build` — clean.
- `swift test --filter "AppLocalizationTests|TaskQueueStoreTests"` — 22 tests
  (4 and 18), all passed.
- `plutil -lint` on the three strings files; identical key sets; the new key
  present in each.
- Debug in-app E2E against the running App and the reader's own library, main
  window `1445 × 821`, with `click`, `rightClick`, `keyPress`, `scroll` and
  `capture`. No E2E facility was added.
  - **Rename Folder dialog.** The scene reports the sheet at width `388`.
    The capture shows `Current Name` above the full path, `New Name` above
    the field, and the field's right edge on the Rename button's right edge.
  - **Rename Files dialog.** Same layout; the shared base name wraps inside
    the column under its label.
  - **Task panel, Completed.** The Rename Folder card for the 07:02 task
    shows `一个测试文件啊` then `非自然死亡真的好垃圾`; the Rename Files
    card shows its two old paths then its two new paths. The Completed tab
    was clicked at a coordinate read from the Current capture, because the
    tab bar is centred in the header and the tab widths are not documented.
- Both dialogs were dismissed with Escape; no rename was queued.
