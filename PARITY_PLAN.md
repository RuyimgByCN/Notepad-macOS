# Notepad++ 功能补齐计划 (native-macos)

基于 2026-06 对 `Sources/` 与上游 `PowerEditor` 菜单/功能集的差距分析。
按"价值 / 工作量"排序,P0 最优先。每项含触改文件与验收标准。
统一验收前提:`swift test && swift build` 通过,新逻辑优先放入
`NotepadMacCore` 并配套单元测试。

---

## P0 — 缺失菜单命令(零架构改动,约 1–2 周)✅ 已完成 2026-06-10

实现说明:0.1–0.6 全部落地(0.6 的更新器部分仍按计划留待 P5;
菜单标题保持上游 "Update Notepad++",行为为打开下载页)。
`swift build` 与 `swift test`(412 项)全部通过。

### 0.1 New and Paste
- 实现:`AppDelegate.newDocument` 变体,新建后读剪贴板插入。
- 触改:`AppMenu.swift`、`AppDelegate.swift`。
- 验收:剪贴板有文本时新建标签并粘贴;为空时仅新建。

### 0.2 Proper Case (blend) / Sentence case (blend)
- 实现:在 `TextEditCommands.swift` 的大小写转换中加 blend 语义
  (只改首字母、不强制其余小写)。
- 验收:与上游对同一输入产生相同输出的用例表测试。

### 0.3 Begin/End Select in Column Mode
- 实现:复用现有 Begin Select 锚点,结束时走
  `SCI_SETSELECTIONMODE(SC_SEL_RECTANGLE)` + `SCI_SETRECTANGULARSELECTION*`。
- 触改:`EditorWindowController.swift`、`EditorSurface.swift`。
- 验收:Scintilla 路径生成矩形选区;NSTextView 回退为连续选区。

### 0.4 Cut/Copy/Paste Binary Content
- 实现:自定义 NSPasteboard 类型保存原始字节(含 NUL),粘贴时按
  当前编码注入缓冲区。
- 触改:`EditorWindowController.swift`、`NotepadMacCore` 新增
  `BinaryClipboard.swift`。
- 验收:含 NUL 字节的选区 Copy Binary → Paste Binary 字节级一致。

### 0.5 Function Parameters Next/Previous Hint
- 实现:`CallTipPanelController` 已有 overload 列表,补两个循环切换
  命令与快捷键(默认 Alt+↑/↓ 等价物)。
- 验收:多签名函数可循环显示,单签名时命令禁用。

### 0.6 杂项
- `Validate shortcuts.xml`:复用 `ShortcutsXMLCodec` 做校验并报告错误行。
- `Update Notepad++`:见 P5 更新器;短期保持打开下载页,菜单文案改为
  "Check for Updates…" 避免误导。

---

## P1 — 编码覆盖补全(约 1 周)✅ 已完成 2026-06-10

实现说明:新增 24 种编码(ISO 8859-3/4/5/6/7/8/9/10/13/14、KOI8-U、
TIS-620、Windows-949、OEM 737/775/852/855/857/860/862/863/865/869),
Encoding 菜单改为上游式 "Character sets" 地区分组。顺带修复了 4 处
原有的 CFStringEncoding 映射 bug(isoLatin9 实际是 8859-1、dosCP850
实际是 cp775、dosCP866 是未定义值、windowsCP1255-1258 传入了非法
codepage 号)。例外:OEM 720/858 无 CF 支持、OEM 861 的 macOS CF
解码表损坏(解码走 cp775),三者 defer——如需支持须实现自带字节
映射表并贯通 String.Encoding 之外的自定义编解码管线。每种新编码
均有 round-trip 与字节级回归测试(swift test 416 项全过)。

- 目标:补 ISO 8859-3/4/5/6/7/8/10/13/14、KOI8-U、TIS-620、
  Windows-949、OEM 720/737/775/852/855/857/858/860–869。
- 实现:`TextEncodingOption` 扩展,经 `CFStringEncoding`
  (`kCFStringEncodingISOLatin*`、`kCFStringEncodingDOS*` 等)桥接;
  CF 不支持的少数 OEM 页内置 256 项映射表。
- 触改:`TextFileCodec.swift`、Encoding 菜单构建处。
- 验收:每种新编码的 round-trip 测试(decode→encode 字节一致);
  "Reload as Encoding / Convert to" 菜单分组与上游一致。
- 注:"ANSI" 在 macOS 无系统代码页概念,映射为 Windows-1252 并注明。

---

## P2 — 语法高亮语言覆盖(高价值,约 2–3 周)✅ 已完成 2026-06-10

实现说明:`NotepadPlusLexillaMapping` 重写为与上游
`ScintillaEditView::_langNameInfoArray` 一致的完整 language→lexer 表
(~95 种语言),C 族(java/javascript/typescript/cs/swift/go/
actionscript/rc)按上游惯例共用 cpp lexer,scheme→lisp、nim→nimrod、
fortran77→f77、cobol→COBOL、postscript→ps 等别名逐一核对过本地
Lexilla lexer 目录。折叠属性与关键字槽位走既有通用路径,XML DTD
槽位特例保留。新增上游映射表镜像测试与目录覆盖率(≥90%)测试,
swift test 418 项全过。

现状:`ScintillaLexilla.swift` 仅映射 ~31 种语言,其余 ~60 种回退轻量高亮。
上游大量语言复用同一 Lexilla lexer,多数缺口只是映射缺失:

1. 别名扩容(低成本高收益):
   - `java / javascript / typescript / cs / objc / go / swift / scala /
     verilog…` → `cpp` lexer(同上游 `SCLEX_CPP` 用法),按
     `stylers.model.xml` 风格 ID 着色,关键字集走 `langs.model.xml`。
   - `pascal→pascal`、`haskell→haskell`、`latex→tex`、`matlab→matlab`、
     `vhdl→vhdl`、`lisp→lisp`、`erlang→erlang`、`smalltalk→smalltalk` 等
     直接名补入 `directNames`(liblexilla 默认编译全部 lexer,先用
     `_lm*` 符号脚本核对)。
2. 每语言核对 keyword set 槽位(参考上游 `ScintillaEditView::setXxxLexer`),
   特殊槽位仿照现有 XML 的 `xmlKeywordSetIndex` 模式处理。
3. 折叠属性:对新映射语言开启对应 `fold.*` lexilla properties。
- 验收:每新增语言一个快照测试(样例文件 → 风格 ID 序列),
  目标覆盖上游语言菜单 ≥ 90%。

---

## P3 — 正则引擎对齐(约 2 周,分两步)— 第一步 ✅ 已完成 2026-06-10

实现说明:新增 `BoostRegexTranslation`(NotepadMacCore)。模式翻译:
`\<`/`\>` 词界 → `\b(?=\w)`/`\b(?<=\w)`(字符类内保持字面量);
`\K`、`(?R)`/`(?0)`、`(?&name)`、`(?(...)...)`、`(?>...)`、`\g` 给出明确
不支持错误,Find 面板状态栏显示原因。替换模板翻译:`\1`-`\9`→`$1`-`$9`、
`$&`→`$0`、`${n}`→`$n`、`\n\t\r` 展开、字面 `$` 转义。`replaceNext`
正则路径现在也支持捕获组替换(对齐上游单次替换行为),并修复了
findRegex 漏掉 dotMatchesLineSeparators 的问题。`[[:alpha:]]` 与 `\R`
经测试 ICU 原生兼容,无需翻译。9 个新用例,swift test 427 项全过。
第二步(boost::regex C++ 桥,100% 兼容)仍为可选项。

上游 Boost::regex(PCRE 风格)vs 现有 NSRegularExpression(ICU)。

- 第一步(兼容层):在 `TextSearch.swift` 前置翻译层,处理常见差异
  (`\R`、POSIX 类、`\<` `\>` 词界等 → ICU 等价式),不可译语法给出
  明确错误提示;文档化剩余差异。
- 第二步(可选,完整对齐):新增 SwiftPM C++ target `CBoostRegexBridge`,
  编译上游同款 boost::regex 搜索(参照 `BoostRegexSearch.cxx`),
  Find/Replace 在 Scintilla 路径走该桥,NSTextView 回退 ICU。
- 验收:移植上游正则测试用例集,第一步通过 ≥ 80%,第二步 100%。

---

## P4 — 双视图/分屏(最大单项,约 3–4 周)— 克隆分屏 ✅ 已完成 2026-06-10

实现说明:本项目是"每文档一窗口 + 自绘标签栏"架构(非上游单窗口双
tab 区),因此 P4 落地为窗口内克隆分屏:View > Clone to Other View 在
`NSSplitView` 中创建第二个 Scintilla 表面,经 `SCI_GETDOCPOINTER`/
`SCI_SETDOCPOINTER` 共享同一文档(独立光标/滚动/折叠,编辑实时互通),
再次执行即关闭分屏并 detach 文档引用;View > Focus on Another View
(F8)在两面间切换焦点。克隆面镜像主面的字体/换行/边距/样式配置;
NSTextView 回退路径禁用该菜单(documentPointer 为 nil)。跨文档
"Move to Other View" 由既有 "Move Tab to New Window" + 跨窗口滚动
同步承接,记为架构性差异。swift test 429 项全过;克隆面的手工视觉
验证待打包后进行。

- 目标:Move to Other View、Clone to Other View、Focus on Another View、
  Synchronize Across Views。
- 实现:
  1. `EditorWindowController` 引入 `NSSplitView`,持有两个 tab group +
     两个 `EditorSurface`;第二视图惰性创建,空时折叠。
  2. Clone 复用同一 Scintilla document:`SCI_GETDOCPOINTER` /
     `SCI_SETDOCPOINTER` + 引用计数(`SCI_ADDREFDOCUMENT`),
     两视图实时同文档、各自光标/折叠状态。
  3. 会话持久化扩展 `AppSession.swift`:视图归属、分栏比例、克隆关系。
  4. Synchronize Across Views = 现有滚动同步逻辑限定到同窗口两视图。
- 风险:NSTextView 回退路径不做克隆(降级为只读副本或禁用菜单)。
- 验收:克隆后任一侧编辑另一侧即时可见;关闭一侧不丢文档;
  会话重启恢复双视图布局。

---

## P5 — 生态与周边(约 2 周,可并行)— 主体 ✅ 已完成 2026-06-10

实现说明:
- 插件缓冲区改写协议:新增 `PluginEditScript`(JSON v1,动作
  replaceSelection/insertAtCaret/replaceRange/setText,UTF-16 偏移,
  顺序应用,越界报错)。宿主以 `NOTEPAD_MAC_EDIT_SCRIPT_FILE` 注入
  临时结果文件路径(宿主独占该键,防伪造);命令成功退出后宿主校验
  并应用到活动缓冲区,只读文档拒绝,Plugin Admin 面板回显应用结果。
- Open in New Instance / Move to New Instance:Window 菜单新增,经
  `NSWorkspace` `createsNewApplicationInstance` 启动并传 `-nosession`
  隔离会话;未保存文档先提示保存,Move 成功后关闭本实例标签页。
- 自动更新器 defer:项目尚无发布渠道(无 appcast/GitHub releases),
  Sparkle 集成留待建立分发流程后;Help > Update Notepad++ 维持打开
  下载页行为。swift test 435 项全过。

- 插件:不做 Win32 DLL ABI(维持设计决定);扩展 manifest ABI
  增加"缓冲区改写"协议(JSON over stdio:插件返回编辑指令,宿主
  校验后应用),补 reload/update 边缘情况与从 zip/URL 安装。
- 自动更新:集成 Sparkle(或 GitHub Releases 检查 + DMG 引导),
  替换 P0.6 的临时方案;`Set Updater Proxy` 顺带提供。
- Open in New Instance:用 `NSWorkspace` `-n` 启动新进程实现,
  会话/UserDefaults 加多实例写入保护(文件锁)。

---

## P6 — 收尾(约 1 周)✅ 已完成 2026-06-10

实现说明:实时矩形多光标补全(`applyMultiEditEnabled` 现在同时开启
`SCI_SETADDITIONALSELECTIONTYPING` 与
`SCI_SETMOUSESELECTIONRECTANGULARSWITCH`,Alt 拖拽即实时矩形多光标
打字);P0–P5 全部新增 Localization key 已写入 en/zh-Hans 两份
`Localizable.strings`(中文用 positional 占位符处理语序);README
"Current Native Features" 补入此前遗漏的已实现功能(Find in Files、
Document Map、Run 菜单、Shortcut Mapper 等)和本轮全部新功能,
"Remaining parity areas" 改为指向本计划。历史面板文案的全量迁移仍
是渐进工作,新增代码已全部走 Localization helper。

- 本地化:把面板/视图文案迁入 `Localizable.strings`(README 已列为
  未完成项),en + zh-Hans 全量。
- 实时矩形多光标 UI:在现有面板式块编辑之上,接通 Alt+拖拽 →
  `SCI_SETMULTIPLESELECTION` 实时路径(README 自列项)。
- README 重写"Current Native Features":补入已实现但未列出的
  Find in Files、Document Map、Clipboard History、Run 菜单、
  Shortcut Mapper、Incremental Search、哈希工具等,并链接本计划。

---

## 遗留项收尾(2026-06-11)✅ 已完成

本轮把此前文档化的全部 defer 项逐一落地:

1. **P5 自动更新器**:`UpdateChecker`(NotepadMacCore)走 GitHub
   Releases API(仓库由 Info.plist `NotepadMacUpdateRepository` 或
   UserDefaults `UpdateRepositorySlug` 配置),语义版本比较、draft/
   prerelease 过滤、DMG 资产定位;Help > Update Notepad++ 接通检查
   流程,无渠道/无发布时优雅提示并可打开下载页。新增
   `Set Updater Proxy...`(UpdaterProxyStore,仅用于更新检查的
   HTTP/HTTPS 代理)。
2. **P3 第二步 boost::regex 桥**:新增 SwiftPM C++ target
   `CBoostRegexBridge`,编译上游 vendored Boost.Regex 1.90
   (BOOST_REGEX_STANDALONE,与上游同款编译/搜索/格式化 flags:
   ECMAScript|icase、match_not_dot_newline、format_all)。
   `BoostRegexEngine`(UTF-32 桥 + UTF-16 偏移映射)替换
   TextSearch 的全部正则路径,\K、(?R)/(?&name) 递归、条件组、
   原子组、\g{n}、\u/\l/\U…\E 与 (?1A:B) 条件替换全部可用,
   且对 Scintilla 与 NSTextView 两条后端同时生效。ICU 翻译层保留
   作为文档化对照。
3. **P1 例外编码**:OEM 720/858/861 以内置 256 项字节映射表实现
   (`CustomCodePage`),经合成 String.Encoding 贯通
   TextFileCodec.decode/encode、Reload as Encoding、保存与
   Binary 剪贴板;Character sets 菜单按上游分组补全;
   全字节 round-trip 与参考码点回归测试。
4. **P5 插件收尾**:`installNativePlugin(fromArchive:)` 支持 .zip
   (ditto 解压、容忍单层包裹目录与 __MACOSX、定位最浅 manifest),
   Plugin Admin 新增 "Install from URL..."(URLSession 下载→zip
   安装);安装结果带 previousVersion,更新状态行显示版本迁移;
   命令运行中阻止安装/导入。
5. **P6 本地化批次**:迁移 AppDelegate/AppMenu/ShortcutMapper/
   Workspace/UDL 面板剩余 ~75 处硬编码文案到 Localizable.strings
   (en + zh-Hans),Shortcut Mapper 菜单接线改为不依赖标题查找。
6. **P4 上游式双视图**:View > Move to Other View —— 当前文档经
   SCI_SETDOCPOINTER 停靠进相邻 tab 窗口的第二分屏(共享缓冲、
   独立光标/滚动),原窗口隐藏、tab 点击路由到宿主分屏,再次执行
   移回;宿主/被停靠任一关闭时正确拆解;第二分屏聚焦时 Save 路由
   到被停靠文档的控制器;F8 在两面间切换。
7. **Document Peeker**:标签悬停 0.45s 显示浮动预览(标题 + 前
   24 行、每行 ≤120 字符,等宽 9pt,工具提示材质),离开/点击即隐藏。

`swift build` 与 `swift test`(473 项)全部通过。

## 查找/替换对话框上游化(2026-06-11)✅ 已完成

`FindPanelController` 重写为上游 FindReplaceDlg 式选项卡对话框:
查找/替换/文件中查找/项目中查找/标记 五个选项卡(后两个跳转到既有
专用面板),共享选项区随选项卡复用。新增/对齐:反向查找复选框、
全词/大小写/循环查找左列、选取范围内、查找模式分组框(普通/扩展/
正则表达式 + ". 号匹配换行符"仅正则可用)、透明度分组(失去焦点后/
始终 + 滑杆,实时生效并持久化)、右侧按钮列(查找下一个为默认键、
计数、在当前文件中查找全部、查找所有打开文件 → 结果送 Found
Results 面板、关闭=Esc)、替换页四按钮、标记页(全部标记/清除所有
标记/复制标记文本 + 标记行、每次查找前清除)、底部状态栏与折叠
(˄/˅)按钮、查找/替换历史改为 NSComboBox 下拉。配套核心改动:
`TextSearch.replaceAll` 现在尊重"选取范围内"(searchRange 切片替换
后回拼)、新增 `DocumentMatchLocator`(行/列/行文本定位,驱动
"查找全部"结果列表)、`FindDialogState` 持久化(方向/透明度/标记
选项/折叠态)。离屏渲染快照逐页核对过布局;swift test 483 项全过。

## 智能高亮与查找窗口修复(2026-06-11)✅ 已完成

- 智能高亮(Smart Highlighting)默认开启(对齐上游,持久化到
  `smartHighlightEnabled`),此前默认关闭导致"选中单词后相同文本不
  高亮"。指示器样式由浅黄改为上游式绿色(RGB 0,255,0,roundbox,
  under)。`updateSmartHighlight` 同时支持选区与光标处单词两种取词
  (对齐上游 SmartHighlighter),并加单行/长度/非空白守卫。
- 查找对话框首次打开时"查找目标"组合框塌缩:标签列改固定宽 88、
  字段 leading 由 `>=` 改为 `==` 锚定,宽度确定不再被压缩;补
  `find.button.count` 本地化(此前显示英文 "Count")。新增
  组合框最小宽度回归测试与智能高亮默认值测试。

## 明确不做(Won't do)

- Win32 DLL 插件加载 / Wine 桥接。
- Windows 专属项:注册表/资源管理器集成、tray icon、管理员模式、
  Windows 只读属性位。

## 里程碑顺序建议

P0 → P1 → P2(用户感知最强)→ P3 第一步 → P4 → P5/P6 并行 → P3 第二步(可选)。
