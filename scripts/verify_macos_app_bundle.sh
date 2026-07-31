#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 CueSeeker.app" >&2
    exit 2
fi

APP_PATH="$(cd "$1" && pwd)"
CONTENTS="$APP_PATH/Contents"
EXECUTABLE="$CONTENTS/MacOS/CueSeeker"
FFMPEG_EXECUTABLE="$CONTENTS/Helpers/ffmpeg"
FRAMEWORKS="$CONTENTS/Frameworks"
PLIST="$CONTENTS/Info.plist"

for path in "$EXECUTABLE" "$FFMPEG_EXECUTABLE" "$PLIST" "$FRAMEWORKS"; do
    if [ ! -e "$path" ]; then
        echo "error: required app item missing: $path" >&2
        exit 1
    fi
done

if ! find "$FRAMEWORKS" -type f -name 'libdav1d*.dylib' -print -quit | grep -q .; then
    echo "error: bundled libdav1d is missing" >&2
    exit 1
fi
if ! "$FFMPEG_EXECUTABLE" -hide_banner -decoders 2>/dev/null | \
    grep -E '^[[:space:]]*V[^[:space:]]*[[:space:]]+libdav1d[[:space:]]' >/dev/null; then
    echo "error: bundled ffmpeg executable does not expose libdav1d" >&2
    exit 1
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" != \
    "com.cueseeker.app" ]; then
    echo "error: unexpected bundle identifier" >&2
    exit 1
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:0:CFBundleURLSchemes:0' "$PLIST")" != \
    "cueseeker" ]; then
    echo "error: cueseeker URL scheme is not registered" >&2
    exit 1
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")" != "13.0" ]; then
    echo "error: unexpected minimum macOS version" >&2
    exit 1
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :GCSupportsControllerUserInteraction' "$PLIST")" != \
    "true" ]; then
    echo "error: controller user interaction support is not declared" >&2
    exit 1
fi

if [ "$(/usr/libexec/PlistBuddy -c 'Print :GCSupportedGameControllers:0:ProfileName' "$PLIST")" != \
    "ExtendedGamepad" ]; then
    echo "error: Extended Gamepad support is not declared" >&2
    exit 1
fi

verify_macho() {
    macho="$1"
    archs="$(lipo -archs "$macho")"
    if [ "$archs" != "arm64" ]; then
        echo "error: $macho has unexpected architectures: $archs" >&2
        exit 1
    fi

    while read -r dependency; do
        case "$dependency" in
            @rpath/*)
                basename="${dependency#@rpath/}"
                if [ ! -f "$FRAMEWORKS/$basename" ]; then
                    echo "error: unresolved bundled dependency in $macho: $dependency" >&2
                    exit 1
                fi
                ;;
            /System/Library/*|/usr/lib/*) ;;
            *)
                echo "error: forbidden dependency in $macho: $dependency" >&2
                exit 1
                ;;
        esac
    done < <(otool -L "$macho" | tail -n +2 | awk '{print $1}')
}

verify_macho "$EXECUTABLE"
verify_macho "$FFMPEG_EXECUTABLE"
for dylib in "$FRAMEWORKS"/*.dylib; do
    [ -f "$dylib" ] || continue
    verify_macho "$dylib"
    install_id="$(otool -D "$dylib" | tail -n +2 | head -n 1)"
    case "$install_id" in
        @rpath/*) ;;
        *)
            echo "error: non-rpath install ID in $dylib: $install_id" >&2
            exit 1
            ;;
    esac
done

while read -r rpath; do
    case "$rpath" in
        @loader_path|@executable_path/../Frameworks) ;;
        *)
            echo "error: forbidden executable rpath: $rpath" >&2
            exit 1
            ;;
    esac
done < <(otool -l "$EXECUTABLE" | awk '/LC_RPATH/{getline; getline; print $2}')

while read -r rpath; do
    case "$rpath" in
        @loader_path|@executable_path/../Frameworks) ;;
        *)
            echo "error: forbidden ffmpeg helper rpath: $rpath" >&2
            exit 1
            ;;
    esac
done < <(otool -l "$FFMPEG_EXECUTABLE" | awk '/LC_RPATH/{getline; getline; print $2}')

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "Verified self-contained ARM64 CueSeeker app: $APP_PATH"
