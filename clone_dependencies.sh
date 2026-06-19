#!/usr/bin/env bash
# Pre-clone BuildFFmpeg source dependencies.
#
# Usage:
#   ./clone_dependencies.sh [--depth1|--gitCloneAll|gitCloneAll] [--include-optional] [--disableGPL] [--update]
#
# Defaults mirror BuildFFmpeg:
#   - shallow clones are used unless gitCloneAll is passed
#   - GPL-only default dependencies are included unless --disableGPL is passed
#   - only the BuildFFmpeg default library set is cloned unless --include-optional is passed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="$SCRIPT_DIR/.Script"
mkdir -p "$DEST_DIR"

CLONE_MODE="shallow"
DEPTH_ARGS=(--depth 1)
INCLUDE_OPTIONAL=0
DISABLE_GPL=0
UPDATE_EXISTING=0

usage() {
    sed -n '2,11p' "$0"
}

for arg in "$@"; do
    case "$arg" in
        --depth1)
            CLONE_MODE="shallow"
            DEPTH_ARGS=(--depth 1)
            ;;
        --gitCloneAll|gitCloneAll|--full)
            CLONE_MODE="full"
            DEPTH_ARGS=()
            ;;
        --include-optional)
            INCLUDE_OPTIONAL=1
            ;;
        --disableGPL|disableGPL)
            DISABLE_GPL=1
            ;;
        --update)
            UPDATE_EXISTING=1
            ;;
        -h|--help|h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            usage >&2
            exit 2
            ;;
    esac
done

# Default BuildFFmpeg library order from Plugins/BuildFFmpeg/main.swift.
DEFAULT_DEPS=(
    "libshaderc|v2026.2|https://github.com/google/shaderc"
    "vulkan|v1.2.8|https://github.com/KhronosGroup/MoltenVK"
    "lcms2|lcms2.19.1|https://github.com/mm2/Little-CMS"
    "libplacebo|v7.360.1|https://github.com/haasn/libplacebo"
    "libdav1d|1.5.3|https://github.com/videolan/dav1d"
    "gmp|6.3.0|https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz"
    "nettle|nettle_4.0_release_20260205|https://git.lysator.liu.se/nettle/nettle"
    "gnutls|3.8.13|https://github.com/gnutls/gnutls"
    "readline|readline-8.3|https://git.savannah.gnu.org/git/readline.git"
    "libsmbclient|samba-4.24.3|https://github.com/samba-team/samba"
    "libsrt|v1.5.5|https://github.com/Haivision/srt"
    "libzvbi|v0.2.44|https://github.com/zapping-vbi/zvbi"
    "libfreetype|VER-2-14-3|https://github.com/freetype/freetype"
    "libfribidi|v1.0.16|https://github.com/fribidi/fribidi"
    "libharfbuzz|14.2.1|https://github.com/harfbuzz/harfbuzz"
    "libass|0.17.4|https://github.com/libass/libass"
    "libfontconfig|2.18.1|https://gitlab.freedesktop.org/fontconfig/fontconfig"
    "libbluray|1.3.4|https://code.videolan.org/videolan/libbluray"
    "FFmpeg|release/8.1|https://github.com/FFmpeg/FFmpeg"
    "libmpv|v0.41.0|https://github.com/mpv-player/mpv"
)

# Libraries present in the BuildFFmpeg Library enum but not built by default.
OPTIONAL_DEPS=(
    "libglslang|13.1.1|https://github.com/KhronosGroup/glslang"
    "libdovi|2.1.0|https://github.com/quietvoid/dovi_tool"
    "openssl|openssl-3.2.1|https://github.com/openssl/openssl"
    "libtls|OPENBSD_7_3|https://github.com/libressl/portable"
    "boringssl|master|https://github.com/google/boringssl"
    "libpng|v1.6.43|https://github.com/glennrp/libpng"
    "libupnp|release-1.14.18|https://github.com/pupnp/pupnp"
    "libnfs|libnfs-5.0.2|https://github.com/sahlberg/libnfs"
    "libsmb2|master|https://github.com/sahlberg/libsmb2"
)

DEPS=()
for dep in "${DEFAULT_DEPS[@]}"; do
    if [[ "$DISABLE_GPL" == "1" ]] && [[ "$dep" == readline\|* || "$dep" == libsmbclient\|* ]]; then
        continue
    fi
    DEPS+=("$dep")
done
if [[ "$INCLUDE_OPTIONAL" == "1" ]]; then
    DEPS+=("${OPTIONAL_DEPS[@]}")
fi

clone_repo() {
    local name="$1"
    local version="$2"
    local url="$3"
    local directory_version="${version//\//-}"
    local target="$DEST_DIR/${name}-${directory_version}"

    if [[ "$url" == *.tar.xz || "$url" == *.tar.gz || "$url" == *.tgz ]]; then
        clone_archive "$name" "$version" "$url" "$target"
        return $?
    fi

    if [[ -d "$target/.git" ]]; then
        if [[ "$UPDATE_EXISTING" != "1" ]]; then
            echo "SKIP $name-$version already exists"
            return 0
        fi

        echo "UPDATE $name ($version)"
        if git -C "$target" ls-remote --exit-code --heads origin "$version" >/dev/null 2>&1; then
            git -C "$target" fetch --tags "${DEPTH_ARGS[@]}" origin "+refs/heads/$version:refs/remotes/origin/$version"
            if git -C "$target" show-ref --verify --quiet "refs/heads/$version"; then
                git -C "$target" checkout "$version"
            else
                git -C "$target" checkout -b "$version" "origin/$version"
            fi
            git -C "$target" merge --ff-only "origin/$version"
        else
            git -C "$target" fetch --tags "${DEPTH_ARGS[@]}" origin "$version" 2>/dev/null || git -C "$target" fetch --tags origin
            git -C "$target" checkout "$version"
        fi
        git -C "$target" submodule update --init --recursive
        return 0
    fi

    if [[ -e "$target" ]]; then
        echo "FAIL $target exists but is not a git checkout" >&2
        return 1
    fi

    echo "CLONE $name ($version) from $url"
    if git clone --recurse-submodules "${DEPTH_ARGS[@]}" --branch "$version" "$url" "$target"; then
        return 0
    fi

    echo "FAIL $name-$version clone failed" >&2
    rm -rf "$target"
    return 1
}

clone_archive() {
    local name="$1"
    local version="$2"
    local url="$3"
    local target="$4"
    local archive="$DEST_DIR/$(basename "$url")"
    local tmp_dir="$DEST_DIR/.${name}-${version//\//-}.extract"

    if [[ -d "$target" && "$UPDATE_EXISTING" != "1" ]]; then
        echo "SKIP $name-$version already exists"
        return 0
    fi

    if [[ -e "$target" ]]; then
        rm -rf "$target"
    fi

    if [[ ! -f "$archive" || "$UPDATE_EXISTING" == "1" ]]; then
        echo "DOWNLOAD $name ($version) from $url"
        if ! curl -fL -o "$archive" "$url"; then
            rm -f "$archive"
            return 1
        fi
    fi

    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"
    if ! tar -xf "$archive" -C "$tmp_dir"; then
        rm -rf "$tmp_dir"
        return 1
    fi

    local extracted
    extracted="$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d -print -quit)"
    if [[ -z "$extracted" ]]; then
        echo "FAIL $name-$version archive did not contain a source directory" >&2
        rm -rf "$tmp_dir"
        return 1
    fi

    mv "$extracted" "$target"
    rm -rf "$tmp_dir"
}

sync_shaderc_deps() {
    local shaderc_dir="$DEST_DIR/libshaderc-v2026.2"
    if [[ ! -f "$shaderc_dir/utils/git-sync-deps" ]]; then
        return 0
    fi

    echo ""
    echo "Sync libshaderc third_party dependencies"
    (
        cd "$shaderc_dir"
        python3 utils/git-sync-deps
    )
}

echo "========================================"
echo "Pre-clone BuildFFmpeg dependencies"
echo "Destination : $DEST_DIR"
echo "Clone mode  : $CLONE_MODE"
echo "disableGPL  : $DISABLE_GPL"
echo "optional    : $INCLUDE_OPTIONAL"
echo "update      : $UPDATE_EXISTING"
echo "========================================"

FAILED=()
COUNT=0
TOTAL=${#DEPS[@]}

for dep in "${DEPS[@]}"; do
    COUNT=$((COUNT + 1))
    IFS='|' read -r name version url <<< "$dep"
    echo ""
    echo "[$COUNT/$TOTAL] $name-$version"
    if ! clone_repo "$name" "$version" "$url"; then
        FAILED+=("$name-$version")
    fi
done

if ! sync_shaderc_deps; then
    FAILED+=("libshaderc-v2026.2 third_party")
fi

echo ""
echo "========================================"
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Dependency preparation failed:"
    for item in "${FAILED[@]}"; do
        echo "  - $item"
    done
    exit 1
fi

echo "Dependency preparation completed."
echo ""
echo "Next:"
echo "  cd \"$SCRIPT_DIR\""
if [[ "$CLONE_MODE" == "full" ]]; then
    echo "  swift package --disable-sandbox BuildFFmpeg gitCloneAll"
else
    echo "  swift package --disable-sandbox BuildFFmpeg"
fi
