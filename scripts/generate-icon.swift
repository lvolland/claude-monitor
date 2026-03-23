#!/usr/bin/env swift
import AppKit

let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // Background rounded rect
    let bgColor = NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
    bgColor.setFill()
    bgPath.fill()

    // Glow ellipse
    let glowRect = NSRect(x: size * 0.11, y: size * 0.11, width: size * 0.78, height: size * 0.78)
    let glowGradient = NSGradient(colors: [
        NSColor(red: 0.42, green: 0.39, blue: 1.0, alpha: 0.3),
        NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.15),
        NSColor.clear
    ])!
    let glowPath = NSBezierPath(ovalIn: glowRect)
    ctx.saveGState()
    glowPath.addClip()
    glowGradient.draw(in: glowRect, relativeCenterPosition: NSPoint.zero)
    ctx.restoreGState()

    // Brain icon from SF Symbols
    let iconSize = size * 0.55
    let iconX = (size - iconSize) / 2
    let iconY = (size - iconSize) / 2

    if let symbol = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: iconSize * 0.8, weight: .regular)
        let configured = symbol.withSymbolConfiguration(config)!

        // Create gradient image for the icon
        let iconImage = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { iconRect in
            // Draw gradient
            let gradient = NSGradient(colors: [
                NSColor(red: 0.51, green: 0.55, blue: 0.97, alpha: 1.0),
                NSColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0),
            ], atLocations: [0.0, 1.0], colorSpace: .sRGB)!

            gradient.draw(in: iconRect, angle: 90)

            // Mask with the symbol
            configured.draw(in: iconRect, from: .zero, operation: .destinationIn, fraction: 1.0)
            return true
        }

        iconImage.draw(in: NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
    }

    return true
}

// Save as PNG
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG")
    exit(1)
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let pngPath = "\(outputDir)/icon_1024.png"
try! pngData.write(to: URL(fileURLWithPath: pngPath))
print("Saved \(pngPath)")

// Generate iconset
let iconsetDir = "\(outputDir)/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for (name, px) in sizes {
    let resized = NSImage(size: NSSize(width: px, height: px))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1.0)
    resized.unlockFocus()

    guard let tiff = resized.tiffRepresentation,
          let bmp = NSBitmapImageRep(data: tiff),
          let png = bmp.representation(using: .png, properties: [:]) else { continue }

    try! png.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name).png"))
}
print("Saved iconset to \(iconsetDir)")
