#!/bin/bash
# PreToolUse hook: block Edit/Write/NotebookEdit on upstream/notepad-plus-plus/
# That tree is gitignored and re-cloned fresh by release.yml on every CI run,
# so any manual edit there is silently lost. Real changes belong in
# patches/lexilla/ (for Lexilla) or Sources/ (for everything else).
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ "$file_path" == *"/upstream/notepad-plus-plus/"* ]]; then
  echo "拒绝编辑: $file_path 位于 upstream/notepad-plus-plus/，该目录被 .gitignore 忽略，CI 会按 pinned commit 重新 clone，手动改动会丢失。Lexilla 相关改动请放到 patches/lexilla/，其他改动请放到 Sources/ 下。" >&2
  exit 2
fi

exit 0
