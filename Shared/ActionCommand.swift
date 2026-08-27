import Foundation

struct ActionCommand: Equatable {
    enum Kind: String {
        case newFile
        case newFolder
        case copyFilePath
        case copyDirPath
        case openTerminal
        case openApp
        case runScript
    }

    var kind: Kind
    var id: String?
    var paths: [String]

    static let scheme = "macrightclick"
    static let notificationName = Notification.Name("com.macrightclick.action")

    func url() -> URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "action"
        var items = [URLQueryItem(name: "kind", value: kind.rawValue)]
        if let id {
            items.append(URLQueryItem(name: "id", value: id))
        }
        for path in paths {
            items.append(URLQueryItem(name: "path", value: path))
        }
        components.queryItems = items
        return components.url
    }

    static func from(url: URL) -> ActionCommand? {
        guard url.scheme == scheme else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []
        func first(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }
        guard let kindRaw = first("kind"), let kind = Kind(rawValue: kindRaw) else { return nil }
        let id = first("id")
        let paths = items.filter { $0.name == "path" }.compactMap(\.value)
        return ActionCommand(kind: kind, id: id, paths: paths)
    }

    /// Compact token stored on `NSMenuItem.representedObject`.
    func token() -> String {
        let idPart = id ?? ""
        return "\(kind.rawValue)|\(idPart)"
    }

    static func from(token: String) -> ActionCommand? {
        let parts = token.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let kind = Kind(rawValue: String(parts[0])) else { return nil }
        let idPart = String(parts[1])
        return ActionCommand(kind: kind, id: idPart.isEmpty ? nil : idPart, paths: [])
    }
}
