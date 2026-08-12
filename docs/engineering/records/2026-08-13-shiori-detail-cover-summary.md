# Requirement

- `docs/human/requirements/20260812-Feature-Shiori Detail Cover Summary.md`
- `docs/human/design/UI Design System.md`

# Scope

Implement the first visual-tuning version of the reusable cover summary on the
Shiori detail page. Keep the existing toolbar, table, and playback behavior.
Do not connect the component to other pages in this change.

# Steps

1. Added a shared cover summary component with centralized provisional tokens.
2. Loaded the active list name, description, cover, and recent-playback state
   from the existing Shiori overview projections.
3. Reused the existing recent-playback path and added the same list-level path
   for playing the first valid cue when no recent cue exists.
4. Inserted the summary above the existing Search, Filter, and Select toolbar.
5. Added focused tests for 16:9 geometry, left alignment, compact-width
   clipping, and active-list recent-state projection.
6. Kept the new dimensions in one provisional token block so visual iterations
   change one source of truth before the accepted values are documented.
7. Extended the existing virtual table scroll container to own the Shiori
   detail page chrome, so the cover scrolls away while the toolbar, optional
   facet panel, and table header pin as one stack.
8. Moved the table scrollbar overlay to the full Shiori main viewport and
   included the cover in the existing table document extent without adding a
   second scroll-position source.
9. Replaced the fixed-width surface fade with a stronger tokenized surface
   gradient sized to the live intersection between the cover and the fixed
   text-safe region. The gradient runs top-to-bottom so each text line has
   consistent contrast; no overlap leaves the cover fully clear.
10. Applied the shared summary radius directly to the cover so it keeps four
    matching corners independently of the outer card clip.
11. Anchored the fixed-width metadata card directly after the left cover when
    space permits. Both regions own their four-corner clipping, while the outer
    layout remains transparent and borderless.
12. Set both regions to 448 × 252 points and replaced progressive overlap with
    two states: attached at 896 points or wider, and fully aligned below that
    threshold.
13. Composited the cover and compact-state gradient before applying one shared
    rounded mask, preventing color from leaking through two independently
    antialiased corner edges.

# Verification

- `swift test --filter 'CoverSummaryCardTests|ShioriPresentationTests|WorkbenchControlMetricsTests|LibraryCoverFrameTests'`
- `swift test --filter 'SubtitleTableVirtualRowTests|SubtitleTableScrollbarMetricsTests|CoverSummaryCardTests'`
- `swift test --filter CoverSummaryCardTests`
- Final visual acceptance for the overlap blend and four-corner cover treatment
  is deferred to the owner; no final Debug E2E capture is required for this
  tuning iteration.
- Actual-app Light and Dark captures used list 5's current database name,
  description, stored cover, recent state, and 28-row result projection.
- A full `swift test` run was also executed. The new and focused tests passed;
  the aggregate run remained red with unrelated pre-existing/global-state and
  native-playback timing failures, including `ApplicationPersistenceTests`,
  `DebugE2EControllerTests`, and native media timeline tests.

# Outcome

The Shiori detail page now presents real list metadata beside its real stored
cover as two attached rounded regions. The cover remains 16:9 and left-aligned;
the matching metadata card switches directly from an attached position to full
overlap at compact widths using the surface-to-image blend. The page now has one
vertical scroll model: the cover leaves the viewport, the search/filter stack
and table header stay pinned, and the unified custom scrollbar tracks the full
Shiori viewport at its right edge.

# Follow-ups

- Continue owner-directed visual tuning in small commits.
- After visual acceptance, the human owner will update
  `docs/human/design/UI Design System.md` with the accepted component tokens and
  rules.
