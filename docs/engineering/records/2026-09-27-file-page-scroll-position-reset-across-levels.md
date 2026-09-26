# File page scroll position reset across levels

Human-owned documents:

- `docs/human/requirements/20260927-Bug-File Page Scroll Position Reset Across Levels.md`
- `docs/human/requirements/20260926-UI-File Page Three Level Card Redesign.md`

## Why

In `WorkbenchFileView`, a single `WorkbenchScrollView` was placed at the root of the view body wrapping the route conditional `switch`. Because the outer scroll view was shared across the three levels without route identity isolation, the underlying AppKit `NSScrollView` maintained its existing vertical scroll offset across drill-downs (e.g. scrolling to the bottom of Level 2 and clicking a folder resulted in Level 3 opening already scrolled down instead of starting at the top).

## What changed

- **Scoped scroll containers**: Moved `switch routeState.currentRoute` outside the scroll view so each level (Level 1 Roots, Level 2 Subfolders, Level 3 Files) creates its own independent scroll surface.
- **Route identity binding**: Implemented `fileScrollSurface(id:content:)` which binds the active route/folder identifier (`rootPath`, `folderPath`) as `.id(id)` on the scroll view, ensuring that entering any level or switching between distinct folders always mounts a clean scroll view starting at `(0, 0)`.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Library/WorkbenchFileView.swift`

## Verification

- `swift build --package-path apps/macos-native`: succeeded with 0 errors.
- `swift test --package-path apps/macos-native --filter FileRouteNavigationTests`: 1 test passed.
- `swift test --package-path apps/macos-native --filter WorkbenchScrollViewTests`: 6 tests passed.
