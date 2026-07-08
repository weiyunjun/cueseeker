# Shiori Tag Composer Focus and Alignment

Date: 2026-07-08

Human-owned coverage:

- `docs/human/requirements/20260708-Feature-Shiori Tag Column And Popover.md`
- `docs/human/design/UI.md`

## Implementation

- Aligned the Shiori tag composer wrap layout so items in the same row share a visual center instead of top-aligning shorter inline inputs with taller tag chips.
- Set the inline text input's transparent visual item height to match the tag chip row height, with a small internal leading inset so the caret does not protrude left of the input item.
- Cleared the hosted menu root view when the popover closes, so reopening after Escape remounts the popover and restores the default composer input focus lifecycle.

## Verification

- `swift test --filter SubtitleTableVirtualRowTests`
- `swift build`
- `git diff --check`

Outcome: Passed. The change preserves existing menu open/dismiss behavior while making tag composer input alignment and reopen focus deterministic.
