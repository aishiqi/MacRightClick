import AppKit
import UniformTypeIdentifiers

enum IconProvider {
    /// Finder menu display size (points). Keep this at 16 so rows stay standard height.
    static let menuSize = NSSize(width: 16, height: 16)
    /// Single bitmap sent over Finder XPC. 64px is sharp at 16pt without the old multi-rep stall.
    static let menuRasterPixels = 64
    static let rowSize = NSSize(width: 24, height: 24)

    private static let cache = NSCache<NSString, NSImage>()

    static func fileIcon(fileName: String, size: NSSize = menuSize) -> NSImage {
        let key = "file:\(fileName):\(Int(size.width)):\(menuRasterPixels)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        DebugLog.mark("IconProvider.fileIcon miss \(fileName)")

        let ext: String
        if fileName.hasPrefix("."), !fileName.dropFirst().contains(".") {
            ext = String(fileName.dropFirst())
        } else {
            ext = (fileName as NSString).pathExtension
        }

        let image: NSImage
        if let type = UTType(filenameExtension: ext), !ext.isEmpty {
            image = NSWorkspace.shared.icon(for: type)
        } else {
            image = NSWorkspace.shared.icon(for: .data)
        }
        let result = prepared(image, size: size, template: false)
        cache.setObject(result, forKey: key)
        return result
    }

    static func appIcon(for item: AppItem, size: NSSize = menuSize) -> NSImage {
        let key = "app:\(item.id):\(item.customPath ?? ""):\(Int(size.width)):\(menuRasterPixels)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        DebugLog.mark("IconProvider.appIcon miss \(item.name)")

        // Do not call `icon(forFile:)` on another .app — that is the Sequoia
        // “wants to access data from other apps” prompt, every time TCC resets.
        let result: NSImage
        if let icon = runningAppIcon(for: item) {
            result = prepared(icon, size: size, template: false)
        } else if AppLocator.isInstalled(item) {
            result = prepared(NSWorkspace.shared.icon(for: .application), size: size, template: false)
        } else {
            result = symbol("app.dashed", size: size)
        }
        cache.setObject(result, forKey: key)
        return result
    }

    private static func runningAppIcon(for item: AppItem) -> NSImage? {
        for id in item.bundleIdentifiers {
            if let icon = NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.icon {
                return icon
            }
        }
        return nil
    }

    static func actionIcon(kind: ActionKind, size: NSSize = menuSize) -> NSImage {
        symbol(kind.symbolName, size: size)
    }

    static func symbol(_ name: String, size: NSSize) -> NSImage {
        let key = "sym:\(name):\(Int(size.width)):\(menuRasterPixels)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let raw = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "questionmark.square", accessibilityDescription: nil)
            ?? NSImage()
        let configured = raw.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: size.height, weight: .regular)
        ) ?? raw
        let result = prepared(configured, size: size, template: true)
        cache.setObject(result, forKey: key)
        return result
    }

    /// Finder copies every `NSImage` representation over XPC. Workspace icons
    /// include 32–1024px reps; that transfer is ~1s. Settings can keep a cheap
    /// resized copy; Finder menu items get one 64px bitmap at 16pt.
    /// Never force a non-square image into `size` — that stretches SF Symbols.
    static func prepared(_ image: NSImage, size: NSSize, template: Bool) -> NSImage {
        if size.width <= menuSize.width {
            return flattened(image, pointSize: size, pixels: menuRasterPixels, template: template)
        }
        return scaledToFit(image, in: size, template: template)
    }

    static func scaledToFit(_ image: NSImage, in size: NSSize, template: Bool) -> NSImage {
        let source = image.size.width > 0 && image.size.height > 0 ? image.size : pixelSize(of: image)
        guard source.width > 0, source.height > 0 else {
            let copy = image.copy() as? NSImage ?? image
            copy.isTemplate = template
            return copy
        }
        let scale = min(size.width / source.width, size.height / source.height)
        let copy = image.copy() as? NSImage ?? image
        copy.size = NSSize(width: source.width * scale, height: source.height * scale)
        copy.isTemplate = template
        return copy
    }

    static func flattened(_ image: NSImage, pointSize: NSSize, pixels: Int, template: Bool) -> NSImage {
        let pixels = max(1, pixels)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            let copy = image.copy() as? NSImage ?? image
            copy.size = pointSize
            copy.isTemplate = template
            return copy
        }
        rep.size = pointSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        NSColor.clear.set()
        NSRect(origin: .zero, size: pointSize).fill()
        image.draw(in: aspectFittedRect(of: image, in: pointSize), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        let out = NSImage(size: pointSize)
        out.addRepresentation(rep)
        out.isTemplate = template
        return out
    }

    static func aspectFittedRect(of image: NSImage, in pointSize: NSSize) -> NSRect {
        let source = image.size.width > 0 && image.size.height > 0 ? image.size : pixelSize(of: image)
        guard source.width > 0, source.height > 0 else {
            return NSRect(origin: .zero, size: pointSize)
        }
        let scale = min(pointSize.width / source.width, pointSize.height / source.height)
        let fitted = NSSize(width: source.width * scale, height: source.height * scale)
        return NSRect(
            x: (pointSize.width - fitted.width) / 2,
            y: (pointSize.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    private static func pixelSize(of image: NSImage) -> NSSize {
        let best = image.representations.max(by: { $0.pixelsWide < $1.pixelsWide })
        if let best, best.pixelsWide > 0, best.pixelsHigh > 0 {
            return NSSize(width: best.pixelsWide, height: best.pixelsHigh)
        }
        return image.size
    }
}
