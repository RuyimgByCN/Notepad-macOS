#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Notepad++ Mac"
EXECUTABLE_NAME="NotepadMac"
BUNDLE_ID="org.notepad-plus-plus.macnative"
VERSION="8.9.6.2"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
UPSTREAM_DIR="$ROOT_DIR/../notepad-plus-plus"
ICON_SOURCE="$UPSTREAM_DIR/PowerEditor/misc/chameleon/chameleon-pencil-1000.png"
ICON_NAME="NotepadMac.icns"
SCINTILLA_DERIVED_DATA="${MACOS_SCINTILLA_DERIVED_DATA:-$ROOT_DIR/.build/scintilla-derived}"
SCINTILLA_CONFIGURATION="${MACOS_SCINTILLA_CONFIGURATION:-Release}"
SCINTILLA_FRAMEWORK="$SCINTILLA_DERIVED_DATA/Build/Products/$SCINTILLA_CONFIGURATION/Scintilla.framework"
LEXILLA_DYLIB="$UPSTREAM_DIR/lexilla/bin/liblexilla.dylib"
ARM64_TRIPLE="${MACOS_ARM64_TRIPLE:-arm64-apple-macosx13.0}"
X86_64_TRIPLE="${MACOS_X86_64_TRIPLE:-x86_64-apple-macosx13.0}"
UNIVERSAL_BIN_DIR="$ROOT_DIR/.build/universal-release"
SCINTILLA_UNIVERSAL_ARCHS="${MACOS_SCINTILLA_UNIVERSAL_ARCHS:-arm64 x86_64}"
LEXILLA_UNIVERSAL_ARCHS="${MACOS_LEXILLA_UNIVERSAL_ARCHS:-arm64 x86_64}"
CODESIGN_IDENTITY="${MACOS_CODESIGN_IDENTITY:--}"
CODESIGN_KEYCHAIN="${MACOS_CODESIGN_KEYCHAIN:-}"
LIPO="$(xcrun --find lipo 2>/dev/null || true)"
INSTALL_NAME_TOOL="$(xcrun --find install_name_tool 2>/dev/null || true)"

MAIN_BINARY_SOURCE=""
RESOURCE_BIN_DIR=""
MAIN_BUILD_MODE=""
LEXILLA_BUILD_MODE=""
LEXILLA_REQUESTED_ARCHS=""

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

binary_has_universal_archs() {
    local binary="$1"

    binary_has_arch "$binary" arm64 && binary_has_arch "$binary" x86_64
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

swift_build_supports_arch_flag() {
    swift build --help 2>&1 | grep -q -- "--arch"
}

show_bin_path() {
    swift build --package-path "$ROOT_DIR" -c release "$@" --show-bin-path
}

build_main_one_step_universal() {
    local bin_dir
    local candidate

    if ! swift_build_supports_arch_flag; then
        echo "SwiftPM --arch is not available in this toolchain; using per-architecture fallback."
        return 1
    fi

    echo "Attempting one-step universal SwiftPM build for $EXECUTABLE_NAME..."
    if ! swift build --package-path "$ROOT_DIR" -c release --arch arm64 --arch x86_64; then
        echo "One-step universal SwiftPM build failed; using per-architecture fallback." >&2
        return 1
    fi

    if ! bin_dir="$(show_bin_path --arch arm64 --arch x86_64)"; then
        echo "Could not resolve one-step universal SwiftPM output path; using per-architecture fallback." >&2
        return 1
    fi

    candidate="$bin_dir/$EXECUTABLE_NAME"
    if ! binary_has_universal_archs "$candidate"; then
        echo "One-step SwiftPM output is not universal ($(archs_for_binary "$candidate")); using per-architecture fallback." >&2
        return 1
    fi

    MAIN_BINARY_SOURCE="$candidate"
    RESOURCE_BIN_DIR="$bin_dir"
    MAIN_BUILD_MODE="swiftpm-universal"
}

build_main_lipo_universal() {
    local arm_bin_dir
    local x86_bin_dir
    local arm_binary
    local x86_binary
    local universal_binary="$UNIVERSAL_BIN_DIR/$EXECUTABLE_NAME"

    if [[ -z "$LIPO" ]]; then
        echo "lipo is not available; cannot merge per-architecture builds." >&2
        return 1
    fi

    echo "Building $EXECUTABLE_NAME for arm64..."
    if ! swift build --package-path "$ROOT_DIR" -c release --triple "$ARM64_TRIPLE"; then
        echo "arm64 Swift build failed; cannot create universal main executable." >&2
        return 1
    fi
    if ! arm_bin_dir="$(show_bin_path --triple "$ARM64_TRIPLE")"; then
        echo "Could not resolve arm64 Swift build output path." >&2
        return 1
    fi

    echo "Building $EXECUTABLE_NAME for x86_64..."
    if ! swift build --package-path "$ROOT_DIR" -c release --triple "$X86_64_TRIPLE"; then
        echo "x86_64 Swift build failed; cannot create universal main executable." >&2
        return 1
    fi
    if ! x86_bin_dir="$(show_bin_path --triple "$X86_64_TRIPLE")"; then
        echo "Could not resolve x86_64 Swift build output path." >&2
        return 1
    fi

    arm_binary="$arm_bin_dir/$EXECUTABLE_NAME"
    x86_binary="$x86_bin_dir/$EXECUTABLE_NAME"
    if [[ ! -x "$arm_binary" || ! -x "$x86_binary" ]]; then
        echo "Per-architecture Swift build output is incomplete:" >&2
        echo "  arm64:  $arm_binary" >&2
        echo "  x86_64: $x86_binary" >&2
        return 1
    fi

    mkdir -p "$UNIVERSAL_BIN_DIR"
    rm -f "$universal_binary"
    "$LIPO" -create "$arm_binary" "$x86_binary" -output "$universal_binary"

    if ! binary_has_universal_archs "$universal_binary"; then
        echo "Merged main executable is not universal ($(archs_for_binary "$universal_binary"))." >&2
        return 1
    fi

    MAIN_BINARY_SOURCE="$universal_binary"
    RESOURCE_BIN_DIR="$arm_bin_dir"
    MAIN_BUILD_MODE="lipo-universal"
}

build_main_native() {
    local bin_dir

    echo "Building native release binary for $EXECUTABLE_NAME..."
    swift build --package-path "$ROOT_DIR" -c release
    bin_dir="$(show_bin_path)"

    MAIN_BINARY_SOURCE="$bin_dir/$EXECUTABLE_NAME"
    RESOURCE_BIN_DIR="$bin_dir"
    MAIN_BUILD_MODE="native-fallback"
}

build_scintilla_framework() {
    if [[ -n "${MACOS_SCINTILLA_ARCHS:-}" || -n "${MACOS_SCINTILLA_ONLY_ACTIVE_ARCH:-}" || -n "${MACOS_SCINTILLA_DESTINATION:-}" || -n "${MACOS_SCINTILLA_CONFIGURATION:-}" || -n "${MACOS_SCINTILLA_DERIVED_DATA:-}" ]]; then
        "$ROOT_DIR/scripts/build-scintilla-framework.sh" >/dev/null
        return
    fi

    echo "Attempting universal Scintilla.framework build (ARCHS=$SCINTILLA_UNIVERSAL_ARCHS)..."
    if MACOS_SCINTILLA_ARCHS="$SCINTILLA_UNIVERSAL_ARCHS" \
        MACOS_SCINTILLA_ONLY_ACTIVE_ARCH=NO \
        MACOS_SCINTILLA_DESTINATION="generic/platform=macOS" \
        "$ROOT_DIR/scripts/build-scintilla-framework.sh" >/dev/null; then
        return
    fi

    echo "WARNING: Universal Scintilla.framework build failed; retrying with Xcode default arch selection." >&2
    echo "         Override with MACOS_SCINTILLA_ARCHS, MACOS_SCINTILLA_ONLY_ACTIVE_ARCH, or MACOS_SCINTILLA_DESTINATION if you need a specific slice." >&2
    "$ROOT_DIR/scripts/build-scintilla-framework.sh" >/dev/null
}

build_lexilla_dylib() {
    if [[ -n "${MACOS_LEXILLA_ARCHS:-}" ]]; then
        LEXILLA_REQUESTED_ARCHS="${MACOS_LEXILLA_ARCHS}"
        LEXILLA_BUILD_MODE="custom-archs"
        "$ROOT_DIR/scripts/build-lexilla-dylib.sh" >/dev/null
        return
    fi

    if [[ -n "${MACOS_LEXILLA_ONLY_ACTIVE_ARCH:-}" || -n "${MACOS_LEXILLA_EXTRA_BASE_FLAGS:-}" || -n "${MACOS_LEXILLA_EXTRA_LDFLAGS:-}" || -n "${MACOS_LEXILLA_UNIVERSAL_ARCHS:-}" || -n "${LDFLAGS:-}" ]]; then
        if is_truthy "${MACOS_LEXILLA_ONLY_ACTIVE_ARCH:-}"; then
            LEXILLA_REQUESTED_ARCHS="$(uname -m)"
            LEXILLA_BUILD_MODE="active-arch"
        else
            LEXILLA_REQUESTED_ARCHS="${MACOS_LEXILLA_UNIVERSAL_ARCHS:-$LEXILLA_UNIVERSAL_ARCHS}"
            LEXILLA_BUILD_MODE="custom-env"
        fi
        "$ROOT_DIR/scripts/build-lexilla-dylib.sh" >/dev/null
        return
    fi

    echo "Attempting universal Lexilla build (ARCHS=$LEXILLA_UNIVERSAL_ARCHS)..."
    if MACOS_LEXILLA_ARCHS="$LEXILLA_UNIVERSAL_ARCHS" \
        MACOS_LEXILLA_ONLY_ACTIVE_ARCH=NO \
        "$ROOT_DIR/scripts/build-lexilla-dylib.sh" >/dev/null; then
        LEXILLA_REQUESTED_ARCHS="$LEXILLA_UNIVERSAL_ARCHS"
        LEXILLA_BUILD_MODE="universal-request"
        return
    fi

    echo "WARNING: Universal Lexilla build failed; retrying with the active architecture only." >&2
    echo "         Override with MACOS_LEXILLA_ARCHS, MACOS_LEXILLA_ONLY_ACTIVE_ARCH, or MACOS_LEXILLA_UNIVERSAL_ARCHS if you need a specific slice." >&2
    MACOS_LEXILLA_ONLY_ACTIVE_ARCH=YES "$ROOT_DIR/scripts/build-lexilla-dylib.sh" >/dev/null
    LEXILLA_REQUESTED_ARCHS="$(uname -m)"
    LEXILLA_BUILD_MODE="active-arch-fallback"
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

print_architecture_report() {
    local main_binary="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
    local scintilla_binary
    local lexilla_binary="$APP_PATH/Contents/Frameworks/liblexilla.dylib"
    local main_archs
    local scintilla_archs
    local lexilla_archs

    scintilla_binary="$(scintilla_binary_path "$APP_PATH/Contents/Frameworks/Scintilla.framework")"
    main_archs="$(archs_for_binary "$main_binary" 2>/dev/null || echo "missing")"
    scintilla_archs="$(archs_for_binary "$scintilla_binary" 2>/dev/null || echo "missing")"
    lexilla_archs="$(archs_for_binary "$lexilla_binary" 2>/dev/null || echo "missing")"

    echo "Architecture report:"
    echo "  Main executable ($MAIN_BUILD_MODE): $main_archs"
    echo "  Scintilla.framework: $scintilla_archs"
    echo "  liblexilla.dylib ($LEXILLA_BUILD_MODE): $lexilla_archs"
    if [[ -n "$LEXILLA_REQUESTED_ARCHS" ]]; then
        echo "    requested: $LEXILLA_REQUESTED_ARCHS"
    fi

    if ! binary_has_universal_archs "$main_binary"; then
        echo "WARNING: Main executable is not universal. Packaged architecture(s): $main_archs" >&2
        echo "         Universal Swift build was unavailable; this package used $MAIN_BUILD_MODE." >&2
    fi

    if ! binary_has_universal_archs "$scintilla_binary"; then
        echo "WARNING: Scintilla.framework is not universal. Packaged architecture(s): $scintilla_archs" >&2
        echo "         Even with a universal main executable, the Scintilla editor path is limited by this framework." >&2
        echo "         Do not treat this app bundle as fully universal until Scintilla also includes arm64 and x86_64." >&2
    fi

    if [[ " $LEXILLA_REQUESTED_ARCHS " == *" arm64 "* && " $LEXILLA_REQUESTED_ARCHS " == *" x86_64 "* ]] && ! binary_has_universal_archs "$lexilla_binary"; then
        echo "WARNING: liblexilla.dylib is not universal. Packaged architecture(s): $lexilla_archs" >&2
        echo "         Requested Lexilla archs: $LEXILLA_REQUESTED_ARCHS" >&2
        echo "         Scintilla can build universal, but runtime lexer support is still limited by this dylib." >&2
        echo "         Override with MACOS_LEXILLA_ARCHS or MACOS_LEXILLA_ONLY_ACTIVE_ARCH to make the slice choice explicit." >&2
    fi
}

codesign_target() {
    local target="$1"
    local args=(--force --sign "$CODESIGN_IDENTITY")

    if [[ -n "$CODESIGN_KEYCHAIN" ]]; then
        args+=(--keychain "$CODESIGN_KEYCHAIN")
    fi

    codesign "${args[@]}" "$target" >/dev/null
}

rewrite_lexilla_install_name() {
    local lexilla_binary="$1"

    if [[ -z "$INSTALL_NAME_TOOL" ]]; then
        echo "WARNING: install_name_tool is not available; liblexilla.dylib install name was not rewritten." >&2
        return
    fi

    "$INSTALL_NAME_TOOL" -id "@rpath/liblexilla.dylib" "$lexilla_binary"
}

echo "Building $EXECUTABLE_NAME release binary..."
build_scintilla_framework
build_lexilla_dylib
if ! build_main_one_step_universal && ! build_main_lipo_universal; then
    echo "WARNING: Falling back to native Swift release build; main executable will not be universal." >&2
    build_main_native
fi

rm -rf "$APP_PATH" "$DMG_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources/Plugins" "$APP_PATH/Contents/Frameworks" "$DIST_DIR"

cp "$MAIN_BINARY_SOURCE" "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
cp "$UPSTREAM_DIR/PowerEditor/src/langs.model.xml" "$APP_PATH/Contents/Resources/langs.model.xml"
cp "$UPSTREAM_DIR/PowerEditor/src/stylers.model.xml" "$APP_PATH/Contents/Resources/stylers.model.xml"
ditto "$UPSTREAM_DIR/PowerEditor/installer/APIs" "$APP_PATH/Contents/Resources/APIs"
ditto "$UPSTREAM_DIR/PowerEditor/installer/functionList" "$APP_PATH/Contents/Resources/functionList"
ditto "$UPSTREAM_DIR/PowerEditor/installer/themes" "$APP_PATH/Contents/Resources/themes"
for resource_bundle in "$RESOURCE_BIN_DIR"/*.bundle; do
    [[ -e "$resource_bundle" ]] || continue
    bundle_name="$(basename "$resource_bundle")"
    ditto "$resource_bundle" "$APP_PATH/Contents/Resources/$bundle_name"
done
if [[ ! -d "$SCINTILLA_FRAMEWORK" ]]; then
    echo "Expected Scintilla.framework was not built: $SCINTILLA_FRAMEWORK" >&2
    echo "Check MACOS_SCINTILLA_CONFIGURATION and MACOS_SCINTILLA_DERIVED_DATA." >&2
    exit 1
fi
echo "Packaging Scintilla.framework from $SCINTILLA_FRAMEWORK"
ditto "$SCINTILLA_FRAMEWORK" "$APP_PATH/Contents/Frameworks/Scintilla.framework"
cp "$LEXILLA_DYLIB" "$APP_PATH/Contents/Frameworks/liblexilla.dylib"
rewrite_lexilla_install_name "$APP_PATH/Contents/Frameworks/liblexilla.dylib"

# Upstream resources copied from downloaded source trees can carry quarantine
# attributes. Strip them before signing so local Gatekeeper policy evaluates the
# bundle signature rather than inherited source-file metadata.
xattr -cr "$APP_PATH" 2>/dev/null || true

if [[ -f "$ICON_SOURCE" ]]; then
    ICONSET_DIR="$ROOT_DIR/.build/NotepadMac.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
        double_size=$((size * 2))
        sips -z "$double_size" "$double_size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
    done

    iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/$ICON_NAME"
fi

cat > "$APP_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

if [[ "$CODESIGN_IDENTITY" == "-" ]]; then
    echo "WARNING: Using ad hoc code signing. Some macOS policies reject ad hoc GUI apps." >&2
    echo "         Set MACOS_CODESIGN_IDENTITY to a Developer ID/Application signing identity for a distributable build." >&2
fi
codesign_target "$APP_PATH/Contents/Frameworks/Scintilla.framework"
codesign_target "$APP_PATH/Contents/Frameworks/liblexilla.dylib"
codesign_target "$APP_PATH"

echo "Creating dmg..."
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null
codesign_target "$DMG_PATH"

echo "Created:"
echo "  $APP_PATH"
echo "  $DMG_PATH"
print_architecture_report
