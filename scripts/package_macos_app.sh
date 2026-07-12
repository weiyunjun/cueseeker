#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_ROOT="$REPO_ROOT/apps/macos-native"
MEDIA_ROOT="${CUESEEKER_MEDIA_RUNTIME_ROOT:-$REPO_ROOT/.build/media-runtime/arm64-macos13}"
OUTPUT_ROOT="${CUESEEKER_APP_OUTPUT_ROOT:-$REPO_ROOT/.build/distribution}"
APP_PATH="$OUTPUT_ROOT/CueSeeker.app"
SIGNING_IDENTITY="${CUESEEKER_SIGNING_IDENTITY:--}"
PLIST_SOURCE="$REPO_ROOT/packaging/macos/Info.plist"

usage() {
    echo "Usage: $0 [--output PATH] [--sign IDENTITY]"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --output)
            APP_PATH="$2"
            shift 2
            ;;
        --sign)
            SIGNING_IDENTITY="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

"$SCRIPT_DIR/verify_macos_media_runtime.sh" "$MEDIA_ROOT"

export CUESEEKER_MEDIA_RUNTIME_ROOT="$MEDIA_ROOT"
export CLANG_MODULE_CACHE_PATH="$REPO_ROOT/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
export XDG_CACHE_HOME="$REPO_ROOT/.build/cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$XDG_CACHE_HOME"
(
    cd "$PACKAGE_ROOT"
    swift build -c release --product CueSeeker
)
BIN_DIR="$(cd "$PACKAGE_ROOT" && swift build -c release --show-bin-path)"
EXECUTABLE="$BIN_DIR/CueSeeker"

if [ ! -x "$EXECUTABLE" ]; then
    echo "error: release executable missing: $EXECUTABLE" >&2
    exit 1
fi

rm -rf "$APP_PATH"
mkdir -p \
    "$APP_PATH/Contents/MacOS" \
    "$APP_PATH/Contents/Frameworks" \
    "$APP_PATH/Contents/Helpers" \
    "$APP_PATH/Contents/Resources/ThirdPartyLicenses"

cp "$EXECUTABLE" "$APP_PATH/Contents/MacOS/CueSeeker"
cp "$MEDIA_ROOT/bin/ffmpeg" "$APP_PATH/Contents/Helpers/ffmpeg"
cp "$PLIST_SOURCE" "$APP_PATH/Contents/Info.plist"
find "$MEDIA_ROOT/lib" -maxdepth 1 -type f -name '*.dylib' -print | sort | while read -r dylib; do
    cp "$dylib" "$APP_PATH/Contents/Frameworks/$(basename "$dylib")"
done
cp "$MEDIA_ROOT/licenses/"* "$APP_PATH/Contents/Resources/ThirdPartyLicenses/"
cp "$MEDIA_ROOT/sources.lock" "$APP_PATH/Contents/Resources/ThirdPartyLicenses/sources.lock"
cp "$MEDIA_ROOT/ffmpeg-cueseeker.patch" \
    "$APP_PATH/Contents/Resources/ThirdPartyLicenses/ffmpeg-cueseeker.patch"
cp "$MEDIA_ROOT/lame-cueseeker.patch" \
    "$APP_PATH/Contents/Resources/ThirdPartyLicenses/lame-cueseeker.patch"
cp "$MEDIA_ROOT/build-info.txt" \
    "$APP_PATH/Contents/Resources/ThirdPartyLicenses/media-runtime-build-info.txt"

if otool -l "$APP_PATH/Contents/MacOS/CueSeeker" | \
    awk '/LC_RPATH/{getline; getline; print $2}' | \
    grep -Fx "$MEDIA_ROOT/lib" >/dev/null; then
    install_name_tool -delete_rpath "$MEDIA_ROOT/lib" "$APP_PATH/Contents/MacOS/CueSeeker"
fi
if otool -l "$APP_PATH/Contents/Helpers/ffmpeg" | \
    awk '/LC_RPATH/{getline; getline; print $2}' | \
    grep -Fx "$MEDIA_ROOT/lib" >/dev/null; then
    install_name_tool -delete_rpath "$MEDIA_ROOT/lib" "$APP_PATH/Contents/Helpers/ffmpeg"
fi

find "$APP_PATH/Contents/Frameworks" -type f -name '*.dylib' -print | sort | while read -r dylib; do
    if [ "$SIGNING_IDENTITY" = "-" ]; then
        codesign --force --sign - --timestamp=none "$dylib"
    else
        codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$dylib"
    fi
done

if [ "$SIGNING_IDENTITY" = "-" ]; then
    codesign --force --sign - --timestamp=none "$APP_PATH/Contents/Helpers/ffmpeg"
else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
        "$APP_PATH/Contents/Helpers/ffmpeg"
fi

if [ "$SIGNING_IDENTITY" = "-" ]; then
    codesign --force --sign - --timestamp=none "$APP_PATH/Contents/MacOS/CueSeeker"
    codesign --force --sign - --timestamp=none "$APP_PATH"
else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
        "$APP_PATH/Contents/MacOS/CueSeeker"
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_PATH"
fi

"$SCRIPT_DIR/verify_macos_app_bundle.sh" "$APP_PATH"
echo "CueSeeker app ready: $APP_PATH"
