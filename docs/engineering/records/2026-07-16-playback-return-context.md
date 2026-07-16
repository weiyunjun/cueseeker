# Playback Return Context

## Requirement

- `docs/human/requirements/20260715-Feature-Shared Workbench Playback Feature Surfaces.md`

## Scope

Implement the four reviewed Playback Return Context targets and keep that
context alive across multiple Overlay Sessions on the same Playback Page.

## Steps

1. Replaced the panel-mode-only origin with an explicit Return Context for
   Search, Shiori, Recent, and Library Folder Detail.
2. Initialized the context from the Workbench Feature that opened the Playback
   Page without copying any Feature data or query snapshot.
3. Updated the context after successful Search, Shiori, Recent, or Library
   playback only; failed playback and presentation-only actions retain the
   previous context.
4. Identified Library Folder Detail by folder path so closing Playback can
   restore the specific Workbench detail and hydrate its shared data.
5. Restored the current Search query through the shared Search Store and
   destroyed the Return Context after Playback closes.

## Verification

- Focused Return Context, Playback Search, URL Scheme Search, and Playback
  keyboard-action tests passed: 25 tests.
- `git diff --check` passed.
- The full 735-test suite reached one pre-existing isolation failure in
  `ApplicationPersistenceTests`: its unique `UserDefaults` suite sees the
  process-registered `workbenchPanelMode` value after other tests run. The same
  test passes in isolation; no Return Context test failed.

## Outcome

The Playback Page now retains exactly one explicit Return Context. Only a later
successful playback replaces it, and closing Playback returns to the current
state of the corresponding Workbench Feature without retaining a second
Feature-state copy.
