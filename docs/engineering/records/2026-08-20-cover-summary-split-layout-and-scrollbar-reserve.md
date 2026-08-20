# Requirement

- `docs/human/requirements/20260820-UI-Cover Summary Split Layout And Page Scrollbar Reserve.md`

# Scope

Unify the Workbench page inline padding against the page's vertical Scrollbar,
align the sidebar auto-collapse threshold and the table content box with the
page content minimum width, and change the shared Cover Summary into a split
form for wide widths and a 16:9 backdrop form for narrow widths.

# Architecture

- Platform UI/UX only: shared layout tokens and existing SwiftUI/AppKit layout
  ownership.
- Product semantics, persistence, cover generation, and playback execution are
  unchanged.
- No new state, cache, asynchronous lifecycle, or page-specific component is
  introduced.

# Steps

1. Page inline padding and Scrollbar channel.
   - Added `redesignWorkbenchPageScrollbarChannel` (Scrollbar size plus both
     insets) and `redesignWorkbenchPageTrailingPadding` (page padding plus the
     channel) to the shared control metrics.
   - Added the `workbenchPageInlinePadding()` view modifier so every Workbench
     page keeps equal visual left and right margins while reserving the channel
     on the trailing side at every width.
   - Applied the modifier to the Schema search shell, the Library page and
     folder detail, the Library overview layout, and the Data page.
   - Split `SubtitleTablePageChrome.horizontalInset` into `leadingInset` and
     `trailingInset` so the hosted table, its pinned chrome, and its header use
     the same content box, and passed the new page values from the Shiori
     detail page.

2. Sidebar auto-collapse threshold.
   - Derived `sidebarAutoCollapseWindowWidth` from the page content minimum
     width plus the sidebar width instead of the previous hard-coded 760, so the
     sidebar collapses exactly when keeping it would force page-level horizontal
     scrolling.

# Verification

- Step 1: `swift build` succeeds; `swift test` over the Workbench control
  metrics, page Scrollbar, Cover Summary, and virtual-row suites passes
  (104 tests).
- Step 2: `swift build` succeeds; the Workbench layout-state suite passes
  (12 tests), including a new assertion that the threshold equals the page
  content minimum width plus the sidebar width.

# Outcome

Steps 1 and 2 match expectations. Remaining steps pending.

# Follow-ups

- After owner visual acceptance, the human owner updates
  `docs/human/design/UI Design System.md` with the finalized tokens and rules.
