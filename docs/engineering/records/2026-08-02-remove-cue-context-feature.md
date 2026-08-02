# Remove Cue Context Feature

## Requirement

- `docs/human/requirements/20260802-Feature-Remove Cue Context Feature.md`
- `docs/human/design/UI.md`

## Classification

- Product semantics: removes the Cue Context feature and every user-facing
  `Context` action from the Workbench.
- Platform UI/UX: removes the Search-hosted Context table mode while preserving
  native right-click context-menu infrastructure.
- Playback execution: unchanged. Playback Return Context and action execution
  context remain intact.
- Persistence and migration: unchanged; the removed feature owned no durable
  user data that requires a compatibility path.

## Scope

- Removed Cue Context request, projection, paging, cancellation, and viewport
  restoration state from `SearchStore`.
- Removed the dedicated database page query and unused first-Cue lookup.
- Removed Search, Shiori, Recent, and Library Context entry points and menu
  actions.
- Removed Context-specific table probe ownership, callbacks, presentation
  branches, row-store prepend/append helpers, and dedicated tests.
- Kept the generic right-click menu hosts and row-menu interaction pipeline.
- Kept Playback Return Context and Playback action execution context.
- Updated current product and engineering documents without rewriting
  historical implementation records or human-owned documents.

## Verification

- `swift test --package-path apps/macos-native`: compiled successfully and ran
  941 tests; the full concurrent run reported 22 issues in unrelated native
  playback timing/presentation, Library folder removal, Subtitle Focus timing,
  and UI probe tests.
- Focused removal and regression run: 25 tests passed, including Search/Shiori
  menu models, row-menu dispatch, Library selection-mode behavior, Search
  projection state, URL Scheme Cue playback, and the serialized Cue-table
  refresh-scope suite.
- Residual source scan found no Cue Context request, query, table mode, action,
  callback, or menu-title references. Generic context-menu and Playback context
  references remain intentionally.
- `swift build --package-path apps/macos-native`: passed.
- `git diff --check`: passed.

## Outcome

Cue Context is no longer a product feature or implementation path. Workbench
menus contain no `Context` item, and no replacement state or abstraction was
introduced. Unrelated technical uses of context continue under their existing
owners.
