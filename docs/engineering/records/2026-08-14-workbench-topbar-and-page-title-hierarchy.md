# Requirement

- `docs/human/requirements/20260814-Feature-Workbench Topbar And Page Title Hierarchy.md`
- `docs/human/design/UI Design System.md`

# Scope

Make the non-Sidebar Workbench topbar one shared Back-only function region,
move page titles below it, unify the six explicit page titles with the Cover
Summary title hierarchy, preserve the smaller Recent overview section titles,
unify the six titled-page boundaries, and reduce Library and Shiori detail top
spacing by 20 points.

# Architecture

- Platform UI/UX: one stateless page-title component and one shared Back control
  render from the existing route state.
- Navigation: the existing Recent, Library, and Shiori route clear actions remain
  the only owners of detail-to-overview transitions.
- Visual values use shared Workbench semantic colors, typography metrics, and
  page-boundary spacing metrics. No persistence, asynchronous lifecycle, cache,
  data model, dependency, or new E2E capability was added.

# Steps

1. Replaced route-specific topbar titles and detail headers with one shared Back
   button, Disabled on primary pages and Enabled on the four supported details.
2. Added a stateless 28-point Bold page-title component with optional 18-point
   Regular Secondary count text and monospaced digits.
3. Added the shared title to Search, Recent, Library, and Shiori overviews and
   to Recent Videos and Recent Shioris details. The Recent overview's existing
   18-point Semibold section headers and 14-point counts remain unchanged.
4. Unified the six titled pages on shared 32-point horizontal, 4-point top, and
   24-point bottom page bounds for title, Summary, action, Grid, and List.
5. Kept Library and Shiori detail identity inside Cover Summary, with no second
   page title, and changed both shared detail top paddings from 24 to 4 points.
6. Renamed topbar layout metrics from title-specific to content-specific names
   and removed the obsolete route-title and detail-header implementations.
7. Added focused route-state and shared-metric tests and documented the updated
   known-coordinate visual gate.

# Verification

- `swift test --filter 'WorkbenchLayoutState|workbenchPageTitle'` passes 11
  focused route and metric tests.
- `swift build -c release --product CueSeeker` passes.
- Debug in-app E2E passed in a real `1443 x 821`-point, `2x` window. Light Mode
  captures covered all eight affected routes, Back Disabled/Enabled behavior,
  both 18-point Recent detail counts, unchanged 14-point overview counts, shared
  page bounds, and Library/Shiori Cover Summary placement.
- Light Mode also passed Library primary/detail with the Sidebar collapsed. Dark
  Mode sampled the shared Shiori primary and Cover Summary detail hierarchy,
  after which the original Light appearance was restored.
- The existing click, capture, and appearance controls were sufficient; no new
  automated E2E capability was required.
- Default parallel `swift test` ran 1001 tests and reported 28 unrelated shared
  window, database I/O, native playback timing, and table-mount issues. Serial
  `swift test --no-parallel` reduced this to the existing shared-default
  migration expectation and two Shiori table-mount waits. The migration test
  passed alone; both Shiori waits reproduced alone. None of these failures
  exercises the changed topbar, title, route predicate, or spacing paths.
- `git diff --check` passes.

# Outcome

Workbench now has one predictable function topbar and one page-title hierarchy.
Primary pages and Recent details share the Cover Summary's 28-point Bold title
scale without forcing White text. Their content now follows one 32/4/24-point
page boundary, detail counts use 18 points while Recent overview counts remain
14 points, and Cover Summary details reclaim 20 points of vertical space.

# Follow-ups

- The human owner will update `docs/human/design/UI Design System.md` after
  visual acceptance, as required by the current requirement. This implementation
  intentionally does not edit `docs/human/`.
- After acceptance, synchronize the derived topbar and page-title mappings in
  the relevant product UX documentation.
