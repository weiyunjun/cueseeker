# 2026-10-27 Decomposed Character Folder Path Removal And Subfolder Matching Fix

## Covering Requirement

- `docs/human/requirements/20261027-Bug-Decomposed Character Folder Path Removal And Subfolder Matching Fix.md`
- Referenced designs:
  - `docs/human/design/data/Data.md`
  - `docs/human/design/workbench/Library and File.md`

## Implementation Summary

1. Updated SQLite `substr(..., 1, ?)` prefix length bindings in `IndexingDatabase` and `IndexingDatabase+TombstoneReconciliation` to bind `prefix.unicodeScalars.count` instead of `prefix.count` so decomposed characters match accurately during folder removal and scan reconciliation.
2. Removed `.precomposedStringWithCanonicalMapping` from `relativeMediaPath` and `renameRelativePath` in `IndexingDatabase+LibraryHierarchy`, `IndexingDatabase+Rename`, and `LibraryDatabase` so subfolder relative paths preserve the same canonical character form as root and file paths.
3. Normalized new path components in `LibraryRenamer.replacingLastPathComponent` and `checkFileGroupRename` (`URL(fileURLWithPath:isDirectory: false).lastPathComponent` for local paths, `precomposedStringWithCanonicalMapping` for remote paths) so in-App renames with keyboard-entered composed characters remain consistent with disk paths.

## Verification

- Added unit tests in `IndexingDatabaseTests` and `LibraryRenameTests` covering decomposed kana root folder removal and consecutive local subfolder renames with composed kana input.
- Executed `swift test --package-path apps/macos-native`.
