# Filter menu replaces the filter panel

Human-owned documents:

- `docs/human/requirements/20260826-UI-Filter Menu Replaces Filter Panel.md`

## Why

The in-page filter panel occupied a pinned band of the Search and Shiori detail
pages whether or not the reader was filtering. The requirement replaces it with
a menu hanging off a pure-icon filter button, so filtering borrows the page for
a moment instead of owning part of it.

## What changed

The filter button is the existing icon button with one new state: while its
menu is open it shows the macOS accent color behind a white glyph, expressed as
two new tokens rather than a reuse of the sidebar's. The old panel-trigger
toolbar button with label and chevron is gone from the redesign toolbar.

The menu itself is built on the existing menu machinery — highlight model,
placement, gate modality, height cap and inner scrollbar — with three new
content elements: a title row, a section header with the group's icon, and an
option row of circular checkbox, label and trailing count or calculating
placeholder. Titles, headers and dividers never enter the highlight order, so
opening highlights the first option, Duration's <1s, with no special case.
Checking applies immediately and leaves the menu open; the old Draft / Apply /
Cancel / Reset state machine is gone, matching what the implementation already
did. The panel's grid, card and pinned-height metrics were removed with it.

Two general menu rules were implemented in the shared highlight model:

- The wheel closes the hover-adoption gate the way a keyboard move does, so
  rows sliding under a stationary pointer cannot move the highlight; real
  pointer motion reopens it. A scrollbar drag never raises row hover at all,
  because the pointer stays on the scrollbar in the padding ring.
- Every keyboard move announces itself through a counter, and a scrolling menu
  answers by scrolling the new highlight into view — the filter menu is the
  first menu tall enough to need it.

Two pieces of plumbing were new. The menu's SwiftUI surface is hosted in the
existing menu hosting view, so a wheel its content does not spend stops there
instead of scrolling the page, and its scrollbar escapes the page-wide freeze
an open menu imposes. And because the Shiori detail pins its toolbar inside the
table's own hosting hierarchy, the button's frame travels to the page-level
menu host through a window-coordinate anchor probe instead of a SwiftUI
coordinate space, which cannot cross hosting boundaries.

The menu is measured when it opens and when its content changes, never during
a view update: measuring a hosting view inside body evaluation aborted in
AttributeGraph, found and fixed during in-app verification.

## Verification

Unit: the two new highlight-model rules, the menu model's element order,
default first option and immediate toggle, and the flipped default-closed
expectations. All suites touched by the change pass; the full run's failures
are the same environment-dependent families that fail on the unmodified
baseline, checked by running both trees.

In-app, driven through the debug E2E controller with screenshots: icon button
default, hover-free open state in accent and white; menu structure, section
icons, counts and calculating; default highlight on <1s; check and uncheck
applying immediately with the menu open; wheel scrolling the menu without
moving the highlight; outside click closing without reaching the page; the
button toggling its own menu closed; and the Shiori detail menu anchoring
correctly across the hosting boundary with live counts. Keyboard arrows, Enter
and scroll-follow could not be driven — the controller's key posting needs the
app active, which a background launch cannot obtain — so their visual pass is
left to acceptance; their logic is unit-covered.

Files:

- `Sources/CueSeekerApp/Shared/WorkbenchRedesignTokens.swift`
- `Sources/CueSeekerApp/Shared/MenuHighlightModel.swift`
- `Sources/CueSeekerApp/Shared/MenuAnchorProbe.swift` (new)
- `Sources/CueSeekerApp/Shared/WorkbenchControls/WorkbenchControls.swift`
- `Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/SchemaWorkbenchSearchShell.swift`
- `Sources/CueSeekerApp/TableSandbox/WorkbenchTestSearchView.swift`
- `Sources/CueSeekerApp/TableSandbox/WorkbenchShioriTableView.swift`
- `Tests/CueSeekerAppTests/MenuHighlightModelTests.swift`
- `Tests/CueSeekerAppTests/SearchStoreTests.swift`
- `Tests/CueSeekerAppTests/SettingsStoreSearchTests.swift`
- `Tests/CueSeekerAppTests/WorkbenchPageScrollbarTests.swift`

`CueFacetFilterPanel.swift` now holds the filter menu; the file name lags its
content and renaming is left to the owner.
