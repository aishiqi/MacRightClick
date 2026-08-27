import Foundation

/// Path tokens exported into bash scripts as environment variables.
enum ScriptMacros {
    struct Values: Equatable {
        var file: String
        var folder: String
        var filename: String
        var basename: String
        var ext: String
        var folderName: String
        var parent: String
        var files: [String]
        var folders: [String]
    }

    struct Token: Identifiable {
        var name: String
        var summary: String
        var id: String { name }
    }

    static let catalog: [Token] = [
        Token(name: "$FOLDER", summary: "Containing folder of a file, or the folder itself"),
        Token(name: "$FILE", summary: "First selected path"),
        Token(name: "$FILENAME", summary: "Name of the first selected item"),
        Token(name: "$BASENAME", summary: "Filename without extension"),
        Token(name: "$EXT", summary: "Extension without the dot"),
        Token(name: "$FOLDERNAME", summary: "Name of $FOLDER"),
        Token(name: "$PARENT", summary: "Parent of $FOLDER"),
        Token(name: "$FILES", summary: "All selected paths, one per line"),
        Token(name: "$FOLDERS", summary: "Containing folder of each selected item"),
    ]

    static func resolve(directory: URL, files: [String]) -> Values {
        let file = files.first ?? directory.path
        let folder = files.first.map(PathResolver.folderPath(for:)) ?? directory.path
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let (basename, ext) = splitName(filename)
        return Values(
            file: file,
            folder: folder,
            filename: filename,
            basename: basename,
            ext: ext,
            folderName: URL(fileURLWithPath: folder).lastPathComponent,
            parent: URL(fileURLWithPath: folder).deletingLastPathComponent().path,
            files: files,
            folders: files.map(PathResolver.folderPath(for:))
        )
    }

    static func environment(from values: Values) -> [String: String] {
        [
            "FILE": values.file,
            "FOLDER": values.folder,
            "FILENAME": values.filename,
            "BASENAME": values.basename,
            "EXT": values.ext,
            "FOLDERNAME": values.folderName,
            "PARENT": values.parent,
            "FILES": values.files.joined(separator: "\n"),
            "FOLDERS": values.folders.joined(separator: "\n"),
            "MRC_DIR": values.folder,
            "MRC_FILES": values.files.joined(separator: "\n"),
        ]
    }

    private static func splitName(_ filename: String) -> (String, String) {
        if filename.hasPrefix(".") {
            let rest = String(filename.dropFirst())
            if !rest.contains(".") {
                return (filename, "")
            }
        }
        let ns = filename as NSString
        let ext = ns.pathExtension
        let base = ext.isEmpty ? filename : ns.deletingPathExtension
        return (base, ext)
    }
}

enum ScriptRunner {
    struct Result: Equatable {
        var exitCode: Int32
        var stdout: String
        var stderr: String
    }

    /// Runs `script` with `/bin/bash`. Working directory is `directory`
    /// (or the desktop). Path macros such as `$FOLDER` and `$FILE` are exported.
    static func run(_ script: ScriptItem, directory: URL?, files: [String]) -> Result {
        let workDir = directory ?? PathResolver.desktopDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let env = environment(directory: workDir, files: files)
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacRightClick-\(UUID().uuidString).sh")

        do {
            try script.source.write(to: temp, atomically: true, encoding: .utf8)
        } catch {
            return Result(exitCode: 1, stdout: "", stderr: error.localizedDescription)
        }
        defer { try? FileManager.default.removeItem(at: temp) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [temp.path] + files
        process.currentDirectoryURL = workDir
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return Result(exitCode: 1, stdout: "", stderr: error.localizedDescription)
        }

        return Result(
            exitCode: process.terminationStatus,
            stdout: read(stdout),
            stderr: read(stderr)
        )
    }

    /// Opens Terminal and runs the script text in that shell — the text is sent
    /// to Terminal as is, never through a file on disk. The window stays open at
    /// the prompt when the commands finish.
    static func runInTerminal(_ script: ScriptItem, directory: URL?, files: [String]) {
        TerminalLauncher.run(terminalCommand(for: script, directory: directory, files: files))
    }

    static func terminalCommand(for script: ScriptItem, directory: URL?, files: [String]) -> String {
        let workDir = directory ?? PathResolver.desktopDirectory ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let macros = ScriptMacros.resolve(directory: workDir, files: files)
        let exports = ScriptMacros.environment(from: macros)
            .sorted { $0.key < $1.key }
            .map { "export \($0.key)=\(shellEscape($0.value))" }
            .joined(separator: "\n")
        let fileArgs = files.map(shellEscape).joined(separator: " ")
        return """
        cd \(shellEscape(workDir.path)) || exit 1
        \(exports)
        set -- \(fileArgs)
        \(script.source)
        """
    }

    static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func read(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func environment(directory: URL, files: [String]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extras = [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            SharedConfig.realHomeDirectory.appendingPathComponent(".local/bin").path
        ]
        let current = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let parts = current.split(separator: ":").map(String.init)
        var seen = Set(parts)
        var prefix: [String] = []
        for extra in extras where !seen.contains(extra) {
            prefix.append(extra)
            seen.insert(extra)
        }
        env["PATH"] = (prefix + parts).joined(separator: ":")
        env["HOME"] = SharedConfig.realHomeDirectory.path
        let macros = ScriptMacros.resolve(directory: directory, files: files)
        for (key, value) in ScriptMacros.environment(from: macros) {
            env[key] = value
        }
        return env
    }
}
