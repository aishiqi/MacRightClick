import AppKit
import Foundation

@main
struct LogicTests {
    static func main() throws {
        var failed = 0
        var passed = 0

        func expect(_ condition: Bool, _ name: String, _ detail: String = "") {
            if condition {
                passed += 1
                print("PASS  \(name)")
            } else {
                failed += 1
                print("FAIL  \(name)\(detail.isEmpty ? "" : " — \(detail)")")
            }
        }

        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MacRightClickTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let file = tmp.appendingPathComponent("readme.md")
        FileManager.default.createFile(atPath: file.path, contents: Data(), attributes: nil)
        let folder = tmp.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        expect(PathResolver.isDirectory(folder), "isDirectory folder")
        expect(!PathResolver.isDirectory(file), "isDirectory file")

        let dirFromFile = PathResolver.targetDirectory(selected: [file], targeted: tmp)
        expect(dirFromFile?.path == tmp.path, "targetDirectory from file is parent", dirFromFile?.path ?? "nil")

        let dirFromFolder = PathResolver.targetDirectory(selected: [folder], targeted: tmp)
        expect(dirFromFolder?.path == folder.path, "targetDirectory from folder is itself", dirFromFolder?.path ?? "nil")

        let dirFromEmpty = PathResolver.targetDirectory(selected: [], targeted: tmp)
        expect(dirFromEmpty?.path == tmp.path, "targetDirectory from empty uses targetedURL")

        expect(PathResolver.filePaths(selected: [file], targeted: tmp) == [file.path], "filePaths uses selection")
        expect(PathResolver.dirPaths(selected: [file], targeted: tmp) == [tmp.path], "dirPaths of file is parent")
        expect(PathResolver.dirPaths(selected: [folder], targeted: tmp) == [folder.path], "dirPaths of folder is itself")
        expect(PathResolver.folderPath(for: file.path) == tmp.path, "folderPath of file is parent")
        expect(PathResolver.folderPath(for: folder.path) == folder.path, "folderPath of folder is itself")

        let fileMacros = ScriptMacros.resolve(directory: tmp, files: [file.path])
        expect(fileMacros.file == file.path, "FILE is selected file")
        expect(fileMacros.folder == tmp.path, "FOLDER of file is parent")
        expect(fileMacros.filename == "readme.md", "FILENAME")
        expect(fileMacros.basename == "readme", "BASENAME")
        expect(fileMacros.ext == "md", "EXT")
        expect(fileMacros.folderName == tmp.lastPathComponent, "FOLDERNAME")
        expect(fileMacros.parent == tmp.deletingLastPathComponent().path, "PARENT of file folder")
        expect(fileMacros.files == [file.path], "FILES is selection")
        expect(fileMacros.folders == [tmp.path], "FOLDERS of file is parent")

        let folderMacros = ScriptMacros.resolve(directory: folder, files: [folder.path])
        expect(folderMacros.file == folder.path, "FILE of folder is itself")
        expect(folderMacros.folder == folder.path, "FOLDER of folder is itself")
        expect(folderMacros.filename == "src", "FILENAME of folder")
        expect(folderMacros.basename == "src", "BASENAME of folder")
        expect(folderMacros.ext == "", "EXT of folder is empty")
        expect(folderMacros.folderName == "src", "FOLDERNAME of folder")

        let multiMacros = ScriptMacros.resolve(directory: tmp, files: [file.path, folder.path])
        expect(multiMacros.file == file.path, "FILE uses first selection")
        expect(multiMacros.folder == tmp.path, "FOLDER uses first selection")
        expect(multiMacros.files == [file.path, folder.path], "FILES keeps order")
        expect(multiMacros.folders == [tmp.path, folder.path], "FOLDERS matches each item")

        let emptyMacros = ScriptMacros.resolve(directory: tmp, files: [])
        expect(emptyMacros.file == tmp.path && emptyMacros.folder == tmp.path, "empty selection uses directory")
        expect(ScriptMacros.environment(from: fileMacros)["MRC_DIR"] == tmp.path, "MRC_DIR aliases FOLDER")
        expect(ScriptMacros.environment(from: fileMacros)["FOLDER"] == tmp.path, "FOLDER is exported")

        let hidden = ScriptMacros.resolve(directory: tmp, files: [tmp.appendingPathComponent(".gitignore").path])
        expect(hidden.filename == ".gitignore" && hidden.basename == ".gitignore" && hidden.ext == "", "dotfile keeps name")

        let firstSwift = PathResolver.uniqueURL(in: tmp, preferredName: "untitled.swift")
        expect(firstSwift.lastPathComponent == "untitled.swift", "unique untitled.swift")
        FileManager.default.createFile(atPath: firstSwift.path, contents: Data(), attributes: nil)
        let secondSwift = PathResolver.uniqueURL(in: tmp, preferredName: "untitled.swift")
        expect(secondSwift.lastPathComponent == "untitled 2.swift", "increment untitled.swift", secondSwift.lastPathComponent)

        let docker = PathResolver.uniqueURL(in: tmp, preferredName: "Dockerfile")
        FileManager.default.createFile(atPath: docker.path, contents: Data(), attributes: nil)
        let docker2 = PathResolver.uniqueURL(in: tmp, preferredName: "Dockerfile")
        expect(docker2.lastPathComponent == "Dockerfile 2", "increment Dockerfile", docker2.lastPathComponent)

        let gitignore = PathResolver.uniqueURL(in: tmp, preferredName: ".gitignore")
        FileManager.default.createFile(atPath: gitignore.path, contents: Data(), attributes: nil)
        let gitignore2 = PathResolver.uniqueURL(in: tmp, preferredName: ".gitignore")
        expect(gitignore2.lastPathComponent == ".gitignore 2", "increment .gitignore", gitignore2.lastPathComponent)

        let command = ActionCommand(kind: .newFile, id: "file.swift", paths: [tmp.path])
        let url = command.url()
        expect(url != nil, "command.url is non-nil")
        expect(url?.scheme == "macrightclick", "scheme")
        let parsed = url.flatMap(ActionCommand.from(url:))
        expect(parsed?.kind == .newFile, "parse kind")
        expect(parsed?.id == "file.swift", "parse id")
        expect(parsed?.paths == [tmp.path], "parse path")

        let token = ActionCommand(kind: .openApp, id: "app.cursor", paths: []).token()
        let fromToken = ActionCommand.from(token: token)
        expect(fromToken?.kind == .openApp && fromToken?.id == "app.cursor", "token round-trip")

        let scriptCommand = ActionCommand(kind: .runScript, id: "custom.script.1", paths: [tmp.path, file.path])
        let scriptURL = scriptCommand.url()
        let parsedScript = scriptURL.flatMap(ActionCommand.from(url:))
        expect(parsedScript?.kind == .runScript, "script command kind")
        expect(parsedScript?.id == "custom.script.1", "script command id")
        expect(parsedScript?.paths == [tmp.path, file.path], "script command paths")
        let scriptToken = ActionCommand(kind: .runScript, id: "custom.script.1", paths: []).token()
        expect(ActionCommand.from(token: scriptToken)?.kind == .runScript, "script token kind")

        let config = MenuConfig.default
        expect(config.fileTypes.count == FileTypeItem.presets.count, "file type presets")
        expect(config.apps.count == AppItem.presets.count, "app presets")
        expect(config.actions.count == ActionKind.allCases.count, "action presets")
        expect(config.scripts.isEmpty, "default has no scripts")
        expect(config.fileTypes.contains { $0.fileName == "untitled.swift" && $0.placement == .submenu }, "swift is submenu")
        expect(config.actions.allSatisfy { $0.placement == .mainMenu }, "actions default to main menu")
        expect(config.fileTypes.contains { $0.fileName == "Dockerfile" }, "Dockerfile preset")
        expect(config.fileTypes.contains { $0.fileName == ".gitignore" }, "gitignore preset")
        expect(config.apps.contains { $0.id == "app.cursor" }, "Cursor preset")
        expect(config.apps.contains { $0.id == "app.vscode" }, "VS Code preset")

        var stale = MenuConfig(fileTypes: [], apps: [], actions: [])
        stale = stale.mergingNewPresets()
        expect(stale.fileTypes.count == FileTypeItem.presets.count, "merge adds missing file presets")
        expect(stale.apps.count == AppItem.presets.count, "merge adds missing app presets")
        expect(stale.actions.count == ActionItem.presets.count, "merge adds missing actions")
        expect(stale.scripts.isEmpty, "merge keeps empty scripts")

        let oldJSON = """
        {"fileTypes":[],"apps":[],"actions":[]}
        """.data(using: .utf8)!
        let decodedOld = try JSONDecoder().decode(MenuConfig.self, from: oldJSON)
        expect(decodedOld.scripts.isEmpty, "old config without scripts decodes")

        let bashScript = ScriptItem.custom(
            name: "Echo",
            source: "printf '%s\\n' \"$FOLDER\" \"$FILE\" \"$FILENAME\" \"$BASENAME\" \"$EXT\" \"$MRC_DIR\" \"$1\""
        )
        let bashResult = ScriptRunner.run(bashScript, directory: tmp, files: [file.path])
        expect(bashResult.exitCode == 0, "bash script exit 0", bashResult.stderr)
        expect(bashResult.stdout.contains(tmp.path), "bash sees FOLDER", bashResult.stdout)
        expect(bashResult.stdout.contains(file.path), "bash sees FILE", bashResult.stdout)
        expect(bashResult.stdout.contains("readme.md"), "bash sees FILENAME", bashResult.stdout)
        expect(bashResult.stdout.contains("readme"), "bash sees BASENAME", bashResult.stdout)
        expect(bashResult.stdout.split(separator: "\n").contains("md"), "bash sees EXT", bashResult.stdout)

        let legacyScriptJSON = """
        {"id":"custom.script.old","name":"Legacy","kind":"python","source":"echo hi","enabled":true,"placement":"submenu"}
        """.data(using: .utf8)!
        let legacyScript = try JSONDecoder().decode(ScriptItem.self, from: legacyScriptJSON)
        expect(legacyScript.name == "Legacy" && legacyScript.source == "echo hi", "legacy kind field is ignored")
        expect(legacyScript.runInTerminal == false, "legacy script defaults In Terminal off")
        expect(bashScript.runInTerminal == false, "new script defaults In Terminal off")
        expect(ScriptRunner.shellEscape("it's") == "'it'\\''s'", "shell escape single quote")
        let inline = ScriptRunner.terminalCommand(for: bashScript, directory: tmp, files: [file.path])
        expect(inline.contains("printf '%s\\n' \"$FOLDER\" \"$FILE\" \"$FILENAME\" \"$BASENAME\" \"$EXT\" \"$MRC_DIR\" \"$1\""), "terminal command uses script text")
        expect(inline.contains("export FOLDER="), "terminal command exports FOLDER")
        expect(inline.contains("export FILE="), "terminal command exports FILE")
        expect(inline.contains("cd "), "terminal command cds into folder")
        expect(!inline.contains(".sh"), "terminal command does not load a temp script file")
        expect(
            TerminalLauncher.appleScriptEscape("say \"hi\"\nls\\") == "say \\\"hi\\\"\\nls\\\\",
            "AppleScript escape quotes, newlines and backslashes",
            TerminalLauncher.appleScriptEscape("say \"hi\"\nls\\")
        )

        let previous = SharedConfig.configData()
        var custom = MenuConfig.default
        custom.fileTypes[0].enabled = false
        custom.fileTypes[0].placement = .mainMenu
        SharedConfig.save(custom)
        let loaded = SharedConfig.load()
        expect(loaded.fileTypes[0].enabled == false, "config persists enabled")
        expect(loaded.fileTypes[0].placement == .mainMenu, "config persists placement")
        if let previous {
            try? previous.write(to: SharedConfig.configURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: SharedConfig.configURL)
        }

        if let cursor = config.apps.first(where: { $0.id == "app.cursor" }) {
            print("INFO  Cursor installed: \(AppLocator.isInstalled(cursor)) url=\(AppLocator.url(for: cursor)?.path ?? "nil")")
        }
        if let vscode = config.apps.first(where: { $0.id == "app.vscode" }) {
            print("INFO  VS Code installed: \(AppLocator.isInstalled(vscode)) url=\(AppLocator.url(for: vscode)?.path ?? "nil")")
        }
        if let xcode = config.apps.first(where: { $0.id == "app.xcode" }) {
            expect(AppLocator.isInstalled(xcode), "Xcode is installed")
        }
        if let textedit = config.apps.first(where: { $0.id == "app.textedit" }) {
            expect(AppLocator.isInstalled(textedit), "TextEdit is installed")
        }

        expect(IconProvider.fileIcon(fileName: "untitled.swift").size.width == 16, "file icon sized 16")
        expect(IconProvider.actionIcon(kind: .newFolder).size.width == 16, "action icon sized 16")

        try? FileManager.default.removeItem(at: tmp)

        print("----")
        print("\(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}
