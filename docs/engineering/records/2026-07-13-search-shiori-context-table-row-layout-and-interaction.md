# Search, Shiori, and Context Table Row Layout and Interaction

## Human-Owned Source

- `docs/human/requirements/20260713-Feature-Search Shiori Context Table Row Layout And Interaction.md`

## Scope

Implement Step 1 of the accepted table update: rename the user-visible `Time`
column label to `Time Range` across Search, Shiori, and Context table paths.
Internal column IDs, model names, and time-range behavior remain unchanged.

## Step 1 Changes

- Updated the shared Search and Shiori column schema titles.
- Updated Search, Shiori, and shared table header fallback values.
- Updated direct tests for column visibility, virtual table headers, and copied
  TSV headers.

## Verification

- `swift build`
  - Passed.
- `swift test --filter 'schemaWorkbenchColumnVisibilityMenuLocksCuesAndSkipsCheckboxColumn|schemaWorkbenchColumnVisibilityMenuUsesShioriColumnOrder|subtitleTableClipboardCopiesHeadersAndExpandsCueLines|subtitleTableClipboardCopiesCrossHourTimeRangeWithFullFormat|subtitleTableViewMapsTextColumnsWhenDisplayTitleIsHidden|subtitleTableViewUsesExplicitColumnOrderForTextColumns'`
  - Passed all 6 selected Swift Testing tests.
- Exact-string source scan for `"Time"` in the macOS App sources and tests.
  - No remaining exact `"Time"` table label was found.
- `git diff --check`
  - Passed.

## Outcome

Search, Shiori, and Context table paths now present `Time Range` as the column
label and copied TSV header. The internal `time` column ID and time-range model
behavior are unchanged.
