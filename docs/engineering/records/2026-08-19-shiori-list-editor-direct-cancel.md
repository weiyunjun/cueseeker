# Shiori List Editor Direct Cancel

## Requirement

- `docs/human/requirements/20260819-UI-Edit List Inline Unsaved Changes Confirmation.md`

## Classification

- macOS platform UI/UX only.
- Product semantics, persistence, platform integration, and playback execution
  are unchanged.

## Implementation

- Removed the Shiori List Editor unsaved-changes confirmation state and the
  Save Changes overlay.
- Connected `Cancel` directly to the existing close action for both Edit List
  and New List.
- Kept the existing `Save` and `Create` validation, error, and persistence
  paths unchanged.
- Left all other confirmation dialogs unchanged.
- Recorded the user-visible cancellation change in the Unreleased changelog.

## Verification

- `swift test --filter ShioriListEditor`: passed 2 tests and compiled the
  affected App target.
- `swift build -c release --product CueSeeker`: passed.
- Source search confirmed that Shiori List Editor no longer contains
  `Don't Save` or `Save Changes` UI.
- Existing automation was sufficient; no new end-to-end capability was needed.
- `git diff --check`: run before commit.

## Outcome

- `Cancel` now immediately discards the current Shiori List Editor session and
  closes both Edit List and New List without another interface.
