import SwiftUI

enum SettingsTab: Hashable {
    case newFile
    case openApps
    case actions
    case scripts
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
        selectedTab = ExtensionStatus.isEnabled() ? .newFile : .setup
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

    func addScript(name: String, source: String) {
        config.scripts.append(.custom(name: name, source: source))
    }

    func updateScript(id: String, name: String, source: String) {
        guard let index = config.scripts.firstIndex(where: { $0.id == id }) else { return }
        config.scripts[index].name = name
        config.scripts[index].source = source
    }

    func removeScript(id: String) {
        config.scripts.removeAll { $0.id == id }
    }
}
