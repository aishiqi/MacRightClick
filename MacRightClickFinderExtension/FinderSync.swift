import Cocoa
import FinderSync

@objc(MRCFinderSync)
final class MRCFinderSync: FIFinderSync {
    private static let toolbarIcon = IconProvider.symbol("menucard", size: NSSize(width: 18, height: 18))

    private let directoryQueue = DispatchQueue(label: "com.macrightclick.directories", qos: .utility)

    override init() {
        super.init()
        DebugLog.mark("FinderSync.init start")
        MenuCache.shared.warmup()
        refreshMonitoredDirectories()
        DebugLog.mark("FinderSync.init end")

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshMonitoredDirectories()
        }
        workspace.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refreshMonitoredDirectories()
        }
    }

    /// `mountedVolumeURLs` can stall on network volumes, so it never runs on a
    /// thread Finder might be waiting on.
    private func refreshMonitoredDirectories() {
        directoryQueue.async {
            DebugLog.mark("refreshMonitoredDirectories start")
            var urls = Set<URL>()
            DebugLog.measure("mountedVolumeURLs") {
                if let volumes = FileManager.default.mountedVolumeURLs(
                    includingResourceValuesForKeys: nil,
                    options: [.skipHiddenVolumes]
                ) {
                    urls.formUnion(volumes)
                }
            }
            urls.insert(FileManager.default.homeDirectoryForCurrentUser)
            urls.insert(URL(fileURLWithPath: "/Applications"))
            for directory in [FileManager.SearchPathDirectory.desktopDirectory, .documentDirectory, .downloadsDirectory] {
                if let url = FileManager.default.urls(for: directory, in: .userDomainMask).first {
                    urls.insert(url)
                }
            }
            DebugLog.mark("refreshMonitoredDirectories volumes=\(urls.count)")
            DispatchQueue.main.async {
                DebugLog.measure("set directoryURLs") {
                    FIFinderSyncController.default().directoryURLs = urls
                }
            }
        }
    }

    override var toolbarItemName: String { "MacRightClick" }

    override var toolbarItemToolTip: String {
        "MacRightClick actions for the current Finder location"
    }

    override var toolbarItemImage: NSImage {
        Self.toolbarIcon
    }

    /// Finder asks for a badge on every item it displays in a monitored folder.
    /// This extension has no badges, so the override stays empty and cheap.
    override func requestBadgeIdentifier(for url: URL) {}

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        DebugLog.mark("menu(for:) kind=\(menuKind)")
        switch menuKind {
        case .contextualMenuForItems, .contextualMenuForContainer, .toolbarItemMenu:
            return DebugLog.measure("menu(for:) full build") {
                MenuBuilder.makeMenu()
            }
        default:
            return NSMenu()
        }
    }

    @objc func handleMenuItem(_ sender: NSMenuItem) {
        let title = sender.title
        let context = ExtensionActionRunner.Context.current()
        guard let token = MenuActionRegistry.token(for: title),
              let command = ActionCommand.from(token: token)
        else {
            ExtensionActionRunner.performTitleFallbackAsync(title, in: context)
            return
        }
        ExtensionActionRunner.performAsync(command, in: context)
    }
}
