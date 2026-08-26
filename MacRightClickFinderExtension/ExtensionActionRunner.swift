import AppKit
import FinderSync

enum ExtensionActionRunner {
    /// Finder state captured while still on the click callback, so the action
    /// itself can run off that thread without the selection changing underneath.
    struct Context {
        var selected: [URL]?
        var targeted: URL?

        static func current() -> Context {
            let controller = FIFinderSyncController.default()
            return Context(selected: controller.selectedItemURLs(), targeted: controller.targetedURL())
        }
    }

    private static let queue = DispatchQueue(label: "com.macrightclick.actions", qos: .userInitiated)

    /// Returns immediately; Finder is still tracking the menu when this is called.
    static func performAsync(_ command: ActionCommand, in context: Context) {
        queue.async { perform(command, in: context) }
    }

    static func performTitleFallbackAsync(_ title: String, in context: Context) {
        queue.async { performTitleFallback(title, in: context) }
    }

    static func perform(_ command: ActionCommand, in context: Context) {
        let selected = context.selected
        let targeted = context.targeted
        let config = SharedConfig.load()

        switch command.kind {
        case .copyFilePath:
            copy(PathResolver.filePaths(selected: selected, targeted: targeted))

        case .copyDirPath:
            copy(PathResolver.dirPaths(selected: selected, targeted: targeted))

        case .newFile:
            guard let fileType = config.fileTypes.first(where: { $0.id == command.id }),
                  let directory = PathResolver.targetDirectory(selected: selected, targeted: targeted)
            else { return }
            createEmptyFile(named: fileType.fileName, in: directory)

        case .newFolder:
            guard let directory = PathResolver.targetDirectory(selected: selected, targeted: targeted) else { return }
            createFolder(in: directory)

        case .openApp:
            guard let app = config.apps.first(where: { $0.id == command.id }),
                  let appURL = AppLocator.url(for: app)
            else { return }
            let urls = PathResolver.selectedOrTargeted(selected: selected, targeted: targeted)
            open(urls: urls, with: appURL)

        case .openTerminal, .openTerminalTab:
            guard let directory = PathResolver.targetDirectory(selected: selected, targeted: targeted) else { return }
            TerminalLauncher.open(at: directory.path)
        }
    }

    static func performTitleFallback(_ title: String, in context: Context) {
        let config = SharedConfig.load()
        if title == ActionKind.newFolder.title {
            perform(ActionCommand(kind: .newFolder, id: nil, paths: []), in: context)
        } else if title == ActionKind.copyFilePath.title {
            perform(ActionCommand(kind: .copyFilePath, id: nil, paths: []), in: context)
        } else if title == ActionKind.copyDirPath.title {
            perform(ActionCommand(kind: .copyDirPath, id: nil, paths: []), in: context)
        } else if title == ActionKind.openTerminal.title {
            perform(ActionCommand(kind: .openTerminal, id: nil, paths: []), in: context)
        } else if title == ActionKind.openTerminalTab.title {
            perform(ActionCommand(kind: .openTerminalTab, id: nil, paths: []), in: context)
        } else if let fileType = config.fileTypes.first(where: { title == $0.name || title == "New \($0.name)" }) {
            perform(ActionCommand(kind: .newFile, id: fileType.id, paths: []), in: context)
        } else if let app = config.apps.first(where: { title == $0.name || title == "Open in \($0.name)" }) {
            perform(ActionCommand(kind: .openApp, id: app.id, paths: []), in: context)
        }
    }

    private static func copy(_ paths: [String]) {
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
    }

    private static func createEmptyFile(named fileName: String, in directory: URL) {
        let url = PathResolver.uniqueURL(in: directory, preferredName: fileName)
        do {
            try Data().write(to: url, options: .withoutOverwriting)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            createViaFinder(name: url.lastPathComponent, in: directory, isFolder: false)
        }
    }

    private static func createFolder(in directory: URL) {
        let url = PathResolver.uniqueURL(in: directory, preferredName: "untitled folder")
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            createViaFinder(name: url.lastPathComponent, in: directory, isFolder: true)
        }
    }

    private static func createViaFinder(name: String, in directory: URL, isFolder: Bool) {
        let kind = isFolder ? "folder" : "file"
        let script = """
        set posixPath to "\(escape(directory.path))"
        set itemName to "\(escape(name))"
        tell application "Finder"
            set theFolder to (POSIX file posixPath) as alias
            make new \(kind) at theFolder with properties {name:itemName}
            select (item itemName of theFolder)
            activate
        end tell
        """
        runAppleScript(script)
    }

    private static func open(urls: [URL], with appURL: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        if urls.isEmpty {
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration, completionHandler: nil)
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func runAppleScript(_ source: String) {
        // NSAppleScript is not thread-safe, and this script drives Finder itself.
        DispatchQueue.main.async {
            var error: NSDictionary?
            if let script = NSAppleScript(source: source) {
                script.executeAndReturnError(&error)
                if let error {
                    NSLog("MacRightClick extension AppleScript error: \(error)")
                }
            }
        }
    }
}
