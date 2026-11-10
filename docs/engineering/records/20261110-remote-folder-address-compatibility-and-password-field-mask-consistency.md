# 2026-11-10: Remote Folder Address Compatibility and Password Field Mask Consistency

## Requirement Source
- `docs/human/requirements/20261110-UI-Remote Folder Address Compatibility And Password Field Mask Consistency.md`
- `docs/human/design/ui/UI Design Rules.md`
- `docs/human/design/ui/UI Components - Controls.md`
- `docs/human/design/ui/UI Layouts - Workbench.md`
- `docs/human/design/workbench/Library and File.md`

## Summary of Changes
1. **Unified Remote Folder Address Parsing & Normalization (`RemoteAddressParser`, `WebDAVAddress`, `WebDAVRootConfig`, `WebDAVClient`)**:
   - Extended `RemoteAddressParser.parseURL` to support `allowedSchemes: [String]?` and `defaultPort: Int?`, case-insensitive protocol prefix recognition (normalizing `HTTP://`, `HTTPS://`, `SMB://`, `FTP://`, `NFS://` to lowercase and rejecting mismatched schemes), and background default scheme completion (`http://` for WebDAV, `smb://` for SMB, `ftp://` for FTP, `nfs://` for NFS) without mutating the user's input text in the dialog `Address` field.
   - Unified `WebDAVAddress.parseURL(from:)` onto `RemoteAddressParser.parseURL(from: rawAddress, scheme: "http", allowedSchemes: ["http", "https"], defaultPort: nil, portOverride: nil, allowCustomPort: true)`, giving WebDAV full parity with SMB/FTP/NFS on schemeless addresses, case-insensitive schemes, bare IPv6 auto-bracketing, `user@` / `user:pass@` prefix stripping, iterative percent-decoding, and strict IPv4/port validation.
   - Updated `WebDAVRootConfig` and `WebDAVClient` so normalized `rootMediaPath` is persisted internally while preserving `session.address` in the dialog input field.
2. **Password Field Mask Glyph Consistency Across Focus States (`WorkbenchSecureSingleLineInput`, `WorkbenchNativeSecureTextField`, `WorkbenchSecureTextFieldCell`)**:
   - Removed the custom `drawInterior(withFrame:in:)`, custom `drawingRect(forBounds:)`, and `bulletKern` override from `WorkbenchSecureTextFieldCell` that previously drew `•` (`U+2022`) when unfocused while AppKit's `NSSecureTextView` rendered `●` (`U+25CF`) when focused.
   - Added `sizeThatFits` to `WorkbenchSecureSingleLineInput` and `intrinsicContentSize` to `WorkbenchNativeSecureTextField`, and unified `WorkbenchSecureTextFieldCell.applyTextStyleToCurrentEditor()` with `WorkbenchNativeSingleLineTextField.applyTextStyle(to:)` so focused and unfocused password fields share identical native mask glyph shape, size, spacing, and coordinates (`0` pixel difference).
3. **Unit Tests (`WebDAVSupportTests`, `SMBSupportTests`, `FTPNFSSupportTests`, `WebDAVFolderDialogTests`, `SMBFolderDialogTests`, `WorkbenchInputControlsTests`)**:
   - Added address compatibility tests for WebDAV, SMB, FTP, and NFS covering schemeless WebDAV input, case-insensitive scheme prefixes, bare IPv6, userinfo stripping, and invalid scheme rejection.
   - Extended `singleLineInputKeepsIdenticalClipBoundsAndGlyphPositionAcrossFocusAndOverflowStates` to assert `0` pixel difference between unfocused and focused `WorkbenchNativeSecureTextField` rendering across multiple password lengths.

## Verification
- Ran `swift test --package-path apps/macos-native --filter "WebDAVSupportTests|SMBSupportTests|FTPNFSSupportTests|WebDAVFolderDialogTests|SMBFolderDialogTests|FTPNFSFolderDialogTests|WorkbenchInputControlsTests"`.
