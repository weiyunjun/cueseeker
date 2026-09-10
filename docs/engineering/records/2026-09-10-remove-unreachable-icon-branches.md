# Unreachable icon branches are gone

Human-owned documents:

- `docs/human/requirements/20260910-Engineering-Remove Unreachable Icon Branches.md`
- `docs/human/design/Icon Registry.md`

## Why

Converting every glyph to Phosphor meant touching every place that names an icon, and some of those places can never be drawn. They still needed assets, sizes and line-width rows to compile, so the icon registry and the line width table carried entries that no screen shows. The requirement asks for the registry and the table to hold only what Icon Registry lists.

## What changed

**The `library` Workbench mode is gone.** The Sidebar shows Library through `testLibrary`, and `WorkbenchRoute.panelMode` never yields `library`: the Library route maps to `testLibrary`, and `firstLevel(of: .library)` sent the mode to Search. A value an older build saved still opens on Search, because an unknown raw value now falls back the same way. The test that pinned the migration keeps pinning it with the literal saved string.

**The Search page's Library panel is gone, with everything only it drew.** `SearchView.libraryPanel` had no reference anywhere; the `library` case of the page switch showed the search surface. With it went the folder-collapse state, the `indexing` and `library` environment objects SearchView read only for the panel, and the views reachable from nowhere else: the nine-state info page, the folder group and folder header, the episode grid and episode button, their `LibraryLayout`, `WrapFlowLayout`, `SearchTypography`, and `LiquidGlassTokens` with the selectable card that shared its file.

**The legacy search command bar and filter bar are gone.** Both callers of the search shell pass `isRedesign: true`, so its other branch never rendered. `WorkbenchToolbarButton` was used only there, and it held the only `caret-up-down`.

**Controls nothing calls are gone.** `WorkbenchPlainActionButton` had no caller; it was the only reason `plus` existed. `ShioriCardGroupView` had no caller, and `CardGroupHeader`, `EqualHeightCardGridLayout` and `SearchCardLayout` were used only through it. The player button kind `primaryTransport` was never constructed, so the 26pt glyph size it carried never drew.

**The overlay module icon is gone.** `PlaybackOverlayModule.icon` had no reader; the module switcher renders text only.

**The registry and the table now match Icon Registry.** `AppIcon` dropped `caret-up-down`, `plus`, `tray` and `list-bullets`, leaving the 55 glyphs Icon Registry lists. `AppIconLineWidth.bySize` dropped 13, 17 and 26, leaving its nine sizes. Its comment now points at Icon Registry instead of the migration requirement.

**Strings nothing reads are gone.** 21 keys in each of the three string tables: the 16 info-page titles and messages, `export.group_to_anki`, `library.episode`, `library.playing_episode`, and `shiori.count.one`/`.other`. None is built dynamically.

## Files the owner removed

The requirement leaves whole-file removal to the owner. The package cannot build while these exist, because they reference the symbols above:

- `apps/macos-native/Sources/CueSeekerApp/Workbench/InfoPageStateView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/Library/LibraryFolderGroupView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/Library/LibraryFolderHeader.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/Library/LibraryEpisodeGrid.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/Library/LibraryEpisodeButton.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/Shiori/ShioriCardGroupView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Search/Results/CardGroupHeader.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/LiquidGlassSelectableCard.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/InfoPageStateTests.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/Icons/tray.svg`, `list-bullets.svg`, `plus.svg`, `caret-up-down.svg`

## Left as they are

- The redesign/legacy branches inside live controls stay, as the requirement scopes them out. One of them, the legacy menu row's selected check, still names 17pt; it never draws.
- `WorkbenchControlMetrics.redesignInlineAddSymbolFontSizeMacOS` has no user now that the plain action button is gone. It stays as the mirror of `--size-inline-add-symbol-font-size-macos`, which UI Design System still lists.
- `AppCoordinator.hydrateLibraryAsync()` lost its only caller with the panel. It is data loading rather than a component, outside what the requirement removes.
- `SearchView`'s private `listRowAction` was already unused before this change.

## Verification

Before the owner deleted the files, verification ran on a copy of the package that left them out. After the deletion, it ran again in the working tree.

- `swift build --build-tests` from clean succeeds. Its five warnings are all in files this change does not touch: `MenuPanelHeightTests`, `SubtitleIndexerTests`, `TaskQueueStore` (two) and `WorkbenchShioriTableView`. Running `swift build` in the working tree before the deletion failed as expected, with errors only in `ShioriCardGroupView.swift`, `CardGroupHeader.swift` and `InfoPageStateView.swift`.
- `swift test`: 1176 tests, one fewer than before because the info page test is gone. The copy's parallel run failed the same 15 as the recorded baseline, and the working tree's run failed 12 of them, none new. Rerun alone, all pass except the two Shiori table tests, which fail the same way on a clean `HEAD`.
- Debug in-app E2E controller, first pass on the copy: the app opened on Recent with the Sidebar collapsed, which is not the layout the Sidebar coordinates assume. The first click changed nothing. The second landed on the first Recent card and opened *It's MyGO!!!!! - 01* at 12:14. Its resume position was 12:57 at the next launch, so it played about 43 seconds before Command-Q stopped it. The playback page drew its control bar correctly.
- Second pass in the working tree, with each capture read before the next click: the Sidebar toggle, derived from the documented window-control inset, traffic-light width and toggle gap, opened the Sidebar with its five items. Search shows its field, filter and select-mode buttons. The first Shiori list shows the same toolbar. Its "3 results" comes from a Watch Status "Unwatched" filter set before this session, which was left as it was; the filter menu's section icons and ticked checkbox draw correctly. The app was put back on Recent with the Sidebar collapsed before quitting.
