import AppKit

enum MenuBarIcon {
    static func make() -> NSImage? {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side))
        for scale in [2, 3] {
            let pixels = Int(side * CGFloat(scale))
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
            ) else { return nil }
            rep.size = NSSize(width: side, height: side)
            guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            draw(in: NSRect(x: 0, y: 0, width: side, height: side))
            context.flushGraphics()
            NSGraphicsContext.restoreGraphicsState()
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        image.accessibilityDescription = "LookHere"
        return image
    }

    private static func draw(in rect: NSRect) {
        let s = rect.width
        let center = NSPoint(x: rect.midX, y: rect.midY)

        let ringRadius = s * 0.345
        let ring = NSBezierPath(ovalIn: NSRect(
            x: center.x - ringRadius,
            y: center.y - ringRadius,
            width: ringRadius * 2,
            height: ringRadius * 2
        ))
        ring.lineWidth = s * 0.10
        NSColor.black.setStroke()
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
        let arrowHeight = s * 0.40
        let arrowWidth = arrowHeight * 8.0 / 13.0
        let arrowOrigin = NSPoint(
            x: center.x - arrowWidth / 2 + s * 0.015,
            y: center.y - arrowHeight / 2 - s * 0.015
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
    }
}
