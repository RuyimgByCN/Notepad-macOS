#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_APP_PATH="$ROOT_DIR/dist/Notepad++ Mac.app"
DEFAULT_DMG_PATH="$ROOT_DIR/dist/Notepad++ Mac.dmg"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
read -r -a REQUIRED_ARCHS <<< "${MACOS_VERIFY_REQUIRED_ARCHS:-x86_64 arm64}"
LEXILLA_INSTALL_NAME="@rpath/liblexilla.dylib"

TMP_DIR=""

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

usage() {
    cat <<USAGE
Usage: $(basename "$0") [app-path] [dmg-path]

Defaults:
  app-path: $DEFAULT_APP_PATH
  dmg-path: $DEFAULT_DMG_PATH

If a single argument ends in .dmg, it is treated as the DMG path and the
default app path is used.
USAGE
}

cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

have_command() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local command_name="$1"
    local hint=""

    if have_command "$command_name"; then
        return 0
    fi

    case "$command_name" in
        lipo|otool)
            hint=" Install Xcode Command Line Tools with: xcode-select --install"
            ;;
        plutil|file|codesign|hdiutil|xattr|grep|mktemp)
            hint=" This is a required macOS system command."
            ;;
    esac

    fail "Required command is not available: $command_name.$hint"
}

contains_text() {
    local file="$1"
    local text="$2"

    if have_command rg; then
        rg -q --fixed-strings -- "$text" "$file"
    else
        grep -Fq -- "$text" "$file"
    fi
}

print_matching_text() {
    local file="$1"
    local text="$2"

    if have_command rg; then
        rg --fixed-strings -- "$text" "$file"
    else
        grep -F -- "$text" "$file"
    fi
}

resolve_path() {
    local path="$1"
    local dir
    local base

    if [[ "$path" == /* ]]; then
        echo "$path"
        return 0
    fi

    dir="$(dirname "$path")"
    base="$(basename "$path")"
    if [[ -d "$dir" ]]; then
        echo "$(cd "$dir" && pwd -P)/$base"
    else
        echo "$(pwd -P)/$path"
    fi
}

plist_value() {
    local plist="$1"
    local key="$2"

    "$PLIST_BUDDY" -c "Print :$key" "$plist" 2>/dev/null || true
}

require_plist_value() {
    local plist="$1"
    local key="$2"
    local value

    value="$(plist_value "$plist" "$key")"
    [[ -n "$value" ]] || fail "Info.plist is missing required key: $key"
    echo "$value"
}

assert_plist_equals() {
    local plist="$1"
    local key="$2"
    local expected="$3"
    local actual

    actual="$(require_plist_value "$plist" "$key")"
    [[ "$actual" == "$expected" ]] || fail "Info.plist key $key is '$actual', expected '$expected'"
    echo "  $key: $actual"
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

assert_file_output_contains_macho() {
    local label="$1"
    local path="$2"
    local output

    output="$(file "$path")" || fail "file failed for $label: $path"
    echo "  $label file: $output"
    [[ "$output" == *"Mach-O"* ]] || fail "$label is not reported as a Mach-O binary: $path"
}

assert_universal_archs() {
    local label="$1"
    local path="$2"
    local archs
    local required_arch

    [[ -f "$path" ]] || fail "$label is missing: $path"

    assert_file_output_contains_macho "$label" "$path"
    archs="$(lipo -archs "$path" 2>/dev/null)" || fail "lipo failed for $label: $path"

    for required_arch in "${REQUIRED_ARCHS[@]}"; do
        [[ " $archs " == *" $required_arch "* ]] || fail "$label is missing $required_arch slice. Found: $archs"
    done

    echo "  $label architectures: $archs"
}

assert_lexilla_install_name() {
    local lexilla_path="$1"
    local output
    local install_names=""
    local line

    output="$(otool -D "$lexilla_path" 2>/dev/null)" || fail "otool -D failed for Lexilla: $lexilla_path"

    while IFS= read -r line; do
        case "$line" in
            "$lexilla_path"*)
                ;;
            "")
                ;;
            *)
                install_names+="${line}"$'\n'
                ;;
        esac
    done <<< "$output"

    [[ -n "$install_names" ]] || fail "Lexilla install name is missing from otool output"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" == "$LEXILLA_INSTALL_NAME" ]] || fail "Lexilla install name is '$line', expected '$LEXILLA_INSTALL_NAME'"
    done <<< "$install_names"

    echo "  Lexilla install name: $LEXILLA_INSTALL_NAME"
}

verify_codesign() {
    local label="$1"
    local path="$2"
    shift 2

    echo "Checking codesign: $label"
    if ! codesign --verify "$@" "$path"; then
        fail "codesign verification failed for $label: $path"
    fi
    echo "  $label signature is valid"
}

assert_no_quarantine() {
    local label="$1"
    local path="$2"
    local output="$TMP_DIR/xattr-${label//[^A-Za-z0-9_]/_}.txt"

    if ! xattr -r "$path" >"$output" 2>/dev/null; then
        fail "xattr failed while checking quarantine attributes for $label: $path"
    fi

    if contains_text "$output" "com.apple.quarantine"; then
        echo "ERROR: Found com.apple.quarantine on $label: $path" >&2
        print_matching_text "$output" "com.apple.quarantine" >&2 || true
        exit 1
    fi

    echo "  $label has no com.apple.quarantine xattr"
}

APP_PATH_INPUT="$DEFAULT_APP_PATH"
DMG_PATH_INPUT="$DEFAULT_DMG_PATH"

case "$#" in
    0)
        ;;
    1)
        if [[ "$1" == *.dmg ]]; then
            DMG_PATH_INPUT="$1"
        else
            APP_PATH_INPUT="$1"
        fi
        ;;
    2)
        APP_PATH_INPUT="$1"
        DMG_PATH_INPUT="$2"
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

require_command plutil
require_command file
require_command lipo
require_command otool
require_command codesign
require_command hdiutil
require_command xattr
require_command grep
require_command mktemp
[[ -x "$PLIST_BUDDY" ]] || fail "Required macOS command is not available: $PLIST_BUDDY"

TMP_DIR="$(mktemp -d)"
APP_PATH="$(resolve_path "$APP_PATH_INPUT")"
DMG_PATH="$(resolve_path "$DMG_PATH_INPUT")"
PLIST_PATH="$APP_PATH/Contents/Info.plist"

echo "Verifying package artifacts:"
echo "  app: $APP_PATH"
echo "  dmg: $DMG_PATH"

[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ -f "$DMG_PATH" ]] || fail "DMG not found: $DMG_PATH"
[[ -f "$PLIST_PATH" ]] || fail "Info.plist not found: $PLIST_PATH"

echo "Checking Info.plist"
plutil -lint "$PLIST_PATH"
assert_plist_equals "$PLIST_PATH" CFBundleDisplayName "Notepad++ Mac"
assert_plist_equals "$PLIST_PATH" CFBundleName "Notepad++ Mac"
assert_plist_equals "$PLIST_PATH" CFBundleExecutable "NotepadMac"
assert_plist_equals "$PLIST_PATH" CFBundleIdentifier "org.notepad-plus-plus.macnative"
assert_plist_equals "$PLIST_PATH" CFBundlePackageType "APPL"
echo "  CFBundleShortVersionString: $(require_plist_value "$PLIST_PATH" CFBundleShortVersionString)"
echo "  CFBundleVersion: $(require_plist_value "$PLIST_PATH" CFBundleVersion)"
echo "  LSMinimumSystemVersion: $(require_plist_value "$PLIST_PATH" LSMinimumSystemVersion)"

MAIN_BINARY="$APP_PATH/Contents/MacOS/$(require_plist_value "$PLIST_PATH" CFBundleExecutable)"
SCINTILLA_FRAMEWORK="$APP_PATH/Contents/Frameworks/Scintilla.framework"
SCINTILLA_BINARY="$(scintilla_binary_path "$SCINTILLA_FRAMEWORK")"
LEXILLA_BINARY="$APP_PATH/Contents/Frameworks/liblexilla.dylib"

[[ -x "$MAIN_BINARY" ]] || fail "Main executable is missing or not executable: $MAIN_BINARY"
[[ -d "$SCINTILLA_FRAMEWORK" ]] || fail "Scintilla.framework is missing: $SCINTILLA_FRAMEWORK"
[[ -f "$LEXILLA_BINARY" ]] || fail "Lexilla dylib is missing: $LEXILLA_BINARY"

echo "Checking binary architectures"
assert_universal_archs "Main executable" "$MAIN_BINARY"
assert_universal_archs "Scintilla.framework" "$SCINTILLA_BINARY"
assert_universal_archs "Lexilla dylib" "$LEXILLA_BINARY"

echo "Checking Lexilla install name"
assert_lexilla_install_name "$LEXILLA_BINARY"

echo "Checking DMG file type"
file "$DMG_PATH"

verify_codesign "app bundle" "$APP_PATH" --deep --strict --verbose=2
verify_codesign "Scintilla.framework" "$SCINTILLA_FRAMEWORK" --strict --verbose=2
verify_codesign "Lexilla dylib" "$LEXILLA_BINARY" --strict --verbose=2
verify_codesign "DMG" "$DMG_PATH" --strict --verbose=2

echo "Checking DMG checksum"
hdiutil verify "$DMG_PATH"

echo "Checking quarantine attributes"
assert_no_quarantine "app bundle" "$APP_PATH"
assert_no_quarantine "DMG" "$DMG_PATH"

echo "Package verification passed."
