# Shiori becomes Excerpt and navigation shows the boundary

Human-owned documents:

- `docs/human/requirements/20260913-Feature-Shiori Becomes Excerpt And Navigation Shows Boundary.md`
- `docs/human/design/Data.md`, `docs/human/design/UI Design System.md`, `docs/human/design/UI Application Rules.md`, `docs/human/design/Icon Registry.md`, `docs/human/design/Toast Usage Registry.md`, `docs/human/design/Command Panel.md` and `docs/human/design/Cue Parsing.md` (to be updated by the owner after acceptance)

## Why

The owner renamed Shiori to Excerpt (摘录) and Shiori List to Excerpt List (摘录集), so the concept has one name in the interface, the code and the database. The same requirement asks English counts to take the singular for exactly one, and previous/next to say that the list has ended instead of "No Result", "No Library Video" and "No Bookmark".

The work lands in steps that each stay reviewable: the database tables, then the copy and the feedback, then the naming in code.

Classified as product semantics for the table names, which live in `CueSeekerCore`, and platform UI for the copy and the feedback.

## Database: schema 47

- A fresh database creates `excerpt_lists` and `excerpts`, with the indexes `idx_excerpt_lists_normalized_name`, `idx_excerpts_list_order`, `idx_excerpts_cue` and `idx_excerpts_created_order`.
- `migrateSchema46To47` drops the two Cue reference triggers, renames both tables, replaces the four indexes and recreates the triggers against `excerpts`. Rows, ids and stored cover paths are untouched. The triggers go first because a table rename re-reads every trigger that names it.
- The triggers' SQL now takes the table name. The 41 to 42 migration still creates them against `shioris`: every migration before 47 runs on a database whose table has the old name, which is also why the older migrations keep the old names.
- `ShioriDatabase` and the one query in `IndexingDatabase` that joins the table read and write the new names. The Swift type and member names wait for the naming step.

Tests:

- `migratesSchema46ByRenamingShioriTablesToExcerptTables` turns a fresh database back into a 46 one with a list, an excerpt and the old triggers, migrates it, and checks that the old tables and indexes are gone, the new ones exist, `excerpts` refers to `excerpt_lists`, the list keeps its description and cover path, the excerpt keeps its list, cue and date, and both triggers now name `excerpts`.
- `preSchema47ExcerptTablesSQL` in `DatabaseTestSupport` performs that turning back. The 41 migration test and the 39 facet count test start from it, because both begin an older migration from the current schema; the facet count test failed with `no such table: shioris` until it did.
- The 36, 37 and 38 fixtures had a two-column `shioris`, and the 38 fixture had no list table. A real database at those versions has `list_id` and `created_at` (since 35) and the list table (since before 33); the fixtures now say so, since the 47 step indexes those columns.
- Assertions on a fresh or migrated schema use the new names. Fixtures that describe an old database keep the old ones.

Files:

- `apps/macos-native/Sources/CueSeekerCore/DatabaseBootstrap.swift`
- `apps/macos-native/Sources/CueSeekerCore/ShioriDatabase.swift`
- `apps/macos-native/Sources/CueSeekerCore/IndexingDatabase.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/DatabaseBootstrapTests.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/DatabaseTestSupport.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/CueFacetCountCacheTests.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/ShioriDatabaseTests.swift`
- `apps/macos-native/Tests/CueSeekerCoreTests/SubtitleIndexerTests.swift`

## Copy, counts and boundary feedback

- The three `Localizable.strings` files carry the requirement's copy word for word: Excerpt / 摘录 / 摘錄 for the page and the playback source, Recent Excerpt Lists, Save to Excerpt List without an ellipsis in the row menu, the footer and Settings, Remove Excerpt, 摘录集 / 摘錄集 wherever Chinese said 列表 for a list, and the failure toasts with their full stop. Keys stay as they were apart from the ones below; renaming them belongs to the naming step.
- English counts that need a singular are split into `.one` and `.other` keys, the form the table result count already used: the footer's cues, videos, results and excerpt lists, the card's cue badge and the Excerpt page summary. The summary became a `%1$@ · %2$@` format over two counts so each count is chosen on its own. Chinese carries both keys with the same text.
- `PlaybackCueFooterStatus` chooses the key through one private helper. The Command Panel's Recent Videos and Recent Excerpt Lists footers now go through it instead of formatting their own count.
- Previous and next: when nothing further can be opened, the feedback reads Already at First or Last Result, Video or Excerpt by the direction pressed, in place of No Result, No Library Video and No Bookmark. The three feedback functions already received the direction. Every path that used to report "no result" — the real boundary, a single cue opened from a Deep Link, an empty or failed search snapshot, a playlist out of step — now shows the boundary for its direction, as the requirement asks. Excerpt navigation's own success text changes from Bookmark to Excerpt; the video and result success texts are unchanged.
- Tests: the footer test adds the singular cases and the excerpt list count, and the row menu and toast registry tests expect the new copy. The toast registry test now pins the copy that `Toast Usage Registry.md` will carry once the owner updates it.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueFooter.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCommandPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListCardGrid.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListOverviewView.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusLayoutTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTableRowActionMenuTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTableVirtualRowTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/ToastTests.swift`

## Verification

- `swift build`: clean.
- `swift test` on the working tree, with the copy and feedback step below also applied: 1208 tests, 15 failing. Thirteen are the set earlier records list as failing on the baseline as well — the seven native playback timeline, audio and presentation cases, the two Debug E2E scene and window-width cases, `shioriTableStartsAtTopAfterPanelRemount` and `showCueGroupInvalidationIsScopedToMountedShiori`, and the two library-folder-removal cases, which both pass when run on their own. `showCueGroupInvalidationIsScopedToMountedShiori` was checked rather than assumed: with this change stashed it fails at the same line on `656ec7c9`. The other two were copy assertions, updated in the next step.
- The database step's own tests — migration, fresh schema, the Excerpt database, the indexer and the facet count cache — pass.
- Before the App first opened the owner's real database, it was copied next to the live file as `CueSeeker.sqlite.backup-20260913-before-schema-47-excerpt-rename`: schema 46, 8 lists, 700 excerpts.
- After the copy step, `swift test --filter` over the toast registry, the row menu, the footer counts and the localization key set passes, and a key-by-key comparison of the three string files finds the same 432 keys in the same order.

In the App: Debug E2E controller, `.build/debug/CueSeeker --cueseeker-debug-e2e` under a PTY, main window 1445×821 at 2×, Light, English, the owner's real library. No E2E command or facility was added; the FIFO that fed the PTY is a session-local convenience equivalent to typing at the terminal. Card and row coordinates were read off captures, the deviation earlier records already note for the grids and tables.

1. The first launch migrated the real database: schema 47, `excerpt_lists` with 8 rows and 6 cover paths, `excerpts` with 700 rows, the four new indexes, no Shiori table or index left, and both Cue reference triggers naming `excerpts`.
2. The Excerpt page: Sidebar item and title `Excerpt`, summary `8 Lists · 695 Cues`, each card's badge in the form `397 Cues`, covers drawn.
3. Recent: tabs `Recent Videos` and `Recent Excerpt Lists`.
4. The first list's row menu: `Play`, `Open Subtitle Folder`, the four copy items, `Move to ...`, `Duplicate to ...` and `Remove Excerpt`.
5. Its first row played. That cue lasts two seconds, so auto switch had already moved on with `Next Excerpt` before the first key arrived. From the third excerpt, `A` twice showed `Previous Excerpt` and reached the first, and `A` once more showed `Already at First Excerpt` over the same cue.
6. The Playback Overlay's Playlist footer: `396 cues` and `Save to Excerpt List` with its `S` keycap.
7. The first Recent Videos card, *It's MyGO!!!!!* EP01: `A` showed `Already at First Video`.
8. The Command Panel searched `ok`: footer `170 results (Showing first 50 results)` beside `Save to Excerpt List`. Enter played the first result and `A` showed `Already at First Result`.

Not verified in the App: the Last variants, which are the other branch of the same expression; the Chinese copy, since the language setting is outside the captured scene, as earlier records note; the singular counts, which no list at hand has, and which the footer test covers; the toasts, which are reached through the destination submenu the controller cannot open, as the toast record notes; and a Deep Link's single cue. The run played several cues and videos, which updated their recent-playback times and resume positions; nothing was saved, moved or removed.

## Outcome

The database and the copy steps matched expectations. The naming step in code is held for the owner: renaming what is persisted by name would also reset a rebound Save to Excerpt List shortcut and a remembered Excerpt page selection, and would stop old covers from being removed when they are replaced, none of which the requirement lists.

The owner then updated requirement 2.5 (`582dc5bb`): existing covers are copied into the new cover folder and the lists use the new location, the old folder stays for the owner to delete, and the rebound shortcut and the remembered Sidebar page join the preferences that reset once.

## Naming in code

A mechanical rename, kept apart from any change in behaviour:

- Every `Shiori` and `shiori` in the macOS sources, tests and string tables became `Excerpt` and `excerpt`: types, members, the `Excerpt` source folder and the sixteen files named after it, localization keys and their comments, log and probe names such as `UI.ExcerptPresentation.rebuilt` and `table.excerpt.*`, the table name `excerpt`, and the toast scenario IDs `excerpt.*`.
- Names that are stored therefore change and reset once, as 2.5 now lists: the preference keys `excerptFacetExclusionsByListID` and `recentExcerptSaveListID`, the shortcut action `saveToExcerpt` inside the stored overrides, and the panel mode `excerpt` behind the remembered Sidebar page.
- Kept on purpose: every table, index, column and data value in the migrations before 47 and in the fixtures that stand for an old database, the comments that explain them, and the cover folder literal `Shiori` with the one test that checks it, which the cover step below changes.
- The first pass ran the replacement over the three bootstrap files as well, despite the exclusion meant to skip them, and turned the pre-47 migrations' table names into the new ones. It still built. The damage was caught by counting the old table names left in those files, which had dropped to zero; the three files were restored from `582dc5bb` and only their Swift names renamed.
- Documents: the `table.excerpt.*` counter family and the footer's `Save to Excerpt List S` in `08_end_to_end_testing.md`, and `ExcerptStore` in `04_architecture_rules.md`. The narrative uses of Shiori in product documents, records and proposals describe history and stay as written.

Verification:

- `swift build`: clean.
- `swift test`: 1208 tests, 15 failing. Thirteen are the baseline set — the seven native playback cases, the two Debug E2E cases, the four refresh-scope integration cases now named `excerptTableStartsAtTopAfterPanelRemount`, `showCueGroupInvalidationIsScopedToMountedExcerpt`, `progressiveSearchProjectionRefreshesOnlyMountedTable` and `searchFacetSelectionDoesNotRefreshGlobalOrInactiveSurfaces` — and `libraryFolderRemovalAndIndexingRejectEachOther`; the last three of those pass when run on their own.
- `playbackExcerptCopiesSettledPrimaryCueAsMarkdownLink` fails on its own too, and not because of the rename: it builds its App on the shared preferences, whose App language was set to Simplified Chinese at 20:34 today outside this work, so the feedback it reads is 已复制 Deep Link. The same test passed in the earlier full run. The preference was left as it is.
