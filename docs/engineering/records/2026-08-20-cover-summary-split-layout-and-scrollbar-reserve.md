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

3. Cover Summary split and backdrop forms.
   - Replaced the single fixed-height Cover Summary layout with two forms
     resolved from the available width: a split form that locks the cover at its
     token size with the content column beside it, and the existing backdrop
     form whose card height now follows the shared 16:9 cover aspect ratio.
   - Added `CoverSummaryCardLayout.height(forCardWidth:)` and made
     `SubtitleTablePageChrome.scrollableHeaderHeight` a function of the chrome's
     own content width, so the Shiori detail page scroll geometry follows the
     width-dependent card height.
   - Retired the fixed `redesignCoverSummaryHeight` token.
   - The split form uses the primary text colours and `WorkbenchPrimaryButton`;
     the backdrop form keeps the scrim, white text, and translucent action, and
     now lays its content out at its natural height from the top instead of
     stretching to the card height.
4. Cover placeholder flash across a form change.
   - The two forms were written as branches of one `switch`, so crossing the
     switch width tore down the whole subtree, including the cover. The rebuilt
     cover started with no decoded image and showed its placeholder for a few
     frames while it re-read the cache.
   - Restructured the card so a single cover instance serves both forms and only
     its size, corner radius, and scrim change, which preserves the cover's view
     identity across a width change.

5. Backdrop-form height and content padding.
   - Owner review found the `180 -> 373` card-height step at the switch width
     too abrupt. Replaced the width-tracking backdrop height with a fixed one
     derived from new tokens: the backdrop block padding above and below a
     content column as tall as the split form's cover.
   - The card height now steps once between `180` and `225` instead of tracking
     the width, and the text and action area keeps the same height across a form
     change, so the action stays at its bottom-leading corner in both forms.
   - Both forms now share one content-column height, which removed the optional
     content height and the form-conditional spacer from the card view.

# Verification

- Step 1: `swift build` succeeds; `swift test` over the Workbench control
  metrics, page Scrollbar, Cover Summary, and virtual-row suites passes
  (104 tests).
- Step 2: `swift build` succeeds; the Workbench layout-state suite passes
  (12 tests), including a new assertion that the threshold equals the page
  content minimum width plus the sidebar width.
- Steps 3 and 4: `swift build` succeeds; the Cover Summary, Workbench control
  metrics, Workbench layout-state, and table virtual-row suites pass
  (112 tests), covering both forms, the switch width, the card height function,
  and the narrowest presentable card width.
- Pre-existing failures unrelated to this change: two `DebugE2EController`
  scene tests and two `CueGroupRefreshScopeIntegration` tests fail on the
  unchanged baseline as well, and the native playback timeline tests live in a
  different target and need real decode and audio output.

- Step 5: `swift build` succeeds; the same four suites pass (113 tests),
  including new assertions that the backdrop height is fixed at every width,
  that it equals the cover's own 16:9 height at the narrowest card, and that
  both forms resolve the same content-column height.

# Outcome

Steps 1 through 5 match expectations in build and tests. The visual result is
pending owner acceptance in the real Debug client.

# Follow-ups

- After owner visual acceptance, the human owner updates
  `docs/human/design/UI Design System.md` with the finalized tokens and rules.
