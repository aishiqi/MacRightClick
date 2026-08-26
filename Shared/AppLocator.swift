import AppKit

enum AppLocator {
    private static let lock = NSLock()
    private static var cache: [String: URL] = [:]
    private static var negative: Set<String> = []

    static func url(for item: AppItem) -> URL? {
        lock.lock()
        if let cached = cache[item.id] {
            lock.unlock()
            return cached
        }
        if negative.contains(item.id) {
            lock.unlock()
            return nil
        }
        lock.unlock()

        DebugLog.mark("AppLocator.resolve miss id=\(item.id) name=\(item.name)")
        let resolved = DebugLog.measure("AppLocator.resolve \(item.name)") {
            resolve(item)
        }

        lock.lock()
        if let resolved {
            cache[item.id] = resolved
            negative.remove(item.id)
        } else {
            negative.insert(item.id)
        }
        lock.unlock()
        return resolved
    }

    static func isInstalled(_ item: AppItem) -> Bool {
        url(for: item) != nil
    }

    static func prefetch(_ items: [AppItem]) {
        for item in items where item.enabled {
            _ = url(for: item)
        }
    }

    static func invalidate() {
        lock.lock()
        cache.removeAll()
        negative.removeAll()
        lock.unlock()
    }

    /// Launch Services only. Reading another `.app` (exists checks, Info.plist,
    /// icons) is what shows “想访问其他App的数据” on macOS 15+.
    private static func resolve(_ item: AppItem) -> URL? {
        for bundleID in item.bundleIdentifiers {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                return url
            }
        }
        if let customPath = item.customPath {
            return URL(fileURLWithPath: customPath)
        }
        return nil
    }
}
