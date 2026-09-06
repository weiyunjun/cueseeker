# Save to Shiori asks where, and remembers the answer

Human-owned documents:

- `docs/human/requirements/20260906-Feature-Save To Shiori Destination Menu And Recent List.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/UI Application Rules.md`

## Why

`Save to Shiori` on the playback footer wrote straight into whichever list was
created first. With several lists that is a guess, and the only way to correct
it was to open the Shiori list afterwards and move the row. The footer now asks
the same question the Workbench row menu already asks — which list — and the
answer is remembered, so the common case is one key and one Return.

## What changed

**The footer's key and button open a menu instead of writing.** `S` and a click
on `Save to Shiori` both go through the one request path they already shared;
that path now opens the destination menu hung off the button, or closes it when
it is already up. Nothing is written until a list is chosen.

**The menu is the one the table already uses.** `ShioriDestinationMenu` is the
list-plus-divider-plus-`New List` surface, and the table row menu's submenu is
now a thin wrapper around it, so the two cannot drift apart. Placement, the
input barrier, the highlight, the height cap and the scrollbar are the shared
menu machinery; the only new thing the gate learns is the menu's name, which is
what its scroll table is keyed on.

**One writer for all three surfaces, two containers.** The playback page and the
Command Panel used to save through an actor with its own Shiori connection; the
Workbench saved on the main actor. All three now call the Workbench's saver, and
the actor's write path and its second connection are gone. What differs is only
where the result is said: the Workbench keeps the Toast, and the playback
surfaces use the playback feedback, which is the only thing visible over the
video. The sentence is the same either way — the saver hands the same registry
message to whichever container the caller names.

**Every outcome names the list.** Two registry sentences had no room for a name;
they have one now, and because the unavailable case is shared with `Move to ...`
and `Duplicate to ...`, those two flows pass a name as well. A list that is gone
by the time the save runs can only be named by what the menu displayed, so the
saver takes that name and falls back to it.

**The list saved to most recently is remembered.** The store holds it, settings
persist it, and the destination menu opens its highlight on it instead of the
first item. Because SQLite reuses a deleted row's id, the memory is dropped the
moment its list leaves the overview rather than when a menu next asks for it —
otherwise a list created right after the remembered one was deleted would
inherit the highlight.

**A cue that is already a Shiori still opens the menu.** Saving to a *different*
list is the point of choosing one, so the old "already saved, do nothing"
shortcut is gone. A cue whose identity cannot be resolved — a legacy Shiori row
with no cue id — still opens nothing and says so.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriDestinationMenu.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackCueFooter.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackViewModel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusActions.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusDatabaseReader.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Shiori.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackSubtitleFocus.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackCommandPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Settings/SettingsStore.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/Toast.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shiori/ShioriListEditor.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchShioriTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuGate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuAnchorProbe.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableRowActionMenu.swift`
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/*.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusKeyboardActionTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusLayoutTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusSessionStoreTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackShioriOverlayTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/CueGroupRefreshScopeIntegrationTests.swift`

## Result that did not match the requirement

Requirement 4.2 asks that `C` and `X` keep working while the destination menu is
open. **They do not, and no change was made to force them to.** The App's menu
barrier lets a key through only when it carries Command; every plain key stops at
the open menu, which is what `aPlainKeyStopsAtTheMenu` in `MenuGateTests` fixes
as the behaviour. Making `C` and `X` live would mean either this one menu
answering keys no other menu answers, or changing the shared rule in
`UI Application Rules.md` 菜单模态 1 for every menu at once. Both are the owner's
decision, so the clause is reported rather than implemented.

The same barrier is why requirement 4.3 could not be met by letting `S` reach the
footer again: the menu answers `S` itself and closes, which is the menu owning
its own key rather than an exception to the barrier.

## Verification

`swift build` clean. `swift test`: 1142 tests, 11 failures, every one of them
also failing at `331a9fd4` without this change (native playback media and
presentation tests, the Debug E2E scene and window tests, three
`CueGroupRefreshScopeIntegrationTests`, and the shared-persistence migration
test). Failing-test names were compared against a `git archive` export of
`331a9fd4` built with the same media runtime: nothing regressed, and several
tests that were failing there now pass, including two Shiori keyboard tests whose
save is no longer asynchronous.

Debug E2E controller, `swift run CueSeeker --cueseeker-debug-e2e`, against the
real library:

1. Workbench Search row menu, `Save to Shiori ...`: the submenu opens on the
   first list while nothing has been saved yet.
2. Choosing the second list writes the row and shows `Saved to “第二个列表”`.
   Reopening the submenu on another row opens the highlight on 第二个列表.
3. Into playback, Playback Overlay, `S`: the menu opens upward off the
   `Save to Shiori` button, inside the surface, with its own scrollbar, and the
   button takes the same background it takes on hover. 第二个列表 is highlighted.
4. Down, Return: `Saved to “列表 3”`, and the menu closes. `S` again opens the
   menu on 列表 3. (This step ran while the result was still a Toast; steps 10
   and 11 below are the same flow after it moved to the playback feedback.)
5. `S` a second time closes the menu and the button returns to Default; a click
   outside does the same.
6. Quit and relaunch: the menu still opens on 列表 3, so the memory survives a
   launch.
7. Command Panel over the playback page, search results, `S`: the menu opens off
   that footer's own button, stays inside the panel, and opens on 列表 3.
8. Return on a cue already in that list: `Shiori already exists in “列表 3”`, no
   second row.
9. With the menu open, `C` copies nothing — the result reported above.

After the result was moved to the playback feedback:

10. Playback Overlay, choose a list: the dark pill with a bookmark reads
    `Saved to “5”` over the video, and no Toast appears.
11. The same cue and list again: the same pill reads
    `Shiori already exists in “5”`.

The Search row menu's Toast was verified before this last change and its code
path is unchanged; it was not exercised again afterwards. The two failure
sentences are covered by `shioriToastRequestsMatchTheUsageRegistry` instead —
they need a broken database or a list deleted mid-menu to reach in the App.

Not exercised in the App, and left for acceptance: `New List` from the playback
footer, renaming and deleting the remembered list, the three languages and the
two themes.

The runs wrote three Shiori rows into the owner's real library — the cue `A班` of
`BanG Dream! - 01` into `第二个列表`, `列表 3` and `5` — and left the remembered
save target pointing at `5`. Nothing else was changed.

No end-to-end capability was added for this change. The controller cannot report
which menu item is highlighted, so every highlight above was read from `capture`
images.
