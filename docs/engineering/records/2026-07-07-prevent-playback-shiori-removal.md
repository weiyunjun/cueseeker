# Prevent Playback Shiori Removal

## Human-Owned Source

- `docs/human/requirements/20260707-Feature-Prevent Playback Shiori Removal.md`

## Scope

Prevent accidental Shiori removal from playback controls while keeping playback
Shiori saving and Shiori table removal intact.

## Classification

- Product semantics: playback Shiori controls are save-only for the current cue;
  they no longer delete an already saved Shiori.
- Platform UI/UX: the playback button and `S` shortcut keep using the existing
  Shiori command path.
- Platform integration: unchanged.
- Playback execution: unchanged; video playback, cue resolution, and subtitle
  timing behavior are not changed.

## Changes

- Changed the playback Shiori command so an already saved cue remains saved
  instead of being removed.
- Added the `Shiori Already Saved` playback feedback for that already-saved
  path.
- Kept the unsaved-cue path saving the current playback cue as a Shiori.
- Kept Shiori table removal through `removeShiori`.
- Updated product requirements to describe playback save-only behavior and the
  Shiori table as the deletion surface.

## Verification

- `git diff --check`
- `swift test --filter ShioriPresentationTests`
- `swift test`

## Outcome

Playback Shiori controls now prevent accidental deletion. Pressing `S` or the
playback Shiori button still saves an unsaved current cue, but repeating the
action on an already saved cue leaves it in Shiori and shows `Shiori Already
Saved`. Deletion remains available from the Shiori table.
