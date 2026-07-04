# Library Card Context Menus

## Human-Owned Source

- `docs/human/requirements/20260704-Feature-Library Card Action Menus.md`
- `docs/human/design/UI.md`

## Scope

Add the documented right-click context menus to Recent Watching cards,
Complete Library folder cards, and Complete Library episode rows. The previous
cover `...` action button and system popover implementation is removed so
Library card behavior matches the shared Row Action Menu interaction model.

## Classification

- Product semantics: Library video identity, folder identity, subtitle identity,
  and watch-state meanings remain unchanged.
- Platform UI/UX: uses card hover regions for right-click context menus, shared
  Row Action Menu styling, card tap routing, and cover hover scale behavior
  documented for the Library cards.
- Platform integration: added Finder reveal/open actions and Library Context
  entry points from the card menus.
- Playback execution: unchanged; card and episode row clicks still call the
  existing Library playback path.

## Changes

- Removed the Library cover `...` action button, its token constants, and all
  SwiftUI `.popover` usage from the Library card menus.
- Reworked Recent Watching, Complete Library folder cards, and Complete Library
  episode rows to open context menus from right-clicks inside the active hover
  region without triggering the primary left-click action.
- Added a reusable Library context-menu host that positions
  `WorkbenchPopoverPanel` and `WorkbenchPopoverRow` content at the right-click
  point, clamps the menu to the visible card-grid bounds, and avoids system
  popover arrows.
- Removed the Complete Library episode row Play button and made the row tap
  open the video instead, matching Recent Watching playback behavior.
- Updated the Complete Library episode row hover background, cover hover effect,
  pointer cursor, and list item gap to match the documented card interaction.
- Added menu actions for Open Folder, Mark as Finished, Mark as Unwatched, Mark
  as Watching, and Context according to each card type, using the documented
  `doc.text` Context symbol.
- Reused the existing Library watch-state and first-cue Context actions; the
  watch-state storage/progress separation is tracked in the dedicated
  watch-state regression record.

## Verification

- `git diff --check`
- `swift build`
- `swift test --filter libraryCoverProgressPresentationKeepsFinishedProgressAtSavedPosition`
- `swift test --filter recentPlaybackNavigationPreparesSameFolderEpisodes`
- `swift test`

## Outcome

Recent Watching, Complete Library folder, and Complete Library episode cards now
use right-click Library Card Context Menus backed by the shared Row Action Menu
views. The previous `...` buttons and system popover arrows are removed.
Complete Library episode rows now match the other Library card surfaces for
left-click playback, hover feedback, pointer cursor behavior, and context-menu
entry.
