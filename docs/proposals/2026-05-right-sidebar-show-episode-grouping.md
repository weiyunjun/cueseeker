# Right Sidebar Show / Episode / Hit Grouping

Status: Rejected

## Revision Note (after implementation review)

The Show / Episode / Hit grouping was implemented in commit `9a49d8e` and then
withdrawn by the user during the same review cycle for two reasons:

1. **The Show layer (parent folder) is structurally redundant in the right
   sidebar.** In the left Library panel, the parent folder is the user's
   primary navigation handle and the contract-based alias rank always exists
   for every video — those serial numbers are stable and the folder name
   repeats across many rows, so the two-line layout (folder + `N episodes`)
   earns its space. In the right sidebar the user is searching for
   keyword-bearing content; the matched cue text is the focus, the subtitle
   file alias plus the cue text is sufficient context, and the parent folder
   name is redundant header chrome. Not every subtitle file in a folder will
   have matches, so the Show layer is partially populated and unstable.
2. **Performance and attention.** A Show row that aggregates a full season's
   matches can render dozens of cue rows under one heading, increasing
   visual noise and pulling user focus away from the matched content. The
   previous flat subtitle-file group layout combined with the global
   `Collapse All` control already handles this case without a Show layer.

The accepted direction is to keep the previous flat subtitle-file group
structure (header `Parent Folder Name - NN  N results` plus left disclosure
rail with a chevron and a vertical line under expanded groups) while keeping
the row visual updates introduced alongside this proposal: Hit rows drop the
cue start timestamp, the selected row uses the macOS system accent color
with white text, and keyword highlights use the three-state token set
(`#FFE066` / `#FFCB1F` / `30%` white on selected). Disclosure chevrons
across the workbench are unified to a single-icon rotation animation
(`0°↔90°` over `160ms`).

The text below records the originally proposed direction. It is preserved as
historical context per the proposals workflow.

---

Status (original): Proposed

## Background

The right-side Search Panel currently groups search results in a single level
under one header per subtitle file, where the header text combines the parent
folder name and the subtitle file's natural-sort rank as `Parent Folder - 01`.
The Shiori panel mirrors that single-level grouping.

A new high-fidelity design for the right sidebar replaces this with a
three-level structure aligned with the macOS Sidebar idiom and with the existing
left Library panel:

- A **Show** row that names the work (the subtitle file's parent folder) and
  totals the matched cue groups across all of its subtitle files.
- An **Episode** header that names a single subtitle file inside that Show by
  the file's contract-based alias rank.
- A **Hit** row that shows one matched cue group inside that Episode.

This proposal accepts the three-level structure for both Search and Shiori,
unifies the disclosure-chevron animation between the right sidebar and the left
Library panel, and removes the start-time column from result rows so the row
can later host hover actions without re-flowing on hover.

## Goals

- Group right-sidebar results into Show → Episode → Hit, replacing the current
  single-level subtitle-file grouping.
- Reuse the existing contract-based alias rule for Episode identity. Episode
  numbers come from `SubtitleDisplayTitleResolver`'s same-folder
  same-extension Finder-like sort, so Episode numbers are always present and
  always unique within a Show. No filename parsing and no fallback is needed.
- Make the Show row visually consistent with the Library folder row: a two-line
  left column (Show title on the first line, plain `N results` on the second)
  with a single disclosure chevron on the right that rotates 0° ↔ 90° on
  toggle.
- Make the Episode header non-interactive. It is a section heading, not a
  hit target. It does not collapse, does not respond to hover, and has no
  chevron.
- Remove the start-time column from result rows. The visible content becomes
  the cue text only. Two layered indents continue to convey hierarchy:
  Show → Episode and Episode → Hit text.
- Selected and hover row backgrounds left-align with the Episode header text,
  not with the row text. The row's internal left padding produces the visual
  indent of row text relative to Episode text.
- Use the macOS system accent color (`NSColor.controlAccentColor` /
  SwiftUI `Color.accentColor`) for the selected row background, so users who
  change their system accent color see that color reflected in the panel. A
  future settings option may expose a custom accent override; this proposal
  does not include that.
- Keyword highlight tokens are defined as a three-state token set that varies
  with the parent row state, not with the highlight's own hover state.
- Apply the same Show → Episode → Hit grouping to Shiori. Shiori rows do not
  carry a query, so keyword highlight does not apply, but the row layout and
  selection background rules are identical.
- Unify the Library folder-row chevron with the new Show-row chevron: single
  icon, 160 ms ease, 0° ↔ 90° rotation. Replace the existing
  `chevron.right` ↔ `chevron.down` icon swap.

## Non-goals

- Change the top-bar controls (sidebar collapse / restore, Search mode toggle,
  Shiori mode toggle). Their visuals, hit regions, and animations are
  unchanged.
- Change the panel slide-in / slide-out animation, the resize divider
  behavior, or any other animation outside the disclosure chevron.
- Change the lazy-loading rules. Search keeps the global 100 cue-group page
  budget; the only change is that the loaded rows render under the
  Show / Episode tree instead of under flat subtitle-file headers.
- Implement hover action buttons (bookmark, screenshot, copy subtitle). The
  row layout reserves room for them by removing the timestamp and by using
  overlay-based hover affordances later, but no hover button is shipped in
  this proposal.
- Implement keyboard navigation between rows (↑ / ↓ / Return / Esc). The
  selectable row identity stays the same, so future keyboard navigation can
  still be added without a structural change.
- Specify dark-mode colors. The first implementation targets the same light
  surface as the rest of the workbench. Dark-mode tokens are deferred.

## Show / Episode / Hit Layout

The right-side panel content area is laid out top-to-bottom:

```
┌─────────────────────────────────────────────┐
│  [🔍] query                            [✕]  │   Search field (Search mode)
├─────────────────────────────────────────────┤
│  Found 185 results in 74 files [Collapse All]│  Summary row
├─────────────────────────────────────────────┤
│  Ave Mujica                          [▾]    │  Show row (collapsible)
│  9 results                                  │
│      Episode 01                  4 results  │  Episode header (NOT collapsible)
│        毋庸担心 月霞自会为我们将她唤醒        │  Hit row
│        [大丈夫]月の光が起こしてくれますわ    │
│        没问题的 诚实就是你的美德哦           │
│        [大丈夫]あなたの誠実さは美徳よ        │
│      Episode 02                  2 results  │
│        ...                                  │
│  It's MyGO!!!!!                     [▸]    │  Show row (collapsed)
│  38 results                                 │
│  ...                                        │
└─────────────────────────────────────────────┘
```

Show row presentation:

- Two-line left column: the Show title on the first line, the total result
  count on the second line as plain text such as `9 results` or `1 result`.
  The Show title uses the same weight and size as the Library folder title.
  The count uses the same secondary tone as the Library folder subtitle.
- A single disclosure chevron on the right that rotates from 0° (collapsed)
  to 90° (expanded) over 160 ms with an ease curve.
- The whole row is a single click target that toggles expand or collapse.
- Hover state shows a soft fill across the full Show row width.
- The Show row is never the selected row. Selection lives on Hit rows only.
- Show identity is the parent folder path of its member subtitle files. The
  Show title is the last path component of that folder.

Episode header presentation:

- A single non-interactive row inside an expanded Show.
- The label on the left is `Episode NN`, where `NN` is the subtitle file's
  one-based natural-sort rank within its parent folder among files with the
  same final subtitle extension. The rank is supplied by
  `SubtitleDisplayTitleResolver`. Numbers are zero-padded to at least two
  digits and expand to the sibling count's digit width when needed, matching
  the existing alias rule.
- The right side of the row shows the per-Episode result count as plain text
  such as `4 results` or `1 result`.
- The Episode header is purely visual. It does not collapse, does not respond
  to hover, and does not draw a chevron.
- Show name is not repeated in the Episode header, since the enclosing Show
  row already carries the Show name.

Hit row presentation:

- One row per matched cue group, keeping the existing row identity and the
  existing rule that all cue lines in the matched group are rendered.
- Row content is the cue text only. The original-language line carries inline
  keyword highlights. The translation line, when present, is rendered above
  the original-language line in the same row.
- Row no longer renders the start timestamp.
- Row hover and selected backgrounds left-align with the Episode header
  text. The row's own left padding then offsets the row text further to the
  right so the text appears visually nested under the Episode header.
- Selection is single-select across the entire panel, the same way the
  current implementation already behaves.
- Selecting a row continues to open or update the central Playback Area at
  the cue's start timestamp.

## Visual Indent And Selection Background

Three indented edges convey the Show → Episode → Hit hierarchy:

- The Show title sits at the panel's outer left padding.
- The Episode header text and the row backgrounds (hover or selected) sit at
  a deeper indent. Their left edges align with each other.
- The row text sits one further padding step inside the row background, so
  even on a selected row the cue text reads as nested under the Episode
  header.

Initial indent magnitudes follow the existing right-panel scale and the
design reference. Exact pixel values may be tuned during implementation
without re-issuing this proposal.

The selection background uses the macOS system accent color
(`NSColor.controlAccentColor`, surfaced through `Color.accentColor` in
SwiftUI). Selected row text becomes white. Selected row keyword highlights
follow the on-selected token described below. Hover background uses a soft
gray fill consistent with native macOS list rows.

A future settings option may let users choose a custom accent color for the
selection background; this proposal does not include that change.

## Result Row Content

A Hit row no longer shows the cue start timestamp.

Rationale:

- The two-level Show → Episode hierarchy already orders cues by time within
  a single Episode. Spatial order communicates time order.
- Users select a row to seek to the cue. The exact timestamp is not the
  decision driver; the cue text is.
- Removing the timestamp recovers horizontal space that future hover actions
  (such as bookmark, save screenshot, copy subtitle) will use.

Hover actions are not part of this proposal. The row layout reserves space
for them implicitly by freeing the right side of the row.

## Keyword Highlight Tokens

The keyword highlight inside the original-language cue line uses three tokens
driven by the parent row state:

| Row state | Highlight background | Highlight foreground | Weight |
|---|---|---|---|
| Default | `#FFE066` | label primary | 500 |
| Hover | `#FFCB1F` | label primary | 500 |
| Selected | `rgba(255,255,255,0.30)` | white | 600 |

Rationale: the saturated yellow is the most prominent token on a white or
gray row. On a selected row the same yellow would clash with the accent-color
background, so the highlight inverts to a translucent-white fill with bolder
white text. This keeps the matched substring the most prominent token in the
line while staying inside the accent-color envelope.

These tokens belong to the right-sidebar Search results. Other surfaces that
display query highlights (for example future Timeline or Shiori detail views)
may reuse them or define their own.

Dark-mode equivalents are deferred to a later proposal.

## Show Row Disclosure Animation

The Show row chevron is a single icon (a right-pointing chevron). On expand
the icon rotates 0° → 90° over 160 ms with an ease curve. On collapse it
rotates back. There is no icon swap.

The Library folder row chevron is unified to the same animation:

- The Library folder row already has the same toggle semantics.
- The current Library implementation swaps `chevron.right` and
  `chevron.down`. This is replaced with the same single-icon rotation so the
  two sidebars share one disclosure language.

The top-bar collapse and mode toggle controls are out of scope and are not
modified.

## Shiori Inheritance

The Shiori panel reuses the Show → Episode → Hit grouping with these
adjustments:

- The summary row continues to read `<count> shioris in <count> files`. The
  panel exposes a fixed `Collapse All` control and does not flip to
  `Expand All`.
- Episode header counts read as `N shioris` or `1 shiori`.
- Shiori Hit rows display saved cue text only. Like Search rows they no
  longer show the start timestamp.
- Shiori rows do not carry a query, so the keyword highlight tokens do not
  apply.
- Show row, Episode header, hover background, and selected background follow
  the same rules as Search.

Shiori may later introduce more sophisticated grouping rules. Any such change
will be a separate proposal.

## Acceptance Criteria

- Search results in the right-sidebar render under Show rows, with Episode
  headers inside expanded Shows and Hit rows inside Episode sections.
- Each Show row shows the Show title on the first line and a plain
  `N results` count on the second line.
- Each Episode header shows `Episode NN` on the left and a plain
  `N results` count on the right, without a chevron and without responding
  to hover.
- Hit rows do not render a start timestamp.
- The selected Hit row background uses the macOS system accent color and
  left-aligns with the Episode header text. The cue text inside that row is
  visually indented to the right of the background's left edge.
- Keyword highlights inside the selected row use the on-selected token.
- The Show row chevron rotates 0° ↔ 90° over 160 ms when toggled.
- The Library folder row chevron uses the same single-icon rotation.
- Top-bar controls (sidebar collapse / restore, Search / Shiori toggle) and
  panel slide animations are unchanged.
- Lazy-loading still uses a global 100 cue-group page budget. Expanding a
  Show or scrolling to the bottom of the visible rows behaves the same way
  it does today, with the rendered rows merely re-distributed under the
  Show / Episode tree.
- The Shiori panel renders the same Show → Episode → Hit hierarchy with
  Shiori-specific summary text and per-Episode counts.

## Decision

Adopt the Show → Episode → Hit three-level grouping in both Search and
Shiori panels, the row layout and selection rules described above, and the
unified Show / Library disclosure chevron animation.

Merge the accepted text into the affected product documents
(`02_functional_requirements.md`, `03_ui_design.md`, `04_ux_interaction.md`,
`08_search_interface_llm_brief.md`) and bundle the documentation update with
the implementation in a single commit, per the user's instruction.
