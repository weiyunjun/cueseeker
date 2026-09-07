# The four playback top bars become one 45-point layout with Task and Settings entries

Human-owned documents:

- `docs/human/requirements/20260908-UI-Playback Topbars Share One Layout.md`

## Why

The playback page and the Playback Overlay each had a top bar of its own: the player's was 46 points with a circular return button and a 13-point title, the Overlay's an undocumented 54 points with the tabs and the Collage button, and neither carried the App's Task and Settings entries, which the previous requirement had just settled into the Workbench top bar. The owner asked for one layout: every playback bar is exactly the window controls' band, `--height-app-topbar`, so everything in it — the return button, the title or tabs, the trailing entries — shares the traffic lights' centre line by construction, and the Task and Settings entries appear at the trailing edge of every page.

## What changed

- `TopbarAppEntries` is new in `Shared/`: the Task entry and a `SettingsEntryButton` extracted from the Workbench top bar, at `--spacing-1`, wired to the same App commands. The Workbench top bar, the player top bar and the Overlay top bar all place this one view, so the App's entries are the same control in the same order everywhere; a bar on another surface passes that surface's icon color and hover paint. The view reads `AppCoordinator` from the environment and hands each entry the store it reflects — the task queue, the layout state's window flag — as an observed object, the way the Task entry already took its store. A first cut read `WorkbenchLayoutState` from the environment too, and the full test run crashed in a host that injects the coordinator but not the layout state; the observed-object form has no such requirement.
- `WorkbenchIconButton` takes an optional `iconColor`. On the video the Workbench's secondary text is dark on dark in Light appearance, so the player top bar draws its Icon Buttons in `--color-player-text-primary` with `--color-player-control-bg-hover` as the hover and Open paint, the two Player Chrome tokens the requirement names. `TaskEntryButton` passes both through.
- `PlaybackReturnButton` is a `WorkbenchIconButton` with `chevron.left` instead of a Player Circle Button. It no longer pins itself to the band's top edge: both bars are now the band, so centring in the bar is the controls' centre line.
- `LiquidGlassVideoTopBar` and the Overlay's top bar use `--height-app-topbar`; `videoTopBarHeight`, `topbarTitleFontSize` and the Overlay's `tabBarHeight` are gone. The Display Title and the Editing Collage title are `--font-size-body` semibold; the Collage title lost its pencil glyph. The Overlay's trailing region is one `HStack`: the Collage button on Current, then the entries, at `--spacing-4` from the trailing edge.
- The Task panel's header kept its 54 points through a new `redesignTaskPanelHeaderHeight`, since it had been borrowing the Overlay's constant and the requirement leaves it alone.
- `playback.collage.editing` gained the single-character ellipsis in all three languages.
- `AppDelegate` gives the main window's hosting view no safe-area regions. This was found during verification, not planned: with the 45-point titlebar left as SwiftUI's top safe area, the Overlay's new top bar — a subtree lying wholly inside that band — was neither drawn nor hit-tested, while the same bar at 46 or 54 points rendered fully. The Workbench already lays itself out from the window's top edge with the band's token and ignores the safe area at its root, so nothing else moved; the Settings window has its own hosting view and is untouched.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppDelegate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackTheme.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackVideoStage.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/SubtitleFocus/PlaybackSubtitleFocusOverlay.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/LiquidGlassVideoTopBar.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/TopBar/PlaybackReturnButton.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/TopbarAppEntries.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskEntryButton.swift`
- `apps/macos-native/Sources/CueSeekerApp/Tasks/TaskPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/Workbench/ContentView.swift`
- `apps/macos-native/Sources/CueSeekerApp/Resources/en.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hans.lproj/Localizable.strings`
- `apps/macos-native/Sources/CueSeekerApp/Resources/zh-Hant.lproj/Localizable.strings`
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackSubtitleFocusLayoutTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/WorkbenchControlMetricsTests.swift`

## Verification

Debug E2E controller, main window 1445×821, Light appearance, English. The video was the first Recent Videos card; the Overlay was opened with Enter. Trailing-region centres derived from the tokens: Settings 32pt from the trailing edge, Task 68pt, Collage 104pt, all 22pt down; the return button 108pt from the leading edge.

- Player top bar on entry: white chevron after the window controls, `Ave Mujica - 01` centred, white Task and Settings glyphs at the trailing edge, all on the traffic lights' line over the gradient.
- Overlay Current: chevron, centred Current / Playlist tabs, Collage, Task and Settings on the same line; clicking Playlist switches the tabs and drops the Collage button, leaving Task and Settings.
- Clicking Collage shows `Editing Collage…` centred with no glyph and the Collage button in its Open paint; clicking it again returns to Current with the button bare.
- Clicking Task over the Collage screen opens the Task panel with the Task button lit; Escape closes the panel and the button returns to bare.
- Clicking Settings on the Overlay opens the Settings window — the controller reports a second window, 760×520 — and the gear is lit on the Overlay, still lit on the video page after Escape, and still lit on the Workbench after the return button. Closing the Settings window by its close button returns the gear to bare on both the Overlay and the video page.
- The Workbench's Recent page is pixel-for-pixel where it was before the hosting-view change.
- Before the hosting-view change, the same Overlay capture showed a bar with nothing in it and a click on the Playlist tab did nothing; the pre-change baseline, built from a stash of this work, showed the old 54-point bar in full.

`swift test`: 1144 tests, 32 issues. The same suite on this commit's parent, with the changes stashed, produced 26 issues. The four tests that failed only with the changes — the three library-folder-removal cases and `nativeSeekAndOpenRetainPresentedImageUntilCurrentGenerationCommits` — pass in isolation with the changes applied, so they are the load-dependent cases the earlier records describe. Two `CueGroupRefreshScopeIntegrationTests` cases, `showCueGroupInvalidationIsScopedToMountedShiori` and `shioriTableStartsAtTopAfterPanelRemount`, fail in isolation on the parent commit on the same two expectations, so they are not this change's either. The first full run with the changes crashed on the missing environment object described above; the numbers are from the run after that fix. Nothing in the failing set reads a top bar, and the two suites touched here, `WorkbenchControlMetricsTests` and `PlaybackSubtitleFocusLayoutTests`, pass.

## Follow-up: two defects the owner found on the Overlay top bar

Both were reported against the shipped commit and fixed in the same requirement's scope; both predate it and were merely hard to reach before the bar carried the Settings entry.

- **No hover on any of the bar's Icon Buttons.** The bar never claimed the Overlay's interface layer, so its buttons read the default context — the Workbench page's — and that page counts as frozen for as long as playback is open. The hover gate delivers nothing to a frozen surface. The old Collage button had the same blind spot. The bar now claims `.playbackOverlay` for itself, the way the footer does, so its hover follows the Overlay's own coverage: live while the Overlay is the top layer, stopped while the Command Panel covers it.
- **Tabs and the editing title kept the old language after a switch.** Language switching re-renders only the views that observe `AppLocalizationStore`; the bar's inputs — modules, selection, callbacks — do not change with the language, so SwiftUI skipped the bar even though its parent re-rendered, while the footer, which observes the store itself, updated. The bar now observes the store too.

Verified with the Debug E2E controller: with the Overlay open, Settings → Language → Simplified Chinese through the popup and the arrow keys. The tabs read 当前 / 播放列表 at once, the Collage screen's title reads 正在编辑长截图…, and the Playlist tab stays translated after Tab. The language was put back to Follow System afterwards. Hover is not automatable, for the reason below; the layer claim is proven by reading, not by capture.

`swift test` after the two fixes: 1144 tests, 32 issues, the same families as the run above. Two clipboard cases, `playbackShioriCopiesSettledPrimaryCueAsMarkdownLink` and `subtitleTableViewUnifiedRowMenuAndClipboardKeepPrimaryAndGroupSemantics`, failed in that run — a Debug E2E session of the App was running alongside it — and pass in isolation.

## Known limits

Hover on the new Icon Buttons is a manual acceptance step for the reason `docs/engineering/08_end_to_end_testing.md` §1.1 records: a synthesized `mouseMove` never reaches SwiftUI's `.onHover`. The Open paint is the same fill as hover, so the token itself is proven on every surface; the hover trigger is not.

Dark appearance and the Simplified and Traditional Chinese labels were not captured: switching them means changing the owner's settings from inside the App, which this verification left alone. The Chinese ellipsis is a strings-file change with no logic behind it.

The hover paint on the video page is not proven for the same reason as above; the Open paint of the Task and Settings buttons over the gradient is.

`UI Design System.md` still lists `--height-player-topbar`, the Player Circle Button as the return action, the Overlay top bar's old structure and the 13-point player title. Per the owner's instruction the design documents are updated after this round of UI tuning is accepted, so that gap is expected until then.
