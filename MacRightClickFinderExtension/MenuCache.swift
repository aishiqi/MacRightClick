import AppKit

/// Precomputed Finder menu.
///
/// Finder blocks the entire context menu until `menu()` returns, so that path
/// must never touch `UserDefaults`, disk, or Launch Services. All of that work
/// happens on `queue`; `menu()` only assembles `NSMenuItem`s from the snapshot.
final class MenuCache {
    static let shared = MenuCache()

    private struct Item {
        var title: String
        var image: NSImage?
        var token: String
    }

    private struct Snapshot {
        var fileSubmenu: [Item]
        var fileMain: [Item]
        var actionMain: [Item]
        var actionSub: [Item]
        var appMain: [Item]
        var appSub: [Item]
        var scriptMain: [Item]
        var scriptSub: [Item]
        var newFileIcon: NSImage
        var actionsIcon: NSImage
        var scriptsIcon: NSImage
        var openInIcon: NSImage
    }

    /// Longest Finder waits for the very first snapshot. Warmup starts when the
    /// extension loads, so this only matters if the user right-clicks instantly.
    private static let firstBuildTimeout: TimeInterval = 0.25

    /// Floor on how often a menu request may trigger a background staleness
    /// check, so repeated right-clicks do not queue repeated defaults reads.
    private static let refreshInterval: TimeInterval = 2

    private let condition = NSCondition()
    private var snapshot: Snapshot?
    private var lastConfigData: Data?
    private var lastRefreshCheck: TimeInterval = 0

    private let queue = DispatchQueue(label: "com.macrightclick.menucache", qos: .userInitiated)
    private var configObserver: NSObjectProtocol?

    private init() {
        configObserver = DistributedNotificationCenter.default().addObserver(
            forName: SharedConfig.configChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildAsync(force: true)
        }
    }

    func warmup() {
        DebugLog.mark("MenuCache.warmup")
        rebuildAsync(force: true)
    }

    func menu() -> NSMenu {
        return DebugLog.measure("MenuCache.menu") {
            refreshInBackgroundIfDue()
            guard let snap = waitForFirstSnapshot() else {
                DebugLog.mark("MenuCache.menu no snapshot yet")
                return NSMenu(title: "")
            }
            return assemble(snap)
        }
    }

    // MARK: - Snapshot lifecycle

    private func rebuildAsync(force: Bool) {
        queue.async { [weak self] in
            self?.rebuild(force: force)
        }
    }

    /// Nudges a background rebuild when the snapshot is missing or the staleness
    /// check is due. Never blocks on the rebuild itself.
    private func refreshInBackgroundIfDue() {
        let now = ProcessInfo.processInfo.systemUptime
        condition.lock()
        let due = snapshot == nil || now - lastRefreshCheck >= Self.refreshInterval
        if due { lastRefreshCheck = now }
        condition.unlock()
        guard due else { return }
        rebuildAsync(force: false)
    }

    private func waitForFirstSnapshot() -> Snapshot? {
        DebugLog.measure("waitForFirstSnapshot") {
            condition.lock()
            defer { condition.unlock() }
            let deadline = Date().addingTimeInterval(Self.firstBuildTimeout)
            while snapshot == nil, condition.wait(until: deadline) {}
            if snapshot == nil {
                DebugLog.mark("waitForFirstSnapshot timed out")
            }
            return snapshot
        }
    }

    private func rebuild(force: Bool) {
        DebugLog.measure("MenuCache.rebuild force=\(force)") {
            let data = DebugLog.measure("SharedConfig.configData") {
                SharedConfig.configData()
            }
            condition.lock()
            let unchanged = !force && snapshot != nil && data == lastConfigData
            condition.unlock()
            if unchanged {
                DebugLog.mark("MenuCache.rebuild skipped (unchanged)")
                return
            }

            if force {
                AppLocator.invalidate()
            }
            let config = DebugLog.measure("SharedConfig.load") {
                SharedConfig.load()
            }
            DebugLog.measure("AppLocator.prefetch apps=\(config.apps.count)") {
                AppLocator.prefetch(config.apps)
            }
            let next = makeSnapshot(config)

            condition.lock()
            lastConfigData = data
            snapshot = next
            condition.broadcast()
            condition.unlock()
        }
    }

    private func makeSnapshot(_ config: MenuConfig) -> Snapshot {
        DebugLog.measure("MenuCache.makeSnapshot") {
        let fileEnabled = config.fileTypes.filter(\.enabled)
        let actionEnabled = config.actions.filter(\.enabled)
        let scriptEnabled = config.scripts.filter(\.enabled)
        let appEnabled = DebugLog.measure("filter installed apps") {
            config.apps.filter { $0.enabled && AppLocator.isInstalled($0) }
        }

        return Snapshot(
            fileSubmenu: fileEnabled.filter { $0.placement == .submenu }.map { item in
                Item(
                    title: item.name,
                    image: IconProvider.fileIcon(fileName: item.fileName),
                    token: ActionCommand(kind: .newFile, id: item.id, paths: []).token()
                )
            },
            fileMain: fileEnabled.filter { $0.placement == .mainMenu }.map { item in
                Item(
                    title: "New \(item.name)",
                    image: IconProvider.fileIcon(fileName: item.fileName),
                    token: ActionCommand(kind: .newFile, id: item.id, paths: []).token()
                )
            },
            actionMain: actionEnabled.filter { $0.placement == .mainMenu }.map(actionItem),
            actionSub: actionEnabled.filter { $0.placement == .submenu }.map(actionItem),
            appMain: appEnabled.filter { $0.placement == .mainMenu }.map { item in
                Item(
                    title: "Open in \(item.name)",
                    image: IconProvider.appIcon(for: item),
                    token: ActionCommand(kind: .openApp, id: item.id, paths: []).token()
                )
            },
            appSub: appEnabled.filter { $0.placement == .submenu }.map { item in
                Item(
                    title: item.name,
                    image: IconProvider.appIcon(for: item),
                    token: ActionCommand(kind: .openApp, id: item.id, paths: []).token()
                )
            },
            scriptMain: scriptEnabled.filter { $0.placement == .mainMenu }.map { item in
                Item(
                    title: item.name,
                    image: IconProvider.scriptIcon(),
                    token: ActionCommand(kind: .runScript, id: item.id, paths: []).token()
                )
            },
            scriptSub: scriptEnabled.filter { $0.placement == .submenu }.map { item in
                Item(
                    title: item.name,
                    image: IconProvider.scriptIcon(),
                    token: ActionCommand(kind: .runScript, id: item.id, paths: []).token()
                )
            },
            newFileIcon: IconProvider.symbol("doc.badge.plus", size: IconProvider.menuSize),
            actionsIcon: IconProvider.symbol("bolt", size: IconProvider.menuSize),
            scriptsIcon: IconProvider.symbol("terminal", size: IconProvider.menuSize),
            openInIcon: IconProvider.symbol("arrow.up.forward.app", size: IconProvider.menuSize)
        )
        }
    }

    private func actionItem(_ item: ActionItem) -> Item {
        let kind: ActionCommand.Kind
        switch item.kind {
        case .newFolder: kind = .newFolder
        case .copyFilePath: kind = .copyFilePath
        case .copyDirPath: kind = .copyDirPath
        case .openTerminal: kind = .openTerminal
        case .openTerminalTab: kind = .openTerminalTab
        }
        return Item(
            title: item.kind.title,
            image: IconProvider.actionIcon(kind: item.kind),
            token: ActionCommand(kind: kind, id: item.id, paths: []).token()
        )
    }

    // MARK: - Assembly

    private func assemble(_ snap: Snapshot) -> NSMenu {
        DebugLog.measure("MenuCache.assemble") {
        var tokens: [String: String] = [:]
        let menu = NSMenu(title: "")

        if !snap.actionMain.isEmpty || !snap.actionSub.isEmpty {
            for item in snap.actionMain {
                menu.addItem(menuItem(item, tokens: &tokens))
            }
            if !snap.actionSub.isEmpty {
                let submenu = NSMenu(title: "Actions")
                for item in snap.actionSub {
                    submenu.addItem(menuItem(item, tokens: &tokens))
                }
                let parent = NSMenuItem(title: "Actions", action: nil, keyEquivalent: "")
                parent.image = snap.actionsIcon
                parent.submenu = submenu
                menu.addItem(parent)
            }
        }

        if !snap.fileSubmenu.isEmpty || !snap.fileMain.isEmpty {
            if !snap.fileSubmenu.isEmpty {
                let submenu = NSMenu(title: "New File")
                for item in snap.fileSubmenu {
                    submenu.addItem(menuItem(item, tokens: &tokens))
                }
                let parent = NSMenuItem(title: "New File", action: nil, keyEquivalent: "")
                parent.image = snap.newFileIcon
                parent.submenu = submenu
                menu.addItem(parent)
            }
            for item in snap.fileMain {
                menu.addItem(menuItem(item, tokens: &tokens))
            }
        }

        if !snap.appMain.isEmpty || !snap.appSub.isEmpty {
            for item in snap.appMain {
                menu.addItem(menuItem(item, tokens: &tokens))
            }
            if !snap.appSub.isEmpty {
                let submenu = NSMenu(title: "Open In")
                for item in snap.appSub {
                    submenu.addItem(menuItem(item, tokens: &tokens))
                }
                let parent = NSMenuItem(title: "Open In", action: nil, keyEquivalent: "")
                parent.image = snap.openInIcon
                parent.submenu = submenu
                menu.addItem(parent)
            }
        }

        if !snap.scriptMain.isEmpty || !snap.scriptSub.isEmpty {
            for item in snap.scriptMain {
                menu.addItem(menuItem(item, tokens: &tokens))
            }
            if !snap.scriptSub.isEmpty {
                let submenu = NSMenu(title: "Scripts")
                for item in snap.scriptSub {
                    submenu.addItem(menuItem(item, tokens: &tokens))
                }
                let parent = NSMenuItem(title: "Scripts", action: nil, keyEquivalent: "")
                parent.image = snap.scriptsIcon
                parent.submenu = submenu
                menu.addItem(parent)
            }
        }

        MenuActionRegistry.merge(tokens)
        DebugLog.mark("MenuCache.assemble items=\(menu.items.count)")
        return menu
        }
    }

    private func menuItem(_ item: Item, tokens: inout [String: String]) -> NSMenuItem {
        // Do not set `target`. Finder displays this menu in another process;
        // a pointer target is invalid and clicks silently do nothing.
        let menuItem = NSMenuItem(title: item.title, action: #selector(MRCFinderSync.handleMenuItem(_:)), keyEquivalent: "")
        menuItem.image = item.image
        tokens[item.title] = item.token
        return menuItem
    }
}

enum MenuActionRegistry {
    private static let lock = NSLock()
    private static var titleToToken: [String: String] = [:]

    /// Merged rather than replaced: the context menu and the toolbar menu can be
    /// alive at the same time, and clearing would strip the other one's actions.
    static func merge(_ tokens: [String: String]) {
        lock.lock()
        titleToToken.merge(tokens) { _, new in new }
        lock.unlock()
    }

    static func token(for title: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return titleToToken[title]
    }
}
