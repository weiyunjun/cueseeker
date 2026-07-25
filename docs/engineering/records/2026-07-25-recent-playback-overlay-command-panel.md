# Recent, Playback Overlay, And Command Panel

## Human-Owned Source

- `docs/human/requirements/20260725-Feature-Recent Playback Overlay And Command Panel.md`
- `docs/human/design/UI.md`

## Scope

Implement the accepted Recent navigation, Recent Shiori recovery, simplified
Playback Overlay, and Playback Command Panel in small, independently verified
steps. Reuse existing feature stores, database boundaries, playlist sources,
and presentation components without adding parallel state sources or
speculative abstractions.

## Architecture Alignment

- Removed the obsolete single-default-list limitation from the Shiori data
  ownership rules.
- Kept Shiori relation ownership on the existing multi-list persistence and
  presentation paths.

## Architecture Verification

- Confirmed the replacement matches the committed multi-list implementation
  and the current human-owned requirement.
- `git diff --check` passed.
