# Implementation Record: FTP And NFS Folder Support

- Date: 2026-10-20
- Requirement: `docs/human/requirements/20261020-Feature-FTP And NFS Folder Support.md`
- Branch: `main`

## Scope Delivered

1. **Toolbar Add Menu & Remote Protocol Grouping (`CueSeekerCore`, `CueSeekerApp`)**
   - Added `Add FTP Folder` and `Add NFS Folder` actions after `Add SMB Folder` in the top-left `Add` menu (`WorkbenchFileView`).
   - Extended `URL`/`String` media path helpers (`isFTPPath`, `isNFSPath`, `isFTPURL`, `isNFSURL`, `isRemoteMediaPath`, `isRemoteMediaURL`), `LibraryRootGroupSectionKind` (`.ftp`, `.nfs`), and `LibraryRootGroupPresentationBuilder` so Sidebar, Library, and Search root filter groupings display `LOCAL` -> `WEBDAV` -> `SMB` -> `FTP` -> `NFS`.

2. **C-Library Protocol Backends & Shared Remote Folder Infrastructure (`CSMBClient`, `CueSeekerCore`)**
   - **NFS (`libnfs` 6.0.2, LGPLv2.1+)**: Added `libnfs-6.0.2` to `third_party/media-runtime/sources.lock`, `scripts/build_macos_media_runtime.sh`, `scripts/verify_macos_media_runtime.sh`, and `scripts/verify_macos_app_bundle.sh`. Implemented `CNFSClient.c` (`cnfs_list_exports`, `cnfs_list_directory`, `cnfs_stat`, `cnfs_read_file_range`, `cnfs_rename`) with automatic NFSv3 and NFSv4 support.
   - **FTP (`libcurl`, macOS system library)**: Linked system `libcurl` in `Package.swift` and implemented `CFTPClient.c` (`cftp_list_directory`, `cftp_stat`, `cftp_read_file_range`, `cftp_rename`) with automatic RFC 2640 UTF-8 negotiation (`*OPTS UTF8 ON`), `MLSD`/`LIST` parsing, `SIZE`/`MDTM` probing, passive mode (`EPSV`/`PASV`) byte-range transfers, and `RNFR`/`RNTO` rename support. Added strict UTF-8 validation with GB18030/GBK fallback decoding in `NativeFTPBackend` (`FTPSupport.swift`) so Chinese directory and file names display properly across both UTF-8 and legacy GBK FTP servers.
   - **Shared Remote Infrastructure (`RemoteFolderCommon.swift`)**: Extracted `RemoteAddressParser`, `RemoteRootConfigStore<Config>`, `RemoteDirectoryEntry` / `RemoteDirectoryListingHelper`, and `RemoteMediaStreamServer` so `SMBSupport.swift`, `FTPSupport.swift`, and `NFSSupport.swift` share a single implementation of URL normalization, configuration persistence, recursive directory scanning, and local HTTP `Range` streaming proxy.

3. **Two-Step Add/Edit Dialogs (`FTPFolderDialog.swift`, `NFSFolderDialog.swift`)**
   - Implemented two-step connection & remote directory browser modals for FTP (Address, Port default `21`, Username, Password) and NFS (Address only, port `2049` automatic).
   - Wired `Edit` context-menu actions on FTP and NFS root folders in Sidebar and Library to open pre-populated edit dialogs and re-index on save.

4. **Indexing, Playback, and Rename Integration (`CueSeekerCore`, `CueSeekerPlayback`, `CueSeekerApp`)**
   - Updated `SubtitleIndexer`, `IndexingDatabase`, `LibraryDatabase`, `LibraryCoverIndexer`, `PlaybackVideoMetadataIndexer`, `PlaybackSourceResolver`, and `LibraryRenamer` to support `ftp://` and `nfs://` folders and files across indexing, playback, and rename flows.

## Verification

- Verified media runtime build and verification (`./scripts/verify_macos_media_runtime.sh .build/media-runtime/arm64-macos13`).
- Verified unit and integration tests in `SMBSupportTests`, `SMBFolderDialogTests`, `FTPNFSSupportTests`, and `FTPNFSFolderDialogTests`.
