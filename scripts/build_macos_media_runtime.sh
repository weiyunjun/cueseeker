#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCK_FILE="$REPO_ROOT/third_party/media-runtime/sources.lock"
PATCH_FILE="$REPO_ROOT/third_party/ffmpeg/patches/ffmpeg-8.1-cueseeker-skip-internal-subtitles.patch"
LAME_PATCH_FILE="$REPO_ROOT/third_party/lame/patches/lame-3.100-remove-obsolete-export.patch"
BUILD_ROOT="${CUESEEKER_MEDIA_BUILD_ROOT:-$REPO_ROOT/.build/media-runtime-build}"
CACHE_ROOT="${CUESEEKER_MEDIA_CACHE_ROOT:-$REPO_ROOT/.build/media-runtime-cache}"
PREFIX="${CUESEEKER_MEDIA_RUNTIME_ROOT:-$REPO_ROOT/.build/media-runtime/arm64-macos13}"
DEPLOYMENT_TARGET="13.0"
JOBS="${CUESEEKER_MEDIA_BUILD_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"

usage() {
    echo "Usage: $0 [--clean] [--prefix PATH]"
}

CLEAN=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --clean)
            CLEAN=1
            shift
            ;;
        --prefix)
            PREFIX="$2"
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

if [ "$(uname -m)" != "arm64" ]; then
    echo "error: the CueSeeker media runtime is ARM64-only" >&2
    exit 1
fi

for tool in curl shasum tar patch xcrun clang clang++ make install_name_tool otool lipo; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required tool not found: $tool" >&2
        exit 1
    fi
done

if [ "$CLEAN" -eq 1 ]; then
    rm -rf "$BUILD_ROOT" "$PREFIX"
fi

mkdir -p "$CACHE_ROOT" "$BUILD_ROOT/sources" "$BUILD_ROOT/build" "$PREFIX"

download_sources() {
    while IFS='|' read -r name version archive url sha source_directory; do
        case "$name" in
            ''|'#'*) continue ;;
        esac
        destination="$CACHE_ROOT/$archive"
        if [ ! -f "$destination" ]; then
            echo "Downloading $name $version"
            curl -L --fail --retry 3 --output "$destination.part" "$url"
            mv "$destination.part" "$destination"
        fi
        actual_sha="$(shasum -a 256 "$destination" | awk '{print $1}')"
        if [ "$actual_sha" != "$sha" ]; then
            echo "error: SHA-256 mismatch for $archive" >&2
            echo "expected: $sha" >&2
            echo "actual:   $actual_sha" >&2
            exit 1
        fi
    done < "$LOCK_FILE"
}

extract_sources() {
    rm -rf "$BUILD_ROOT/sources"
    mkdir -p "$BUILD_ROOT/sources"
    while IFS='|' read -r name version archive url sha source_directory; do
        case "$name" in
            ''|'#'*) continue ;;
        esac
        tar -xf "$CACHE_ROOT/$archive" -C "$BUILD_ROOT/sources"
        if [ ! -d "$BUILD_ROOT/sources/$source_directory" ]; then
            echo "error: expected source directory missing: $source_directory" >&2
            exit 1
        fi
    done < "$LOCK_FILE"
}

bootstrap_meson() {
    TOOL_VENV="$BUILD_ROOT/tools"
    if [ ! -x "$TOOL_VENV/bin/meson" ] || [ ! -x "$TOOL_VENV/bin/ninja" ]; then
        rm -rf "$TOOL_VENV"
        python3 -m venv "$TOOL_VENV"
        "$TOOL_VENV/bin/python" -m pip install --disable-pip-version-check \
            'meson==1.9.1' 'ninja==1.13.0'
    fi
    MESON="$TOOL_VENV/bin/meson"
}

configure_environment() {
    SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
    export SDKROOT
    export MACOSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"
    export CC="$(xcrun --find clang)"
    export CXX="$(xcrun --find clang++)"
    export CFLAGS="-arch arm64 -mmacosx-version-min=$DEPLOYMENT_TARGET -O2"
    export CXXFLAGS="$CFLAGS"
    export LDFLAGS="-arch arm64 -mmacosx-version-min=$DEPLOYMENT_TARGET"
    export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/clang-module-cache"
    mkdir -p "$CLANG_MODULE_CACHE_PATH"
    export PATH="$BUILD_ROOT/tools/bin:/usr/bin:/bin:/usr/sbin:/sbin"
}

build_pkgconf() {
    source="$BUILD_ROOT/sources/pkgconf-2.5.1"
    build="$BUILD_ROOT/build/pkgconf"
    rm -rf "$build"
    mkdir -p "$build"
    (
        cd "$build"
        "$source/configure" \
            --prefix="$BUILD_ROOT/tools" \
            --disable-shared \
            --enable-static
        make -j "$JOBS"
        make install
    )
    ln -sf pkgconf "$BUILD_ROOT/tools/bin/pkg-config"
    export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
    export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"
}

meson_build() {
    name="$1"
    source="$2"
    shift 2
    build="$BUILD_ROOT/build/$name"
    rm -rf "$build"
    "$MESON" setup "$build" "$source" \
        --prefix "$PREFIX" \
        --libdir lib \
        --buildtype release \
        --default-library shared \
        --wrap-mode nofallback \
        "$@"
    "$MESON" compile -C "$build" -j "$JOBS"
    "$MESON" install -C "$build"
}

build_freetype() {
    meson_build freetype "$BUILD_ROOT/sources/freetype-2.14.3" \
        -Dbrotli=disabled \
        -Dbzip2=disabled \
        -Dharfbuzz=disabled \
        -Dpng=disabled \
        -Dzlib=system \
        -Dtests=disabled
}

build_fribidi() {
    meson_build fribidi "$BUILD_ROOT/sources/fribidi-1.0.16" \
        -Ddeprecated=false \
        -Ddocs=false \
        -Dbin=false \
        -Dtests=false
}

build_harfbuzz() {
    meson_build harfbuzz "$BUILD_ROOT/sources/harfbuzz-14.1.0" \
        -Dglib=disabled \
        -Dgobject=disabled \
        -Dcairo=disabled \
        -Dchafa=disabled \
        -Dpng=disabled \
        -Dzlib=disabled \
        -Dicu=disabled \
        -Dgraphite=disabled \
        -Dgraphite2=disabled \
        -Dfreetype=enabled \
        -Dcoretext=disabled \
        -Draster=disabled \
        -Dvector=disabled \
        -Dgpu=disabled \
        -Dsubset=disabled \
        -Dtests=disabled \
        -Dintrospection=disabled \
        -Ddocs=disabled \
        -Dutilities=disabled
}

build_libunibreak() {
    source="$BUILD_ROOT/sources/libunibreak-6.1"
    build="$BUILD_ROOT/build/libunibreak"
    rm -rf "$build"
    mkdir -p "$build"
    (
        cd "$build"
        "$source/configure" \
            --prefix="$PREFIX" \
            --libdir="$PREFIX/lib" \
            --enable-shared \
            --disable-static
        make -j "$JOBS"
        make install
    )
}

build_libass() {
    source="$BUILD_ROOT/sources/libass-0.17.4"
    build="$BUILD_ROOT/build/libass"
    rm -rf "$build"
    mkdir -p "$build"
    (
        cd "$build"
        "$source/configure" \
            --prefix="$PREFIX" \
            --libdir="$PREFIX/lib" \
            --enable-shared \
            --disable-static \
            --disable-fontconfig \
            --enable-coretext \
            --enable-libunibreak
        make -j "$JOBS"
        make install
    )
}

build_lame() {
    source="$BUILD_ROOT/sources/lame-3.100"
    build="$BUILD_ROOT/build/lame"
    patch --forward -p1 -d "$source" < "$LAME_PATCH_FILE"
    rm -rf "$build"
    mkdir -p "$build"
    (
        cd "$build"
        "$source/configure" \
            --prefix="$PREFIX" \
            --libdir="$PREFIX/lib" \
            --enable-shared \
            --disable-static \
            --disable-frontend
        make -j "$JOBS"
        make install
    )
}

build_dav1d() {
    meson_build dav1d "$BUILD_ROOT/sources/dav1d-1.5.4" \
        -Denable_tools=false \
        -Denable_examples=false \
        -Denable_tests=false \
        -Denable_docs=false \
        -Dxxhash_muxer=disabled
}

build_ffmpeg() {
    source="$BUILD_ROOT/sources/ffmpeg-8.1.2"
    build="$BUILD_ROOT/build/ffmpeg"
    patch --forward -p1 -d "$source" < "$PATCH_FILE"
    rm -rf "$build"
    mkdir -p "$build"
    (
        cd "$build"
        "$source/configure" \
            --prefix="$PREFIX" \
            --libdir="$PREFIX/lib" \
            --shlibdir="$PREFIX/lib" \
            --arch=arm64 \
            --target-os=darwin \
            --cc="$CC" \
            --cxx="$CXX" \
            --enable-shared \
            --disable-static \
            --enable-ffmpeg \
            --disable-ffplay \
            --disable-ffprobe \
            --disable-doc \
            --disable-debug \
            --disable-avdevice \
            --disable-gpl \
            --disable-nonfree \
            --enable-libdav1d \
            --enable-libmp3lame \
            --enable-videotoolbox \
            --enable-audiotoolbox \
            --disable-metal \
            --enable-pic \
            --install-name-dir='@rpath' \
            --extra-cflags="$CFLAGS -I$PREFIX/include" \
            --extra-cxxflags="$CXXFLAGS -I$PREFIX/include" \
            --extra-ldflags="$LDFLAGS -L$PREFIX/lib -Wl,-rpath,$PREFIX/lib -Wl,-rpath,@executable_path/../Frameworks"
        if grep -Eq '^CONFIG_(GPL|NONFREE)=yes' ffbuild/config.mak; then
            echo "error: FFmpeg configured with GPL or nonfree components" >&2
            exit 1
        fi
        make -j "$JOBS"
        make install
        cp ffbuild/config.mak "$PREFIX/ffmpeg-config.mak"
        cp config.h "$PREFIX/ffmpeg-config.h"
    )
}

rewrite_install_names() {
    mapfile_path="$BUILD_ROOT/dylib-map.txt"
    : > "$mapfile_path"
    find "$PREFIX/lib" -type f -name '*.dylib' -print | sort | while read -r dylib; do
        old_id="$(otool -D "$dylib" | tail -n +2 | head -n 1)"
        basename="$(basename "$dylib")"
        echo "$old_id|@rpath/$basename" >> "$mapfile_path"
        install_name_tool -id "@rpath/$basename" "$dylib"
    done

    find "$PREFIX/lib" -type f -name '*.dylib' -print | sort | while read -r dylib; do
        while IFS='|' read -r old_id new_id; do
            [ -n "$old_id" ] || continue
            if otool -L "$dylib" | awk '{print $1}' | grep -Fx "$old_id" >/dev/null; then
                install_name_tool -change "$old_id" "$new_id" "$dylib"
            fi
        done < "$mapfile_path"
    done

    if [ -x "$PREFIX/bin/ffmpeg" ]; then
        while IFS='|' read -r old_id new_id; do
            [ -n "$old_id" ] || continue
            if otool -L "$PREFIX/bin/ffmpeg" | awk '{print $1}' | grep -Fx "$old_id" >/dev/null; then
                install_name_tool -change "$old_id" "$new_id" "$PREFIX/bin/ffmpeg"
            fi
        done < "$mapfile_path"
    fi
}

stage_licenses_and_manifest() {
    licenses="$PREFIX/licenses"
    mkdir -p "$licenses"
    cp "$BUILD_ROOT/sources/ffmpeg-8.1.2/LICENSE.md" "$licenses/FFmpeg-LICENSE.md"
    cp "$BUILD_ROOT/sources/dav1d-1.5.4/COPYING" "$licenses/dav1d-COPYING"
    cp "$BUILD_ROOT/sources/libass-0.17.4/COPYING" "$licenses/libass-COPYING"
    cp "$BUILD_ROOT/sources/freetype-2.14.3/LICENSE.TXT" "$licenses/FreeType-LICENSE.txt"
    cp "$BUILD_ROOT/sources/fribidi-1.0.16/COPYING" "$licenses/FriBidi-COPYING"
    cp "$BUILD_ROOT/sources/harfbuzz-14.1.0/COPYING" "$licenses/HarfBuzz-COPYING"
    cp "$BUILD_ROOT/sources/libunibreak-6.1/LICENCE" "$licenses/libunibreak-LICENCE"
    cp "$BUILD_ROOT/sources/lame-3.100/COPYING" "$licenses/LAME-COPYING"
    cp "$LOCK_FILE" "$PREFIX/sources.lock"
    cp "$PATCH_FILE" "$PREFIX/ffmpeg-cueseeker.patch"
    cp "$LAME_PATCH_FILE" "$PREFIX/lame-cueseeker.patch"
    {
        echo "deployment_target=$DEPLOYMENT_TARGET"
        echo "architecture=arm64"
        echo "sdk=$(xcrun --sdk macosx --show-sdk-version)"
        echo "clang=$($CC --version | head -n 1)"
        echo "meson=$($MESON --version)"
        echo "ninja=$($BUILD_ROOT/tools/bin/ninja --version)"
        echo "patch_sha256=$(shasum -a 256 "$PATCH_FILE" | awk '{print $1}')"
        echo "lame_patch_sha256=$(shasum -a 256 "$LAME_PATCH_FILE" | awk '{print $1}')"
    } > "$PREFIX/build-info.txt"
}

download_sources
extract_sources
bootstrap_meson
configure_environment
build_pkgconf
rm -rf "$PREFIX"
mkdir -p "$PREFIX"
build_freetype
build_fribidi
build_harfbuzz
build_libunibreak
build_libass
build_lame
build_dav1d
build_ffmpeg
rewrite_install_names
stage_licenses_and_manifest
"$SCRIPT_DIR/verify_macos_media_runtime.sh" "$PREFIX"
echo "CueSeeker media runtime ready: $PREFIX"
