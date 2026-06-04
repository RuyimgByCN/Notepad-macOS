import Foundation

struct CommandLineArgs {
    let fileURLs: [URL]
    /// File paths passed on the command line that do not exist yet.
    let newFileURLs: [URL]
    let noSession: Bool
    let noPlugin: Bool
    let alwaysOnTop: Bool
    let readOnly: Bool
    let monitoring: Bool
    let gotoLine: Int?
    let gotoColumn: Int?
    let gotoPosition: Int?
    let languageName: String?
    let openFoldersAsWorkspace: Bool
    let windowX: Int?
    let windowY: Int?

    static func parse(_ args: any Collection<String>) -> CommandLineArgs {
        var fileURLs: [URL] = []
        var newFileURLs: [URL] = []
        var noSession = false
        var noPlugin = false
        var alwaysOnTop = false
        var readOnly = false
        var monitoring = false
        var gotoLine: Int? = nil
        var gotoColumn: Int? = nil
        var gotoPosition: Int? = nil
        var languageName: String? = nil
        var openFoldersAsWorkspace = false
        var windowX: Int? = nil
        var windowY: Int? = nil

        var iterator = args.makeIterator()
        while let arg = iterator.next() {
            switch arg {
            case "-nosession", "--nosession":
                noSession = true
            case "-noPlugin", "--noPlugin":
                noPlugin = true
            case "-alwaysOnTop", "--alwaysOnTop":
                alwaysOnTop = true
            case "-ro", "-readOnly", "--ro", "--readOnly",
                 "-fullReadOnly", "--fullReadOnly":
                readOnly = true
            case "-monitor", "--monitor":
                monitoring = true
            case "-openFoldersAsWorkspace", "--openFoldersAsWorkspace":
                openFoldersAsWorkspace = true
            case "-multiInst", "--multiInst":
                // On macOS each launch is already a new instance; flag is accepted but no-op
                break
            case "-notabbar", "--notabbar", "-systemtray", "--systemtray",
                 "-loadingTime", "--loadingTime":
                // Windows-only flags: accepted silently
                break
            case "-n", "--n":
                if let next = iterator.next(), let line = Int(next) {
                    gotoLine = line
                }
            case "-c", "--c":
                if let next = iterator.next(), let col = Int(next) {
                    gotoColumn = col
                }
            case "-p", "--p":
                if let next = iterator.next(), let pos = Int(next) {
                    gotoPosition = pos
                }
            case "-x", "--x":
                if let next = iterator.next(), let x = Int(next) {
                    windowX = x
                }
            case "-y", "--y":
                if let next = iterator.next(), let y = Int(next) {
                    windowY = y
                }
            case "-l", "--l":
                languageName = iterator.next()
            case "-lLanguage", "--lLanguage":
                languageName = iterator.next()
            case "-udl", "--udl":
                languageName = iterator.next()  // treat UDL name as language name
            default:
                if !arg.hasPrefix("-") {
                    let url = URL(fileURLWithPath: arg).resolvingSymlinksInPath()
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                        if !isDir.boolValue {
                            fileURLs.append(url)
                        } else if openFoldersAsWorkspace {
                            // folder handled at launch time via openFoldersAsWorkspace flag
                            fileURLs.append(url)
                        }
                    } else {
                        newFileURLs.append(url)
                    }
                }
            }
        }

        return CommandLineArgs(
            fileURLs: fileURLs,
            newFileURLs: newFileURLs,
            noSession: noSession,
            noPlugin: noPlugin,
            alwaysOnTop: alwaysOnTop,
            readOnly: readOnly,
            monitoring: monitoring,
            gotoLine: gotoLine,
            gotoColumn: gotoColumn,
            gotoPosition: gotoPosition,
            languageName: languageName,
            openFoldersAsWorkspace: openFoldersAsWorkspace,
            windowX: windowX,
            windowY: windowY
        )
    }
}
