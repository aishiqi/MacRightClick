import AppKit
import CoreServices
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }
        Divider()
        Button("Quit MacRightClick") {
            NSApp.terminate(nil)
        }
    }
}

@main
struct MacRightClickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ConfigStore()

    var body: some Scene {
        Window("MacRightClick", id: "settings") {
            SettingsView()
                .environmentObject(store)
                .frame(minWidth: 740, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 780, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("MacRightClick", systemImage: "menucard") {
            MenuBarContent()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var launchedWithURL = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleDistributedAction(_:)),
            name: ActionCommand.notificationName,
            object: nil
        )
        DispatchQueue.main.async {
            if !self.launchedWithURL {
                self.showSettings()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        launchedWithURL = true
        urls.forEach { ActionRunner.run($0) }
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        launchedWithURL = true
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string)
        else { return }
        ActionRunner.run(url)
    }

    @objc private func handleDistributedAction(_ notification: Notification) {
        launchedWithURL = true
        if let string = notification.object as? String {
            if let url = URL(string: string), url.scheme == ActionCommand.scheme {
                ActionRunner.run(url)
            } else if let command = ActionCommand.from(token: string) {
                ActionRunner.run(command)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.title == "MacRightClick" || window.identifier?.rawValue.contains("settings") == true {
            window.makeKeyAndOrderFront(nil)
            return
        }
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}
