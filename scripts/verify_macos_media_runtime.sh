#!/bin/bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 MEDIA_RUNTIME_ROOT" >&2
    exit 2
fi

ROOT="$(cd "$1" && pwd)"
LIB_DIR="$ROOT/lib"
FFMPEG_EXECUTABLE="$ROOT/bin/ffmpeg"
required=(
    libavformat
    libavcodec
    libavutil
    libswresample
    libswscale
    libdav1d
    libass
    libfreetype
    libfribidi
    libharfbuzz
    libunibreak
    libmp3lame
)

for stem in "${required[@]}"; do
    if ! find "$LIB_DIR" -type f -name "$stem*.dylib" -print -quit | grep -q .; then
        echo "error: missing required runtime library: $stem" >&2
        exit 1
    fi
done

if [ ! -x "$FFMPEG_EXECUTABLE" ]; then
    echo "error: missing bundled ffmpeg executable" >&2
    exit 1
fi
if [ "$(lipo -archs "$FFMPEG_EXECUTABLE")" != "arm64" ]; then
    echo "error: bundled ffmpeg executable is not ARM64-only" >&2
    exit 1
fi
while read -r dependency; do
    case "$dependency" in
        @rpath/*|/System/Library/*|/usr/lib/*) ;;
        *)
            echo "error: forbidden ffmpeg executable dependency: $dependency" >&2
            exit 1
            ;;
    esac
done < <(otool -L "$FFMPEG_EXECUTABLE" | tail -n +2 | awk '{print $1}')

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
if ! grep -Eq '^CONFIG_LIBDAV1D_DECODER=yes$' "$ROOT/ffmpeg-config.mak"; then
    echo "error: staged FFmpeg configuration is missing libdav1d decoding" >&2
    exit 1
fi
if ! "$FFMPEG_EXECUTABLE" -hide_banner -decoders 2>/dev/null | \
    grep -E '^[[:space:]]*V[^[:space:]]*[[:space:]]+libdav1d[[:space:]]' >/dev/null; then
    echo "error: bundled ffmpeg executable does not expose libdav1d" >&2
    exit 1
fi
libavcodec_dylib="$(find "$LIB_DIR" -type f -name 'libavcodec*.dylib' -print -quit)"
if ! otool -L "$libavcodec_dylib" | tail -n +2 | awk '{print $1}' | \
    grep -E '^@rpath/libdav1d(\.[0-9]+)*\.dylib$' >/dev/null; then
    echo "error: staged libavcodec is not linked to bundled libdav1d" >&2
    exit 1
fi

echo "Verified ARM64 macOS media runtime: $ROOT"
