# Remove table header sorting UI

Human-owned documents:

- `docs/human/requirements/20260824-UI-Remove Table Header Sorting UI.md`

## Why

The Search and Shiori table headers presented a sortable control: a chevron or
arrow indicator next to each column label, a hover background, a pointing-hand
cursor, a focus ring, and a click that opened an ascending/descending menu.
None of it sorted anything. Choosing a direction only repainted the header
icon; the row order never changed. The affordance promised a feature the
product does not have, so it was removed rather than completed.

## What changed

The header cell is now a plain label. It has no button, no sort indicator, no
hover background, no cursor change, no focus ring, and no keyboard tab stop.
Its text, font, colour, and horizontal padding are unchanged, including the
disabled colour it takes in selection mode.

The sort menu and the coordinator state that fed it are gone: the sorted column
and direction, the direction enum, the active header-menu column, the
header-menu anchor, and the deferred header-menu action that the header text
overlay used to replay after a click without a drag. The header now records
only text-selection intent on mouse down.

Header text selection is unaffected and gains reach. Previously the label's
padding was registered as an interactive control region, so a press there was
routed to the button instead of starting a selection drag; without the button
the whole header cell starts a selection, which is how the non-sortable index
column already behaved.

The row context menu shares the menu host, the dismiss overlay, and the
positioning helpers. All of it is untouched; only the header branch of the menu
anchor was removed.

The two now-unused localization keys were removed from all three languages.

The keyboard bridge that carries focus from the header into the table body was
deliberately left in place. It is inert for the header now, but it also routes
the key-view chain into the document view, and removing it is not part of this
requirement.

Files: `SubtitleTableView.swift`, `en.lproj/Localizable.strings`,
`zh-Hans.lproj/Localizable.strings`, `zh-Hant.lproj/Localizable.strings`,
`SubtitleTableVirtualRowTests.swift`.

## Verification

Automated: `swift build` and `swift build --build-tests` clean.

Three header tests were updated to the new behaviour and pass:
a header text drag still selects across columns while a click now opens no
menu; a press in the label's leading padding now routes to text selection
instead of being blocked by the control region; the selection-mode assertion
that the header menu stays closed was dropped with the function it called.

Full `swift test` was compared against a pristine export of `4b5bb112` built in
a separate directory. Both trees fail the same media-decode, native-playback,
window-scene and CueGroup refresh-timing cases. The five tests that differed
between the two runs pass in isolation on this tree and shuffle between runs on
the baseline as well, so they are order-dependent flakes, not a regression.

In-app: launched with `--cueseeker-debug-e2e` and captured the Shiori list
table and the Search table. Both headers render `#`, 台词数, 显示标题, 时间范围,
添加日期 as plain labels with no indicator. A click on 显示标题 produced no menu
and no visual change.

## Outcome

Matches the requirement. Column widths, order, visibility, header height,
pinning, horizontal sync, the selection-mode checkbox column, and the existing
row order are unchanged.

`docs/human/design/UI Design System.md` still documents the Sortable header
variant and lists it in the Search / Shiori Table Layout components. The
requirement assigns that update to the human owner after visual acceptance, so
it is intentionally not part of this change.
