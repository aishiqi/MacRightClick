import SwiftUI

enum SettingsTab: Hashable {
    case newFile
    case openApps
    case actions
    case setup
}

@MainActor
final class ConfigStore: ObservableObject {
    @Published var config: MenuConfig {
        didSet { SharedConfig.save(config) }
    }
    @Published var selectedTab: SettingsTab

    init() {
        config = SharedConfig.load()
        let seenFirstLaunch = UserDefaults.standard.bool(forKey: "didShowFirstLaunch")
        selectedTab = seenFirstLaunch ? .newFile : .setup
        if !seenFirstLaunch {
            UserDefaults.standard.set(true, forKey: "didShowFirstLaunch")
        }
    }

    func addFileType(name: String, fileName: String) {
        config.fileTypes.append(.custom(name: name, fileName: fileName))
    }

    func removeFileType(id: String) {
        config.fileTypes.removeAll { $0.id == id && !$0.isPreset }
    }

    func addApp(name: String, bundleIdentifier: String?, path: String) {
        config.apps.append(.custom(name: name, bundleIdentifier: bundleIdentifier, path: path))
    }

    func removeApp(id: String) {
        config.apps.removeAll { $0.id == id && !$0.isPreset }
    }

    func resetToDefaults() {
        config = .default
    }
}
