# Implementation Record: Unify Remote Media Streaming Across Network Protocols

- Date: 2026-10-20
- Requirement: `docs/human/requirements/20261020-Feature-Unify Remote Media Streaming Across Network Protocols.md`
- Branch: `main`

## Scope Delivered

1. **Unified Continuous Streaming Pipeline (`RemoteFolderCommon.swift`, `SMBSupport.swift`, `FTPSupport.swift`, `NFSSupport.swift`)**
   - Replaced `RemoteMediaStreamServer.streamFromRangeReader` and `SMBClient.streamNativeSMBFile` with a single unified `RemoteMediaStreamServer.streamContinuousRange` implementation shared across SMB, FTP, and NFS.
   - Added `streamRange` to `SMBBackendProtocol`, `FTPBackendProtocol`, and `NFSBackendProtocol` so every HTTP `Range` request opens one continuous protocol stream from the requested byte offset and pushes chunks directly until completion or client disconnect (such as the next Seek), matching WebDAV's HTTP `Range` streaming contract.

2. **Protocol-Level Continuous Streaming (`CSMBClient.h`, `CSMBClient.c`, `CFTPClient.c`, `CNFSClient.c`)**
   - **SMB**: Made `smb2_fstat` on `csmb_file_open` conditional on `out_total_size != NULL` so streaming requests reuse cached file sizes without an extra `fstat` round-trip.
   - **FTP**: Implemented `cftp_stream_file_range` using a single persistent `libcurl` transfer with `CURLOPT_RESUME_FROM_LARGE` (`REST`) and `CURLFTPMETHOD_NOCWD` (with fallback to `CURLFTPMETHOD_MULTICWD`), eliminating repeated 256 KB slice logins and `SIZE`/`MDTM` probes.
   - **NFS**: Implemented `cnfs_stream_file_range` with thread-safe per-host export list caching and mounted `nfs_context` pooling so Seek and playback reuse mounted NFS contexts and stream continuously via `nfs_pread` without repeated `mount_getexports` and `nfs_mount`/`nfs_umount` handshakes.

## Verification

- Verified unit and integration tests in `SMBSupportTests` and `FTPNFSSupportTests`, including multi-chunk continuous streaming and call-count assertions confirming a single continuous stream per HTTP `Range` request.
