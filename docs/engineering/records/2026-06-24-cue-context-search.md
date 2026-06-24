# Cue Context Search

## Requirement

- Human-owned requirement: `docs/human/requirements/20260624-Feature-Cue Context Search.md`

## Scope

- Added a technical-validation Context action to the Search and Shiori cue row action menus.
- Kept the change in the macOS UI/Search coordination path, with durable cue identity and first-screen context window loading handled through `CueSeekerCore`.
- The target cue is shown as the first row when enough following rows exist; near the end of a subtitle file, the window shifts upward so the target stays as early as possible.
- The Context view reports an exact virtual row count immediately after the first page, while only hydrating the rows needed for the visible table.
- Did not add row highlighting or selection after navigation; this remains a later interaction refinement.

## Steps

- Added a Cue Context Search request model to the Search store.
- Added AppCoordinator entry points for Search-result and Shiori-originated Context actions.
- Added Core helpers to resolve a cue group from Shiori timing and load a target-anchored context page from the current subtitle file.
- Removed the previous all-cue rank lookup and table scroll request path so the Search table can render the initial context window directly.
- Added Context-specific cursor handling so the first page hydrates 50 rows from the anchor, reports the exact remaining context count, and maps later table ranges back to the same subtitle-file offset.
- Kept normal filter-only loading separate from Context loading so manual filter edits return to the existing all-cue virtual table behavior.
- Added `Context` to the cue row action menu with the `doc.text` SF Symbol.
- Wired Search and Shiori table rows to emit the Context action.

## Verification

- Added Core tests for exact cue-group lookup, target-first context windows, exact virtual totals, continuation cursors, and near-tail context windows.
- Ran `swift test` from `apps/macos-native`.

## Outcome

- Cue Context Search technical validation is implemented. Search and Shiori cue
  row menus can request a filtered Search view with an empty query and a single
  Display Title filter. Search renders the target-anchored first-screen context
  window, immediately reports the exact virtual row count, and hydrates later
  visible ranges through the same Context offset without selecting or
  highlighting the target cue.

## Follow-ups

- Later UX work may add row highlighting, temporary focus, or another arrival affordance after the technical path is accepted.

## 2026-06-25 Performance Instrumentation Follow-up

### Requirement

- Human-owned requirement: `docs/human/requirements/20260624-Feature-Cue Context Search.md`

### Steps

- Added a gated Cue Context performance logger for the technical validation path.
- Recorded Context request creation, Search panel selection, Search view request application, Context page DB return, first-page load return, row-store commit, first hydration scheduling, and visible-row callbacks under a shared Context request ID.
- Added a generic table `updateNSView` timing event to the existing table-rendering performance log so the Context timeline can be aligned with table update cost.
- Kept the instrumentation disabled unless `CUESEEKER_PERF_CONTEXT`, `CUESEEKER_PERF_SEARCH`, or `CUESEEKER_PERF` is enabled.

### Verification

- Ran `swift build` from `apps/macos-native`.
- Ran `swift test --filter 'cueContextSearchPage|SearchStore|SubtitleTableVirtualRow|TableSandboxRowModelStore'` from `apps/macos-native`; 39 Swift Testing tests passed.

### Outcome

- Cue Context now has a focused performance timeline written to `logs/cue-context/` when enabled, while table update timings continue to be written to `logs/table-rendering/` through the existing table logger.
- No product behavior change is intended by this follow-up.

## 2026-06-25 Complete Context Window Follow-up

### Requirement

- Human-owned requirement: `docs/human/requirements/20260624-Feature-Cue Context Search.md`

### Steps

- Corrected Cue Context paging so the virtual result keeps the complete target subtitle file instead of truncating rows before the target cue.
- Kept the first Context page anchored at the target cue, shifting upward near the tail, while later hydration ranges load by their real full-file row indexes.
- Changed the Search table Context path to hydrate the initial anchored page sparsely at its real row index and then scroll the virtual table to that row.
- Added a table scroll target row parameter and test coverage so a reset can land on a specific virtual row instead of only the top.
- Kept the Context performance instrumentation in place to measure the corrected flow.

### Verification

- Ran `swift build` from `apps/macos-native`.
- Ran `swift test --filter 'cueContextSearchPage|SubtitleTableVirtualRow|TableSandboxRowModelStore|SearchStore'` from `apps/macos-native`; 40 Swift Testing tests passed.
- Ran a read-only micro-benchmark against the live CueSeeker SQLite database. On the largest scoped subtitle file, target lookup averaged about 1.6 ms and 50-row page loads around the anchor averaged about 0.25 ms.

### Outcome

- Context now preserves the complete subtitle file in the virtual table, including rows before the target cue.
- The initial screen still starts at the target cue when possible and reports the full exact row count.
- Current database timings indicate that any remaining multi-second delay should be investigated in the UI/view lifecycle timeline rather than the Context SQL page query.
