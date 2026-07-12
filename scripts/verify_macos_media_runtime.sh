#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 MEDIA_RUNTIME_ROOT" >&2
    exit 2
fi

ROOT="$(cd "$1" && pwd)"
LIB_DIR="$ROOT/lib"
required=(
    libavformat
    libavcodec
    libavutil
    libswresample
    libswscale
    libass
    libfreetype
    libfribidi
    libharfbuzz
    libunibreak
)

for stem in "${required[@]}"; do
    if ! find "$LIB_DIR" -type f -name "$stem*.dylib" -print -quit | grep -q .; then
        echo "error: missing required runtime library: $stem" >&2
        exit 1
    fi
done

for dylib in "$LIB_DIR"/*.dylib; do
    [ -f "$dylib" ] || continue
    archs="$(lipo -archs "$dylib")"
    if [ "$archs" != "arm64" ]; then
        echo "error: $dylib has unexpected architectures: $archs" >&2
        exit 1
    fi

    install_id="$(otool -D "$dylib" | tail -n +2 | head -n 1)"
    case "$install_id" in
        @rpath/*) ;;
        *)
            echo "error: non-rpath install ID in $dylib: $install_id" >&2
            exit 1
            ;;
    esac

    while read -r dependency; do
        case "$dependency" in
            @rpath/*|/System/Library/*|/usr/lib/*) ;;
            *)
                echo "error: forbidden dependency in $dylib: $dependency" >&2
                exit 1
                ;;
        esac
    done < <(otool -L "$dylib" | tail -n +2 | awk '{print $1}')
done

if grep -Eq '^CONFIG_(GPL|NONFREE)=yes' "$ROOT/ffmpeg-config.mak"; then
    echo "error: staged FFmpeg configuration enables GPL or nonfree" >&2
    exit 1
fi

echo "Verified ARM64 macOS media runtime: $ROOT"
