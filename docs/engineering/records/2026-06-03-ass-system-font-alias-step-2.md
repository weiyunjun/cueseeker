# ASS System Font Alias Step 2

Requirement: `docs/human/requirements/20260603-Bug-ASS System Font Alias Name Table.md`

## Scope

- Added a font environment snapshot made from installed font file paths, file sizes, and modification timestamps.
- Added a derived JSON cache for parsed installed-font `name` table faces under the user cache directory.
- Invalidated the derived cache when the font environment snapshot or alias cache algorithm version changes.
- Registered installed font files for the current process before rebuilding the CoreText descriptor collection, including cache-hit paths.
- Bound the in-memory alias table to the current font environment snapshot so a same-process font change can rebuild the table.

## Verification

- `swift test --package-path apps/macos-native --filter assFont`
- `swift test --package-path apps/macos-native`

Both commands passed. The targeted cache test verifies that cached font faces are reused only for an identical font snapshot and rejected after a font file changes.

## Result

The second implementation step matched expectations: installed-font alias parsing can now reuse a derived cache while still invalidating on font file changes, reducing repeated name-table parsing without making final libass fallback decisions authoritative at index time.
