import Foundation

enum PathResolver {
    static func selectedOrTargeted(selected: [URL]?, targeted: URL?) -> [URL] {
        if let selected, !selected.isEmpty {
            return selected
        }
        if let targeted {
            return [targeted]
        }
        return desktopDirectory.map { [$0] } ?? []
    }

    static var desktopDirectory: URL? {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

    /// Folder to create files/folders in, or to `cd` into.
    static func targetDirectory(selected: [URL]?, targeted: URL?) -> URL? {
        let urls = selectedOrTargeted(selected: selected, targeted: targeted)
        guard let first = urls.first else { return targeted ?? desktopDirectory }
        return isDirectory(first) ? first : first.deletingLastPathComponent()
    }

    static func filePaths(selected: [URL]?, targeted: URL?) -> [String] {
        selectedOrTargeted(selected: selected, targeted: targeted).map(\.path)
    }

    static func dirPaths(selected: [URL]?, targeted: URL?) -> [String] {
        selectedOrTargeted(selected: selected, targeted: targeted).map { folderPath(for: $0.path) }
    }

    /// Containing folder of a file, or the path itself when it is a folder.
    static func folderPath(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return isDirectory(url) ? url.path : url.deletingLastPathComponent().path
    }

    static func uniqueURL(in directory: URL, preferredName: String) -> URL {
        let fm = FileManager.default
        let candidate = directory.appendingPathComponent(preferredName)
        if !fm.fileExists(atPath: candidate.path) {
            return candidate
        }

        let (base, ext) = splitName(preferredName)
        var index = 2
        while true {
            let nextName: String
            if ext.isEmpty {
                nextName = "\(base) \(index)"
            } else if preferredName.hasPrefix(".") && base.isEmpty == false && !base.dropFirst().contains(".") {
                nextName = "\(preferredName) \(index)"
            } else {
                nextName = "\(base) \(index).\(ext)"
            }
            let url = directory.appendingPathComponent(nextName)
            if !fm.fileExists(atPath: url.path) {
                return url
            }
            index += 1
        }
    }

    private static func splitName(_ preferredName: String) -> (String, String) {
        if preferredName.hasPrefix(".") {
            let rest = String(preferredName.dropFirst())
            if !rest.contains(".") {
                return (preferredName, "")
            }
        }
        let ns = preferredName as NSString
        let ext = ns.pathExtension
        let base = ext.isEmpty ? preferredName : ns.deletingPathExtension
        return (base, ext)
    }
}
