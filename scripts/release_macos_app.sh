#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT_DIR="${CUESEEKER_RELEASE_OUTPUT_DIR:-$REPO_ROOT/.build/distribution}"
SIGNING_IDENTITY="${CUESEEKER_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${CUESEEKER_NOTARY_PROFILE:-CueSeeker}"

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

One-step notarized DMG release pipeline for macOS distribution.

Options:
  --sign IDENTITY          Developer ID signing identity (e.g. "Developer ID Application: ...")
                           Defaults to auto-detecting from Keychain or \$CUESEEKER_SIGNING_IDENTITY.
  --notary-profile PROFILE Keychain profile name for xcrun notarytool (defaults to "CueSeeker" or \$CUESEEKER_NOTARY_PROFILE).
  --output-dir DIR         Output directory for packaged and released artifacts (defaults to .build/distribution).
  -h, --help               Show this help message.

EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --sign)
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --notary-profile)
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# If no signing identity provided, attempt auto-detection from Keychain
if [ -z "$SIGNING_IDENTITY" ]; then
    DETECTED_IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null | grep 'Developer ID Application:' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
    if [ -n "$DETECTED_IDENTITY" ]; then
        SIGNING_IDENTITY="$DETECTED_IDENTITY"
        echo "Auto-detected signing identity: $SIGNING_IDENTITY"
    else
        echo "error: no Developer ID signing identity provided or found in Keychain." >&2
        echo "Please provide --sign \"Developer ID Application: <Name> (<TeamID>)\" or set CUESEEKER_SIGNING_IDENTITY." >&2
        exit 1
    fi
fi

# Verify notarization profile exists in Keychain
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "error: notarytool keychain profile '$NOTARY_PROFILE' is invalid or not found." >&2
    echo "Please configure credentials using:" >&2
    echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --key <AuthKey.p8> --key-id <KEY_ID> --issuer <ISSUER_ID>" >&2
    exit 1
fi

APP_PATH="$OUTPUT_DIR/CueSeeker.app"
DMG_PATH="$OUTPUT_DIR/CueSeeker.dmg"
DMG_STAGING_DIR="$OUTPUT_DIR/dmg-staging"

mkdir -p "$OUTPUT_DIR"

echo "=== Step 1/6: Building and signing CueSeeker.app ==="
"$SCRIPT_DIR/package_macos_app.sh" --output "$APP_PATH" --sign "$SIGNING_IDENTITY"

echo "=== Step 2/6: Assembling DMG staging directory ==="
rm -rf "$DMG_STAGING_DIR" "$DMG_PATH"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

echo "=== Step 3/6: Creating DMG disk image ==="
hdiutil create \
    -volname "CueSeeker" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"
rm -rf "$DMG_STAGING_DIR"

echo "=== Step 4/6: Signing DMG disk image ==="
codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"

echo "=== Step 5/6: Submitting DMG to Apple Notary Service ==="
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "=== Step 6/6: Stapling and verifying notarization on DMG ==="
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open -vv "$DMG_PATH"

echo ""
echo "============================================================"
echo "Release DMG successfully created, notarized, and stapled!"
echo "  DMG: $DMG_PATH"
echo "============================================================"
