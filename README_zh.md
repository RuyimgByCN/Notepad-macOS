[English](README.md) | [中文](README_zh.md)

# Notepad++ Mac Native

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://www.swift.org/)
[![Upstream Notepad++](https://img.shields.io/badge/upstream-Notepad%2B%2B-90E59A.svg)](https://notepad-plus-plus.org/)

**Notepad++ Mac Native** 是一款面向 **macOS** 的免费开源代码编辑器和记事本替代
方案，使用 Swift / AppKit 原生构建。它**不是** Wine 封装 —— Notepad++ 的 Win32
GUI 层已用原生 macOS 代码重写，而上游平台无关的资源（语言模型、主题、API 表、
图标）以及上游 Scintilla / Lexilla 编辑器则直接复用。

这是 Notepad++ 的独立 macOS 实现。它**不是** Notepad++ 官方项目，与 Don HO
及 Notepad++ 团队无关，也未获得其认可。官方 Windows 项目位于
<https://github.com/notepad-plus-plus/notepad-plus-plus>。

## 产品截图

| 编辑器 | 查找与替换 |
|---|---|
| ![Notepad++ Mac Native 编辑 Rust 文件](docs/images/screenshots/editor-rust.png) | ![查找与替换面板](docs/images/screenshots/find-replace.png) |

| 偏好设置 | 样式配置器 |
|---|---|
| ![偏好设置面板](docs/images/screenshots/preferences.png) | ![样式配置器面板](docs/images/screenshots/style-configurator.png) |

| 函数列表 |
|---|
| ![函数列表面板](docs/images/screenshots/function-list.png) |

## 与上游 Notepad++ 的关系

原始 Notepad++ 源码保留在 `upstream/notepad-plus-plus/` 目录下（供本地开发和构建
参考；该目录已加入 `.gitignore`，CI 构建时会按固定 commit 重新 clone）。平台无关
的 Notepad++ 数据将直接使用。macOS 专属的 UI 和应用生命周期代码使用 AppKit 重写，
因为原始的 `PowerEditor` 应用是 Win32 GUI 程序。Scintilla 有 Cocoa 代码，但
Notepad++ 的主窗口、对话框、菜单命令、注册表集成和插件宿主均为 Windows 专属。

与上游 Notepad++ 的功能对齐进展记录在 [PARITY_PLAN.md](PARITY_PLAN.md) 中。

## 许可证

本项目基于 **GNU General Public License v3.0**（[LICENSE](LICENSE)）分发，继承自
Notepad++，为其衍生作品。

与 Notepad++ 一样，这是自由软件：你可以按照 GPL-3.0 的条款重新分发和/或修改，
且**不提供任何担保**。详见 [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.html)。

项目版权声明及衍生作品归属说明（Notepad++、Scintilla、Lexilla、Boost.Regex）位于
[NOTICE](NOTICE) 文件中。

### 第三方组件

打包后的应用捆绑了多个第三方组件，每个组件均遵循其各自的许可证。其版权及许可证
声明复制在 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) 文件中，汇总如下：

| 组件 | 来源 | 许可证 |
|---|---|---|
| **Notepad++**（语言模型、主题、API/functionList XML、图标、boostregex 桥接） | [`upstream/notepad-plus-plus`](https://github.com/notepad-plus-plus/notepad-plus-plus) — © Don HO | [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html) |
| **Scintilla**（Cocoa 编辑框架） | [`scintilla`](https://www.scintilla.org/) — © Neil Hodgson | Historical Permission Notice and Disclaimer (HPND-like) |
| **Lexilla**（词法分析库） | [`lexilla`](https://www.scintilla.org/Lexilla.html) — © Neil Hodgson | Historical Permission Notice and Disclaimer (HPND-like) |
| **Boost.Regex**（正则引擎，通过 boostregex 桥接） | [boost.org](https://www.boost.org/) | [Boost Software License 1.0](https://www.boost.org/LICENSE_1_0.txt) |

所有打包资源（Notepad++ `langs.model.xml`、`stylers.model.xml`、API XML、
function-list XML、主题 XML、chameleon 图标）均为上游项目的 GPL-3.0 素材，
按相同条款重新分发。

### 商标

"Notepad++" 以及 Notepad++ 的名称和徽标均为其各自所有者的商标，此处仅用于标识
本编辑器所衍生的上游项目。本项目为独立衍生作品，不代表 Notepad++ 商标持有者
的认可。

## 构建与测试

```bash
swift test
swift build
```

## 打包

```bash
scripts/package-macos.sh
```

打包脚本将生成：

- `dist/Notepad++ Mac.app`
- `dist/Notepad++ Mac.dmg`

打包后运行 `scripts/smoke-packaged-app.sh`，将使用临时 Rust 文件启动应用，
验证打包后的应用加载的是捆绑的 Scintilla 和 Lexilla 运行时，而非开发树或系统
副本。

冒烟测试前如需静态包验证，运行 `scripts/verify-package.sh` 检查应用包、捆绑
运行时、签名、DMG 校验和以及隔离属性。验证和冒烟脚本可提供打包应用正在使用
捆绑的 Scintilla 框架和 Lexilla 动态库的证据。

脚本尝试将主 `NotepadMac` 可执行文件打包为通用 `arm64` + `x86_64` 版本。首先
在已安装工具链支持的情况下使用 SwiftPM 的一步架构支持；否则分别构建 arm64 和
x86_64 的 release 二进制文件，再通过 `lipo` 合并。如果无法实现，脚本将回退至
原生 Swift release 构建并打印检测到的架构。脚本默认尝试将捆绑的 Scintilla Cocoa
框架构建为 `arm64` + `x86_64`，若该框架构建不可用则回退至 Xcode 的默认架构选择。
脚本同时打印打包后的 Scintilla 和 Lexilla 架构，因为当捆绑的框架或动态库仍为
单架构时，即使主可执行文件是通用的，整个应用包也并非真正通用。设置
`MACOS_SCINTILLA_ARCHS`、`MACOS_SCINTILLA_ONLY_ACTIVE_ARCH`、
`MACOS_SCINTILLA_DESTINATION`、`MACOS_SCINTILLA_CONFIGURATION` 或
`MACOS_SCINTILLA_DERIVED_DATA` 可覆盖 Scintilla Xcode 构建输入及打包框架路径。

Lexilla 打包采用显式验证方式，不依赖上游 makefile 的默认 macOS 标志。默认情况下，
`scripts/package-macos.sh` 请求构建包含 `arm64 x86_64` 的通用 `liblexilla.dylib`，
验证构建的 dylib 包含两个请求的架构切片，仅在通用构建请求失败时回退至当前架构。
要直接控制该构建，使用 `MACOS_LEXILLA_ARCHS`、`MACOS_LEXILLA_ONLY_ACTIVE_ARCH`
或 `MACOS_LEXILLA_UNIVERSAL_ARCHS`；底层 `scripts/build-lexilla-dylib.sh` 脚本还
接受 `MACOS_LEXILLA_EXTRA_BASE_FLAGS` 和 `MACOS_LEXILLA_EXTRA_LDFLAGS` 用于工具链
特定覆盖，以及当本地内存压力需要降低 make 并行度时的 `MACOS_LEXILLA_JOBS`。Lexilla
安装名称默认为 `@rpath/liblexilla.dylib`，可通过 `MACOS_LEXILLA_INSTALL_NAME` 覆盖；
打包时会将复制的 dylib 重写为该包安全的安装名称后再签名。最终的打包报告会打印
Lexilla 构建模式、请求的架构以及实际打包的架构切片。

默认情况下，应用包和 DMG 使用 ad hoc 签名，供本地开发使用。部分受管理或更严格的
macOS 安装在启动时会拒绝 ad hoc 签名的 GUI 应用。如需构建能通过 Gatekeeper 的
版本（无需本地覆盖），请提供真实的签名标识：

```bash
MACOS_CODESIGN_IDENTITY="Developer ID Application: Example Team" \
scripts/package-macos.sh
```

如果签名标识不在默认钥匙串搜索列表中，还需设置
`MACOS_CODESIGN_KEYCHAIN=/path/to/keychain`。分发仍需在打包后进行常规的 Apple
公证流程。

## 可复用的上游组件

已接入原生应用：

- `../notepad-plus-plus/PowerEditor/src/langs.model.xml`
  - 打包至 `Contents/Resources/langs.model.xml`
  - 运行时解析，用于语言检测、注释标记和关键字数据
- `../notepad-plus-plus/PowerEditor/src/stylers.model.xml`
  - 打包至 `Contents/Resources/stylers.model.xml`
  - 运行时解析，用于词法分析器样式 ID、颜色、字体和关键字类别
- `../notepad-plus-plus/PowerEditor/installer/APIs`
  - 打包至 `Contents/Resources/APIs`
  - 运行时解析，用于各语言的自动补全关键字、函数标记、重载描述和参数列表
- `../notepad-plus-plus/PowerEditor/installer/functionList`
  - 打包至 `Contents/Resources/functionList`
  - 运行时解析，用于函数列表解析器元数据；原生 macOS 符号提取对支持的语言使用
    兼容的正则规则
- `../notepad-plus-plus/PowerEditor/installer/themes`
  - 打包至 `Contents/Resources/themes`
  - 运行时扫描 Notepad++ 主题 XML 文件，并通过与 `stylers.model.xml` 相同的样式
    解析器加载
- `../notepad-plus-plus/PowerEditor/misc/chameleon/chameleon-pencil-1000.png`
  - 转换为 macOS 应用图标

已完成构建并打包：

- `../notepad-plus-plus/scintilla/cocoa/Scintilla/Scintilla.xcodeproj`
  - 使用 `scripts/build-scintilla-framework.sh` 构建
  - 输出：`.build/scintilla-derived/Build/Products/Release/Scintilla.framework`
  - 打包至 `Contents/Frameworks/Scintilla.framework`
  - 运行时由原生编辑器界面加载；加载失败时应用回退至 `NSTextView`
- `../notepad-plus-plus/lexilla`
  - 使用 `scripts/build-lexilla-dylib.sh` 构建
  - 输出：`../notepad-plus-plus/lexilla/bin/liblexilla.dylib`
  - 打包至 `Contents/Frameworks/liblexilla.dylib`
  - 构建请求具有架构感知能力，并针对生成的 dylib 进行验证
  - 打包安装名称重写为 `@rpath/liblexilla.dylib`
  - 运行时加载，为 Scintilla 创建 Lexilla `ILexer5` 实例

## 当前原生功能

- 原生 AppKit 窗口和菜单栏
- 新建、打开、保存和另存为
- 原生偏好设置面板，基于 macOS `UserDefaults`
- 原生查找和替换面板，支持区分大小写、全词匹配、方向、循环搜索选项；Search 菜单
  包含 Find Previous（Cmd+Shift+G）
- 原生会话恢复，适用于文件支持的文档
- 原生脏缓冲区快照恢复，使用应用管理的备份文件
- 原生工作区面板，支持 Notepad++ 项目 XML 和文件夹树
- 原生 AppKit 文档标签页，支持重复文件激活
- 原生编辑器工具栏，包含保存、打印、查找、替换、书签、换行、函数列表和可选的
  折叠命令
- 原生样式配置器面板，基于 Notepad++ `stylers.model.xml`
- 原生文件监控，适用于已保存文档，提供重新加载/保留当前内容的提示
- 原生打印操作，适用于当前文档，包含页眉和行号
- 原生宏录制与回放，适用于文本编辑命令，包含已保存的命名宏
- 原生插件管理面板，支持基于 manifest 的 macOS 插件发现和 Windows Notepad++ DLL
  插件的兼容性诊断，具备原生命令执行、原生 manifest 插件的持久化启用/禁用控制、
  从现有插件文件夹安装/更新、受限的用户安装原生 manifest 插件删除、显式重新扫描、
  用户插件文件夹打开，以及面板中流式显示的 stdout/stderr
- 原生自动补全面板，基于 Notepad++ `installer/APIs/*.xml`
- 原生函数调用提示面板，基于 Notepad++ API 重载元数据
- 原生函数列表面板，基于 Notepad++ `installer/functionList/*.xml` 元数据和原生
  符号提取
- 原生文档统计命令，显示当前缓冲区的行数、字数、UTF-16 字符数和 Unicode 标量计数
- 原生主题菜单，基于 Notepad++ `installer/themes/*.xml`，支持持久化主题选择和
  已打开编辑器窗口的实时样式切换
- 原生书签命令，支持切换当前行、带循环的上一/下一书签导航、清除书签，以及在状态栏
  中显示书签数量；书签可在重新打开的会话文件和未保存文档的快照备份中恢复
- 原生行编辑命令，支持删除当前行或选中行范围、合并行、删除空行/空白行、删除重复或
  连续重复行、升序/降序排列选中行、将选中文本转换为大写/小写/反转大小写，以及将
  当前行或选中行块上下移动
- 原生列编辑器面板，支持在选中行范围内按固定 1-based 列插入文本，具备短行填充和
  保留行尾的功能
- 原生列编辑器数字模式，支持十进制、十六进制、八进制和二进制序列，可指定增量、
  重复次数和前导零/空格填充
- 编辑器界面在捆绑框架可用时基于上游 Scintilla Cocoa
- 通过 Scintilla `SCI_SETILEXER` 加载 Lexilla 词法分析器，映射上游语言名称
- 原生 Scintilla 行号、书签标记和折叠边距，在捆绑 Scintilla 框架激活时可用
- 打包后的 Scintilla 编辑器界面可处理书签和折叠边距点击
- 原生 Scintilla 折叠命令，通过 View > Folding 切换当前折叠、全部折叠和全部展开
- UTF-8 和 UTF-16 文本加载、BOM 检测，以及原生 Encoding 菜单转换命令
- LF、CRLF 和 CR 行尾检测/保留
- 等宽字体编辑器，支持撤销、剪切/复制/粘贴、全选
- 状态栏显示行号、列号、字符数、语言、行尾、编码
- 语言检测、注释标记和关键字数据从 Notepad++ 上游
  `PowerEditor/src/langs.model.xml` 加载
- 用户自定义语言核心模型，支持 JSON 持久化、XML 导入/导出、扩展名规范化、无扩展名
  手动语言、语言目录合并/覆盖，以及结构化的 WordsStyle 字段更新辅助
- 原生用户自定义语言面板，支持列出已保存的 UDL、导入 XML、导出 XML、编辑定义
  （包括结构化多样式 WordsStyle 矩阵）和删除已保存定义；导入/导出文件 I/O 在
  主 actor 之外运行
- 可复用的矩形选择/块编辑核心变换，具备短行填充和 LF/CRLF/CR 保留功能
- 原生本地化矩形选择面板，支持在选中行范围和字符列中插入或替换多行文本块，替换模式
  默认为选中文本预览
- 编辑器界面上有界的 Scintilla 多选适配器方法，用于应用不连续的 UTF-16 范围或恢复
  实时的矩形锚点/光标元数据，`NSTextView` 保留空操作回退
- 可复用的搜索核心和原生查找面板，支持向上搜索方向和无循环扫描，Search 菜单包含
  Find Previous（Cmd+Shift+G），面板中提供方向/循环控制
- 本地化应用菜单和编辑器工具栏，基于 SwiftPM 打包的英文和简体中文字符串资源；更广泛
  的面板/视图本地化部分完成
- 轻量级原生语法高亮，由上游语言模型驱动，作为无 Lexilla 词法分析器映射时的回退；
  Lexilla 映射反映上游 `ScintillaEditView::_langNameInfoArray`（约 95 种语言，
  C 家族语言共享 cpp 词法分析器）
- 原生 Find in Files / Find in Projects，包含查找结果面板、上一/下一结果导航和
  Find in Search Results
- 原生增量搜索栏和 Search > Mark，支持五种上游标记样式、样式标记命令和每种样式
  的上下跳转
- 原生 Document Map、Document List、Clipboard History、Character Panel 和 Task
  List 面板
- 原生 Run 菜单，包含已保存的命令，以及 MD5/SHA-1/SHA-256/SHA-512 生成命令
- 原生 Shortcut Mapper，支持冲突检测、shortcuts.xml 导入/导出和
  Settings > Validate shortcuts.xml 诊断
- 原生 Go To Line、Go to Matching Brace、花括号/XML 标签高亮、智能高亮、变更历史
  导航和 Hide Lines
- View > Launch in Browser 子菜单（与上游 Firefox/Chrome/Edge 对齐），提供系统默认
  浏览器以及按 bundle identifier 发现的各已安装浏览器（Safari、Chrome、Firefox、
  Edge、Brave、Arc、Opera、Chromium、Vivaldi）；未保存文档通过临时 HTML 文件预览
- 完整的 Encoding 菜单，采用与上游一致的"Character sets"区域分组，涵盖 UTF-8/UTF-16
  以及约 45 种旧式代码页（ISO 8859-x、Windows-125x、KOI8-R/U、CJK、TIS-620、
  OEM/DOS 页面），覆盖转换/以此编码/以此编码重新打开等流程
- 面向 macOS（ICU）引擎的 Notepad++/Boost 风格正则翻译：`\<`/`\>` 单词边界、`\1`
  风格替换反向引用、`$&`、`${n}`，以及在查找面板中清晰的"不支持构造"错误提示
- View > Clone to Other View 将窗口分割为第二个 Scintilla 界面，共享同一文档
  （独立的光标/滚动/折叠），View > Focus on Another View（F8）切换窗格
- Window > Open in New Instance / Move to New Instance 为当前文件启动一个独立的
  `-nosession` 应用实例
- Edit > Paste Special 二进制剪贴板命令（Cut/Copy/Paste Binary Content），在文档
  编码中实现 NUL 安全的字节往返
- 插件缓冲区变更协议：原生 manifest 插件可通过 `NOTEPAD_MAC_EDIT_SCRIPT_FILE` 返回
  经过验证的 JSON 编辑脚本，由宿主应用到活动缓冲区

## 移植边界

这是原生 macOS 应用，不是完整的 Notepad++ Win32 移植。复制的上游源码是功能对齐
的参考基线。要实现完全对齐，需要逐个模块地将 Win32 窗口/对话框/插件 API 替换为
AppKit 等价实现。

Notepad++ 插件是 Win32 DLL，不会被本原生 macOS 宿主加载。应用改为公开原生的
基于 manifest 的插件发现层，Plugin Admin 面板将复制的 `.dll` 插件报告为
Windows-only，不会通过 Wine 桥接。

## 原生插件命令 ABI

原生 manifest 命令直接从其声明的可执行入口点启动。运行时验证入口点是可执行的且
位于插件目录内，然后通过 `Process` 以 argv 数组形式传递参数：
`--notepad-command <command-id>`，后跟调用者提供的参数。Manifest 和用户参数文本
不会经过 shell 插值处理。

宿主拥有以下命令环境键，并在启动前覆盖调用者提供的伪造值：

- `NOTEPAD_MAC_PLUGIN_IDENTIFIER`
- `NOTEPAD_MAC_COMMAND_IDENTIFIER`
- `NOTEPAD_MAC_PLUGIN_DIRECTORY`

当命令调用提供文件支持的文档 URL 时，宿主还会公开：

- `NOTEPAD_MAC_DOCUMENT_PATH`
- `NOTEPAD_MAC_DOCUMENT_DIRECTORY`
- `NOTEPAD_MAC_DOCUMENT_NAME`

如果未提供文档 URL，这些文档键将被从进程环境中移除，以便原生插件区分"无文件支持
的文档"和真实路径。非文件文档 URL 在命令启动前会被拒绝。当存在文件支持的文档时，
Plugin Admin 提供活动编辑器的文件支持文档 URL；无标题文档和脏快照文档在没有文档
路径键的情况下运行。

当命令调用提供活动编辑器选择上下文时，宿主还会公开 UTF-16 选择元数据：

- `NOTEPAD_MAC_SELECTION_UTF16_LOCATION`
- `NOTEPAD_MAC_SELECTION_UTF16_LENGTH`
- `NOTEPAD_MAC_SELECTION_TEXT`

位置和长度是当前缓冲区中的十进制 UTF-16 偏移量，文本值为选中的文本。如果未提供选择
上下文，这些选择键将被从进程环境中移除，以便插件区分"无编辑器选择元数据"和在已知
光标位置的空选择。Plugin Admin 在运行原生 manifest 命令时提供活动编辑器的当前选择
上下文。包含 NUL 的选择文本在启动前会被拒绝，因为进程环境字符串使用 NUL 结尾的
传输方式，无法安全保留嵌入的 NUL 字节。

## 复用策略

- 复用平台无关的 Notepad++ 资源，如语言模型、图标和语法元数据。
- 复用能在 macOS 上干净构建的原生/跨平台上游库。Scintilla Cocoa 用作打包编辑器界面，
  因为它已从复制的上游源码生成原生框架。
- 用原生 macOS 代码重写 Win32-only 的 UI/应用行为。
- 保持复用边界清晰。

## 当前 Scintilla 限制

应用在打包时使用上游 Scintilla Cocoa 框架。Swift 适配层较为精简：

- 打包尝试构建通用 Scintilla 框架并报告捆绑框架的架构。如果 Scintilla 保持单架构，
  即使主可执行文件是通用的，Scintilla 支持的编辑器路径也仅限于该架构切片；除非
  Scintilla 和 Lexilla 都同时包含 x86_64 和 arm64，否则该包不是完整的通用应用包
- 文本获取/设置、编辑通知、选择范围、字体选择、换行模式和关键字集转发通过类型化
  Objective-C 调用接入
- Scintilla 矩形选择和多选消息可通过编辑器界面进行有界选择应用，包括在
  `SCI_SETSELECTION`、`SCI_ADDSELECTION` 和 `SCI_SETRECTANGULARSELECTION*` 之前
  将 UTF-16 转换为 Scintilla 位置
- Lexilla 词法分析器创建通过共享库的 C ABI 接入，并通过 `SCI_SETILEXER` 传递给
  Scintilla
- 词法分析器特定样式颜色从 `stylers.model.xml` 加载；原生配置器覆盖每个样式 ID 的
  前景/背景/字体/粗体/斜体
- 开发中运行时没有捆绑框架时回退到 `NSTextView`

## 贡献

欢迎贡献。关于构建说明和本项目遵循的规则（版本号必须与上游 Notepad++ 一致、
`upstream/` 树已加入 `.gitignore` 并由 CI 重新 clone、构建顺序限制），请在提交
Pull Request 前阅读 [CLAUDE.md](CLAUDE.md) 和 [PARITY_PLAN.md](PARITY_PLAN.md)。

请遵循 [Conventional Commits](https://www.conventionalcommits.org/) 格式
（`feat:`、`fix:`、`docs:` …），以便从提交日志生成清晰的发布说明。

## 免责声明

这是衍生自 Notepad++ 的独立社区 macOS 移植版本，与 Notepad++ 官方项目或其维护者
无关，未获得其赞助或认可。"Notepad++" 是其各自所有者的商标。所有商标和注册商标
均为其各自所有者的财产。
