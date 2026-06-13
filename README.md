# Notepad++ Mac Native

This directory contains a native macOS implementation layer for the copied
Notepad++ source tree. It does not use Wine.

The upstream Windows source is preserved under `../notepad-plus-plus`. Reusable
Notepad++ data is consumed directly where it is platform-neutral. macOS-specific
UI and application lifecycle code is rewritten with AppKit because the original
`PowerEditor` application is a Win32 GUI program. Scintilla has Cocoa code, but
Notepad++'s main windowing, dialogs, menu commands, registry integration, and
plugin host are Windows-specific.

## Build and Test

```bash
swift test
swift build
```

## Package

```bash
scripts/package-macos.sh
```

The packaging script creates:

- `dist/Notepad++ Mac.app`
- `dist/Notepad++ Mac.dmg`

After packaging, run `scripts/smoke-packaged-app.sh` to launch the app with a
temporary Rust file and verify that the packaged app loads the bundled
Scintilla and Lexilla runtimes, rather than a development-tree or system copy.

For static package validation before smoke testing, run
`scripts/verify-package.sh` to check the app bundle, bundled runtimes, signing,
DMG checksum, and quarantine attributes. The verify and smoke scripts now give
stricter evidence that the packaged app is using the bundled Scintilla framework
and Lexilla dylib.

The script attempts to package the main `NotepadMac` executable as universal
`arm64` + `x86_64`. It first uses SwiftPM's one-step architecture support when
the installed toolchain exposes it; otherwise it builds separate arm64 and
x86_64 release binaries and merges them with `lipo`. If that is not possible,
the script falls back to the native Swift release build and prints the detected
architecture. It attempts to build the bundled Scintilla Cocoa framework as
`arm64` + `x86_64` by default, then falls back to Xcode's default architecture
selection if that framework build is not available. It also prints the packaged
Scintilla and Lexilla architectures, because a universal main executable does
not make the full app bundle universal when a bundled framework or dylib is
still single-architecture. Set `MACOS_SCINTILLA_ARCHS`,
`MACOS_SCINTILLA_ONLY_ACTIVE_ARCH`, `MACOS_SCINTILLA_DESTINATION`,
`MACOS_SCINTILLA_CONFIGURATION`, or `MACOS_SCINTILLA_DERIVED_DATA` to override
the Scintilla Xcode build inputs and packaged framework path.

Lexilla packaging is now explicit and verified instead of relying on the
upstream makefile's default macOS flags. By default `scripts/package-macos.sh`
requests a universal `liblexilla.dylib` build with `arm64 x86_64`, verifies
that the built dylib contains both requested slices, and falls back to the
active architecture only when the universal request fails. To control that
build directly, use `MACOS_LEXILLA_ARCHS`, `MACOS_LEXILLA_ONLY_ACTIVE_ARCH`,
or `MACOS_LEXILLA_UNIVERSAL_ARCHS`; the lower-level
`scripts/build-lexilla-dylib.sh` script also accepts
`MACOS_LEXILLA_EXTRA_BASE_FLAGS` and `MACOS_LEXILLA_EXTRA_LDFLAGS` for
toolchain-specific overrides, plus `MACOS_LEXILLA_JOBS` when local memory
pressure requires a lower make parallelism. The Lexilla install name defaults
to `@rpath/liblexilla.dylib` and can be overridden with
`MACOS_LEXILLA_INSTALL_NAME`; packaging rewrites the copied dylib to that
bundle-safe install name before signing. The final package report prints the
Lexilla build mode, requested architectures, and actual packaged slices.

By default the app bundle and DMG are ad hoc signed for local development. Some
managed or stricter macOS installations reject ad hoc GUI apps at launch. For a
build meant to run through Gatekeeper without local overrides, provide a real
signing identity:

```bash
MACOS_CODESIGN_IDENTITY="Developer ID Application: Example Team" \
scripts/package-macos.sh
```

If the identity lives outside the default keychain search list, also set
`MACOS_CODESIGN_KEYCHAIN=/path/to/keychain`. Distribution still requires the
usual Apple notarization flow after packaging.

## Reusable Upstream Components

Already wired into the native app:

- `../notepad-plus-plus/PowerEditor/src/langs.model.xml`
  - packaged into `Contents/Resources/langs.model.xml`
  - parsed at runtime for language detection, comment markers, and keyword data
- `../notepad-plus-plus/PowerEditor/src/stylers.model.xml`
  - packaged into `Contents/Resources/stylers.model.xml`
  - parsed at runtime for lexer style IDs, colors, fonts, and keyword classes
- `../notepad-plus-plus/PowerEditor/installer/APIs`
  - packaged into `Contents/Resources/APIs`
  - parsed at runtime for language-specific auto-completion keywords,
    function markers, overload descriptions, and parameter lists
- `../notepad-plus-plus/PowerEditor/installer/functionList`
  - packaged into `Contents/Resources/functionList`
  - parsed at runtime for function-list parser metadata; native macOS symbol
    extraction uses compatible regex rules for supported languages
- `../notepad-plus-plus/PowerEditor/installer/themes`
  - packaged into `Contents/Resources/themes`
  - scanned at runtime for Notepad++ theme XML files and loaded through the
    same style parser used by `stylers.model.xml`
- `../notepad-plus-plus/PowerEditor/misc/chameleon/chameleon-pencil-1000.png`
  - converted into the macOS app icon

Verified as buildable and intended for the next reuse step:

- `../notepad-plus-plus/scintilla/cocoa/Scintilla/Scintilla.xcodeproj`
  - build with `scripts/build-scintilla-framework.sh`
  - output: `.build/scintilla-derived/Build/Products/Release/Scintilla.framework`
  - packaged into `Contents/Frameworks/Scintilla.framework`
  - loaded at runtime by the native editor surface; if loading fails, the app
    falls back to `NSTextView`
- `../notepad-plus-plus/lexilla`
  - build with `scripts/build-lexilla-dylib.sh`
  - output: `../notepad-plus-plus/lexilla/bin/liblexilla.dylib`
  - packaged into `Contents/Frameworks/liblexilla.dylib`
  - build requests are arch-aware and validated against the produced dylib
  - packaged install name is rewritten to `@rpath/liblexilla.dylib`
  - loaded at runtime to create Lexilla `ILexer5` instances for Scintilla

## Current Native Features

- Native AppKit window and menu bar
- New, open, save, and save-as
- Native Preferences panel backed by macOS `UserDefaults`
- Native find and replace panel with match-case, whole-word, direction, and
  wrap-around options; Search menu includes Find Previous (Cmd+Shift+G)
- Native session restore for file-backed documents
- Native dirty-buffer snapshot restore using app-managed backup files
- Native Workspace panel for Notepad++ project XML and folder trees
- Native AppKit document tabs with duplicate-file activation
- Native editor toolbar with Save, Print, Find, Replace, bookmark, line-wrap,
  function-list, and optional folding commands
- Native Style Configurator panel backed by Notepad++ `stylers.model.xml`
- Native file monitoring for saved documents with reload/keep-current prompts
- Native print operation for the current document with headers and line numbers
- Native macro recording and replay for text-edit commands, including saved
  named macros
- Native Plugin Admin panel for manifest-based macOS plugin discovery and
  compatibility diagnostics for Windows Notepad++ DLL plugins, with native
  command execution, persisted enable/disable controls for native manifest
  plugins, install/update from an existing native plugin folder, bounded removal
  of user-installed native manifest plugins, explicit rescan, a user plugin
  folder opener, and streamed stdout/stderr in the panel
- Native Auto Completion panel backed by Notepad++ `installer/APIs/*.xml`
- Native Function Call Tip panel backed by Notepad++ API overload metadata
- Native Function List panel backed by Notepad++ `installer/functionList/*.xml`
  metadata and native symbol extraction
- Native Document Statistics command showing line count, word count, UTF-16
  characters, and Unicode scalar counts for the current buffer
- Native Theme menu backed by Notepad++ `installer/themes/*.xml`, with
  persisted theme selection and live restyling of open editor windows
- Native bookmark commands for toggling the current line, navigating previous
  and next bookmarks with wraparound, clearing bookmarks, and showing bookmark
  count in the status line, with bookmark restoration for reopened session
  files and dirty snapshot drafts
- Native line editing commands for deleting the current line or selected line
  range, joining lines, removing empty/blank lines, removing duplicate or
  consecutive duplicate lines, sorting selected lines ascending/descending,
  converting selected text to upper/lower/inverted case, and moving the current
  line or selected line block up and down
- Native Column Editor panel for inserting text at a fixed 1-based column
  across the current selected line range, with short-line padding and preserved
  line endings
- Native Column Editor number mode for decimal, hexadecimal, octal, and binary
  sequences with increment, repeat count, and leading zero/space padding
- Editor surface backed by upstream Scintilla Cocoa when the bundled framework
  is available
- Lexilla lexer loading through Scintilla `SCI_SETILEXER` for mapped upstream
  language names
- Native Scintilla line-number, bookmark-marker, and fold margins when the
  bundled Scintilla framework is active
- Packaged Scintilla editor surface handles bookmark and fold margin clicks;
  packaged-build hand-click behavior was manually confirmed on June 2, 2026
- Native Scintilla folding commands for toggling the current fold, folding all,
  and unfolding all through View > Folding
- UTF-8 and UTF-16 text loading, BOM detection, and native Encoding menu
  conversion commands
- LF, CRLF, and CR line-ending detection/preservation
- Monospaced editor with undo, cut/copy/paste, select-all
- Status line with line, column, character count, language, line ending, encoding
- Language detection, comment markers, and keyword data loaded from Notepad++'s
  upstream `PowerEditor/src/langs.model.xml`
- User-defined-language core model, JSON persistence, XML import/export,
  extension normalization, extensionless manual languages, and language-catalog
  merge/override support, with structured WordsStyle field update helpers
- Native User Defined Languages panel for listing saved UDLs, importing XML,
  exporting XML, editing definitions including a structured multi-style
  WordsStyle matrix, and deleting saved definitions; import/export file I/O
  runs off the main actor
- Reusable rectangular selection/block-edit core transforms with short-line
  padding and LF/CRLF/CR preservation
- Native localized rectangular selection panel for inserting or replacing
  multi-line blocks across the current selected line range and character
  column, with selected-text preview defaults for replacement mode
- Bounded Scintilla multi-selection adapter methods on the editor surface for
  applying discontiguous UTF-16 ranges or restoring live rectangular
  anchor/caret metadata, with `NSTextView` retaining a no-op fallback
- Reusable search core and native Find panel expose upward search direction and
  no-wrap scans, with Find Previous (Cmd+Shift+G) in the Search menu and
  direction/wrap controls in the panel
- Localized app menus and editor toolbar backed by SwiftPM-bundled English and
  Simplified Chinese strings; broader panel/view copy is still being migrated
- Lightweight native syntax highlighting driven by that upstream language model
  as the fallback when no Lexilla lexer is mapped; the Lexilla mapping now
  mirrors upstream `ScintillaEditView::_langNameInfoArray` (~95 languages,
  C-family languages share the cpp lexer)
- Native Find in Files / Find in Projects with a Found Results panel,
  next/previous result navigation, and Find in Search Results
- Native Incremental Search bar and Search > Mark with the five upstream mark
  styles, style-token commands, and Jump Up/Down per style
- Native Document Map, Document List, Clipboard History, Character Panel, and
  Task List panels
- Native Run menu with saved commands, plus MD5/SHA-1/SHA-256/SHA-512
  generation commands
- Native Shortcut Mapper with conflict detection, shortcuts.xml import/export,
  and Settings > Validate shortcuts.xml diagnostics
- Native Go To Line, Go to Matching Brace, brace/XML-tag highlighting, smart
  highlighting, change-history navigation, and Hide Lines
- View > Launch in Browser submenu (upstream Firefox/Chrome/Edge parity)
  offering the system default browser plus each installed browser discovered
  by bundle identifier (Safari, Chrome, Firefox, Edge, Brave, Arc, Opera,
  Chromium, Vivaldi); unsaved documents preview from a temporary HTML file
- Full Encoding menu with upstream-style "Character sets" region grouping
  covering UTF-8/UTF-16 plus ~45 legacy codepages (ISO 8859-x, Windows-125x,
  KOI8-R/U, CJK, TIS-620, OEM/DOS pages) across the convert / encode-in /
  reload-as flows
- Notepad++/Boost-flavoured regex translation for the macOS (ICU) engine:
  `\<`/`\>` word boundaries, `\1`-style replacement backreferences, `$&`,
  `${n}`, and clear unsupported-construct errors surfaced in the Find panel
- View > Clone to Other View splits the window onto a second Scintilla surface
  sharing the same document (independent carets/scroll/folds), with
  View > Focus on Another View (F8) switching panes
- Window > Open in New Instance / Move to New Instance launch a separate
  `-nosession` app instance for the current file
- Edit > Paste Special binary clipboard commands (Cut/Copy/Paste Binary
  Content) with NUL-safe byte round-tripping in the document encoding
- Plugin buffer-mutation protocol: native manifest plugins can return a
  validated JSON edit script through `NOTEPAD_MAC_EDIT_SCRIPT_FILE` that the
  host applies to the active buffer

Feature-parity progress against upstream Notepad++ is tracked in
[PARITY_PLAN.md](PARITY_PLAN.md).

## Porting Boundary

This is a native macOS app, not a full Notepad++ Win32 port. The copied upstream
source remains available as the reference baseline for future feature parity
work. Full parity would require replacing Win32 window/dialog/plugin APIs with
AppKit equivalents module by module.

Notepad++ plugins are Win32 DLLs and are not loaded by this native macOS host.
The app exposes a native manifest-based plugin discovery layer instead, and the
Plugin Admin panel reports copied `.dll` plugins as Windows-only rather than
bridging them through Wine.

## Native Plugin Command ABI

Native manifest commands are launched directly from their declared executable
entry point. The runtime validates that the entry point is executable and stays
inside the plugin directory, then passes arguments through `Process` as an argv
array: `--notepad-command <command-id>` followed by caller-supplied arguments.
Manifest and user argument text is not shell-interpolated.

The host owns these command environment keys and overwrites caller-supplied
spoofed values before launch:

- `NOTEPAD_MAC_PLUGIN_IDENTIFIER`
- `NOTEPAD_MAC_COMMAND_IDENTIFIER`
- `NOTEPAD_MAC_PLUGIN_DIRECTORY`

When a file-backed document URL is supplied to the command invocation, the host
also exposes:

- `NOTEPAD_MAC_DOCUMENT_PATH`
- `NOTEPAD_MAC_DOCUMENT_DIRECTORY`
- `NOTEPAD_MAC_DOCUMENT_NAME`

If no document URL is supplied, those document keys are removed from the process
environment so native plugins can distinguish "no file-backed document" from a
real path. Non-file document URLs are rejected before the command is launched.
Plugin Admin supplies the active editor's file-backed document URL when one is
available; untitled and dirty snapshot documents run without document path keys.

When the command invocation supplies active editor selection context, the host
also exposes UTF-16 selection metadata:

- `NOTEPAD_MAC_SELECTION_UTF16_LOCATION`
- `NOTEPAD_MAC_SELECTION_UTF16_LENGTH`
- `NOTEPAD_MAC_SELECTION_TEXT`

The location and length are decimal UTF-16 offsets in the current buffer, and
the text value is the selected text. If no selection context is supplied, those
selection keys are removed from the process environment so plugins can
distinguish "no editor selection metadata" from an empty selection at a known
caret location. Plugin Admin supplies the active editor's current selection
context when running a native manifest command. Selection text containing NUL is
rejected before launch because process environment strings use NUL-terminated
transport and cannot safely preserve embedded NUL bytes.

## Native Module Progress

- Core document I/O: native macOS implementation with reusable encoding and
  line-ending logic. The Encoding menu can convert the current buffer target
  encoding between UTF-8, UTF-16, UTF-16 LE, and UTF-16 BE before saving. The
  core codec detects UTF-8/UTF-16 byte-order marks and preserves compatible
  loaded-file BOM intent through save operations, while new UTF-8 documents stay
  BOM-less by default.
- Language metadata: reuses Notepad++ `langs.model.xml`.
- User-defined languages: native core/store layer can persist lightweight UDL
  definitions, import/export the Notepad++ UDL XML shape, preserve WordsStyle
  style metadata, update structured WordsStyle fields while preserving unknown
  attributes, accept extensionless manual-only languages, and merge them into
  the language catalog without duplicate-name or duplicate-extension crashes.
  The native Language menu has a minimal manager for listing, XML
  import/export, deletion, and structured WordsStyle edits for DEFAULT,
  COMMENTS, NUMBER, OPERATOR, FOLDEROPEN, FOLDERCLOSE, and KEYWORDS1.
- Editor engine: reuses upstream Scintilla Cocoa and Lexilla where available,
  with `NSTextView` as a native fallback. The Scintilla path configures line
  number, bookmark marker, and fold margins, syncs native bookmarks to Scintilla
  markers, enables lexer folding properties, persists collapsed fold state in
  the native session, and exposes native folding menu/toolbar commands for
  toggle/fold-all/unfold-all. Bookmark and fold margin click handling is wired
  on the packaged Scintilla surface and was manually confirmed on a packaged
  build on June 2, 2026.
- Search and replace: native AppKit panel backed by reusable core search logic,
  including upward search, no-wrap searches, Find Previous (Cmd+Shift+G), and
  direction/wrap controls in the panel.
- Preferences: native AppKit panel and `UserDefaults` persistence for editor
  font size, line wrapping, and find defaults.
- Session persistence: native `UserDefaults` restore for saved file-backed
  documents, active-document tracking, bookmarks, and collapsed fold-state
  records.
- Snapshot backup: native backup directory and session metadata for dirty
  documents, following Notepad++'s snapshot-mode shape of storing a backup file
  path in the session and reloading that content on startup. Snapshot metadata
  carries the loaded-file BOM preservation intent so restored dirty documents
  keep their original save behavior. Dirty documents are snapshot-saved after a
  short native debounce and again during termination.
- Workspace tree: native `NSOutlineView` panel backed by reusable core parsing
  and writing of Notepad++ `<NotepadPlus><Project><Folder><File>` workspace XML,
  plus folder-to-workspace generation and `UserDefaults` restore.
- Tabbed document UI: native AppKit window tab groups with reusable core tab
  identity/state rules for deduplicating files and selecting the next tab after
  close.
- Style configurator: native AppKit panel backed by reusable parsing of
  Notepad++ `stylers.model.xml`; foreground/background/font/bold/italic
  overrides persist in `UserDefaults` and are applied to Scintilla by style ID.
- File monitoring: native macOS file-system event monitoring for saved
  documents, backed by reusable core metadata snapshots for detecting modified
  and deleted files. External changes prompt to reload or keep the current
  buffer; deleted files mark the buffer dirty so it can be saved again.
- Print: native `NSPrintOperation` for the current document, backed by reusable
  core print document rendering with normalized line endings, line numbers, and
  deterministic pagination metadata.
- Macro/command recording: native Macro menu for recording, stopping, replaying,
  saving, playing, deleting, and clearing text-edit macros. The core macro
  model stores UTF-16 text replacement commands, replays them deterministically,
  persists the last recording in `UserDefaults`, and keeps a named macro list
  for Notepad++-style replay workflows.
- Plugin compatibility: native Plugin Admin scans plugin directories for
  `notepad-mac-plugin.json` manifest plugins, lists declared native commands,
  classifies Windows `.dll` Notepad++ plugins as incompatible with a clear
  no-Wine diagnostic, and has a core runtime that validates executable native
  command plans plus Notepad-specific environment keys. Plugin Admin can
  persistently enable/disable native manifest plugins without changing the
  default scan path or overriding Windows-only DLL diagnostics. It exposes an
  install/update action for existing native plugin folders containing
  `notepad-mac-plugin.json`, a bounded remove action for user-installed native
  manifest plugins that rejects Windows-only and non-user plugin locations, an
  explicit rescan command, plus a user plugin folder opener that creates the
  folder if needed, can run native-compatible manifest commands asynchronously,
  pass optional arguments, the active file-backed document path, and current
  editor selection context through validated environment keys, stream
  stdout/stderr while the process is running, and report termination status.
- Auto completion: native panel loads upstream Notepad++ API XML files,
  respects language case-sensitivity, lists overload metadata, and inserts the
  chosen keyword into the current editor buffer.
- Function call tips: native Edit > Function Call Tip panel reuses the same
  upstream API XML overload metadata, detects the active call expression at the
  insertion point, counts the active parameter with nested-call awareness, and
  shows available signatures plus descriptions.
- Function list: native panel loads upstream function-list metadata and extracts
  symbols from the current buffer with macOS-compatible rules for Bash, Rust,
  Python, Swift, JavaScript, PHP, Ruby, and common C-style languages.
- Document statistics: native View command uses a reusable core summary for
  line count, word count, UTF-16 character count, and Unicode scalar count.
- Theme selection: native Theme menu scans installed Notepad++ theme XML files,
  persists the selected theme, reloads it at startup, and applies the selected
  style catalog to existing editor windows and the Style Configurator.
- Bookmarks: native Search > Bookmark commands implement Notepad++-style
  toggle/next/previous/clear semantics with a reusable line-number bookmark
  model. Bookmark line sets are saved in the native session for file-backed
  documents and dirty snapshot drafts, restored by document identity on launch,
  clamped when document line counts shrink, and drawn in the Scintilla bookmark
  margin when the bundled framework is active. Bookmark margin clicks are wired
  on the packaged Scintilla editor surface and were manually confirmed on June
  2, 2026.
- Line editing: native Edit commands can delete the current line or selected
  line range, join lines, remove empty/blank lines, remove duplicate or
  consecutive duplicate lines, sort selected lines ascending/descending, convert
  selected text to upper/lowercase, and move the current line or selected line
  block up and down while preserving the surrounding buffer content.
- Column editor: native Edit > Column Editor panel inserts text across the
  selected line range at a fixed column. The reusable core transform preserves
  LF/CRLF/CR line endings and pads shorter lines with spaces before insertion.
  Number mode supports decimal, lowercase/uppercase hexadecimal, octal, and
  binary sequences with increment, repeat count, and leading zero/space padding.
- Rectangular selection: native core transforms can extract, insert, and replace
  rectangular text blocks by character column, padding short lines as needed and
  preserving per-line endings. A localized native editor panel can insert or
  replace multi-line blocks across the current selected line range, derive
  default line/column ranges from the current selection, read live Scintilla
  rectangular selection metadata when the bundled editor is active, preview
  extracted replacement text, retain precise per-row edited-range metadata, and
  select exact discontiguous edited ranges on the Scintilla-backed surface after
  apply, with `NSTextView` keeping the contiguous fallback. The editor surface
  exposes Scintilla-backed methods for applying discontiguous selections from
  those per-row ranges and for restoring live rectangular anchor/caret metadata
  through `SCI_SETMULTIPLESELECTION`, `SCI_ADDSELECTION`, and
  `SCI_SETRECTANGULARSELECTION*`.
- Localization: English and Simplified Chinese `Localizable.strings` resources
  are bundled through SwiftPM and copied into the packaged app. App menus and
  the editor toolbar consume the localization helper; broader panel/view copy is
  still pending.
- Remaining Notepad++ parity areas (see PARITY_PLAN.md): the previously
  deferred items are now implemented — GitHub Releases update checker with
  updater proxy, the boost::regex C++ bridge (full upstream regex syntax,
  including \K, recursion, conditionals, and atomic groups), OEM 720/858/861
  codepages via built-in byte tables, plugin install from .zip archives and
  URLs with version-aware updates, the legacy hardcoded panel strings
  migration (en + zh-Hans), upstream-style Move to Other View (a second
  split pane hosting another document's shared buffer), and a Document
  Peeker tab-hover preview. Win32 DLL plugin loading and Windows-only OS
  integrations remain intentionally out of scope. Live rectangular
  multi-caret editing is wired through Scintilla multiple-selection settings
  (Alt+drag switches to rectangular mode; typing applies to every caret).

## Reuse Policy

- Reuse platform-neutral Notepad++ resources such as language models, icons, and
  syntax metadata.
- Reuse native/cross-platform upstream libraries when they build cleanly on
  macOS. Scintilla Cocoa is used as the packaged editor surface because it
  already produces a native framework from the copied upstream source.
- Rewrite Win32-only UI/application behavior in native macOS code.
- Keep the reuse boundary explicit so later porting work can replace more
  hardcoded native behavior with upstream-compatible data or libraries when that
  code is genuinely portable.

## Current Scintilla Limitations

The app now uses the upstream Scintilla Cocoa framework when packaged, but the
Swift adapter is intentionally thin:

- packaging attempts a universal Scintilla framework build and reports the
  bundled framework architecture. If Scintilla remains single-architecture, the
  Scintilla-backed editor path is limited to that slice even when the main
  executable is universal; the package should not be described as a fully
  universal app bundle until Scintilla and Lexilla both include x86_64 and arm64
- text get/set, edit notifications, selection range, font selection, wrap mode,
  and keyword set forwarding are wired through typed Objective-C calls
- Scintilla rectangular and multi-selection messages are reachable through the
  editor surface for bounded selection application, including UTF-16 to
  Scintilla-position conversion before `SCI_SETSELECTION`,
  `SCI_ADDSELECTION`, and `SCI_SETRECTANGULARSELECTION*`
- Lexilla lexer creation is wired through the shared library's C ABI and passed
  to Scintilla with `SCI_SETILEXER`
- lexer-specific style colors are loaded from `stylers.model.xml`; the native
  configurator currently covers foreground/background/font/bold/italic per
  style ID
- development runs without the bundled framework fall back to `NSTextView`
