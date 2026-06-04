import Foundation

enum HelpLink {
    case home
    case projectPage
    case userManual
    case forum
    case downloads
}

enum HelpSupport {
    static func url(for link: HelpLink) -> URL {
        switch link {
        case .home:
            URL(string: "https://notepad-plus-plus.org/")!
        case .projectPage:
            URL(string: "https://github.com/notepad-plus-plus/notepad-plus-plus")!
        case .userManual:
            URL(string: "https://npp-user-manual.org/")!
        case .forum:
            URL(string: "https://community.notepad-plus-plus.org/")!
        case .downloads:
            URL(string: "https://notepad-plus-plus.org/downloads/")!
        }
    }

    static func aboutText(appName: String, version: String, subtitle: String) -> String {
        "\(appName)\nVersion: \(version)\n\(subtitle)"
    }

    static func debugInfoText(
        documentName: String,
        documentPath: String?,
        editorBackend: String,
        supportsFolding: Bool,
        documentEncoding: String? = nil,
        documentLineEnding: String? = nil,
        documentLanguage: String? = nil,
        activePluginCount: Int = 0,
        savedCommandCount: Int = 0,
        namedMacroCount: Int = 0
    ) -> String {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Dev"
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        let bundleID = bundle.bundleIdentifier ?? "com.notepadmac"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let arch: String
        #if arch(arm64)
        arch = "arm64 (Apple Silicon)"
        #elseif arch(x86_64)
        arch = "x86_64 (Intel)"
        #else
        arch = "unknown"
        #endif

        // Detect Swift version at compile time
        let swiftVersion: String
        #if swift(>=6.0)
        swiftVersion = "Swift 6.x"
        #elseif swift(>=5.9)
        swiftVersion = "Swift 5.9+"
        #else
        swiftVersion = "Swift 5.x"
        #endif

        let cmdLine = CommandLine.arguments.dropFirst().joined(separator: " ")

        // User data directory
        let userDataDir: String = {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            return appSupport?.appendingPathComponent("NotepadMac").path ?? "(unknown)"
        }()

        // System locale
        let locale = Locale.current.identifier

        var lines = [
            "Notepad++ Mac \(appVersion) (build \(buildVersion))",
            "Bundle ID: \(bundleID)",
            "",
            "OS: macOS \(osVersion)",
            "Architecture: \(arch)",
            "Locale: \(locale)",
            "Compiler: \(swiftVersion)",
            "Editor backend: \(editorBackend)",
            "User data: \(userDataDir)",
            "",
            "Current document: \(documentName)",
            "Path: \(documentPath ?? "Unsaved (new document)")",
        ]
        if let lang = documentLanguage { lines.append("Language: \(lang)") }
        if let enc = documentEncoding { lines.append("Encoding: \(enc)") }
        if let eol = documentLineEnding { lines.append("Line ending: \(eol)") }
        lines += [
            "Supports folding: \(supportsFolding ? "yes" : "no")",
            "",
            "Active plugins: \(activePluginCount)",
            "Saved run commands: \(savedCommandCount)",
            "Saved macros: \(namedMacroCount)",
            "Command line: \(cmdLine.isEmpty ? "(none)" : cmdLine)",
        ]
        return lines.joined(separator: "\n")
    }

    static func commandLineArgumentsText(appName: String) -> String {
        """
        Usage: \(appName) [options] [file paths...]

        Options:
          -help, --help               Print this help and exit
          -nosession                  Launch without restoring previous session
          -openSession <path>         Open specific session file on launch
          -noPlugin                   Skip loading plugins
          -alwaysOnTop                Open window in always-on-top mode
          -ro, -readOnly              Open file(s) as read-only
          -fullReadOnly               Open file(s) as read-only (same as -ro)
          -monitor                    Enable file monitoring (tail -f) on opened file
          -multiInst                  Open a new instance (no-op on macOS)
          -openFoldersAsWorkspace     Open folder arguments as workspace
          -l <language>               Set syntax language (e.g. -l python)
          -udl <language>             Set user-defined language
          -n <line>                   Navigate to line number on open
          -c <column>                 Navigate to column on open (used with -n)
          -p <position>               Navigate to character position (UTF-16 offset)
          -x <x>                      Set window X position in screen coordinates
          -y <y>                      Set window Y position in screen coordinates

        Examples:
          \(appName) file.py -l python -n 42
          \(appName) -nosession -ro /etc/hosts
          \(appName) -openSession ~/work.npsession
          \(appName) -openFoldersAsWorkspace ~/myproject
        """
    }
}
