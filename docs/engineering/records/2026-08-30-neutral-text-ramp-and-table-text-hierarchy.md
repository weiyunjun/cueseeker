# Neutral text ramp and table text hierarchy

Human-owned documents:

- `docs/human/requirements/20260830-UI-Neutral Text Ramp And Table Text Hierarchy.md`
- `docs/human/design/UI Design System.md`

## Why

Two separate faults sat in the same five tokens.

The first is hue. `--color-text-primary` was a flat neutral while the three
steps below it carried a blue cast, so the ramp did not read as one colour
getting lighter — it read as a grey heading above bluish supporting text. That
is the opposite of how a label ramp is meant to work, where the only thing
allowed to change between steps is lightness.

The second is where the top of the ramp sat. The darkest step was 10.4:1
against white. Every system the owner compared against puts its darkest text
between roughly 15:1 and 20:1, and 10.4:1 is what those systems use one step
down, for body copy under a heading. The consequence is not that any single
piece of text is wrong but that the whole ramp is short: the darkest and the
third step were only 2.2x apart, so nothing could be made to stand out by
colour alone, and the interface read grey no matter how the steps were
assigned.

The retired `#0F172A` is worth naming because it is the same mistake in
reverse. It measures 17.9:1, squarely inside the band the comparison systems
occupy; what made it feel wrong was its blue, not its depth, and the correction
applied at the time moved it two full steps lighter instead of removing the
blue.

Inside the table the third fault is an assignment one. The display title, the
time range and the date all shared the lightest content step, so a column that
identifies which episode a cue came from carried the same weight as a
timestamp, and the column headers — labels, not values — sat darker than the
values underneath them.

## What changed

The five text tokens keep their names and their count and take new values. Each
step is a pure neutral, and the steps are spaced at a steady factor of about
1.8 rather than the uneven 1.55 / 1.40 / 1.85 they held before. The two lower
steps land within a tenth of where they already were; the change is
concentrated at the top, which is where the ramp was short.

The icon, checkbox, scrollbar, status-badge and playback tokens happen to spell
some of the same hex values and are deliberately untouched — they are separate
tokens that coincided, not aliases, and the requirement excludes them.

`SubtitleTableTextRole` gains a fourth case. The table needed three
combinations where it previously had two: proportional text at the second step
for the display title, monospaced digits at the second step for the time range,
and monospaced digits at the third step for the date. The existing `.metadata`
case already carried the monospaced font, so the split is on colour only and
`.metadataMuted` shares its font. Doing it as a role rather than a colour
argument at the call site keeps the decision inside `bodyColor` with the other
three, which is where a reader looks for it.

The header cell drops to the third step and to regular weight, in both the
AppKit path (`SubtitleTableText.header`) and the SwiftUI one
(`SubtitleTableHeaderCellView`). Both were changed together because the
requirement asks for every column header to be identical and the two paths
draw headers in the same table.

The display title, the time range and the date drop from medium to regular.
`SubtitleTableText.bodyFont` returned medium for every role, so the target cue
was the same weight as the three columns it is supposed to stand out from and
adding weight to it could not have separated them. `.primaryContent` stays at
medium: nothing is drawn through it — the target cue is drawn by
`SubtitleTableCueTextMeasurer` — and its only job is to measure text selection
geometry for the cues column, which requires it to match the font that column
actually draws.

## Verification

`swift build`: clean.

`swift test`: 1121 tests. The working tree was stashed and the same suite run
on the requirement commit to separate pre-existing failures. That baseline is
already red — 17 failures, the usual playback-media, window-geometry,
persistence and refresh-scope set, with membership varying between runs under
parallelism. With the change applied the run shows 14 failures, all of them
members of the baseline set and none new.

One test failed on the change and was correct to:
`subtitleTableTextUsesRedesignVisualHierarchy` pinned the old assignments. It
now states the new ones, covers the added role, and asserts the header's
regular weight, which nothing covered before. Two expectations in
`SubtitleTableTagStyleTests` name hex values reached through
`--color-text-secondary` and `--color-text-disabled` and moved with them.

The suite was run again after the weight change: 15 failures, every one a
member of the baseline set. `playbackPlaylistCopyAndShioriTargetTheSettledPrimaryCue`
is the only one absent from the baseline listing above and it passes in
isolation, which puts it in the same flake.

The requirement's ninth acceptance item originally asked for the whole suite to
pass. That could not be met by this change and could not have been met before
it, because the suite does not pass at the requirement commit either; the item
was amended to ask instead that the change add no failure, which is what the
two comparisons above show.

Nothing was verified visually. The build and the tests establish which token
each piece of text resolves to; they say nothing about how the result looks,
and the acceptance items about the ramp reading as four distinguishable steps,
about the blue being gone, and about Dark remain for the owner. Dark deserves
the closer look: the requirement holds Dark to the same shape as Light, which
takes its third step from 6.9:1 to 4.9:1 and its fourth from 3.7:1 to 2.8:1.
Those are the only two figures in the change that move a value further from
where it sits today rather than closer to a reference.

## Outcome

Sections 1 and 2 of the requirement are implemented.

The exception recorded when this change first landed is resolved. The
requirement's table and its summary of what changes disagreed about the weight
of the display title, the time range and the date; the owner settled it in
favour of the table, the requirement was corrected to name the weight drop as
one of its deltas, and the three columns are now regular. The same correction
removed the requirement's claim that the target cue moves from regular to
medium — it was already medium, and no code was needed for it.

Section 3 asks for four entries to be added to the design system. Those live
under `docs/human/`, which this assistant must not edit; the wording was handed
to the owner to apply.

The acceptance items covering appearance are outstanding: whether the four
steps read as distinct, whether the blue is gone, and the Dark pass, where the
third and fourth steps are the only two figures in the change that move further
from where they sit today.
