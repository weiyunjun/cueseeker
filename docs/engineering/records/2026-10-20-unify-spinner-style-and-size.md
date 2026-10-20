# Implementation Record: Unify Spinner Style And Size

- Date: 2026-10-20
- Requirement: `docs/human/requirements/20261020-UI-Unify Spinner Style And Size.md`
- Branch: `main`

## Scope Delivered

1. **Unified Spinner Component & Size Token (`WorkbenchSpinner.swift`)**
   - Locked `WorkbenchSpinner` to the standard spinner token `--size-spinner` (`16px`) and stroke width `--width-spinner-stroke` (`2px`), removing custom per-call size overrides.

2. **Replaced Native `ProgressView` Spinners with `WorkbenchSpinner` (`WorkbenchTestLibraryView.swift`, `ExcerptListOverviewView.swift`, `PlaybackLibraryOverlay.swift`, `SettingsMaintenanceCategory.swift`, `SettingsDeveloperCategory.swift`)**
   - Replaced all macOS system `ProgressView()` loading indicators in Recent (`Recent Videos`, `Recent Excerpt Lists`), Library (overview and folder detail), Excerpt overview, Playback Overlay video playlist, Settings Maintenance, and Settings Developer with `WorkbenchSpinner()`.

3. **Aligned Existing `18px` Ring Spinners to `--size-spinner` (`16px`) (`WorkbenchFileView.swift`, `WebDAVFolderDialog.swift`, `SMBFolderDialog.swift`, `FTPFolderDialog.swift`, `NFSFolderDialog.swift`)**
   - Updated the File page status indicator in-progress spinner, File page Level 2/Level 3 directory loading spinners, and WebDAV/SMB/FTP/NFS folder browser directory loading spinners to use `WorkbenchSpinner()` (`16px`).

## Verification

- Verified `swift build --package-path apps/macos-native` and `WorkbenchEmptyHintTests` passed, and confirmed no `ProgressView` or `NSProgressIndicator` calls remain in `apps/macos-native`.
