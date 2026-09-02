# Search Row Menu Save To Shiori

Human-owned requirement:
`docs/human/requirements/20260902-Feature-Search Row Menu Save To Shiori.md`

Related design: `docs/human/design/UI Design System.md`
(Menus / Menu, Submenu, Menu Item, Search / Shiori Table Layout),
`docs/human/design/UI Application Rules.md` (菜单模态) and
`docs/human/design/Toast Usage Registry.md` (Shiori 相关).

## Why

Collecting a Cue from a Search result took a detour: the reader had to play the
video and press the Shiori key there, which also forced the destination to be
the first list. The Shiori table already had the destination submenu for Move
and Duplicate, so the missing piece was one more trigger on the Search side
that writes a Cue instead of relocating an existing Shiori.

The second half of the change corrects a translation defect. The localization
requirement of 2026-08-22 keeps the word Shiori in English in every language,
and one string — the playback footer's Save to Shiori — had been translated to
「栞」 in both Chinese variants against that rule.

## Implementation

The item reuses what the Shiori table already has rather than adding a parallel
path. `SubtitleTableRowAction` gained `saveToShiori`, which reports the same
right-arrow symbol as the two transfer actions, answers yes to
`opensDestinationSubmenu`, and is appended by the menu model only for the
Search style, directly after Open Subtitle Folder and before the first divider.
The submenu surface, its safe area, its hover and keyboard behavior, and its
trailing divider plus New List item are the existing ones, untouched.

Destinations differ by trigger, and that difference lives at the call site, not
in the submenu: the Shiori table filters out the list it is showing, while
Search offers every list because it has no current list. Ordering is the list
overview's own, which is creation order.

The action is disabled wherever the two transfer actions already are — an
unavailable Cue state — and additionally when the row carries no usable Cue
identity, the same condition that disables Copy Deep Link. Without that second
condition the item would open a submenu whose selection could do nothing.

Writing needed a Cue-addressed entry point. `ShioriDatabase.upsertShiori` was
split so the existing selection-based call extracts the Cue and delegates to a
new `upsertShiori(cueID:listID:createdAt:)`; the insert statement and its
conflict clause are unchanged and now have one owner.

`AppCoordinator.saveShiori(cueID:toListID:)` follows the shape of
`duplicateShiori`: resolve the destination first, report the existing
destination-unavailable toast when it is gone, refuse a Cue the list already
holds with the existing already-exists toast, otherwise insert, adjust the
overview count and report success. Success and hard failure use two new
scenarios, `shiori.save.succeeded` and `shiori.save.failed`.

`ShioriListEditorPendingTransfer` now carries a `Target` — an existing Shiori
for Move and Duplicate, a Cue for Save — so the New List path runs the right
operation once the list exists. Its behavior is the one accepted on 2026-08-29
and is not otherwise changed.

Localization added `row_menu.save_to_shiori`, `toast.shiori.saved` and
`toast.shiori.save_failed` in all three languages, and changed
`playback.save_to_shiori` from 「保存到栞」 and 「儲存到栞」 to 「保存到 Shiori」
and 「儲存到 Shiori」. That string was the only occurrence of the mistranslation
in the app; the design system's Playback Footer table still describes the same
status as 「栞数」 and is listed for the documentation sync.

## Verification

- `swift build` — clean.
- `swift test` — 1125 tests. Thirteen failures, all present on the parent
  commit `bf313c0` when the working tree was stashed and the suite re-run: the
  native playback media timelines, the auto-pause seek boundary, the
  cue-group refresh-scope waits, the two window-geometry E2E controller tests
  and the library folder removal set. None of them touch the row menu. The
  baseline run showed twenty failures, so this branch's run is a subset;
  those suites are order- and environment-sensitive.
- Five existing tests asserted the old Search menu shape and were updated to
  the new one: the element list, the title list, the selectable positions and
  divider index, the cue-group-hidden action list, the unavailable-state
  disabled set, and the virtual-row menu titles.
- One test added, `shioriSavesByCueIDIntoEachListWithoutDuplicatingWithinOne`,
  covering the new Cue-addressed insert against a temporary database: the same
  Cue reaches two lists, and a repeat save into a list that already holds it
  returns the existing Shiori without adding a row.

Debug in-app E2E against the running App, main window `1445 x 821`, scale 2,
using `click`, `keyPress`, `mouseMove`, `rightClick` and `capture`. No E2E
command or test facility was added.

- Right-clicking a Search result row opens Play, Open Subtitle Folder,
  Save to Shiori ..., divider, Copy Cue Text, Copy Deep Link,
  Copy Cue Group Text, Copy Time Range. The new item carries the right-arrow
  leading icon and the submenu indicator, and sits inside the first group.
- Hovering the item expands the submenu with no delay. It lists all six lists
  in the same order as the Shiori overview's cards — 我喜欢的字幕, 第二个列表,
  列表 3, 列表 4, 列表 5, new — then a divider and New List. No list is
  excluded.
- Moving the pointer off the trigger to another menu item collapses the
  submenu and moves the highlight to that item.
- From the closed menu, two down arrows reach the item and the right arrow
  expands the submenu with its first list highlighted.

Not verified in the running App:

- **The write itself, and the toasts it raises.** The App reads the owner's
  production library, so committing a Shiori into it was left for the owner.
  The database semantics behind it are covered by the added unit test, and the
  coordinator path mirrors `duplicateShiori`.
- **Dark theme and the two Chinese locales.** The change adds no color and no
  theme-conditional code; the strings were read from the resource files rather
  than on screen.
