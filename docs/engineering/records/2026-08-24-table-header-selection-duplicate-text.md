# Table header selection duplicate text

Human-owned documents:

- `docs/human/requirements/20260824-Bug-Table Header Text Selection Duplicate Text.md`

## Why

Two different text engines were drawing the same header title. The visible
label comes from the SwiftUI header cell. The text-selection layer, sitting
above that label, painted an opaque selection background and then re-drew the
whole title with TextKit so the glyphs would sit on top of its own background.

The two engines disagreed about where the line sits. The selection layer chose
its vertical position from the nominal height of the attributed string, which is
the primary (Latin) system font's line height. For a title made only of Chinese
characters the glyphs actually come from the CJK fallback font, whose line box is
about three points shorter, so the line the selection layer laid out and drew
ended up roughly two points above the label the user normally sees.

The result while dragging: the selection layer's copy of the title inside the
highlight, and the lower part of the original label showing below the opaque
highlight box. Latin and mixed titles never diverged, which is why only the
Chinese headers looked doubled.

## What changed

The header title is now drawn once, by the SwiftUI label, in both the selected
and unselected state. The selection layer no longer draws text at all.

The selection background moved from the layer above the labels into the header
view's own drawing, which paints beneath its subviews, so the highlight sits
behind the existing label instead of covering it. The header view repaints on
selection change, horizontal scroll, and appearance change, as it already did
for its divider.

The header line geometry now comes from the laid-out line box instead of the
nominal string size. For Latin and mixed titles the two are identical, so
nothing moves; for CJK-only titles the highlight now aligns with the glyphs the
user sees. The same geometry feeds header text hit-testing, so clicking and
dragging track the visible glyphs as well.

The overlay view keeps its mouse, focus, copy, and select-all duties and lost
its drawing and appearance-repaint overrides, which no longer had anything to
draw.

Files: `SubtitleTableView.swift`.

## Verification

Automated: `swift build` and `swift build --build-tests` clean.
`swift test --filter "Header"` (11 tests) and `swift test --filter
"Selection|Text"` (132 tests) pass, including the header drag-selection,
header-blank-drag, header/body crossing selection, and select-all copy cases.

Measured, before making the change, with an offscreen harness that renders the
same header cell twice at 2x — once through the SwiftUI label and once through
the code path the selection layer used:

| Title | Font | SwiftUI ink | Selection-layer ink | Offset |
|---|---|---|---|---|
| `Cues` | 12 / 13 / 14 / 16 | identical | identical | 0 |
| `Ag台` | 12 / 13 / 14 / 16 | identical | identical | 0 |
| `台词数` | 12 | 17.0–27.5 | 15.0–25.5 | 2.0 pt |
| `台词数` | 13 | 16.5–28.5 | 14.5–26.5 | 2.0 pt |
| `台词数` | 14 | 16.0–29.0 | 14.0–27.0 | 2.0 pt |

With the line-box geometry the highlight for `台词数` at the shipping 14 pt
header font spans 15.0–29.0 within the 44 pt header cell and therefore contains
the SwiftUI ink at 16.0–29.0, where the previous box, 13.5–27.5, cut off the
bottom 1.5 pt of the glyphs.

In-app: not completed. The app was launched with `--cueseeker-debug-e2e` and the
Shiori list table was opened, but a synthesized `mouseDown` / `mouseDrag` /
`mouseUp` sequence produced no text selection at all — not on the header and not
on a table row — and `⌘C` returned an empty pasteboard, so no selected state
could be captured. The captures confirm only the unselected header, which
renders a single clean title. Visual acceptance of the selected state is left to
the owner.

## Outcome

Matches the requirement for the parts that could be verified here: one copy of
the title, unchanged unselected drawing, unchanged selection interaction and
row-level selection. The selected-state appearance still needs the owner's
visual acceptance because in-app drag selection could not be driven from the
current Debug E2E controller.
