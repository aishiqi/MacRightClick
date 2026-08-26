#!/usr/bin/env swift
import AppKit
import Foundation

let outputDir = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath)
    .appendingPathComponent("MacRightClick/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.22
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: corner, yRadius: corner)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.18, green: 0.36, blue: 0.86, alpha: 1),
        NSColor(calibratedRed: 0.35, green: 0.18, blue: 0.78, alpha: 1)
    ])
    gradient?.draw(in: path, angle: 90)

    let cardInset = size * 0.20
    let card = NSRect(x: cardInset, y: size * 0.28, width: size * 0.42, height: size * 0.48)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: size * 0.04, yRadius: size * 0.04)
    NSColor.white.withAlphaComponent(0.95).setFill()
    cardPath.fill()

    let lineColor = NSColor(calibratedRed: 0.25, green: 0.28, blue: 0.40, alpha: 0.55)
    lineColor.setFill()
    for i in 0..<3 {
        let y = card.maxY - size * 0.12 - CGFloat(i) * size * 0.11
        NSBezierPath(roundedRect: NSRect(x: card.minX + size * 0.06, y: y, width: card.width - size * 0.12, height: size * 0.035), xRadius: size * 0.01, yRadius: size * 0.01).fill()
    }

    let pointer = NSBezierPath()
    let px = size * 0.58
    let py = size * 0.22
    pointer.move(to: NSPoint(x: px, y: py + size * 0.32))
    pointer.line(to: NSPoint(x: px, y: py))
    pointer.line(to: NSPoint(x: px + size * 0.12, y: py + size * 0.10))
    pointer.line(to: NSPoint(x: px + size * 0.05, y: py + size * 0.11))
    pointer.line(to: NSPoint(x: px + size * 0.10, y: py + size * 0.22))
    pointer.close()
    NSColor.white.setFill()
    pointer.fill()
    NSColor.black.withAlphaComponent(0.25).setStroke()
    pointer.lineWidth = max(1, size * 0.012)
    pointer.stroke()

    image.unlockFocus()
    return image
}

func pngData(_ image: NSImage, pixel: Int) -> Data? {
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
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixel, height: pixel))
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

for spec in specs {
    let rendered = drawIcon(size: CGFloat(spec.pixels))
    guard let data = pngData(rendered, pixel: spec.pixels) else { continue }
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
print("Wrote AppIcon.appiconset to \(outputDir.path)")
