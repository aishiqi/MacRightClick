import AppKit

enum TerminalLauncher {
    private static let terminalBundleID = "com.apple.Terminal"

    /// Opens Terminal at `path` without Apple Events, so macOS does not show
    /// the “wants to control Terminal” Automation dialog.
    static func open(at path: String) {
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        if let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) {
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
