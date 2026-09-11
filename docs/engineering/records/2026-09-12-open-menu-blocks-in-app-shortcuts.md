# Open menu blocks in-app shortcuts

Human-owned documents:

- `docs/human/requirements/20260912-UI-Open Menu Blocks In-App Shortcuts.md`
- `docs/human/design/UI Application Rules.md` (菜单模态, 更高层界面的屏蔽) and `docs/human/design/UI Design System.md` (2.4 Menus), to be updated by the owner after acceptance

## Why

The menu rules said shortcuts were unaffected by an open menu, and gave the speed menu three exceptions of its own: its ← and → went to the page as seeks, it did not ban scrolling, and it closed whenever a result was switched or the Command Panel or the Playback Overlay was opened. The owner tested Emby, where an open menu takes the keyboard and every shortcut unrelated to the menu is ignored, and rewrote the rule: while a menu is open and nothing covers it, the arrows, Enter, Esc and the key that opened it belong to the menu, every other in-app function and Tab does nothing, ⌘ shortcuts are unaffected, and the speed menu differs from the other menus in one thing only — it closes with the Player UI.

Classified as platform UI and UX: keyboard routing between a menu and the surfaces under it is macOS interaction. No product semantics move; nothing in `CueSeekerCore` changes.

## What changed

- The playback key owner asks the layer registry whether an uncovered menu is open before anything else — before the collage editor's keys, before Open Command Panel, before the Overlay's and the Command Panel's keys, before the page's shortcuts. When one is, a press without ⌘, ⌃ or ⌥ is offered to the open menus through the gate's router and is spent either way; a press held with ⇧ is spent without being offered. A game controller's input arrives through the same owner and never passes an event monitor, so this is also what keeps the controller's buttons from the functions underneath while a menu is open, and what lets it drive the menu.
- The menu gate's monitor now feeds every menu its keys, the speed menu included, and spends every key no menu takes unless it carries ⌘. The kind no longer says where a menu's keys come from. Measured while verifying this change: a local event monitor installed later runs first, so the gate's monitor — installed when the first menu opens — sees a key before the App-wide playback monitor installed at launch. The comments that said the opposite are corrected. Before this change the speed menu was the one menu the gate's monitor did not feed, so in the running App the gate spent its arrows, Enter and Esc before the playback owner could route them: the speed menu had no working keyboard, and every other key was already blocked while it was open. The owner had observed both; the code comments had claimed otherwise.
- Every open menu bans scrolling for the whole window; the kind no longer carries a scroll-table exception. The speed menu still spends the wheel over its own surface, which has nothing to scroll.
- The three places that closed the speed menu on the owner's behalf — switching to the previous or next result, presenting the Command Panel, and opening the Playback Overlay — are removed. All three are functions an open menu now spends, so the code was unreachable from the keyboard or a controller; the requirement asks for its removal.
- A menu gate session releases its registry entry when it is closed, not only when it is deallocated, so the registry's "an uncovered menu is open" answer — which the focus barrier, the pointer shape and now the key owner all read — never outlives the menu. The chrome's client view already dropped its session on close; a caller that keeps the session object after closing it no longer keeps the menu registered with it.
- `docs/product/12_liquid_glass_ux_mapping.md` §13.1 mirrors the rule; `docs/changelog.md` records the change.

Files:

- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+Playback.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackCommandPanel.swift`
- `apps/macos-native/Sources/CueSeekerApp/App/AppCoordinator+PlaybackSubtitleFocus.swift`
- `apps/macos-native/Sources/CueSeekerApp/Shared/MenuGate.swift`
- `apps/macos-native/Sources/CueSeekerApp/Playback/PlaybackStore.swift` (comments only)
- `apps/macos-native/Tests/CueSeekerAppTests/PlaybackNormalShortcutTests.swift`
- `apps/macos-native/Tests/CueSeekerAppTests/MenuInputBarrierTests.swift`
- `docs/product/12_liquid_glass_ux_mapping.md`
- `docs/changelog.md`

## Verification

Unit tests. In `PlaybackNormalShortcutTests`: with the speed menu open, K, Space, ←, →, A, D, Tab and ⇧. are all spent — the Command Panel and the Playback Overlay do not open, playback does not toggle, the speed in effect and the volume do not move — while ⌘K travels on; Esc closes the menu and K then opens the Command Panel. With an Overlay menu open, Tab, S, C, X, P and K are spent — the module stays, nothing is saved, no second menu opens, the collage editor stays closed, the panel does not open — while ↓ still reaches the menu. The Command Panel freeze test now opens the panel by a path other than the K key, since the open menus spend that key, and asserts that neither menu closes, that the arrows reach the panel, and that the menus take keys again once Esc closes it. The arrow-key test drops the gate session when Enter closes the menu, the way the chrome's client view does. In `MenuGateKindTests`: any open menu, the speed menu included, makes the gate ban window scrolling, and the router offers keys to every kind but the table row menu. The targeted suites — playback shortcuts, menu barrier and kinds, menu highlight, layer freeze, subtitle focus keyboard actions, table row action menu, card highlight, pointer hover, shortcut keymap, Player UI visibility — 126 tests, all passing.

`swift test`: 1204 tests, 14 failing, all in the set the 2026-09-12 Player UI record lists as failing on the baseline as well — the native playback timeline, audio, presentation and auto-pause boundary cases (7), the four refresh-scope integration counts, the two Debug E2E scene-geometry and window-width cases, and the order-dependent library-folder-removal case. None reads a menu or a key.

In the App: Debug E2E controller, `swift run CueSeeker --cueseeker-debug-e2e` from a PTY, main window 1445×821 at 2×, Light appearance, English, the owner's real library. The video was the first Recent Videos card, *It's MyGO!!!!! - 06*; the card's coordinate was read off a capture, the deviation the 2026-09-08 feedback record already notes for the Recent grid. The speed capsule's centre was derived from the tokens: 24 pt chrome padding, the 40 pt fullscreen button, a 6 pt gap and half the 54 pt capsule from the trailing edge, and 12 pt padding plus half the 52 pt controls row from the bottom edge — (1348, 783). The physical pointer rested inside the window, so the Player UI hid three seconds after entry and took the speed menu with it; the speed-menu steps were therefore run inside that window, each key followed at once by the next.

1. Speed menu open, video paused: K, Space, ← and a wheel step over the video — the menu stays open with 1× highlighted and checked, the video stays paused at 14:46, no Command Panel. ↓ moves the highlight to 1.25× while the check stays on 1×. Esc closes the menu; K then opens the Command Panel.
2. The same sequence on the first build of this change, before the gate's monitor fed the speed menu, left the menu deaf: ↓ and Esc did nothing, and K did nothing after Esc. That run is what exposed the monitor order; the order was then measured with a two-monitor script outside the App, and the fix above followed.
3. Playback Overlay, Current, Save to Shiori menu open with S: Tab, C, K and P — the module stays Current, the menu stays open, no feedback pill, no Command Panel, the collage editor stays closed; ↓ moves the highlight from test to New List. S closes the menu. With no menu open, Tab switches to Playlist and Tab again returns, as the control.
4. Playback Overlay, Current, the selected-text menu opened by dragging across the focused cue: Tab, S, C and K — the module stays, the menu stays open on its first item, no Save to Shiori menu opens, no Command Panel, no feedback. Esc closes the menu and clears the selection; the Overlay stays open.
5. With the Save to Shiori menu open, ⌘Q quits the App. Done twice, on each build.
6. A wheel step over the video with the speed menu open changed nothing; the video page has nothing that scrolls, so this shows no regression rather than the ban itself.

Not verified here and left to the owner's acceptance list: ⇧, and ⇧. (the controller sends letters, digits and the named keys only; the unit test covers ⇧.), ⌘, opening Settings over a menu (the controller cannot send a comma), the Workbench menus (their code paths are unchanged; the table row menu suites pass), the speed menu closing with the Player UI hide (unchanged code), and the game controller. No end-to-end capability was added; the FIFO used to type into the controller's PTY is a session-local convenience equivalent to typing at the terminal.

The run advanced the owner's resume position of *It's MyGO!!!!! - 06* from 14:44 to 14:46.

## Outcome

Matched expectations, with one finding beyond them: the speed menu's keyboard had been dead in the running App since the menu gate took over its monitor, hidden from the unit tests because they call the playback key owner directly. The requirement's first acceptance item — ↑↓ move the highlight, Enter selects, Esc closes — now holds in the App. After acceptance the owner updates 菜单模态 1 and 6 and 更高层界面的屏蔽 3 in `UI Application Rules.md`, and the Menu Modality line in `UI Design System.md`.
