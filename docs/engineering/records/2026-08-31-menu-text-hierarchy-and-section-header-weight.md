# The menu spelled its hierarchy twice in the same direction

Human-owned documents:

- `docs/human/requirements/20260831-UI-Menu Text Hierarchy And Section Header Weight.md`

## Why

Menus read grey. The text a menu exists to present — the item labels, the
filter options — was drawn one step below the darkest neutral the app owns,
while the headings above it were drawn at that darkest step and in a heavier
weight. Colour and weight both said "the heading matters more", so the thing
the pointer is aimed at was the quietest text on the surface. Against the
system menus this shows up as a full step of contrast: the item labels sat at
9.0:1 on white where macOS and the mainstream web frameworks put the same text
near 15:1.

The separate defect in the filter menu's section headings came from a gap in
the specification rather than a decision. The heading's label was given a
weight; its leading icon was given a size and a colour and no weight, so the
symbol fell to the system default and rendered a step thinner than the words
beside it.

The fix keeps the four roles and re-spells them as two colour steps crossed
with two weights: the content takes the darkest step, the headings step back in
colour and forward in weight, and the trailing counts stay one step behind the
options they belong to. No token was added and no value changed; only the
assignments moved.

## What changed

Menu items — every context menu, dropdown, submenu and the Playback Overlay's
menus — now draw their label, leading icon, checkmark and submenu arrow at the
primary neutral. The destructive variant and the disabled state keep their own
colours and are untouched.

In the filter menu the option labels join the item labels at the primary
neutral, the counts and the calculating hint move up from muted to secondary so
they trail the options by exactly one step, and the section heading drops from
semibold to medium with its icon pinned to the same weight. The menu's own
title keeps the primary neutral and semibold it already had, which is now the
only thing in the menu carrying both the darkest colour and the heaviest
weight.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
  — `WorkbenchPopoverRow.labelColor` and `.iconColor` resolve to the primary
  neutral.
- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
  — section heading weight and icon weight, option label colour, count colour.

## Verification

`swift build`: clean, no new warnings.

`swift test`: 1125 tests. The working tree was stashed and the same suite run on
the requirement commit to separate pre-existing failures. That baseline is
already red — 18 failures on the baseline run, 21 on the run with the change,
the usual playback-media, window-geometry, persistence and refresh-scope set
whose membership varies between runs under parallelism. The two sets are not
identical, so each test present in one and absent from the other was re-run:
`failedLibraryFolderRemovalPreservesFolderAndPresentationState`,
`libraryFolderRemovalPublishesProgressWithoutBlockingMainActor`,
`sharedPersistenceMigrationCopiesLegacyValuesWithoutOverwritingSharedValues`
and `subtitleFocusShioriIdentityDistinguishesSameTimeSiblingCues` all pass in
isolation with the change applied, which puts them in the same flake. Nothing
in the suite pins a menu colour, so no test needed updating and none broke.

Because no automated test covers what this change does, it was confirmed in the
running App with the Debug in-app E2E controller. The filter menu and a Shiori
row context menu were opened by scripted click and right-click, captured, and
the rendered pixels sampled directly from the PNGs:

| Sampled | Rendered | Token |
| --- | --- | --- |
| Menu item label | `#1F1F1F` | `--color-text-primary` |
| Menu item leading icon | `#1F1F1F` | `--color-text-primary` |
| Submenu indicator arrow | `#1F1F1F` | `--color-text-primary` |
| Filter title | `#1F1F1F` | `--color-text-primary` |
| Section header icon | `#494949` | `--color-text-secondary` |
| Section header label | `#494949` | `--color-text-secondary` |
| Filter option label | `#1F1F1F` | `--color-text-primary` |
| Filter option count | `#494949` | `--color-text-secondary` |

The heading's icon and label sample to the same value, and the captures show
them at the same weight. `Remove Shiori` stays danger red.

This covers acceptance items 1 through 6 in Light. Item 7 — the Dark pass — was
not done: the controller captures whatever appearance the machine is in, and
the session ran in Light. The weights and the token names are shared, so Dark
resolves to `#F7F7F7` and `#B9B9B9` by the same code path, but that it reads
well at those values is the owner's judgement, not something a capture in Light
establishes.

## Outcome

Sections 1 and 2 of the requirement are implemented and confirmed on screen.

Section 3 asks for four entries in the design system. Those live under
`docs/human/`, which this assistant must not edit; the wording is the
requirement's own and is the owner's to apply after acceptance.

The Dark theme pass in acceptance item 7 is outstanding.
