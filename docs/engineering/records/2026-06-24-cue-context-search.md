# Cue Context Search

## Requirement

- Human-owned requirement: `docs/human/requirements/20260624-Feature-Cue Context Search.md`

## Scope

- Added a technical-validation Context action to the Search and Shiori cue row action menus.
- Kept the change in the macOS UI/Search coordination path, with durable cue identity and row-rank lookup handled through `CueSeekerCore`.
- Did not add row highlighting or selection after navigation; this remains a later interaction refinement.

## Steps

- Added a Cue Context Search request model to the Search store.
- Added AppCoordinator entry points for Search-result and Shiori-originated Context actions.
- Added Core helpers to resolve a cue group from Shiori timing and to compute the filtered all-cue row rank for a target cue group.
- Added a shared table scroll request so the Search table can scroll to the target row without selecting it.
- Added `Context` to the cue row action menu with the `doc.text` SF Symbol.
- Wired Search and Shiori table rows to emit the Context action.

## Verification

- Added Core tests for exact cue-group lookup and filtered all-cue rank resolution.
- Ran `swift test` from `apps/macos-native`.

## Outcome

- Cue Context Search technical validation is implemented. Search and Shiori cue
  row menus can request a filtered Search view with an empty query and a single
  Display Title filter, and Search can load and scroll to the target cue row
  without selecting or highlighting it.

## Follow-ups

- Later UX work may add row highlighting, temporary focus, or another arrival affordance after the technical path is accepted.
