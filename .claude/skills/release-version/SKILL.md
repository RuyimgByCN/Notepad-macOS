---
name: release-version
description: 校验发版 tag 是否与上游 Notepad++ resource.h 中的 VERSION_PRODUCT_VALUE 一致。发版前必须运行。
disable-model-invocation: true
---

# release-version

校验本项目即将打的 tag（`vX.Y.Z`）是否与上游 Notepad++ 的
`VERSION_PRODUCT_VALUE`（`PowerEditor/src/resource.h`）一致。

本项目的版本号**不是**自己的语义化版本，而是对齐上游 Notepad++ 的版本号
（见 `CLAUDE.md` 第 1 条规则）。禁止在上游版本号后自行追加小版本号
（如把 `8.9.6` 改成 `8.9.6.5`）。

## 用法

```
/release-version v8.9.6
```

执行 `check-version.sh`：
1. 从 `.github/workflows/release.yml` 中解析 pinned 的 `NPP_COMMIT`。
2. 优先读取本地 `upstream/notepad-plus-plus/PowerEditor/src/resource.h`
   （若该目录存在）；否则通过 GitHub raw 内容在线拉取该 pinned commit 的
   `resource.h`。
3. 解析其中的 `VERSION_PRODUCT_VALUE`，与传入的 tag 去掉 `v` 前缀后的版本号比较。
4. 一致则提示可以发版；不一致则报错并阻止继续。

## 何时使用

- 在执行 `git tag vX.Y.Z && git push --tags` 之前。
- 在 CI（`release.yml`）触发前做一次本地预检，避免发出错误版本号触发的 Release。
