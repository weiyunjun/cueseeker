# Neutral Icon Colors And Control Icon Weight

Human-owned requirement:
`docs/human/requirements/20260901-UI-Neutral Icon Colors And Control Icon Weight.md`

Related design: `docs/human/design/UI Design System.md`（Icon、Text）.

## Why

The 2026-08-30 neutral text ramp deliberately left the icon tokens alone, so the
icons kept the older blue-cast slate values while every piece of text around them
went pure grey. The icon-button pass fixed that for one component family; this
change finishes the job for the rest of the App, and retires the three slate icon
tokens rather than leaving them as a second, parallel colour ramp.

## Implementation

Default-state icons moved from `--color-icon-default` to `--color-text-secondary`:
the search magnifier, the Sidebar's primary and second-level icons, the Settings
window's category icons, the Library file tree's row icons, and the Destructive
Button's leading icon.

De-emphasised icons moved from `--color-icon-muted` to `--color-text-muted`: the
Library list row-end arrow, the file tree's disclosure chevrons, the Shiori list
and video cover placeholders, and the table's cue-state indicator with its hover
fill. Because the two old tokens carried the same value, a de-emphasised icon and
a disabled one used to be indistinguishable; they now sit two steps apart.

Disabled icons moved to `--color-text-disabled`: the Toolbar Button's leading icon
and select indicator, the Button and Destructive Button leading icons, Menu Item
icons, the Checkbox control colour, and the magnifier's disabled state, which had
been reaching for the muted token rather than the disabled one.

Weight: the default-state group now takes `--weight-control-icon`. Only two
actually change — the magnifier and the file tree row icon, both Regular before.
The chevrons and the placeholder glyphs keep their own weights.

`--color-icon-default`, `--color-icon-muted` and `--color-icon-disabled` have no
users left and were removed.

`PlaybackCueResultLayoutTests` pinned the disabled checkbox colour to the old
slate value; it now pins the new one. The enabled checked value is
`--color-bg-checkbox-checked`, a Control token outside this requirement, and is
unchanged.

Files: `Shared/WorkbenchRedesignTokens.swift`,
`Shared/WorkbenchControls/WorkbenchControls.swift`, `Shared/WorkbenchCheckboxStyle.swift`,
`Settings/SettingsView.swift`, `Workbench/ContentView.swift`,
`Library/LibraryFileTree.swift`, `Shiori/ShioriListCoverView.swift`,
`TableSandbox/WorkbenchTestLibraryView.swift`, `TableSandbox/SubtitleTableView.swift`,
`Tests/CueSeekerAppTests/PlaybackCueResultLayoutTests.swift`.

## Verification

- `swift build` — clean.
- `swift test` — 1125 tests. `editingCollageCheckboxMatchesSearchColorsAndMonochromeRendering`
  failed on the old pinned hex and passes after the test was updated to the
  accepted values. Every other failure is the repository's existing
  environment- and timing-dependent set; the families that could plausibly have
  been disturbed were run on their own
  (`--filter 'libraryFolderRemoval|failedLibraryFolderRemoval|subtitleFocus|progressiveSearchProjection|searchFacetSelection'`)
  and all 80 pass, so their appearance in the full run is ordering noise.

Debug in-app E2E against the running App, main window `1445 x 821`, scale 2, using
`click` and `capture`. No E2E command or test facility was added. Colours are read
out of the captured PNGs.

Light theme:

- Search magnifier `#494949`, and its ink pixel count rose from 132 to 184 —
  the Regular-to-Medium weight change is visible in the glyph itself.
- Sidebar second-level icon `#494949`; file tree row icons `#494949`.
- File tree disclosure chevrons `#717171`.
- Select toolbar button while disabled `#9A9A9A`.

Dark theme, switched through Settings > Appearance and restored to Light
afterwards:

- Magnifier and Sidebar icons `#B9B9B9`; file tree row icon `#B9B9B9`.
- File tree chevrons `#878787`.
- Select toolbar button while disabled `#606060`.

Not seen in this session's data, verified by source only: the Shiori list and
video cover placeholders and the table's cue-state indicator, which need a missing
cover and a cue state that this library does not currently produce; and the
Library list row-end arrow, whose list layout was not reachable.

## Reported to the owner

Acceptance item 1 reads "界面上不再出现 `#667085`、`#98A2B3` 及其 Dark 对应值". That
now holds for every icon, but three tokens outside this requirement's scope still
carry those values and were left alone:

- `--color-bg-checkbox-checked`: Light `#667085`; Dark `#A1A1AA`
- `--color-watch-status-unwatched-text`: Light `#667085`; Dark `#A1A1AA`
- `--color-scrollbar-thumb-interactive`: Dark `#71717A`

The player chrome's `--color-player-*` values also include them and are excluded
by the requirement itself.
