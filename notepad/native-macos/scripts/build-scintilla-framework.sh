#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
SCINTILLA_PROJECT="$PROJECT_ROOT/notepad-plus-plus/scintilla/cocoa/Scintilla/Scintilla.xcodeproj"
DERIVED_DATA="${MACOS_SCINTILLA_DERIVED_DATA:-$ROOT_DIR/.build/scintilla-derived}"
CONFIGURATION="${MACOS_SCINTILLA_CONFIGURATION:-Release}"
SCINTILLA_ARCHS="${MACOS_SCINTILLA_ARCHS:-}"
SCINTILLA_ONLY_ACTIVE_ARCH="${MACOS_SCINTILLA_ONLY_ACTIVE_ARCH:-}"
SCINTILLA_DESTINATION="${MACOS_SCINTILLA_DESTINATION:-}"
LIPO="$(xcrun --find lipo 2>/dev/null || true)"

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

scintilla_binary_path() {
    local framework="$1"
    local versioned_binary="$framework/Versions/A/Scintilla"
    local root_binary="$framework/Scintilla"

    if [[ -f "$versioned_binary" ]]; then
        echo "$versioned_binary"
    elif [[ -f "$root_binary" ]]; then
        echo "$root_binary"
    else
        echo "$versioned_binary"
    fi
}

build_cmd=(
    xcodebuild
    -project "$SCINTILLA_PROJECT"
    -scheme Scintilla
    -configuration "$CONFIGURATION"
    -derivedDataPath "$DERIVED_DATA"
)

if [[ -n "$SCINTILLA_DESTINATION" ]]; then
    build_cmd+=(-destination "$SCINTILLA_DESTINATION")
elif [[ -n "$SCINTILLA_ARCHS" ]]; then
    build_cmd+=(-destination "generic/platform=macOS")
fi

if [[ -n "$SCINTILLA_ARCHS" ]]; then
    build_cmd+=("ARCHS=$SCINTILLA_ARCHS")
fi

if [[ -n "$SCINTILLA_ONLY_ACTIVE_ARCH" ]]; then
    build_cmd+=("ONLY_ACTIVE_ARCH=$SCINTILLA_ONLY_ACTIVE_ARCH")
fi

build_cmd+=(build)

"${build_cmd[@]}"

FRAMEWORK_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/Scintilla.framework"
SCINTILLA_BINARY="$(scintilla_binary_path "$FRAMEWORK_PATH")"
ACTUAL_ARCHS="$(archs_for_binary "$SCINTILLA_BINARY" 2>/dev/null || echo "missing")"

if [[ -n "$SCINTILLA_ARCHS" ]]; then
    for required_arch in $SCINTILLA_ARCHS; do
        if ! binary_has_arch "$SCINTILLA_BINARY" "$required_arch"; then
            echo "WARNING: Requested Scintilla arch '$required_arch' was not produced." >&2
            echo "         Requested: $SCINTILLA_ARCHS" >&2
            echo "         Actual:    $ACTUAL_ARCHS" >&2
            exit 1
        fi
    done
fi

if [[ -n "$SCINTILLA_ARCHS" ]]; then
    echo "Built Scintilla framework with requested archs: $SCINTILLA_ARCHS"
else
    echo "Built Scintilla framework with Xcode default arch selection."
fi

echo "Built Scintilla framework:"
echo "  $FRAMEWORK_PATH"
echo "  Architectures: $ACTUAL_ARCHS"
