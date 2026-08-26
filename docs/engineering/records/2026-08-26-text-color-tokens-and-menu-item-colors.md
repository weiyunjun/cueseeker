# Text color tokens and menu item colors

Human-owned documents:

- `docs/human/requirements/20260826-UI-Text Color Tokens And Menu Item Colors.md`
- `docs/human/design/UI Design System.md`

## Why

The three text greys had stopped meaning what their names said. `#0F172A` was
too dark for anything the table wanted, so the table had quietly moved its
primary cue text down to `--color-text-secondary` and everything else down to
`--color-text-muted`. The token called "primary" was left holding the darkest
value in the palette while naming a role nothing in the table filled, and the
gap between the two greys the table actually used — `#404040` to `#667085` — was
wide enough that a header and a cue could not sit in the same visual family.

Four defects had grown in the space the missing rule left.

A menu item drew from three colour sources at once. The label and the leading
icon took the text colour, but the submenu indicator took `--color-icon-default`,
two full steps lighter, so the chevrons on "Move to ..." and "Duplicate to ..."
read as disabled next to their own labels. The design system permitted this by
omission: `Menu Item / Default` states a Label Color and says nothing at all
about either slot's icon.

`Destructive Menu Item` had been specified and never built. The menu row
component had one fixed set of colours, so "Remove Shiori" was indistinguishable
from "Copy Time Range".

"Duplicate to ..." had no icon because the name it asked for, `copy`, is not a
system symbol; the slot reserved its width and drew nothing, which is why the
label still lined up with its neighbours.

The cue underline picked its colour by asking whether a fragment was the last
one, and the primary cue is the first fragment with the cue-group lines after
it. The test was therefore exactly inverted: the primary cue underlined in the
muted colour and the final cue-group line underlined in the darkest one. It only
looked right when the cue group was hidden and there was one fragment to be both
first and last.

## What changed

The palette moved down one step and grew the missing middle. `--color-text-primary`
takes the value the table was already using for cue text, `--color-text-secondary`
becomes a new colour halfway between it and `--color-text-muted`, and `#0F172A` /
`#F4F4F5` retire from text entirely. The middle value is the perceptual midpoint
rather than a picked one: `#535761` and `#BABABF` leave the three tiers about ten
L\* apart on both sides, so no pair is closer than any other.

With the values honest, the roles are assignments rather than exceptions. Table
cue text is `--color-text-primary` again by name. The table header, the menu
items, the neutral buttons and the toolbar buttons take the new middle. The
selection overlay's count drops to `--color-text-muted`, below the buttons beside
it. Nothing else was repointed; every other reference to `--color-text-primary`
keeps it and simply lightens with the token.

A menu row now resolves one label colour and one icon colour, and all four slots
— label, leading icon, checkmark, submenu indicator — read from those two. That
is what removes the pale chevron: not a colour applied to the chevron, but the
end of the chevron having a source of its own. `isDestructive` is a fifth input
to the same two properties and to the highlight fill, so the destructive item
gets its colours from the same place every other item does.

Hover on cue text no longer changes the colour, so the underline is the whole of
the hover feedback and the pointer still turns to a hand. The underline takes its
colour from the fragment it belongs to — a fragment now reports the foreground of
the string it was built from — which is why the ordering bug cannot come back:
there is no longer a position test to get backwards.

`drawBody` lost its `isHovered` and `underline` parameters. No caller had ever
passed either, so the cell hover background and the underline they guarded had
never once drawn.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
  - `textPrimary` and `textSecondary` values.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
  - `WorkbenchPopoverRow` gains `isDestructive`, `labelColor` and `iconColor`;
    `rowBackground` branches on it. `WorkbenchButton` and
    `WorkbenchToolbarButton` label and icon colours.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
  - `bodyColor`, `drawCues`, `cueTextFragments`, the cue hover rect,
    `SubtitleTableTextFragmentLayout.foregroundColor`, `drawBody` parameters,
    and the destructive flag passed from `actionRow`.
- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableRowActionMenu.swift`
  - `duplicateToList` symbol, `isDestructive`.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
  - Selection overlay count colour.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
  - Filter option label colour.
- `apps/macos-native/Tests/CueSeekerAppTests/`
  - `SubtitleTextLayoutTests` drops the hover-colour fixture and expects
    `textPrimary`; `SubtitleTableRowActionMenuTests` expects the arrow symbol and
    covers `isDestructive`; `SubtitleTableTagStyleTests` expects the new
    secondary value.

## Verification

`swift build`: clean.

`swift test`: 1098 tests. Three failed on the change and were expectations that
had pinned the old values — the cue text colour, the `copy` symbol name, and the
grey tag's hex. All three pass after being updated to the accepted values; the
tag one is a value assertion on `redesignForegroundColor()`, which production
does not call, so nothing moved on screen for it. The remaining failures are the
pre-existing set: the working tree was stashed and the same suite run on the
requirement commit produced the same playback, window-geometry and refresh-scope
failures, with membership varying run to run in the usual parallelism flake.
Neither the before nor the after run contained any of the three colour names.

Real UI, Debug in-app E2E controller, Workbench Search and a Shiori list, both
appearances. Colours sampled from the captures are the antialiased renderings of
the tokens, consistently a little lighter than the source values:

| Element | Light | Dark |
| --- | --- | --- |
| Cue text | `#505050` | `#DDDDDD` |
| Table header, menu label, menu icon, submenu chevron, Select button | `#676A73` | `#C6C6CB` |
| Cue group line, Display Title | `#7B8395` | `#B1B2B8` |
| Remove Shiori label and icon | `#B3462D` | `#F2B9B6` |

The four menu parts sample to the same value in both themes, which is the
chevron fix stated as a measurement. Highlighting "Remove Shiori" by keyboard
fills its row `#FDF6F5` against `#F5F6F8` for an ordinary highlighted row.
"Duplicate to ..." draws the arrow.

Hovering a cue with a cue group shows the primary line underlined in the primary
colour and the group line underlined in the muted colour, each matching its own
text, and neither line changes colour under the pointer.

Appearance was switched to Dark for the dark captures and returned to Light
afterwards; the final capture confirms the restore.
