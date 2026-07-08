# Workbench Warning Dialog

## Human-Owned Source

- `docs/human/requirements/20260708-Feature-Workbench Warning Dialog.md`
- `docs/human/design/UI.md`

## Scope

Update the Shiori removal confirmation surface to use the accepted Workbench
warning dialog layout and destructive button component.

## Classification

- Product semantics: unchanged; Shiori table removal still removes the selected
  saved Shiori record only after confirmation.
- Platform UI/UX: updated; the dialog uses the title, message, and trailing
  action layout from the UI document, and the Remove action uses a destructive
  button.
- Platform integration: unchanged.
- Playback execution: unchanged; playback Shiori controls remain save-only for
  already saved cues.

## Changes

- Added `WorkbenchDestructiveButton` using existing Workbench danger text and
  danger background tokens.
- Updated `WorkbenchConfirmationDialog` to remove the icon section and render
  title, message, and trailing horizontal actions.
- Updated the Shiori table removal confirmation to pass a destructive action
  title and handler to the shared dialog.
- Follow-up: aligned the dialog panel to `--color-bg-surface`,
  `--radius-control`, `--color-border-control`, and `Panel Shadow: none`.
- Follow-up: changed the Shiori removal confirmation title from
  `Remove Shiori?` to `Remove Shiori`.

## Verification

- `git diff --check`
- `swift build` from `apps/macos-native`
- `swift test` from `apps/macos-native`

## Outcome

The Shiori removal confirmation now matches the accepted Workbench warning
dialog direction. The visual surface is reusable through dialog parameters, and
the destructive styling is isolated in a shared button component while deletion
behavior remains scoped to the Shiori table confirmation path.

Follow-up alignment removed the legacy panel shadow, tokenized the panel radius,
and matched the accepted Shiori removal title copy.
