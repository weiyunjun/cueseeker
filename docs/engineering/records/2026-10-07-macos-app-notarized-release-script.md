# macOS App Notarized Release Script Implementation

Human-owned documents:

- `docs/human/requirements/20261007-Engineering-macOS App Notarized Release Script.md`

## Why

1. **Problem**:
   - Building and distributing a native macOS app outside the Mac App Store requires multiple sequential manual steps: compilation and assembly, Developer ID codesigning with hardened runtime and timestamps, assembling a DMG disk image with an Applications link, codesigning the DMG, uploading to Apple Notary Service via `notarytool`, waiting for approval, stapling the notarization ticket to the `.dmg`, and validating Gatekeeper acceptance.
   - Performing these manual steps in the terminal for each external release is error-prone and tedious.

2. **Goal**:
   - Provide a zero-hardcoding, single-command release script (`scripts/release_macos_app.sh`) that automates the entire packaging, signing, DMG disk image creation, notarization, stapling, Gatekeeper verification, and distributable `.dmg` generation flow while remaining safe for open-source publication.

## What changed

1. **Release Script (`scripts/release_macos_app.sh`)**:
   - Reuses `scripts/package_macos_app.sh` for compilation and Developer ID codesigning of `CueSeeker.app`.
   - Assembles a staging directory with `CueSeeker.app` and a `/Applications` symlink for native drag-and-drop installation.
   - Uses macOS built-in `hdiutil` to build a compressed `CueSeeker.dmg` (UDZO format).
   - Signs the `CueSeeker.dmg` using the detected or configured `Developer ID Application` certificate with timestamps.
   - Submits the DMG directly to Apple Notary Service via `xcrun notarytool submit --wait`.
   - Staples the approved notarization ticket directly to `CueSeeker.dmg` using `xcrun stapler staple`.
   - Verifies the ticket with `xcrun stapler validate` and Gatekeeper policy assessment with `spctl --assess --type open -vv`.
   - Contains zero hardcoded private credentials or developer names, reading configuration strictly via flags, Keychain profiles, and environment variables.

## Verification

- Verified `scripts/release_macos_app.sh --help` returns usage instructions and exit code 0.
- Verified auto-detection logic against Keychain identities.
- Verified credentials check against `--keychain-profile CueSeeker`.
