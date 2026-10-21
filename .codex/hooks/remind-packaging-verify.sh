#!/bin/bash
# PostToolUse hook: after editing the packaging script, remind to verify.
# scripts/package-macos.sh has a history of shipping violations (missing exec
# bits, DMG naming, hard-coded versions, signing config) — see CLAUDE.md.
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ "$file_path" == *"scripts/package-macos.sh" ]]; then
  echo "提醒: package-macos.sh 已修改，请运行 scripts/verify-package.sh 和 scripts/smoke-packaged-app.sh（或调用 packaging-verifier subagent）确认无打包违规。" >&2
fi

exit 0
