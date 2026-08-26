import AppKit

enum TerminalLauncher {
    /// Opens Terminal at `path` without Apple Events, so macOS does not show
    /// the “wants to control Terminal” Automation dialog.
    /// A new window is used; a new tab requires AppleScript and that prompt.
    static func open(at path: String) {
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        if let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: configuration) { _, _ in }
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", path]
        try? process.run()
    }
}
