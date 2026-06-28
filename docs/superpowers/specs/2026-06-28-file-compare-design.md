# 文件对比（File Compare / Diff）功能设计

日期：2026-06-28
状态：已批准（方案 A）

## 背景与动机

为本项目（NotepadMac，Notepad++ 的 macOS 原生移植版）添加文件对比功能。
参考 `upstream/notepad--` 的对比 UI 思路。**重要事实**：notepad-- 的对比算法是
闭源商业插件（开源仓库里 `slot_compareFile` 等函数体为空，`StrategyCompare.cpp`、
`AbstractCompare.h` 不存在），因此**算法需本项目独立实现**。

## 需求（已通过澄清问题确认）

| 维度 | 决策 |
|------|------|
| 算法来源 | 纯 Swift 自实现行级 diff，无新依赖 |
| 呈现方式 | 双窗格并列高亮（独立 diff 窗口） |
| 输入来源 | 三种：磁盘文件 / 已打开文档 / 文档 vs 磁盘版 |
| diff 粒度 | 行级 + 字词内高亮（两阶段 LCS） |
| 对比操作 | 差异间导航、差异复制/合并、边栏标记符号、同步滚动+对齐填充 |

## 架构（方案 A：独立 diff 窗口 + 纯算法模块）

三层，模块边界清晰，算法层零 UI 依赖、可单测。

```
入口层: AppMenu (Search > Compare Files...)  →  AppDelegate  →  DiffWindowController
UI  层: DiffWindowController.swift + DiffToolbar.swift
算法层: FileDiff.swift (NotepadMacCore，纯值类型)
```

### 新增文件

| 文件 | 模块 | 职责 |
|------|------|------|
| `Sources/NotepadMacCore/FileDiff.swift` | Core | 纯算法：行级 LCS、字词级 LCS、对齐填充、导航索引、复制合并 |
| `Sources/NotepadMac/DiffWindowController.swift` | App | diff 窗口：NSSplitView + 两个只读 EditorSurface + 工具栏 + 同步滚动 |
| `Sources/NotepadMac/DiffToolbar.swift` | App | 工具栏视图（上一/下一差异、复制左→右、复制右→左、交换、关闭） |
| `Tests/NotepadMacCoreTests/FileDiffTests.swift` | Test | 算法单测 |
| `Tests/NotepadMacTests/DiffWindowControllerTests.swift` | Test | 窗口行为测试 |

### 复用现有基础设施

- `EditorSurfaceFactory.make()` → 构造两个只读 EditorSurface
- `TextFileCodec.read(_:)` → 读磁盘文件为纯文本
- Scintilla markers（2-7 号空闲，bookmark=1，fold=25-31）→ 边栏符号
- Scintilla indicators（容器指示器 0）→ 字词内高亮
- `Localization.string(_:default:)` → 菜单/按钮文案

## 算法层详细设计（FileDiff.swift）

### 核心数据结构

```swift
public struct AlignedLine: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case common        // 两边相同
        case changed       // 该行被修改（仅一侧有真实内容，配对侧为 PAD 或另一行）
        case added         // 仅右侧新增
        case removed       // 仅左侧删除
        case pad           // 对齐填充的虚拟空行（使两侧行号对应）
    }
    public let sourceLine: Int?  // 原始行号（1-based），pad 时为 nil
    public let text: String      // 行文本（不含行尾），pad 时为 ""
    public let kind: Kind
}

public struct InlineSegment: Sendable, Equatable {
    public enum Edit: Sendable, Equatable { case equal, insert, delete }
    public let edit: Edit
    public let text: String       // 该字词段文本
}

public struct DiffHunk: Sendable, Equatable {
    public let leftRange: Range<Int>      // 对齐后左侧行索引区间
    public let rightRange: Range<Int>     // 对齐后右侧行索引区间
    public let leftSegments: [[InlineSegment]]   // 每个修改行的字词段
    public let rightSegments: [[InlineSegment]]
}

public struct DiffResult: Sendable, Equatable {
    public let leftLines: [AlignedLine]   // 含 PAD，与 rightLines 等长
    public let rightLines: [AlignedLine]  // 含 PAD
    public let hunks: [DiffHunk]          // 差异块（导航用）
    public let leftTitle: String
    public let rightTitle: String
}
```

### 算法步骤

1. **行级 LCS（标准 DP）**：对 `[String]` 左右两侧求最长公共子序列，
   得到 LCS 矩阵后回溯产出按行对齐的 edit script（equal / insert / delete）。
   - 时间 O(n·m)，空间 O(n·m)。对万行级文件足够；超大文件由上层提示。
2. **对齐填充**：遍历 edit script，insert 时左侧插 PAD，delete 时右侧插 PAD，
   产出等长的 `leftLines` / `rightLines`。这正是 notepad-- `PAD_LINE` 思路。
3. **差异块分组**：把连续的非 equal 行合并为一个 `DiffHunk`，供导航。
4. **字词级 LCS（二次 DP）**：仅对**配对的修改行**（changed）做字符级 LCS，
   产出 `InlineSegment`（equal/insert/delete），用容器指示器高亮。
   - 粒度按 Unicode 标量切分（兼容中文）。
5. **复制合并**：`DiffResult` 提供不可变快照；合并时由控制器把目标侧
   PAD/差异行替换为源侧行文本，然后重算 diff 刷新高亮。
   - 设计为：返回**新的**左右文本，由控制器重新 setText + 重算。
   - 这样保证合并后对齐仍然正确，避免手工维护索引的脆弱性。

### 公共 API

```swift
public enum FileDiff {
    /// 计算两段文本的差异，返回对齐后的结果。
    public static func compute(left: String, right: String,
                               leftTitle: String, rightTitle: String) -> DiffResult

    /// 把一个差异块从左侧复制到右侧，返回新的右侧文本（控制器重算 diff）。
    public static func applyLeftToRight(_ result: DiffResult, hunkIndex: Int) -> String

    /// 把一个差异块从右侧复制到左侧，返回新的左侧文本。
    public static func applyRightToLeft(_ result: DiffResult, hunkIndex: Int) -> String

    /// 重建某一侧的纯文本（去掉 PAD，保留真实行）。
    public static func reconstructText(_ lines: [AlignedLine]) -> String
}
```

## UI 层详细设计

### DiffWindowController（~500 行）

- 持有：两个只读 `EditorSurface`（left/right）、`DiffResult`、当前差异索引、
  标题、是否只读、合并后的脏标记。
- `NSSplitView` 垂直二分，左右各放一个 surface.view。
- 窗口标题：`"Compare: <leftTitle> ↔ <rightTitle>"`。
- 工具栏：`DiffToolbar`（NSView，贴在窗口顶部）。
- 高亮渲染（复用 Scintilla marker/indicator，通过 surface 的 bridge）：
  - 行背景色：`markerDefine`(2=removed 红、3=added 绿、4=changed 黄) + `markerSetBack`
  - 边栏符号：marker symbol（arrowDown/circle 等）显示在行号边栏
  - 字词内：`indicSetStyle`(roundBox) + `indicSetFore` + `indicatorFillRange`
- 同步滚动：监听一侧 `SCI_*SCROLL` 通知，把另一侧的首可见行设为同一对齐行。
  PAD 行保证两侧行号一一对应，同步滚动可直接按行号联动。
- 操作：导航（按 hunk 索引跳转并居中）、复制（调 FileDiff.apply*，重算刷新）、
  交换（交换左右重算）、关闭。
- 关闭后从 AppDelegate 的 diff 窗口列表移除。

### DiffToolbar（~120 行）

NSView，水平排列按钮：
`[ ◀ Previous ] [ Next ▶ ] [ Copy → ] [ ← Copy ] [ ⇄ Swap ] [ ✕ Close ]`
+ 右侧差异计数 `"3 / 7"`。按钮用 `NSButton(bezelStyle: .accessory)`。
动作通过闭包回调到控制器。

### 入口（AppMenu + AppDelegate）

- Search 菜单新增分隔 + 三项：
  - "Compare Files..." → 选两个磁盘文件
  - "Compare Active Document with..." → 当前文档 vs 选一个磁盘文件
  - "Compare Two Open Documents..." → 从已打开列表选两个
- AppDelegate 新增 `private var diffWindows: [DiffWindowController]` 管理。
- 文档 vs 磁盘版：取当前 EditorWindowController 的 text/URL 作左、磁盘读作右。

### Localization

在 `Localization.swift` 的 `Key` enum 增加 `diff*` case；
在 `en.lproj/Localizable.strings` 和 `zh-Hans.lproj/Localizable.strings` 增加条目。

## 错误处理与边界

- 文件读取失败：弹 `NSApp.presentError`，不创建窗口。
- 两文件完全相同：仍打开窗口，显示 "Files are identical" 状态，无高亮。
- 超大文件（如 > 50k 行）：LCS 的 O(n·m) 矩阵内存大，按行数给二次确认。
  MVP 不做硬限制，仅文档说明。
- 合并后文本与磁盘文件编码：写回磁盘由用户通过普通编辑窗口完成（MVP 不在 diff
  窗口实现"保存到磁盘"，仅支持把结果复制到剪贴板或推回编辑窗口）。

## 测试

### FileDiffTests（纯算法，NotepadMacCoreTests）

- 行级 LCS：相同 / 全增 / 全删 / 交错修改 → 正确的对齐与 hunk 数
- 对齐填充：insert/delete 时对侧正确插 PAD，两侧行数相等
- 字词级：修改行的 InlineSegment 标注 equal/insert/delete
- reconstructText：去掉 PAD 后文本与原始一致（往返）
- applyLeftToRight / applyRightToLeft：合并后该 hunk 消失，文本正确
- 空文件、单行、纯空白行边界

### DiffWindowControllerTests（NotepadMacTests，@MainActor）

- 构造 diff 窗口不崩溃，两侧 surface 文本正确
- 导航：next/previous 在 hunks 间正确移动，计数正确
- selectors 存在（供菜单 dispatch）
- 完全相同的两文件：无 hunk，导航禁用

## 范围（YAGNI 边界）

**本期实现**：两个磁盘文件对比为主路径，文档 vs 磁盘版、两已打开文档作为次路径。
**本期不做**：目录对比、二进制对比、三方合并、保存到磁盘、语法高亮着色（diff 窗口
用纯文本）、忽略空白/大小写选项（留扩展点）。
