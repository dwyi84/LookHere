import AppKit
import Foundation

func drawIcon(in rect: NSRect) {
    let s = rect.size.width

    let backgroundPath = NSBezierPath(
        roundedRect: rect,
        xRadius: s * 0.2237,
        yRadius: s * 0.2237
    )
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.24, alpha: 1.0),
        NSColor(calibratedRed: 0.95, green: 0.42, blue: 0.07, alpha: 1.0),
    ])!
    gradient.draw(in: backgroundPath, angle: -90)

    let center = NSPoint(x: rect.midX, y: rect.midY)
    let ringRadius = s * 0.30
    let ringRect = NSRect(
        x: center.x - ringRadius,
        y: center.y - ringRadius,
        width: ringRadius * 2,
        height: ringRadius * 2
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = s * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.015)

    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    let ring = NSBezierPath(ovalIn: ringRect)
    ring.lineWidth = s * 0.10
    NSColor.white.setStroke()
    ring.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()

    let dotRadius = s * 0.08
    let dotRect = NSRect(
        x: center.x - dotRadius,
        y: center.y - dotRadius,
        width: dotRadius * 2,
        height: dotRadius * 2
    )
    NSColor.white.setFill()
    NSBezierPath(ovalIn: dotRect).fill()
}

func makeIcon(pixelSize: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make_icon <output-iconset-dir>\n".utf8))
    exit(1)
}

let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(name: String, pixels: Int)] = [
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

for spec in specs {
    let rep = makeIcon(pixelSize: spec.pixels)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to encode \(spec.name)\n".utf8))
        exit(1)
    }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(spec.name)
    try data.write(to: url)
}

print("icon set written to \(outDir)")