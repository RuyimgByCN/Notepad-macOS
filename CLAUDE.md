# NotepadMac — Claude 项目指南

Notepad++ 的原生 macOS 移植版。Swift 6.0 / AppKit,通过 C/C++ 桥接调用
Lexilla(语法高亮)与 Boost regex,并复用上游 Notepad++ 的部分源码。

## 不可违反的规则

### 1. 版本号必须跟随上游

- 发版 tag `vX.Y.Z` **必须等于** `upstream/notepad-plus-plus/PowerEditor/src/resource.h`
  中 `VERSION_PRODUCT_VALUE` 的值。
- **禁止**随意追加小版本号(如把 `8.9.6` 改成 `8.9.6.5/6/7`)。这不是本项目
  自己的语义化版本,而是对齐上游 Notepad++ 的版本号。
- 版本提取逻辑见 `.github/workflows/release.yml` 的 `Extract version from upstream` 步骤。
- 发版前请用 `/release-version` 技能校验 tag 与 resource.h 一致。

### 2. `upstream/` 目录的处理

- `upstream/notepad-plus-plus/` **被 `.gitignore` 忽略**,CI 时按 `release.yml`
  内硬编码的 pinned commit(`NPP_COMMIT`)重新 clone。
- 因此**手动编辑该目录的改动不会进版本控制,等同于丢失**。如需修改上游行为:
  - Lexilla 相关 → 编辑 `patches/lexilla/LexUser.cxx`(构建/CI 时复制进 upstream 树)
  - 其他 → 在 `Sources/` 下的 Swift 代码里实现/覆盖
- 本地保留 `upstream/` 副本仅供开发与构建参考,不要提交其内容。
- `upstream/notepad--/`、`upstream/NotepadNext/` 是另外两个上游参考,仅占位/参考用。

### 3. 构建顺序(不可打乱)

```bash
scripts/build-scintilla-framework.sh   # 1. Scintilla 框架
scripts/build-lexilla-dylib.sh         # 2. Lexilla 动态库(通用二进制 arm64+x86_64)
scripts/package-macos.sh               # 3. 打包 .app + DMG
```

打包脚本 `scripts/package-macos.sh` 体量很大(20K+)且历史上多次出现违规
(可执行位、命名、签名、版本来源),改动后请用 `/` 调用 packaging-verifier
subagent 跑 `verify-package.sh` / `smoke-packaged-app.sh` 验证。

### 4. 发版流程

- 打 `vX.Y.Z` tag 并 push → 触发 `release.yml` → 自动构建 DMG + 生成 SHA-256 + 创建 GitHub Release。
- release notes 由 `git log` 自动生成,**请遵循 Conventional Commits**(如 `fix:`, `feat:`,
  `docs:`),以免发版说明杂乱。

## 项目结构

```
Sources/
  CLexillaBridge/        Lexilla 的 C 桥接
  CBoostRegexBridge/     Boost regex 的 C 桥接
  NotepadMacCore/        核心:偏好、搜索、语法、插件(AppPreferences.swift 等)
  NotepadMac/            可执行入口:窗口、菜单、UI 交互
Tests/                   XCTest 测试(69 个测试文件)
patches/lexilla/         需注入 upstream 树的补丁
scripts/                 构建/打包/验证脚本
upstream/                上游参考源码(gitignore,本地副本)
.github/workflows/release.yml   发版 CI
PARITY_PLAN.md           与上游 Notepad++ 的功能对齐清单
```

## 常用命令

```bash
swift build                  # 构建
swift test                   # 跑测试
swift run                    # 运行 app
```

## 编码约定

- 偏好模块化,避免巨型文件(注意:`AppPreferences.swift` 已偏大,新增功能优先考虑拆分到独立文件)。
- 回复用户请使用简体中文(继承全局规则)。
