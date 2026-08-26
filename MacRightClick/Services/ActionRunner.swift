import AppKit

enum ActionRunner {
    static func run(_ url: URL) {
        guard let command = ActionCommand.from(url: url) else { return }
        run(command)
    }

    static func run(_ command: ActionCommand) {
        let config = SharedConfig.load()

        switch command.kind {
        case .newFile:
            guard let fileType = config.fileTypes.first(where: { $0.id == command.id }),
                  let directory = firstDirectory(command.paths) else { return }
            createEmptyFile(named: fileType.fileName, in: directory)

        case .newFolder:
            guard let directory = firstDirectory(command.paths) else { return }
            createFolder(in: directory)

        case .copyFilePath:
            copyToPasteboard(command.paths)

        case .copyDirPath:
            copyToPasteboard(command.paths)

        case .openTerminal, .openTerminalTab:
            guard let directory = firstDirectory(command.paths) else { return }
            TerminalLauncher.open(at: directory.path)

        case .openApp:
            guard let app = config.apps.first(where: { $0.id == command.id }) else { return }
            open(app: app, paths: command.paths)
        }
    }

    private static func firstDirectory(_ paths: [String]) -> URL? {
        if let path = paths.first, !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return PathResolver.desktopDirectory
    }

    private static func createEmptyFile(named fileName: String, in directory: URL) {
        let url = PathResolver.uniqueURL(in: directory, preferredName: fileName)
        let created = FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
        if created {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private static func createFolder(in directory: URL) {
        let url = PathResolver.uniqueURL(in: directory, preferredName: "untitled folder")
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSLog("MacRightClick: failed to create folder: \(error.localizedDescription)")
        }
    }

    private static func copyToPasteboard(_ paths: [String]) {
        guard !paths.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }

    private static func open(app item: AppItem, paths: [String]) {
        guard let appURL = AppLocator.url(for: item) else { return }
        let urls = paths.map { URL(fileURLWithPath: $0) }
        let configuration = NSWorkspace.OpenConfiguration()
        if urls.isEmpty {
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
        } else {
            NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration) { _, _ in }
        }
    }

}

