# The table's metadata columns stopped disagreeing about their own step

Human-owned documents:

- `docs/human/requirements/20260831-UI-Table Metadata Text Single Color Step.md`

## Why

Display Title and Time Range had been lifted a step darker so they would not
collide with the column headers, which sat at the same step at the time. The
headers later dropped a step and took a heavier weight instead, which settled
the collision by other means and left the lift behind: three columns of the same
kind — a title, a time range, a date — were drawn in two different steps, and
nothing in the layout explained which column belonged to which.

The owner asked for one step to carry all of it. The table now spends its
neutrals on real distinctions: the cue itself is darkest, everything describing
the cue shares one step below it, and the lightest step is left to the row
number alone. The headers keep that shared step too and separate themselves by
weight, the way they already had been.

## What changed

Column headers, the cue group's additional lines, and the Date Added column all
move to the same step the display title and time range already used.

Date Added had reached its old colour through a text role that existed only to
name that one exception. With the exception gone the role resolved to exactly
what the plain metadata role resolves to, so the date now asks for the plain
role and the muted one is removed rather than left behind as a name that no
longer describes anything.

The headers are drawn twice in this file: the visible header is a SwiftUI cell,
while the AppKit header string backs the header's own text-selection geometry.
Only the SwiftUI one paints, but both stand for the same component, so both
moved — the first pass changed only the AppKit path and the App on screen still
showed the old colour, which is how the split was found.

Files:

- `apps/macos-native/Sources/CueSeekerApp/TableSandbox/SubtitleTableView.swift`
  — header colour in `SubtitleTableHeaderCellView` and `SubtitleTableText.header`,
  the cue group's extra-line colour, and the removal of the muted metadata role.
- `apps/macos-native/Tests/CueSeekerAppTests/SubtitleTextLayoutTests.swift`
  — `subtitleTableTextUsesRedesignVisualHierarchy` pinned the header's old colour
  and the removed role; it now states the header's new one and drops the role.

## Verification

`swift build`: clean, no new warnings.

`swift test`: 1125 tests, 20 failures, every one a member of the flake set this
repository already carries — the playback-media, window-geometry, persistence
and refresh-scope group whose membership shifts between runs under parallelism.
The set was established by running the suite on the requirement commit earlier
today and cross-checked against three further runs; no failure outside it
appeared. `SubtitleTextLayout`, `SubtitleTableTagStyle` and
`SubtitleTableCueGeometry` were also run alone: 25 tests, all pass.

Confirmed in the running App with the Debug in-app E2E controller, which is what
caught the header split. The Shiori list table was opened by scripted click,
captured, and the rendered pixels sampled from the PNG (values are the darkest
antialiased pixel of each glyph run, so ±1 from the token):

| Sampled | Rendered | Token |
| --- | --- | --- |
| Column header — Cues | `#494949` | `--color-text-secondary` |
| Column header — Display Title | `#494949` | `--color-text-secondary` |
| Column header — Time Range | `#494949` | `--color-text-secondary` |
| Column header — Date Added | `#494949` | `--color-text-secondary` |
| Index column | `#707170` | `--color-text-muted` |
| Target cue | `#1E1E1E` | `--color-text-primary` |
| Cue group extra line | `#484848` | `--color-text-secondary` |
| Display Title | `#484948` | `--color-text-secondary` |
| Time Range | `#484848` | `--color-text-secondary` |
| Date Added | `#484948` | `--color-text-secondary` |

The four headers sample identically, and the index column is the only text in
the table still on the muted step.

This covers acceptance items 1 through 4 in Light. Item 5 — the Dark pass — was
not done; the controller captures whatever appearance the machine is in and the
session ran in Light. Dark resolves through the same token names by the same
code path, but whether the result reads well there is the owner's call.

One thing was deliberately left alone: the hover-region measurement path builds
throwaway attributed strings for the extra cue lines and still names the muted
colour. Nothing is painted from them — they exist to compute rects — so the
colour there has no effect and changing it would not trace to this requirement.

## Outcome

Sections 1 and 2 of the requirement are implemented and confirmed on screen.

Section 3 asks for three entries in the design system. Those live under
`docs/human/`, which this assistant must not edit; the wording is the
requirement's own and is the owner's to apply after acceptance.

The Dark theme pass in acceptance item 5 is outstanding.
