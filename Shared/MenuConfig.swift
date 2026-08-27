import Foundation

enum Placement: String, Codable, CaseIterable, Identifiable {
    case mainMenu
    case submenu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainMenu: return "Main menu"
        case .submenu: return "Submenu"
        }
    }
}

struct FileTypeItem: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var fileName: String
    var enabled: Bool
    var placement: Placement
    var isPreset: Bool

    static let presets: [FileTypeItem] = [
        .preset("file.txt", name: "Text", fileName: "untitled.txt"),
        .preset("file.md", name: "Markdown", fileName: "untitled.md"),
        .preset("file.swift", name: "Swift", fileName: "untitled.swift"),
        .preset("file.py", name: "Python", fileName: "untitled.py"),
        .preset("file.js", name: "JavaScript", fileName: "untitled.js"),
        .preset("file.ts", name: "TypeScript", fileName: "untitled.ts"),
        .preset("file.tsx", name: "TSX", fileName: "untitled.tsx"),
        .preset("file.json", name: "JSON", fileName: "untitled.json"),
        .preset("file.yml", name: "YAML", fileName: "untitled.yml"),
        .preset("file.sh", name: "Shell", fileName: "untitled.sh"),
        .preset("file.html", name: "HTML", fileName: "untitled.html"),
        .preset("file.css", name: "CSS", fileName: "untitled.css"),
        .preset("file.go", name: "Go", fileName: "untitled.go"),
        .preset("file.rs", name: "Rust", fileName: "untitled.rs"),
        .preset("file.java", name: "Java", fileName: "untitled.java"),
        .preset("file.kt", name: "Kotlin", fileName: "untitled.kt"),
        .preset("file.cpp", name: "C++", fileName: "untitled.cpp"),
        .preset("file.h", name: "Header", fileName: "untitled.h"),
        .preset("file.sql", name: "SQL", fileName: "untitled.sql"),
        .preset("file.gitignore", name: "Gitignore", fileName: ".gitignore"),
        .preset("file.env", name: "Env", fileName: ".env"),
        .preset("file.dockerfile", name: "Dockerfile", fileName: "Dockerfile")
    ]

    private static func preset(_ id: String, name: String, fileName: String) -> FileTypeItem {
        FileTypeItem(id: id, name: name, fileName: fileName, enabled: true, placement: .submenu, isPreset: true)
    }

    static func custom(name: String, fileName: String) -> FileTypeItem {
        FileTypeItem(
            id: "custom.file.\(UUID().uuidString)",
            name: name,
            fileName: fileName,
            enabled: true,
            placement: .submenu,
            isPreset: false
        )
    }

    var subtitle: String { fileName }
}

struct AppItem: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var bundleIdentifiers: [String]
    var searchNames: [String]
    var customPath: String?
    var enabled: Bool
    var placement: Placement
    var isPreset: Bool

    static let presets: [AppItem] = [
        .preset("app.vscode", name: "Visual Studio Code", ids: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"], names: ["Visual Studio Code", "Visual Studio Code - Insiders"]),
        .preset("app.cursor", name: "Cursor", ids: ["com.todesktop.230313mzl4w4u92"], names: ["Cursor"]),
        .preset("app.xcode", name: "Xcode", ids: ["com.apple.dt.Xcode"], names: ["Xcode"]),
        .preset("app.intellij", name: "IntelliJ IDEA", ids: ["com.jetbrains.intellij", "com.jetbrains.intellij.ce"], names: ["IntelliJ IDEA", "IntelliJ IDEA CE", "IntelliJ IDEA Ultimate", "IntelliJ IDEA Community Edition"]),
        .preset("app.pycharm", name: "PyCharm", ids: ["com.jetbrains.pycharm", "com.jetbrains.pycharm.ce"], names: ["PyCharm", "PyCharm CE", "PyCharm Professional", "PyCharm Community Edition"]),
        .preset("app.webstorm", name: "WebStorm", ids: ["com.jetbrains.WebStorm"], names: ["WebStorm"]),
        .preset("app.goland", name: "GoLand", ids: ["com.jetbrains.goland"], names: ["GoLand"]),
        .preset("app.androidstudio", name: "Android Studio", ids: ["com.google.android.studio"], names: ["Android Studio"]),
        .preset("app.sublime", name: "Sublime Text", ids: ["com.sublimetext.4", "com.sublimetext.3"], names: ["Sublime Text"]),
        .preset("app.zed", name: "Zed", ids: ["dev.zed.Zed"], names: ["Zed"]),
        .preset("app.nova", name: "Nova", ids: ["com.panic.Nova"], names: ["Nova"]),
        .preset("app.textedit", name: "TextEdit", ids: ["com.apple.TextEdit"], names: ["TextEdit"]),
        .preset("app.iterm", name: "iTerm", ids: ["com.googlecode.iterm2"], names: ["iTerm", "iTerm2"]),
        .preset("app.warp", name: "Warp", ids: ["dev.warp.Warp-Stable"], names: ["Warp"])
    ]

    private static func preset(_ id: String, name: String, ids: [String], names: [String]) -> AppItem {
        AppItem(
            id: id,
            name: name,
            bundleIdentifiers: ids,
            searchNames: names,
            customPath: nil,
            enabled: true,
            placement: .submenu,
            isPreset: true
        )
    }

    static func custom(name: String, bundleIdentifier: String?, path: String) -> AppItem {
        AppItem(
            id: "custom.app.\(UUID().uuidString)",
            name: name,
            bundleIdentifiers: bundleIdentifier.map { [$0] } ?? [],
            searchNames: [name],
            customPath: path,
            enabled: true,
            placement: .submenu,
            isPreset: false
        )
    }
}

enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case newFolder
    case copyFilePath
    case copyDirPath
    case openTerminal
    case openTerminalTab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newFolder: return "New Folder"
        case .copyFilePath: return "Copy File Path"
        case .copyDirPath: return "Copy Dir Path"
        case .openTerminal: return "Open Terminal"
        case .openTerminalTab: return "Open Terminal (Tab)"
        }
    }

    var symbolName: String {
        switch self {
        case .newFolder: return "folder.badge.plus"
        case .copyFilePath: return "doc.on.clipboard"
        case .copyDirPath: return "folder"
        case .openTerminal: return "terminal"
        case .openTerminalTab: return "rectangle.split.1x2"
        }
    }
}

struct ActionItem: Identifiable, Codable, Equatable {
    var id: String
    var kind: ActionKind
    var enabled: Bool
    var placement: Placement

    static let presets: [ActionItem] = ActionKind.allCases.map { kind in
        ActionItem(
            id: "action.\(kind.rawValue)",
            kind: kind,
            enabled: true,
            placement: .mainMenu
        )
    }
}

struct ScriptItem: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var source: String
    var enabled: Bool
    var placement: Placement
    var runInTerminal: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, source, enabled, placement, runInTerminal
    }

    init(
        id: String,
        name: String,
        source: String,
        enabled: Bool,
        placement: Placement,
        runInTerminal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.enabled = enabled
        self.placement = placement
        self.runInTerminal = runInTerminal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decode(String.self, forKey: .source)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        placement = try container.decode(Placement.self, forKey: .placement)
        runInTerminal = try container.decodeIfPresent(Bool.self, forKey: .runInTerminal) ?? false
    }

    static let defaultSource = """
        # Finder folder is the working directory.
        # $FOLDER  containing folder of a file, or the folder itself
        # $FILE    first selected path
        # Also: $FILENAME $BASENAME $EXT $FOLDERNAME $PARENT $FILES $FOLDERS
        echo "Folder: $FOLDER"
        echo "File: $FILE"
        printf '%s\\n' "$@"
        """

    static func custom(name: String, source: String) -> ScriptItem {
        ScriptItem(
            id: "custom.script.\(UUID().uuidString)",
            name: name,
            source: source,
            enabled: true,
            placement: .submenu,
            runInTerminal: false
        )
    }
}

struct MenuConfig: Codable, Equatable {
    var fileTypes: [FileTypeItem]
    var apps: [AppItem]
    var actions: [ActionItem]
    var scripts: [ScriptItem]

    enum CodingKeys: String, CodingKey {
        case fileTypes, apps, actions, scripts
    }

    init(fileTypes: [FileTypeItem], apps: [AppItem], actions: [ActionItem], scripts: [ScriptItem] = []) {
        self.fileTypes = fileTypes
        self.apps = apps
        self.actions = actions
        self.scripts = scripts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileTypes = try container.decode([FileTypeItem].self, forKey: .fileTypes)
        apps = try container.decode([AppItem].self, forKey: .apps)
        actions = try container.decode([ActionItem].self, forKey: .actions)
        scripts = try container.decodeIfPresent([ScriptItem].self, forKey: .scripts) ?? []
    }

    static let `default` = MenuConfig(
        fileTypes: FileTypeItem.presets,
        apps: AppItem.presets,
        actions: ActionItem.presets,
        scripts: []
    )

    /// Adds any presets that were introduced after the saved config was written.
    func mergingNewPresets() -> MenuConfig {
        var merged = self

        let existingFileIDs = Set(fileTypes.map(\.id))
        merged.fileTypes.append(contentsOf: FileTypeItem.presets.filter { !existingFileIDs.contains($0.id) })

        let existingAppIDs = Set(apps.map(\.id))
        merged.apps.append(contentsOf: AppItem.presets.filter { !existingAppIDs.contains($0.id) })

        let existingActionIDs = Set(actions.map(\.id))
        merged.actions.append(contentsOf: ActionItem.presets.filter { !existingActionIDs.contains($0.id) })

        return merged
    }
}
