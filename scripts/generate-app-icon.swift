#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("scripts/app-icon-source.png")
let outputDir = root.appendingPathComponent("MacRightClick/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func drawFallback(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let inset = NSAffineTransform()
    inset.translateX(by: size * 0.1, yBy: size * 0.1)
    inset.scale(by: 0.8)
    inset.concat()

    let plate = NSBezierPath(
        roundedRect: NSRect(x: size * 0.04, y: size * 0.04, width: size * 0.92, height: size * 0.92),
        xRadius: size * 0.223,
        yRadius: size * 0.223
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.70, green: 0.88, blue: 0.99, alpha: 1),
        NSColor(calibratedRed: 0.42, green: 0.72, blue: 0.98, alpha: 1)
    ])?.draw(in: plate, angle: 270)

    let folder = NSBezierPath(roundedRect: NSRect(x: size * 0.16, y: size * 0.28, width: size * 0.58, height: size * 0.42), xRadius: size * 0.06, yRadius: size * 0.06)
    NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
    folder.fill()
    NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: size * 0.16, y: size * 0.58, width: size * 0.22, height: size * 0.10), xRadius: size * 0.03, yRadius: size * 0.03).fill()

    let card = NSRect(x: size * 0.36, y: size * 0.18, width: size * 0.42, height: size * 0.42)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: size * 0.07, yRadius: size * 0.07)
    NSColor.white.setFill()
    cardPath.fill()
    NSColor.black.withAlphaComponent(0.12).setStroke()
    cardPath.lineWidth = max(1, size * 0.012)
    cardPath.stroke()

    let barInset = size * 0.05
    let barHeight = max(1.5, size * 0.05)
    let bars = [
        NSColor(calibratedRed: 0.16, green: 0.55, blue: 1.0, alpha: 1),
        NSColor(calibratedWhite: 0.78, alpha: 1),
        NSColor(calibratedWhite: 0.78, alpha: 1)
    ]
    for (index, color) in bars.enumerated() {
        let y = card.maxY - size * 0.10 - CGFloat(index) * size * 0.10
        color.setFill()
        NSBezierPath(
            roundedRect: NSRect(x: card.minX + barInset, y: y, width: card.width - barInset * 2, height: barHeight),
            xRadius: barHeight / 2,
            yRadius: barHeight / 2
        ).fill()
    }

    let pointer = NSBezierPath()
    let px = size * 0.62
    let py = size * 0.40
    pointer.move(to: NSPoint(x: px, y: py + size * 0.22))
    pointer.line(to: NSPoint(x: px, y: py))
    pointer.line(to: NSPoint(x: px + size * 0.09, y: py + size * 0.07))
    pointer.line(to: NSPoint(x: px + size * 0.04, y: py + size * 0.08))
    pointer.line(to: NSPoint(x: px + size * 0.08, y: py + size * 0.15))
    pointer.close()
    NSColor.white.setFill()
    pointer.fill()
    NSColor.black.withAlphaComponent(0.45).setStroke()
    pointer.lineWidth = max(1, size * 0.016)
    pointer.stroke()

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage, pixel: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixel,
        pixelsHigh: pixel,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixel, height: pixel)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    NSColor.clear.setFill()
    context.cgContext.fill(CGRect(x: 0, y: 0, width: pixel, height: pixel))
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixel, height: pixel),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

struct IconSpec {
    let filename: String
    let pixels: Int
}

let specs = [
    IconSpec(filename: "icon_16.png", pixels: 16),
    IconSpec(filename: "icon_16_2x.png", pixels: 32),
    IconSpec(filename: "icon_32.png", pixels: 32),
    IconSpec(filename: "icon_32_2x.png", pixels: 64),
    IconSpec(filename: "icon_128.png", pixels: 128),
    IconSpec(filename: "icon_128_2x.png", pixels: 256),
    IconSpec(filename: "icon_256.png", pixels: 256),
    IconSpec(filename: "icon_256_2x.png", pixels: 512),
    IconSpec(filename: "icon_512.png", pixels: 512),
    IconSpec(filename: "icon_512_2x.png", pixels: 1024)
]

let source = NSImage(contentsOf: sourceURL)

for spec in specs {
    let rendered: NSImage
    if let source, spec.pixels >= 64 {
        rendered = source
    } else {
        rendered = drawFallback(size: CGFloat(spec.pixels))
    }
    guard let data = pngData(from: rendered, pixel: spec.pixels) else { continue }
    try data.write(to: outputDir.appendingPathComponent(spec.filename))
}

let contents = """
{
  "images" : [
    { "filename" : "icon_16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16_2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32_2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128_2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256_2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512_2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try contents.write(to: outputDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Wrote AppIcon.appiconset from \(source == nil ? "fallback drawing" : sourceURL.lastPathComponent)")
