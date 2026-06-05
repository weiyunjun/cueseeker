# Table Sandbox Step 6 — Revert hover memory experiments to f185fdd8

Human requirement:

- `docs/human/requirements/20260605-Feature-UI Redesign.md`

## Scope

Per the owner's request, the table-sandbox code was reverted to commit
`f185fdd8` ("centralize table hover to a single row"), backing out the two
hover-button memory experiments:

- `d952df4a` — single shared SwiftUI hover toolbar (option A; did not reduce the
  reported scroll memory growth).
- `fd7c2575` — pure AppKit hover buttons (option B).

`SubtitleTableView.swift` and the step-5 record were restored to their
`f185fdd8` content (verified identical via `git diff f185fdd8`). The hover
buttons are back to the SwiftUI per-cell version with centralized single-row
hover. The ~60MB scroll memory question is set aside for now at the owner's
direction.

## Verification

- `swift build --target CueSeekerApp` succeeded.
- `git diff f185fdd8` for the reverted files is empty.

## Outcome

Code matches `f185fdd8`. Phase B3's hover memory investigation is paused.
