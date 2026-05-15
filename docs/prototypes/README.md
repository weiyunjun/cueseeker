# UI Prototypes

Status: Reference

This directory stores static HTML prototypes used to reduce ambiguity before
major frontend UI changes.

Current prototypes:

- `card-search-bottom-player-v1.html`: card-based Search and Shiori results,
  Library episode-grid browsing, and the revised topbar and bottom-player shell
  for the staged card Search and bottom player direction.
- `macos-native-bottom-player.html`: isolated bottom-player visual exploration
  that keeps the current playback controls but redraws them as a quieter
  macOS-native window chrome surface.
- `macos-native-search-results.html`: isolated Search results visual
  exploration that applies the quieter macOS-native chrome and color treatment
  to the accepted topbar, grouped results, and persistent bottom player.
- `test3-aligned-workbench.html`: standalone refinement based on the external
  `test3` design draft, adjusted for CueSeeker's Search results, expandable
  video state, equal bilingual subtitle styling, and persistent bottom-player
  behavior.

Major frontend UI implementation work should consult the relevant prototype
when one exists, following
`docs/engineering/02_git_workflow.md`.
