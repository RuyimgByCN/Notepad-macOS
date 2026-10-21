#!/bin/bash
# Verify that a release tag matches upstream Notepad++'s VERSION_PRODUCT_VALUE,
# mirroring the "Extract version from upstream" step in .github/workflows/release.yml.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

TAG="${1:-}"
WORKFLOW=".github/workflows/release.yml"
LOCAL_RESOURCE_H="upstream/notepad-plus-plus/PowerEditor/src/resource.h"

if [[ -z "$TAG" ]]; then
  echo "用法: check-version.sh vX.Y.Z" >&2
  exit 1
fi

NPP_COMMIT=$(grep -o 'NPP_COMMIT="[a-f0-9]*"' "$WORKFLOW" | head -1 | sed 's/NPP_COMMIT="\(.*\)"/\1/')
if [[ -z "$NPP_COMMIT" ]]; then
  echo "无法从 $WORKFLOW 中解析 NPP_COMMIT" >&2
  exit 1
fi

if [[ -f "$LOCAL_RESOURCE_H" ]]; then
  echo "使用本地 upstream 副本: $LOCAL_RESOURCE_H"
  RESOURCE_CONTENT=$(cat "$LOCAL_RESOURCE_H")
else
  echo "本地无 upstream 副本，从 GitHub 拉取 pinned commit ($NPP_COMMIT) 的 resource.h ..."
  RESOURCE_CONTENT=$(curl -fsSL \
    "https://raw.githubusercontent.com/notepad-plus-plus/notepad-plus-plus/${NPP_COMMIT}/PowerEditor/src/resource.h")
fi

NPP_VER=$(echo "$RESOURCE_CONTENT" | grep 'VERSION_PRODUCT_VALUE' | sed 's/.*L"\(.*\)\\0".*/\1/')
if [[ -z "$NPP_VER" ]]; then
  echo "无法从 resource.h 中解析 VERSION_PRODUCT_VALUE" >&2
  exit 1
fi

TAG_VER="${TAG#v}"

echo "pinned commit:        $NPP_COMMIT"
echo "上游 VERSION_PRODUCT_VALUE: $NPP_VER"
echo "目标 tag:              $TAG ($TAG_VER)"

if [[ "$NPP_VER" == "$TAG_VER" ]]; then
  echo "✅ 版本号一致，可以发版。"
  exit 0
else
  echo "❌ 版本号不一致！tag 中的版本号必须等于上游 resource.h 的 VERSION_PRODUCT_VALUE，禁止自行追加小版本号。"
  exit 1
fi
