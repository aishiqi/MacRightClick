import Foundation

enum DebugLog {
    static let logURL = URL(fileURLWithPath: "/tmp/macrightclick-debug.log")

    /// A marker file rather than a preference: the extension's own defaults live
    /// in its sandbox container, and shared defaults would mean an App Group,
    /// which macOS 15 prompts for on every access. See `SharedConfig`.
    static let disabledMarkerURL = SharedConfig.supportDirectory
        .appendingPathComponent("debug-logging-off")

    /// On until someone turns it off in Setup.
    static var isEnabled: Bool {
        get { !FileManager.default.fileExists(atPath: disabledMarkerURL.path) }
        set {
            if newValue {
                try? FileManager.default.removeItem(at: disabledMarkerURL)
            } else {
                try? SharedConfig.ensureSupportDirectory()
                FileManager.default.createFile(atPath: disabledMarkerURL.path, contents: nil)
            }
        }
    }

    private static let lock = NSLock()
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func mark(_ step: String) {
        guard isEnabled else { return }
        let time = formatter.string(from: Date())
        let thread = Thread.isMainThread ? "main" : Thread.current.name ?? "bg"
        let line = "\(time) [\(thread)] \(step)\n"
        lock.lock()
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            if let data = line.data(using: .utf8) {
                try? handle.write(contentsOf: data)
            }
        }
        lock.unlock()
        NSLog("MRC %@", step)
    }

    @discardableResult
    static func measure<T>(_ step: String, _ body: () -> T) -> T {
        guard isEnabled else { return body() }
        mark("BEGIN \(step)")
        let start = CFAbsoluteTimeGetCurrent()
        let result = body()
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000
        mark(String(format: "END   \(step)  %.2fms", ms))
        return result
    }

    static func clear() {
        lock.lock()
        try? FileManager.default.removeItem(at: logURL)
        lock.unlock()
        mark("log cleared")
    }
}
