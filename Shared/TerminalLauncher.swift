import AppKit

enum TerminalLauncher {
    private static let terminalBundleID = "com.apple.Terminal"

    /// Opens Terminal at `path` without Apple Events, so macOS does not show
    /// the “wants to control Terminal” Automation dialog.
    /// A new window is used; a new tab requires AppleScript and that prompt.
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

    /// Opens a **new** Terminal window and types `command` into its shell, so
    /// nothing is written to disk. The window stays at the prompt afterward.
    /// Terminal's `do script` is an Apple Event, so the first use asks for
    /// Automation permission.
    static func run(_ command: String) {
        if isTerminalRunning {
            runAppleScript(source(for: command, reusingWindow: false))
            return
        }
        // Launching through Launch Services rather than an Apple Event means the
        // window Terminal opens on its own can be reused, so a cold start does
        // not leave an empty window behind.
        launchTerminal()
        DispatchQueue.global(qos: .userInitiated).async {
            runAppleScript(source(for: command, reusingWindow: waitForTerminal()))
        }
    }

    private static var isTerminalRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: terminalBundleID).isEmpty
    }

    private static func launchTerminal() {
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: terminal, configuration: configuration, completionHandler: nil)
    }

    /// True once Terminal is up and its startup window can be reused.
    private static func waitForTerminal() -> Bool {
        for _ in 0..<30 {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: terminalBundleID).first,
               app.isFinishedLaunching {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    private static func source(for command: String, reusingWindow: Bool) -> String {
        let target = reusingWindow
            ? """
                  if (count of windows) > 0 then
                      do script theCommand in front window
                  else
                      do script theCommand
                  end if
              """
            : "    do script theCommand"
        return """
        set theCommand to "\(appleScriptEscape(command))"
        tell application "Terminal"
            activate
        \(target)
        end tell
        """
    }

    /// The Apple Event has to come from this process: sending it through a
    /// helper such as `osascript` makes TCC attribute it to the helper, which it
    /// denies outright (-1743) instead of asking the user.
    private static func runAppleScript(_ source: String) {
        // NSAppleScript is main-thread only.
        DispatchQueue.main.async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                NSLog("MacRightClick: Terminal command failed: \(error)")
            }
        }
    }

    static func appleScriptEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
