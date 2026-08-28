# Shiori FIFO Ordering And New List Destination

## Requirement

- `docs/human/requirements/20260829-UI-Shiori FIFO Ordering And New List Destination.md`
- `docs/human/design/UI Design System.md`
- `docs/human/design/Toast Usage Registry.md`

## Classification

- Product semantics: the order Shiori lists and saved cues are presented in,
  and which list a playback save defaults to.
- Platform UI/UX: the destination submenu's New List item.
- Persistence, platform integration, and playback execution are unchanged.

## Implementation

- Reversed the four Shiori ordering queries that back the list overview, the
  list catalogue, the first-list lookup, and the table's relations, so lists
  and saved cues now run oldest first. Everything downstream of the relation
  order — search, filters, Anki export, Copy Table, the playlist a table opens,
  and the Recent resume position — follows without further change.
- Reversed the matching in-memory insert sort, so a list created while the
  overview is on screen lands in the same place a reload would put it.
- Swapped the adjacent-Shiori query's previous and next branches, keeping the
  database navigation fallback aligned with the table order.
- No migration was needed: the order is a query concern, so every existing list
  changes with the first read.
- Added New List to the end of the destination submenu, with a divider above it
  when other lists exist. It reuses the Shiori overview button's string, so no
  new copy was introduced.
- Dropped the rule that disabled Move to and Duplicate to when no other list
  exists. The requirement repeals it, and keeping it would make New List
  unreachable in exactly the case it exists for. An unavailable Shiori still
  disables both.
- Carried the interrupted transfer on the list editor session. On a successful
  create the coordinator runs the original move or duplicate against the new
  list, reusing the existing transfer paths and therefore the registered
  toasts. Cancelling creates nothing and runs nothing, and the new list is kept
  whether or not the transfer succeeds.
- Recorded both user-visible changes in the Unreleased changelog.

## Verification

- `swift build`: passed.
- Added `subtitleTableShioriSubmenuReachesNewListWithoutOtherLists`, covering
  the submenu opening with no other list and the keyboard reaching New List.
- Updated the ordering expectations in `ShioriDatabaseTests`,
  `ShioriPresentationTests`, `ShioriListEditorTests`, and
  `PlaybackEntryAndShioriNavigationTests`, and replaced the menu test that
  encoded the repealed disable rule.
- Repointed one submenu geometry assertion: the taller submenu now covers the
  point that test used as "outside both menus".
- Debug in-app E2E controller: confirmed the overview cards and sidebar in
  oldest-first order, the table's Date Added column ascending, the submenu
  showing the other lists then a divider then New List, the New List dialog
  opening from it, and a create running the pending move with the registered
  `Moved to "…"` toast while the view stayed on the current list.
- `swift test`: the native playback suite and two
  `CueGroupRefreshScopeIntegrationTests` cases fail. Both reproduce on the
  unmodified tree and are unrelated. Several Library removal, Debug E2E
  controller, and refresh-scope cases fail only in the full parallel run and
  pass in isolation, as before this change.
- Existing automation was sufficient; no new end-to-end capability was needed.

## Outcome

- Shiori lists and saved cues read oldest first everywhere they are listed, and
  a playback save defaults to the first card.
- Move to and Duplicate to always offer New List, and creating a list from
  there completes the transfer the user started.
