#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_APP_PATH="$ROOT_DIR/dist/Notepad++ Mac.app"
APP_PATH_INPUT="${1:-$DEFAULT_APP_PATH}"
PLIST_BUDDY="/usr/libexec/PlistBuddy"
PROCESS_TIMEOUT="${SMOKE_PROCESS_TIMEOUT:-20}"
VMAP_TIMEOUT="${SMOKE_VMMAP_TIMEOUT:-30}"
ALLOW_DIRECT_FALLBACK="${SMOKE_ALLOW_DIRECT_FALLBACK:-0}"

TMP_DIR=""
RUST_FILE=""
VMAP_OUTPUT=""
VMAP_ERROR=""
EXECUTABLE_NAME=""
SCINTILLA_FRAMEWORK_PATH=""
LEXILLA_DYLIB_PATH=""
LEXILLA_RUNTIME_MODE=""
BASELINE_PIDS=""
LAUNCHED_PIDS=()

fail() {
    echo "ERROR: $*" >&2
    exit 1
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

have_command() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    have_command "$1" || fail "Required macOS command is not available: $1"
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

process_pids() {
    pgrep -x "$EXECUTABLE_NAME" 2>/dev/null || true
}

pid_in_list() {
    local needle="$1"
    local pids="$2"
    local pid

    for pid in $pids; do
        if [[ "$pid" == "$needle" ]]; then
            return 0
        fi
    done

    return 1
}

pid_is_alive() {
    local pid="$1"

    kill -0 "$pid" 2>/dev/null
}

launched_pids_as_text() {
    local IFS=' '
    echo "${LAUNCHED_PIDS[*]:-}"
}

terminate_launched_app() {
    local pid
    local active_pids=()

    for pid in "${LAUNCHED_PIDS[@]:-}"; do
        if pid_is_alive "$pid"; then
            active_pids+=("$pid")
        fi
    done

    if (( ${#active_pids[@]} == 0 )); then
        return 0
    fi

    echo "Terminating $EXECUTABLE_NAME PID(s): ${active_pids[*]}"
    kill -TERM "${active_pids[@]}" 2>/dev/null || true

    for _ in {1..20}; do
        active_pids=()
        for pid in "${LAUNCHED_PIDS[@]:-}"; do
            if pid_is_alive "$pid"; then
                active_pids+=("$pid")
            fi
        done

        if (( ${#active_pids[@]} == 0 )); then
            return 0
        fi

        sleep 0.25
    done

    echo "WARNING: $EXECUTABLE_NAME did not exit after SIGTERM; sending SIGKILL to PID(s): ${active_pids[*]}" >&2
    kill -KILL "${active_pids[@]}" 2>/dev/null || true
}

cleanup() {
    terminate_launched_app

    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

wait_for_new_process() {
    local deadline=$((SECONDS + PROCESS_TIMEOUT))
    local current_pids
    local pid

    while (( SECONDS < deadline )); do
        current_pids="$(process_pids)"

        for pid in $current_pids; do
            if ! pid_in_list "$pid" "$BASELINE_PIDS"; then
                LAUNCHED_PIDS+=("$pid")
            fi
        done

        if (( ${#LAUNCHED_PIDS[@]} > 0 )); then
            echo "Started $EXECUTABLE_NAME PID(s): $(launched_pids_as_text)"
            return 0
        fi

        sleep 0.5
    done

    echo "WARNING: Timed out waiting for a new $EXECUTABLE_NAME process after opening $APP_PATH" >&2
    return 1
}

launch_packaged_app() {
    local executable_path="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
    local stderr_path="$TMP_DIR/app.stderr"
    local open_status=0

    BASELINE_PIDS="$(process_pids)"

    if open -n "$APP_PATH" --args "$RUST_FILE"; then
        if wait_for_new_process; then
            return 0
        fi
    else
        open_status=$?
        echo "WARNING: open exited with status $open_status for $APP_PATH" >&2
    fi

    if [[ "$ALLOW_DIRECT_FALLBACK" != "1" ]]; then
        echo "ERROR: Timed out waiting for LaunchServices to start $EXECUTABLE_NAME." >&2
        echo "       Re-run with SMOKE_ALLOW_DIRECT_FALLBACK=1 only when diagnosing raw executable startup." >&2
        exit 1
    fi

    echo "Falling back to direct packaged executable launch because SMOKE_ALLOW_DIRECT_FALLBACK=1."
    "$executable_path" "$RUST_FILE" >"$TMP_DIR/app.stdout" 2>"$stderr_path" &
    LAUNCHED_PIDS+=("$!")

    sleep 1
    if ! pid_is_alive "${LAUNCHED_PIDS[0]}"; then
        echo "ERROR: Direct packaged executable launch exited before runtime verification." >&2
        if [[ -s "$stderr_path" ]]; then
            echo "stderr:" >&2
            cat "$stderr_path" >&2
        fi
        exit 1
    fi

    echo "Started $EXECUTABLE_NAME PID(s): $(launched_pids_as_text)"
}

wait_for_mapped_runtime_libraries() {
    local pid="$1"
    local deadline=$((SECONDS + VMAP_TIMEOUT))
    local has_scintilla=1
    local has_lexilla=1
    local last_error=""

    while (( SECONDS < deadline )); do
        if ! pid_is_alive "$pid"; then
            fail "$EXECUTABLE_NAME exited before vmmap could verify bundled runtime libraries"
        fi

        if vmmap "$pid" >"$VMAP_OUTPUT" 2>"$VMAP_ERROR"; then
            has_scintilla=1
            has_lexilla=1
            contains_text "$VMAP_OUTPUT" "$SCINTILLA_FRAMEWORK_PATH" && has_scintilla=0
            contains_text "$VMAP_OUTPUT" "$LEXILLA_DYLIB_PATH" && has_lexilla=0

            if (( has_scintilla == 0 )) && [[ "$LEXILLA_RUNTIME_MODE" == "static" ]]; then
                echo "vmmap verified bundled Scintilla.framework is loaded."
                echo "Lexilla is statically linked into $EXECUTABLE_NAME."
                return 0
            fi

            if (( has_scintilla == 0 && has_lexilla == 0 )); then
                echo "vmmap verified bundled Scintilla.framework and liblexilla.dylib are loaded."
                return 0
            fi
        else
            last_error="$(tr '\n' ' ' < "$VMAP_ERROR")"
        fi

        sleep 1
    done

    echo "ERROR: Timed out waiting for vmmap to show bundled runtime libraries." >&2
    echo "  PID: $pid" >&2
    echo "  Expected mappings:" >&2
    echo "    $SCINTILLA_FRAMEWORK_PATH" >&2
    echo "    $LEXILLA_DYLIB_PATH" >&2
    if [[ -n "$last_error" ]]; then
        echo "  Last vmmap error: $last_error" >&2
    fi
    exit 1
}

detect_lexilla_runtime_mode() {
    local executable_path="$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"
    local linked_libraries
    local executable_symbols

    linked_libraries="$(otool -L "$executable_path")"
    if grep -Fq "@rpath/liblexilla.dylib" <<< "$linked_libraries"; then
        LEXILLA_RUNTIME_MODE="dynamic"
        echo "Lexilla runtime mode: dynamic dylib"
        return 0
    fi

    executable_symbols="$(nm "$executable_path" 2>/dev/null || true)"
    if grep -Eq '_(LexillaBridge_CreateLexer|CreateLexer)$' <<< "$executable_symbols"; then
        LEXILLA_RUNTIME_MODE="static"
        echo "Lexilla runtime mode: static executable symbols"
        return 0
    fi

    fail "$EXECUTABLE_NAME neither links @rpath/liblexilla.dylib nor exposes static Lexilla symbols"
}

confirm_no_launched_processes_remain() {
    local pid
    local remaining=()

    for pid in "${LAUNCHED_PIDS[@]:-}"; do
        if pid_is_alive "$pid"; then
            remaining+=("$pid")
        fi
    done

    if (( ${#remaining[@]} > 0 )); then
        fail "$EXECUTABLE_NAME still has launched PID(s) running after termination: ${remaining[*]}"
    fi

    echo "Confirmed no launched $EXECUTABLE_NAME process remains."
}

require_command open
require_command pgrep
require_command vmmap
require_command grep
require_command kill
require_command nm
require_command otool

APP_PATH="$(resolve_path "$APP_PATH_INPUT")"

[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"
[[ -f "$APP_PATH/Contents/Info.plist" ]] || fail "Info.plist not found in app bundle: $APP_PATH"
[[ -x "$PLIST_BUDDY" ]] || fail "PlistBuddy not found at $PLIST_BUDDY"

EXECUTABLE_NAME="$("$PLIST_BUDDY" -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
[[ -n "$EXECUTABLE_NAME" ]] || fail "CFBundleExecutable is missing from $APP_PATH/Contents/Info.plist"
[[ -x "$APP_PATH/Contents/MacOS/$EXECUTABLE_NAME" ]] || fail "App executable is missing or not executable: $APP_PATH/Contents/MacOS/$EXECUTABLE_NAME"

[[ -d "$APP_PATH/Contents/Frameworks/Scintilla.framework" ]] || fail "Packaged Scintilla.framework is missing from $APP_PATH"
[[ -f "$APP_PATH/Contents/Frameworks/liblexilla.dylib" ]] || fail "Packaged liblexilla.dylib is missing from $APP_PATH"
SCINTILLA_FRAMEWORK_PATH="$(cd "$APP_PATH/Contents/Frameworks/Scintilla.framework" && pwd -P)"
LEXILLA_DYLIB_PATH="$(cd "$APP_PATH/Contents/Frameworks" && pwd -P)/liblexilla.dylib"
detect_lexilla_runtime_mode

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/notepad-mac-smoke.XXXXXX")"
RUST_FILE="$TMP_DIR/smoke.rs"
VMAP_OUTPUT="$TMP_DIR/vmmap.txt"
VMAP_ERROR="$TMP_DIR/vmmap.err"

cat > "$RUST_FILE" <<'RUST'
fn main() {
    println!("packaged Notepad++ Mac smoke test");
}
RUST

echo "Smoke testing packaged app:"
echo "  App: $APP_PATH"
echo "  File: $RUST_FILE"

launch_packaged_app
wait_for_mapped_runtime_libraries "${LAUNCHED_PIDS[0]}"
terminate_launched_app
confirm_no_launched_processes_remain

echo "Packaged app smoke test passed."
