#!/usr/bin/env swift

import AppKit
import Foundation

func createMasterIcon() -> NSImage {
    let size = NSSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // Base squircle geometry (824x824 centered in 1024x1024)
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185.0
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Shadow under the squircle
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 32, color: NSColor(white: 0, alpha: 0.35).cgColor)
    ctx.addPath(squirclePath)
    ctx.setFillColor(NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Squircle background gradient (Dark Obsidian to Deep Graphite)
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.17, green: 0.17, blue: 0.20, alpha: 1.0).cgColor,
        NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    }

    // Inner rim stroke (subtle glass highlight)
    ctx.addPath(squirclePath)
    ctx.setLineWidth(2.0)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.12).cgColor)
    ctx.strokePath()

    // Subtle radial light from top center
    if let radialGrad = CGGradient(colorsSpace: colorSpace, colors: [
        NSColor(white: 1.0, alpha: 0.08).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor
    ] as CFArray, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(radialGrad, startCenter: CGPoint(x: 512, y: 880), startRadius: 0, endCenter: CGPoint(x: 512, y: 600), endRadius: 500, options: [])
    }
    ctx.restoreGState()

    // Draw the Symbol: Magnifying Glass + 2-line Subtitle Cue
    let s: CGFloat = 6.4
    let originX: CGFloat = 512 - (51.5 * s)
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        return CGPoint(x: originX + x * s, y: 1024 - (originX + y * s))
    }

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: NSColor(white: 0, alpha: 0.3).cgColor)

    // 1. Circle rim (Lens)
    let circleCenter = pt(45, 45)
    let radius = 30 * s
    ctx.setLineWidth(6.5 * s)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.strokeEllipse(in: CGRect(x: circleCenter.x - radius, y: circleCenter.y - radius, width: radius * 2, height: radius * 2))

    // 2. Handle
    let handleStart = pt(67, 67)
    let handleEnd = pt(85, 85)
    ctx.setLineCap(.round)
    ctx.setLineWidth(9.0 * s)
    ctx.move(to: handleStart)
    ctx.addLine(to: handleEnd)
    ctx.strokePath()

    // 3. Subtitles
    func drawPill(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, rx: CGFloat) {
        let p = pt(x, y)
        let rect = CGRect(x: p.x, y: p.y - (h * s), width: w * s, height: h * s)
        let path = CGPath(roundedRect: rect, cornerWidth: rx * s, cornerHeight: rx * s, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillPath()
    }

    // Line 1:
    drawPill(x: 25, y: 35, w: 22, h: 6.5, rx: 3.25)
    drawPill(x: 51, y: 35, w: 12, h: 6.5, rx: 3.25)

    // Line 2:
    drawPill(x: 27, y: 47.5, w: 12, h: 6.5, rx: 3.25)
    drawPill(x: 43, y: 47.5, w: 22, h: 6.5, rx: 3.25)

    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func resizedImage(image: NSImage, targetSize: NSSize) -> NSImage {
    let resized = NSImage(size: targetSize)
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
    resized.unlockFocus()
    return resized
}

func savePNG(image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG for \(url.lastPathComponent)"])
    }
    try pngData.write(to: url)
}

func main() {
    let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let repoRoot = scriptDir.deletingLastPathComponent()
    let packagingDir = repoRoot.appendingPathComponent("packaging/macos")
    let outputICNS = packagingDir.appendingPathComponent("AppIcon.icns")

    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let iconsetDir = tempDir.appendingPathComponent("AppIcon.iconset")

    do {
        try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
        let master = createMasterIcon()

        let sizes: [(name: String, px: CGFloat)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024),
        ]

        for entry in sizes {
            let resized = resizedImage(image: master, targetSize: NSSize(width: entry.px, height: entry.px))
            let fileURL = iconsetDir.appendingPathComponent(entry.name)
            try savePNG(image: resized, to: fileURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetDir.path, "-o", outputICNS.path]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            fatalError("iconutil failed with code \(process.terminationStatus)")
        }

        print("Successfully generated \(outputICNS.path)")
        try FileManager.default.removeItem(at: tempDir)
    } catch {
        fatalError("Error: \(error)")
    }
}

main()
