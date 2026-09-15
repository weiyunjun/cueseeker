# Search Single Full Scan — Step 2: Show Waits For The Total

## Human-Owned Source

- `docs/human/requirements/20260915-Feature-Search Single Full Scan And Show Disabled Until Search Completes.md` (sections 3, 4.3, 5)
- `docs/human/design/UI Design System.md` (Button / Primary Disabled, Filter Dialog Layout; the Filter Dialog Layout entry is to be recorded after acceptance)

## Starting Point (commit `921db894`, after Step 1)

Show in the Filter dialog stayed enabled while the total was unknown, reading `Show results`; clicking it, or pressing Return, during a search with a changed selection started a new search.

## Implementation

- The dialog's Show button is disabled while its total is unknown, and Return with it, since its only trigger is the button's default-action shortcut. The disabled look is the existing Button / Primary Disabled state (`--color-bg-disabled`, `--color-text-disabled`); nothing new is drawn.
- The rule reads the total the dialog already holds, so Search and Excerpt share it: over Search the total is unknown until the search completes, over Excerpt only until the list's rows are loaded.
- Chips, Reset, Cancel, Esc and the close button are unchanged.

Files:

- `apps/macos-native/Sources/CueSeekerApp/Shared/WorkbenchSchemaSearch/CueFacetFilterPanel.swift`
- `docs/changelog.md`

## Verification

- `swift build`: no errors or warnings besides the linker's existing duplicate rpath notes.
- App, Debug E2E controller, live library, window 1445 × 821, the owner's saved Language `English` selection:
  - `の` pasted and the filter button clicked 0.4 s later: the dialog showed grey counts, the Spinner with `计算中` and a disabled `显示结果` (capture `step2-searching`).
  - Return pressed during the search: the dialog stayed open and nothing changed (capture `step2-after-enter`).
  - Character `11–20` clicked during the search: it became selected and its count stayed a placeholder (capture `step2-chip-toggled`).
  - After the search completed (first page 853 ms, complete 5,056 ms, 938 results, cold): every count appeared and Show read `显示 378 条结果` and was enabled (capture `step2-completed`).
  - Cancel closed the dialog; the table kept 938 results under `English` (capture `step2-cancelled`).
- A first attempt did not start a search: the Esc sent to close an earlier dialog opened on an empty query did not close it, so the paste went nowhere, and Return then pressed `显示 0 条结果` with an unchanged selection, which only closed the dialog. Nothing in the table or the saved selection changed.
- Full `swift test`: 1231 tests, 30 issues in 17 tests, the environment-sensitive set listed in Step 1 (native playback, Debug E2E scene and width, Excerpt scroll anchor, Library folder removal, which this run adds `libraryFolderRemovalPublishesProgressWithoutBlockingMainActor` to, the two Search refresh-scope tests that pass alone, and the Excerpt copy test that expects English feedback text); none touches the Filter dialog.

## Outcome

Matched requirement section 3. The Excerpt dialog's momentary disabled Show before its rows load is covered by the same rule and was not driven in the App.
