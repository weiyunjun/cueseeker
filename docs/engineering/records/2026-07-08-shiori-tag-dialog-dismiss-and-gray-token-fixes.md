# Shiori Tag Dialog Dismiss and Gray Token Fixes

Date: 2026-07-08

Human-owned coverage:

- `docs/human/requirements/20260708-Feature-Shiori Tag Column And Popover.md`
- `docs/human/design/UI.md`

## Implementation

- Added a narrow table menu dismiss-suspension path so the centered Delete Tag confirmation dialog can receive clicks without causing the underlying Shiori Tag Popover to dismiss.
- Kept the existing external popup layer behavior unchanged; that path still closes table menus when a broader workbench popup covers the table.
- Mapped redesign `.gray` tag colors to the Shiori tag tokens: `--color-bg-hover` and `--color-text-secondary`.
- Added regression coverage for the suspended outside-click dismiss behavior and the gray redesign token mapping.

## Verification

- `swift test --filter SubtitleTableVirtualRowTests`
- `swift test --filter SubtitleTableTagStyleTests`
- `swift build`
- `git diff --check`

Outcome: Passed. Delete Tag dialog clicks no longer classify as table-menu outside clicks while the dialog is open, and Shiori tag chips now use the documented redesign neutral tokens.
