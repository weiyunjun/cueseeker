# App Topbar Layout Dark Mode

## Human-Owned Source

- `docs/human/requirements/20260622-Feature-App Sidebar Navigation Redesign.md`

## Scope

Implement the documented App Topbar Layout follow-up for the non-player
workbench chrome.

## Classification

- Platform UI/UX: the non-player topbar is now a reusable layout with explicit
  topbar background, sidebar segment, title slot, and sidebar toggle slot.
- Platform integration: dynamic AppKit titlebar background colors now resolve
  against the current effective appearance.
- Product semantics: unchanged.
- Playback execution: unchanged; the player keeps its own topbar behavior.

## Changes

- Added native tokens for `--color-app-topbar-bg`, `--height-app-topbar`,
  `--gap-app-topbar-title-after-toggle`, and
  `--padding-app-topbar-title-x`.
- Extracted the non-player topbar structure into `AppTopbarLayout`.
- Switched the non-player titlebar background from `.textBackgroundColor` to
  the documented topbar background token.
- Preserved light mode values while adding the dark mode topbar background.
- Updated the titlebar background bridge to re-resolve dynamic colors when the
  effective appearance changes.
- Routed existing underline and media-card pressed values through their
  documented redesign tokens without changing the values.

## Verification

- `swift build` passed.
- `swift test` passed with 324 tests.
- `git diff --check` passed.
- Residual search confirmed `.textBackgroundColor` remains only in content
  surfaces, not in the non-player App topbar.

## Outcome

The non-player workbench topbar now has a shared layout boundary and an explicit
dark-mode background token while retaining the existing light-mode dimensions
and spacing.
