# Remote Folder Dialogs And File Page Navigation Responsiveness

## Summary

- Requirement: `docs/human/requirements/20261105-Performance-Remote Folder Dialogs And File Page Navigation Responsiveness.md`
- Eliminated the 270ms entrance animation frame drops and Step 2 browser list render stalls in Remote Folder dialogs (`WebDAV` / `SMB` / `FTP` / `NFS`) by isolating remote folder dialog sessions into `RemoteFolderDialogCenter` (avoiding `LibraryStore` invalidations of `WorkbenchFileView`), deferring AppKit TextKit2-to-TextKit1 field editor initialization when unfocused, reusing a shared `NSLayoutManager` in `WorkbenchTextFieldFontMetrics`, mounting `WorkbenchAccessibilityScrollRevealProbe` only when keyboard/controller accessibility focus is active, and precomputing `disabledFolderItemIDs` per evaluation pass in `RemoteFolderBrowserStepContent`.
- Accelerated remote folder connection and directory browsing across `WebDAV`, `SMB`, and `FTP`:
  - `WebDAV`: replaced per-request ephemeral `URLSession` creation/invalidation with a shared `URLSession` (`NoRedirectSessionDelegate`, `urlCache = nil`, `requestCachePolicy = .reloadIgnoringLocalCacheData`, `httpCookieAcceptPolicy = .never`, `httpShouldSetCookies = false`) to reuse HTTP keep-alive connections, and cached origins that required `/dav` fallback (`knownAListDAVOrigins`).
  - `SMB`: added an SMB2 session connection pool (`g_smb_pool`, 8 slots, 120s TTL), share list cache (`g_share_cache`, 16 slots, 120s TTL), and per-host anonymous password mode cache (`g_anon_cache`) in `CSMBClient.c` with transparent reconnect-and-retry on stale pooled sessions; eliminated the redundant `csmb_session_stat` round-trip before `smb2_opendir`; and prioritized `.local` mDNS resolution as well as IPv4 (`AF_INET`) before IPv6 (`AF_INET6`) in `SMBHostResolver` so IPv4-only LAN NAS hosts do not block 2.5s–5.0s waiting for non-existent mDNS `AAAA` records.
  - `FTP` & `NFS`: added a `CURL *` handle pool (`g_cftp_pool`, 8 slots, 120s TTL) and per-server `MLSD` capability cache (`g_cftp_mlsd_cache`) in `CFTPClient.c` so `libcurl` reuses open FTP control connections across directory browsing and file transfers, and shared `cnfs_get_exports_cached` in `cnfs_list_exports` so NFS host-root export listing and subfolder mounting share the same export cache.
- Converted the `File` page Level 1 (`folderRegion`), Level 2 (`subfolderContent`), and Level 3 (`episodeGroupsList`) card containers in `WorkbenchFileView` from `VStack` to `LazyVStack` with `ownerToken`-guarded `registerFileCardAction` / `unregisterFileCardAction`, routed `File` card and breadcrumb navigation through `AppCoordinator.navigateWorkbench(to:trigger:)` for full debug latency telemetry, and moved uncached `hydrateFileSubfoldersAsync` / `hydrateFileObjectsAsync` database queries off the main thread.

## Verification

- `swift test --filter "WebDAVSupportTests|SMBSupportTests|FTPSupportTests|FileRouteNavigationTests"`
