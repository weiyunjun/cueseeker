# Search Shiori Table Content Region Actions

## Human-Owned Source

- `docs/human/requirements/20260705-Feature-Search Shiori Table Content Region Actions.md`
- `docs/human/design/UI.md`

## Scope

Update the Search and Shiori result table so interactive text cells use the
same content hover region for visual hover, cursor feedback, left-click default
actions, and right-click action menus.

## Classification

- Product interaction: changes left-click behavior for Display Title, Cues,
  Time, and Date Added cells from opening menus to running each cell's default
  action.
- Product interaction: moves Row Action Menu opening to right-clicks inside the
  same content hover region.
- UI behavior: keeps non-hover table cell space non-interactive for cell
  actions and lets left-clicks there toggle row checkbox selection.
- UI behavior: extends underline hover feedback to Display Title, Time, and
  Date Added interactive text cells.

## Changes

- Restricted interactive cursor rects, hover hit-testing, left-click actions,
  and right-click menus to each interactive cell's content hover rectangle.
- Added right-click handling for table body cells and routed it to the existing
  Row Action Menu content for the triggering column.
- Changed left-click handling inside interactive content regions to run the
  documented default action:
  - Cues: play the row.
  - Display Title: open the subtitle file in Finder.
  - Time and Date Added: copy the displayed cell text.
- Changed left-click handling outside interactive content regions to toggle row
  checkbox selection.
- Positioned body Row Action Menus below the right-click pointer position and
  clamped the menu to the visible container bounds.
- Updated virtual table tests to assert content-region-only cursor rectangles,
  left-click default actions, right-click menu opening, click-position menu
  anchoring, and non-content selection toggling.

## Verification

- `git diff --check`
- `swift build`
- `swift test --filter SubtitleTableVirtualRowTests`
- `swift test`

## Outcome

Search and Shiori table body interactions now match the documented content
region contract: the visible hover region is the only cell action region, left
click performs the default action, right click opens the matching Row Action
Menu below the click point, and non-hover cell space toggles row selection.
