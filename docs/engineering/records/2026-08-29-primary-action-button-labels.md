# Primary Action Button Labels

## Requirement

- `docs/human/requirements/20260829-UI-Primary Action Button Labels.md`
- `docs/human/design/UI Design System.md`

## Classification

- macOS platform UI/UX only.
- Product semantics, persistence, platform integration, and playback execution
  are unchanged.

## Implementation

- Pointed the Library Overview action at the existing
  `settings.library.add_folder` string so the page and the Settings entry point
  it opens share one label in English, Simplified Chinese, and Traditional
  Chinese.
- Removed the plus icon from the Library Overview and Shiori List Overview
  primary buttons. Button's Leading Icon is already optional in the design
  system, and neither Overview Layout declares an icon, so the buttons now
  match the accepted documents.
- Removed the shared Overview Layout's `actionSystemImage` parameter, which had
  no remaining caller, and the orphaned `library.add_content` string from all
  three catalogs.
- Updated the `Add Content` references in `04_architecture_rules.md` and the
  `08_end_to_end_testing.md` Library step to the new label. Historical
  implementation records keep their original wording.
- Recorded the user-visible label change in the Unreleased changelog.

## Verification

- `swift build`: passed.
- `swift test --filter WorkbenchPageScrollbar`: passed 4 tests.
- `swift test --filter ShioriPresentation`: passed 4 tests.
- `swift test --filter ShioriListEditor`: passed 2 tests.
- Debug in-app E2E controller: captured the Library and Shiori level-one pages
  and confirmed `Add Folder` and `New List` render without a plus icon and keep
  their position and style.
- `swift test`: `CueGroupRefreshScopeIntegrationTests`,
  `NativePlaybackMediaTimelineTests`, and `NativePlaybackPresentationTransitionTests`
  fail. The same failures reproduce on the unmodified tree, so they are
  pre-existing and unrelated to this change. `LibraryFolderRemovalTests` and
  `DebugE2EControllerTests` fail only in the full parallel run and pass in
  isolation.
- Existing automation was sufficient; no new end-to-end capability was needed.

## Outcome

- Library Overview shows `Add Folder` and Shiori List Overview shows
  `New List`, both without a plus icon, with unchanged position, style, states,
  and actions.
