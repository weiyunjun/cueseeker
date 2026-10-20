# Implementation Record: SMB Folder Support

- **Date**: 2026-10-20
- **Requirement**: `docs/human/requirements/20261019-Feature-SMB Folder Support.md`
- **Design References**:
  - `docs/human/design/ui/UI Index.md`
  - `docs/human/design/ui/UI Tokens.md`
  - `docs/human/design/ui/UI Components - Dialogs & Overlays.md`
  - `docs/human/design/ui/UI Components - Cards & Lists.md`
  - `docs/human/design/ui/UI Layouts - Workbench.md`
  - `docs/human/design/func/Library Management.md`
  - `docs/engineering/09_macos_media_runtime_and_packaging.md`

## Summary of Changes

1. **Bundled `libsmb2` Runtime & C Bridge (`third_party/media-runtime/sources.lock`, `scripts/build_macos_media_runtime.sh`, `scripts/verify_macos_media_runtime.sh`, `scripts/verify_macos_app_bundle.sh`, `Package.swift`, `Sources/CSMBClient/`)**:
   - Added `libsmb2-6.2` (LGPLv2.1+, dynamic `.dylib` built `--without-libkrb5` for pure NTLMSSP user-space SMB2/SMB3 support compatible with MIT distribution and Mac App Store App Sandbox) to the locked media runtime and verification scripts.
   - Created the `CSMBClient` C target wrapping `libsmb2` share enumeration (`srvsvc` over `IPC$`), directory listing, file stat, random-access `pread`, and in-place rename.

2. **SMB Address Normalization, Host Resolution, Configuration Store, Client & Loopback HTTP Range Server (`Sources/CueSeekerCore/SMBSupport.swift`, `WebDAVSupport.swift`, `LibraryRootGroups.swift`)**:
   - Added `SMBAddress` supporting background strict case-sensitive `smb://` prefix completion on `Connect` (without mutating the user's input text in the `Address` field), percent-decoding of readable paths, port normalization (defaulting to `445`), fixed-format IPv4/IPv6 vs. friendly-name classification, and top-level host root vs. share path splitting.
   - Added `SMBHostResolver` to resolve non-IP friendly names / hostnames in the application layer (via system DNS, `.local` Bonjour mDNS, `_smb._tcp` Bonjour service discovery, and `smbutil lookup` NetBIOS fallback) into reachable IP addresses before connecting `libsmb2`, while preserving the user's friendly name in breadcrumbs and folder paths.
   - Added `SMBRootConfig` and `SMBConfigurationStore` to persist SMB root credentials and rewrite stored paths on in-App folder rename or remove them on folder deletion.
   - Added `SMBClient` for top-level share browsing (`SHARE_TYPE_DISKTREE`, filtering out `IPC$` and hidden `$` shares), shallow directory browsing, recursive media/subtitle tree scanning, subtitle downloading, and in-App rename.
   - Added `SMBStreamServer`, a local `127.0.0.1` loopback HTTP `Range` (`206 Partial Content`) server backed by `libsmb2` random-access `pread`, allowing `FFmpeg` (`AVFormatContext`), `AVPlayer`, cover sampling, screenshot/collage export, and Anki audio/image export to stream and seek `smb://` videos seamlessly.
   - Extended `URL.isRemoteMediaURL` and `String.isRemoteMediaPath` across `CueSeekerCore`, `CueSeekerPlayback`, and `CueSeekerApp` so `smb://` folders share the same canonical path model, local subtitle cache (`WebDAVSubtitleCache`), and remote indexing concurrency limits (`Reading video info` concurrency = `1`, `Generating covers` max concurrency = `2`) as WebDAV folders.

3. **Two-Step Add SMB Folder Dialog & File Page Integration (`Sources/CueSeekerApp/Library/SMBFolderDialog.swift`, `WorkbenchFileView.swift`, `ContentView.swift`, `AppCoordinator+Indexing.swift`, `Localizable.strings`)**:
   - Added `SMB Folder` (`folder-smb` icon) to the `File` page `Add Folder` menu below `WebDav Folder` and rendered `folder-smb` on SMB folder cards.
   - **Step 1 (`.connection`, `480px` width)**: Implemented `Address` (auto-completing `smb://` and decoding percent-encoding), `Port` (pre-filled with `"445"`), `Username`, and `Password`, with inline error reporting below `Password` and spinner/disabled state while connecting.
   - **Step 2 (`.browser`, `720px × 500px`)**: Implemented breadcrumb navigation, single-click multi-selection of folders (`folder-smb` icon), double-click drill-down, `Back` button returning to Step 1 while preserving inputs, and sequential `Add Folder` task queueing in top-to-bottom display order. When Step 1 connects to a host root without a share path, Step 2 lists top-level disk shares and keeps `Add` disabled until at least one share is selected or the user drills into a share.

## Verification

- Verified `scripts/verify_macos_media_runtime.sh` passes with `libsmb2.6.dylib` and `<smb2/libsmb2.h>`.
- Verified `SMBSupportTests` and `SMBFolderDialogTests` via `swift test`.
