# E2E Variable Scene Coordinate Contract

## Requirement

- `docs/human/requirements/20260820-Engineering-E2E Variable Scene Coordinate Contract.md`

## Scope

- Correct the Debug in-app E2E documentation contract only.
- Keep product UI, product behavior, and the E2E controller unchanged.

## Steps

- Removed the fixed scene geometry from the example ready record.
- Allowed test procedures to derive coordinates from `inspect` window bounds
  and documented layout offsets.
- Replaced fixed Cover Summary edges and the fixed scroll point with
  main-window-relative formulas.
- Updated the Sidebar contract for the current Library, Data, and Shiori order.
- Added Data to the existing Workbench topbar and page-title visual gate.

## Verification

- Ran the Debug in-app E2E controller in the actual `1445 x 821` logical-point,
  `2x` scene.
- Opened and captured Shiori List Detail, Library Overview, Library Folder
  Detail, and Data using the updated coordinates.
- Scrolled and restored Library Folder Detail at the documented
  window-relative safe point.
- Every `inspect`, `click`, `capture`, and `scroll` command returned
  `status: ok` with a fresh scene identifier where required.
- Restored the expanded-Sidebar Shiori Overview before terminating the Debug
  process.

## Outcome

- The current scene completes the Library and Shiori detail capture path
  without a fixed size or scale prerequisite.
- Sidebar navigation and content-bound checks now follow the current layout.
