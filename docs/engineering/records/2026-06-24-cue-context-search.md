# Cue Context Search

## Requirement

- Human-owned requirement: `docs/human/requirements/20260624-Feature-Cue Context Search.md`

## Scope

- Added a technical-validation Context action to the Search and Shiori cue row action menus.
- Kept the change in the macOS UI/Search coordination path, with durable cue identity and first-screen context window loading handled through `CueSeekerCore`.
- The target cue is shown as the first row when enough following rows exist; near the end of a subtitle file, the window shifts upward so the target stays as early as possible.
- Did not add row highlighting or selection after navigation; this remains a later interaction refinement.

## Steps

- Added a Cue Context Search request model to the Search store.
- Added AppCoordinator entry points for Search-result and Shiori-originated Context actions.
- Added Core helpers to resolve a cue group from Shiori timing and load a target-anchored context page from the current subtitle file.
- Removed the previous all-cue rank lookup and table scroll request path so the Search table can render the initial context window directly.
- Added `Context` to the cue row action menu with the `doc.text` SF Symbol.
- Wired Search and Shiori table rows to emit the Context action.

## Verification

- Added Core tests for exact cue-group lookup, target-first context windows, and near-tail context windows.
- Ran `swift test` from `apps/macos-native`.

## Outcome

- Cue Context Search technical validation is implemented. Search and Shiori cue
  row menus can request a filtered Search view with an empty query and a single
  Display Title filter, and Search can render the target-anchored first-screen
  context window without selecting or highlighting the target cue.

## Follow-ups

- Later UX work may add row highlighting, temporary focus, or another arrival affordance after the technical path is accepted.
