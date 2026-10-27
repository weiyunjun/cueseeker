# 2026-10-27 Extended Video Format Support And Matching Priority

## Covering Requirement

- `docs/human/requirements/20261027-Feature-Extended Video Format Support And Matching Priority.md`
- Referenced designs:
  - `docs/human/design/data/Data.md`
  - `docs/human/design/workbench/Library and File.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`

## Implementation Summary

1. Expanded `VideoMatcher.defaultVideoExtensions` to the 20 supported video extensions in priority order (`.mkv > .mp4 > .webm > .flv > .avi > .mov > .ts > .m2ts > .mts > .m4v > .rmvb > .rm > .wmv > .mpg > .mpeg > .vob > .asf > .f4v > .ogv > .3gp`), which is shared by local directory scanning and remote folder browsing/indexing (WebDAV, SMB, FTP, NFS).
2. Updated `MediaDetailFormatter.fileFormatDisplayNames` so File Info (`L-06.8 File Detail Dialog Layout`) displays standard format names for all 20 supported video extensions.

## Verification

- Updated unit tests in `VideoMatcherTests` and `FileDetailDialogTests` to verify the 20-extension priority order and format display names.
- Executed `swift test --package-path apps/macos-native`.
