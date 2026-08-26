import Foundation

/// Config shared between the app and the Finder extension.
///
/// Deliberately a plain file rather than App Group defaults. macOS 15 guards
/// every container under `~/Library/Group Containers` with the “access data
/// from other apps” prompt unless the app-group entitlement is signed by a real
/// team, so a locally signed build asks on every read and every write. Both
/// processes can reach this path without a container: the app is not sandboxed,
/// and the extension holds a filesystem exception.
enum SharedConfig {
    /// Posted after a config write so the Finder extension can rebuild its menu
    /// snapshot ahead of time instead of polling while Finder waits.
    static let configChangedNotification = Notification.Name("com.macrightclick.configChanged")

    static let supportDirectory = realHomeDirectory
        .appendingPathComponent("Library/Application Support/MacRightClick", isDirectory: true)
    static let configURL = supportDirectory.appendingPathComponent("menuConfig.json")

    /// `NSHomeDirectory()` and `FileManager.urls(for:in:)` point at the sandbox
    /// container inside the extension, so they cannot name a path the app also
    /// sees. `getpwuid` is not redirected.
    static let realHomeDirectory: URL = {
        if let entry = getpwuid(getuid()), let home = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }()

    private static let lock = NSLock()
    private static var cachedData: Data?
    private static var cachedConfig: MenuConfig?

    static func configData() -> Data? {
        try? Data(contentsOf: configURL)
    }

    static func load() -> MenuConfig {
        let data = configData()
        lock.lock()
        defer { lock.unlock() }
        if data == cachedData, let cachedConfig {
            return cachedConfig
        }
        let config: MenuConfig
        if let data {
            do {
                config = try JSONDecoder().decode(MenuConfig.self, from: data).mergingNewPresets()
            } catch {
                config = .default
            }
        } else {
            config = .default
        }
        cachedData = data
        cachedConfig = config
        return config
    }

    static func save(_ config: MenuConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            try ensureSupportDirectory()
            try data.write(to: configURL, options: .atomic)
            lock.lock()
            cachedData = data
            cachedConfig = config
            lock.unlock()
            DistributedNotificationCenter.default().postNotificationName(
                configChangedNotification,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        } catch {
            NSLog("MacRightClick: failed to save config: \(error.localizedDescription)")
        }
    }

    static func ensureSupportDirectory() throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
    }
}
