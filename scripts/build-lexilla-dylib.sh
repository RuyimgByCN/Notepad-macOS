#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_DIR="$ROOT_DIR/upstream/notepad-plus-plus"
LEXILLA_BIN="$ROOT_DIR/.build/lexilla/bin"
DEFAULT_JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
if (( DEFAULT_JOBS > 4 )); then
    DEFAULT_JOBS=4
fi
JOBS="${MACOS_LEXILLA_JOBS:-$DEFAULT_JOBS}"
LIPO="$(xcrun --find lipo 2>/dev/null || true)"
LEXILLA_ARCHS="${MACOS_LEXILLA_ARCHS:-}"
LEXILLA_ONLY_ACTIVE_ARCH="${MACOS_LEXILLA_ONLY_ACTIVE_ARCH:-}"
LEXILLA_UNIVERSAL_ARCHS="${MACOS_LEXILLA_UNIVERSAL_ARCHS:-arm64 x86_64}"
LEXILLA_EXTRA_BASE_FLAGS="${MACOS_LEXILLA_EXTRA_BASE_FLAGS:-}"
LEXILLA_EXTRA_LDFLAGS="${MACOS_LEXILLA_EXTRA_LDFLAGS:-${LDFLAGS:-}}"
LEXILLA_INSTALL_NAME="${MACOS_LEXILLA_INSTALL_NAME:-@rpath/liblexilla.dylib}"

archs_for_binary() {
    local binary="$1"

    if [[ ! -e "$binary" ]]; then
        echo "missing"
        return 1
    fi

    if [[ -n "$LIPO" ]]; then
        "$LIPO" -archs "$binary" 2>/dev/null && return 0
    fi

    file "$binary"
}

binary_has_arch() {
    local binary="$1"
    local required_arch="$2"
    local archs

    archs="$(archs_for_binary "$binary" 2>/dev/null || true)"
    [[ " $archs " == *" $required_arch "* ]]
}

is_truthy() {
    case "${1:-}" in
        1|[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_falsey() {
    case "${1:-}" in
        0|[Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

resolve_requested_archs() {
    if [[ -n "$LEXILLA_ARCHS" ]]; then
        echo "$LEXILLA_ARCHS"
        return 0
    fi

    if is_truthy "$LEXILLA_ONLY_ACTIVE_ARCH"; then
        uname -m
        return 0
    fi

    if [[ -n "$LEXILLA_ONLY_ACTIVE_ARCH" ]] && ! is_falsey "$LEXILLA_ONLY_ACTIVE_ARCH"; then
        echo "Unsupported MACOS_LEXILLA_ONLY_ACTIVE_ARCH value: $LEXILLA_ONLY_ACTIVE_ARCH" >&2
        echo "Use YES/NO, TRUE/FALSE, ON/OFF, or 1/0." >&2
        exit 1
    fi

    echo "$LEXILLA_UNIVERSAL_ARCHS"
}

join_flags() {
    local IFS=' '
    printf '%s' "$*"
}

REQUESTED_ARCHS="$(resolve_requested_archs)"
if [[ -z "${REQUESTED_ARCHS// }" ]]; then
    echo "No Lexilla architectures were requested." >&2
    echo "Set MACOS_LEXILLA_ARCHS or MACOS_LEXILLA_UNIVERSAL_ARCHS to at least one architecture." >&2
    exit 1
fi

if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
    echo "Unsupported MACOS_LEXILLA_JOBS value: $JOBS" >&2
    echo "Use a positive integer." >&2
    exit 1
fi

base_flags=()
ldflags=()

for arch in $REQUESTED_ARCHS; do
    base_flags+=(-arch "$arch")
    ldflags+=(-arch "$arch")
done

base_flags+=(-fvisibility=hidden --std=c++17 -fPIC -mmacosx-version-min=13.0)
if [[ -n "${DEBUG:-}" ]]; then
    base_flags+=(-g)
else
    base_flags+=(-O3)
fi
base_flags+=(-Wpedantic -Wall -Wextra)
ldflags+=(-dynamiclib -shared)
if [[ -n "$LEXILLA_INSTALL_NAME" ]]; then
    ldflags+=(-install_name "$LEXILLA_INSTALL_NAME")
fi

if [[ -n "$LEXILLA_EXTRA_BASE_FLAGS" ]]; then
    # shellcheck disable=SC2206
    extra_base_flags=( $LEXILLA_EXTRA_BASE_FLAGS )
    base_flags+=("${extra_base_flags[@]}")
fi

if [[ -n "$LEXILLA_EXTRA_LDFLAGS" ]]; then
    # shellcheck disable=SC2206
    extra_ldflags=( $LEXILLA_EXTRA_LDFLAGS )
    ldflags+=("${extra_ldflags[@]}")
fi

BASE_FLAGS_VALUE="$(join_flags "${base_flags[@]}")"
LDFLAGS_VALUE="$(join_flags "${ldflags[@]}")"

if [[ -n "$LEXILLA_ARCHS" ]]; then
    echo "Building Lexilla with explicit archs: $REQUESTED_ARCHS"
elif is_truthy "$LEXILLA_ONLY_ACTIVE_ARCH"; then
    echo "Building Lexilla for active arch only: $REQUESTED_ARCHS"
else
    echo "Building Lexilla with requested archs: $REQUESTED_ARCHS"
fi

mkdir -p "$LEXILLA_BIN"
SOURCE_DIR="$(mktemp -d "$ROOT_DIR/.build/lexilla-source.XXXXXXXX")"
trap 'rm -rf "$SOURCE_DIR"' EXIT
git -C "$UPSTREAM_DIR" archive HEAD lexilla scintilla/include | tar -x -C "$SOURCE_DIR"
cp "$ROOT_DIR/patches/lexilla/LexUser.cxx" "$SOURCE_DIR/lexilla/lexers/LexUser.cxx"
LEXILLA_SRC="$SOURCE_DIR/lexilla/src"
LEXILLA_DYLIB="$SOURCE_DIR/lexilla/bin/liblexilla.dylib"
make -C "$LEXILLA_SRC" -j"$JOBS" "BASE_FLAGS=$BASE_FLAGS_VALUE" "LDFLAGS=$LDFLAGS_VALUE" all

ACTUAL_ARCHS="$(archs_for_binary "$LEXILLA_DYLIB" 2>/dev/null || echo "missing")"
for required_arch in $REQUESTED_ARCHS; do
    if ! binary_has_arch "$LEXILLA_DYLIB" "$required_arch"; then
        echo "ERROR: Requested Lexilla arch '$required_arch' was not produced." >&2
        echo "       Requested: $REQUESTED_ARCHS" >&2
        echo "       Actual:    $ACTUAL_ARCHS" >&2
        exit 1
    fi
done

cp "$LEXILLA_DYLIB" "$LEXILLA_BIN/liblexilla.dylib"
cp "$SOURCE_DIR/lexilla/bin/liblexilla.a" "$LEXILLA_BIN/liblexilla.a"

echo "Built Lexilla dylib:"
echo "  $LEXILLA_BIN/liblexilla.dylib"
echo "  Architectures: $ACTUAL_ARCHS"
