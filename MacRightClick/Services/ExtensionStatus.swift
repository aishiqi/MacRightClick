import Foundation
import FinderSync

enum ExtensionStatus {
    static let extensionBundleID = "com.macrightclick.app.FinderExtension"
    static let applicationsURL = URL(fileURLWithPath: "/Applications/MacRightClick.app")

    enum RegistrationState: Equatable {
        case notRegistered
        case registeredDisabled
        case enabled
    }

    static func state() -> RegistrationState {
        let output = runPluginKit(["-mAvvv", "-p", "com.apple.FinderSync"])
        let blocks = output.components(separatedBy: "\n\n")
        for block in blocks where block.contains(extensionBundleID) || block.contains("MacRightClickFinderExtension") {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("+") { return .enabled }
            if trimmed.hasPrefix("-") { return .registeredDisabled }
            return .registeredDisabled
        }

        let short = runPluginKit(["-m", "-i", extensionBundleID]).trimmingCharacters(in: .whitespacesAndNewlines)
        if short.hasPrefix("+") { return .enabled }
        if !short.isEmpty { return .registeredDisabled }
        return .notRegistered
    }

    static func isEnabled() -> Bool {
        state() == .enabled
    }

    static func appexURL(from appURL: URL = Bundle.main.bundleURL) -> URL {
        appURL
            .appendingPathComponent("Contents/PlugIns/MacRightClickFinderExtension.appex", isDirectory: true)
    }

    @discardableResult
    static func installToApplications() throws -> URL {
        let runningApp = Bundle.main.bundleURL
        guard runningApp.pathExtension == "app" else {
            throw NSError(domain: "MacRightClick", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Launch MacRightClick.app, then install from Setup."
            ])
        }

        let fm = FileManager.default
        if runningApp.standardizedFileURL == applicationsURL.standardizedFileURL {
            return applicationsURL
        }

        if fm.fileExists(atPath: applicationsURL.path) {
            try fm.removeItem(at: applicationsURL)
        }
        try fm.copyItem(at: runningApp, to: applicationsURL)
        registerWithLaunchServices(applicationsURL)
        return applicationsURL
    }

    @discardableResult
    static func registerExtension(in appURL: URL = Bundle.main.bundleURL) -> String {
        let appex = appexURL(from: appURL)
        var log = runPluginKit(["-a", appex.path])
        log += runPluginKit(["-e", "use", "-i", extensionBundleID])
        return log
    }

    static func enableViaPluginKit() {
        _ = registerExtension()
        if FileManager.default.fileExists(atPath: applicationsURL.path) {
            _ = registerExtension(in: applicationsURL)
        }
    }

    static func installRegisterAndEnable() throws {
        let installed = try installToApplications()
        _ = registerExtension(in: installed)
        if state() != .enabled {
            showSystemManagementInterface()
        }
    }

    @discardableResult
    static func disableExtension() -> String {
        let log = runPluginKit(["-e", "ignore", "-i", extensionBundleID])
        terminateExtension()
        return log
    }

    static func showSystemManagementInterface() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private static func terminateExtension() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["MacRightClickFinderExtension"]
        try? process.run()
        process.waitUntilExit()
    }

    private static func registerWithLaunchServices(_ appURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
        process.arguments = ["-f", appURL.path]
        try? process.run()
        process.waitUntilExit()
    }

    @discardableResult
    static func runPluginKit(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
