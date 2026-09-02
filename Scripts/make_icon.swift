import AppKit
import Foundation

// Mirrors the settings header mark: a colored ring with a black
// macOS-style cursor inside, on a transparent background.
func drawIcon(in rect: NSRect) {
    let s = rect.size.width

    let center = NSPoint(x: rect.midX, y: rect.midY)
    let ringRadius = s * 0.36
    let ringRect = NSRect(
        x: center.x - ringRadius,
        y: center.y - ringRadius,
        width: ringRadius * 2,
        height: ringRadius * 2
    )
    let ring = NSBezierPath(ovalIn: ringRect)
    ring.lineWidth = s * 0.10
    NSColor(calibratedRed: 1.0, green: 0.584, blue: 0.0, alpha: 1.0).setStroke()
    ring.stroke()

    let arrowNorm: [(x: CGFloat, y: CGFloat)] = [
        (0.000, 0.000),
        (0.000, 0.900),
        (0.350, 0.692),
        (0.563, 1.000),
        (0.788, 0.938),
        (0.575, 0.638),
        (1.000, 0.638),
    ]
    let arrowHeight = s * 0.48
    let arrowWidth = arrowHeight * 8.0 / 13.0
    let arrowOrigin = NSPoint(
        x: center.x - arrowWidth / 2 + s * 0.02,
        y: center.y - arrowHeight / 2 - s * 0.02
    )
    let arrow = NSBezierPath()
    for (i, p) in arrowNorm.enumerated() {
        let pt = NSPoint(
            x: arrowOrigin.x + p.x * arrowWidth,
            y: arrowOrigin.y + (1 - p.y) * arrowHeight
        )
        if i == 0 { arrow.move(to: pt) } else { arrow.line(to: pt) }
    }
    arrow.close()

    NSColor.black.setFill()
    arrow.fill()
    arrow.lineWidth = s * 0.04
    NSColor.white.setStroke()
    arrow.stroke()
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