# Library Video / File segments and Data page removal

Human-owned documents:

- `docs/human/requirements/20260901-UI-Library Video File Segments And Data Page Removal.md`

## Why

The file view of the library lived on its own page. Data was always a transitional
interface: it showed the indexed content as a tree, but it sat next to Library in
the sidebar as if it were a second library rather than a second way of reading the
same one. The requirement folds it in: the library's two interfaces each carry a
Video / File segment, Video keeps the card grids, File shows the tree, and the Data
page is gone.

The tree needed no new grouping to move. The Data page's Object Folder level was
already built from the library's own folder grouping — the same folder path the
folder cards group by — so a folder detail can show its own subtree without asking
the database a second question.

## What changed

### One Tabs implementation

Current / Playlist in the Playback Overlay and the Task panel's three tabs were two
copies of the same twenty lines, and the Library's two new segments would have made
four. They are now one component: label over a selection indicator, with the same
colours and metrics as before. The Library's segment asks it to pull the first
label flush with the page content, since it is left-aligned under the summary row
rather than centred in a bar.

Files: `Shared/WorkbenchTabs.swift` (new),
`Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`, `Tasks/TaskPanel.swift`.

### One file tree, two scopes

The tree moved out of the Data page into a component with two scopes: every root
path for the library overview, and one folder for a folder detail. The rows, the
indent, the icons, the object divider and the hover rules are the ones the Data
page had.

Disclosure state is expressed as the rows the reader flipped away from their
default, not as the set of expanded rows. That is what lets the same rows carry
different defaults in the two scopes — roots open and folders closed in the
overview, the folder itself open in a detail — without seeding any state when the
tree arrives.

Files: `Library/LibraryFileTree.swift` (new).

### When the tree is read

The tree is read only while the File segment is on screen: the hydration call
lives inside the File branch, so a reader who stays on Video never pays for a
full-library read. It is stamped with the folder-card revision it was read at, so
a library change makes the next File view re-read it, and a change that lands
mid-read is picked up when that read finishes. A folder detail filters the same
tree by folder path instead of reading anything.

The segment and the tree's disclosure state are page state: entering a folder
detail and returning both start again on Video, and leaving the Library page
resets them.

Files: `Library/LibraryStore.swift`, `App/AppCoordinator+Data.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`,
`CueSeekerCore/IndexedContentDatabaseModels.swift`,
`CueSeekerCore/IndexedContentDatabase.swift`.

### Data page removed

The panel mode, the sidebar entry and the page's place in the workbench switch are
gone, along with the `data.*` strings; the tree strings came back as
`library.file.*` and the two segment labels are new. A saved panel mode of `data`
no longer resolves and falls back to Search, so no migration was needed. The
indexed-content query stays where it was — it is what the File segment reads.

`Data/DataView.swift` became unreferenced and the owner removed it, along with the
`Data` directory.

Files: `App/WorkbenchLayoutState.swift`, `Workbench/ContentView.swift`,
`Search/SearchView.swift`, `App/AppCoordinator+Playback.swift`,
`Resources/*/Localizable.strings`, `Tests/CueSeekerAppTests/WorkbenchLayoutStateTests.swift`.

## Verification

- `swift build` — clean.
- `swift test` — 1125 tests. The failures are the pre-existing environment- and
  timing-dependent set this repository already carries: native playback media and
  presentation transitions, the window-scene geometry checks, the user-defaults
  migration assertion and the refresh-scope integration waits. The suites closest
  to the change — workbench layout state, indexed content database, library
  database, library route snapshot reuse, library folder removal, playback library
  overlay — were run alone: 51 tests, all pass.

Debug in-app E2E against the running App, main window `1445 × 821`, using the
existing `click`, `keyPress` and `capture` commands. No E2E command or test
facility was added.

- **Library overview.** Video / File sits left-aligned under the summary row, with
  the summary and Add Folder unchanged, and Video selected. File shows the root
  path expanded and its folders collapsed, exactly as the Data page did; expanding
  a folder lists its objects with the object divider and row hover in place.
- **Folder detail.** Entering a folder starts on Video with the cover summary and
  the episode grid unchanged. File shows only that folder's own row, expanded,
  with its objects collapsed and no root path row above it; expanding an object
  shows its video and subtitle rows.
- **Navigation.** Returning to the overview from a detail shows Video again.
- **Sidebar.** Data is gone; Search, Recent, Library, Shiori and Settings remain.
- **Dark.** The segment and the tree were checked in Dark and returned to Light.

The lazy read was not measured at runtime; it is structural — the hydration call
exists only inside the File branch of the page.

Outcome matched expectations.
