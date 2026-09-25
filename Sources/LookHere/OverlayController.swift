import AppKit

@MainActor
final class OverlayController {
    private let settings: SettingsStore
    private var windows: [OverlayWindow] = []
    private var mainDisplayHeight: CGFloat = 0

    init(settings: SettingsStore) {
        self.settings = settings
        rebuildForScreens()
    }

    func rebuildForScreens() {
        windows.forEach { $0.close() }
        windows.removeAll()
        mainDisplayHeight = primaryDisplayHeight()
        windows = NSScreen.screens.map { OverlayWindow(screen: $0) }
        windows.forEach { $0.show() }
        updateVisuals()
    }

    // The primary display is the one whose AppKit frame origin is (0,0).
    // Its height anchors the CGEvent coordinate space (origin = its top-left).
    private func primaryDisplayHeight() -> CGFloat {
        NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height
            ?? NSScreen.screens.first?.frame.height
            ?? 0
    }

    /// Applies visual settings to every overlay window. Passed values take
    /// precedence over the store's current values, so callers can hand the
    /// freshly-emitted value straight through (reading a just-mutated
    /// `@Published` property inside a sink returns the previous value).
    func updateVisuals(
        color: NSColor? = nil,
        invert: Bool? = nil,
        radius: CGFloat? = nil,
        opacity: Double? = nil,
        thicknessRatio: Double? = nil,
        ringEnabled: Bool? = nil,
        trailEnabled: Bool? = nil,
        trailDuration: Double? = nil
    ) {
        let resolvedColor = color ?? settings.effectiveColor
        let resolvedInvert = invert ?? settings.ringInvert
        let resolvedRadius = radius ?? CGFloat(settings.ringRadius)
        let resolvedOpacity = opacity ?? settings.ringOpacity
        let resolvedThickness = thicknessRatio ?? settings.ringThicknessRatio
        let resolvedRing = ringEnabled ?? settings.isEnabled
        let resolvedTrail = trailEnabled ?? settings.trailEnabled
        let resolvedDuration = trailDuration ?? settings.trailDuration

        for window in windows {
            window.haloView.configureRing(
                color: resolvedColor,
                invert: resolvedInvert,
                radius: resolvedRadius,
                opacity: resolvedOpacity,
                thicknessRatio: resolvedThickness,
                ringEnabled: resolvedRing,
                trailEnabled: resolvedTrail,
                trailDuration: resolvedDuration
            )
        }
    }

    func setActive(_ active: Bool) {
        for window in windows {
            window.haloView.hideRing()
            window.haloView.clearEffects()
            if active {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
        }
    }

    func updateCursor(_ cgPoint: CGPoint) {
        guard settings.isEnabled || settings.trailEnabled else { return }
        let point = appKitPoint(from: cgPoint)
        for window in windows {
            if window.frame.contains(point) {
                let local = NSPoint(x: point.x - window.frame.minX, y: point.y - window.frame.minY)
                window.haloView.showRing(at: local)
            } else {
                window.haloView.hideRing()
            }
        }
    }

    func playClockWipe(at cgPoint: CGPoint) {
        guard settings.isEnabled else { return }
        let point = appKitPoint(from: cgPoint)
        for window in windows where window.frame.contains(point) {
            window.haloView.playClockWipe()
            break
        }
    }

    private func appKitPoint(from cgPoint: CGPoint) -> NSPoint {
        NSPoint(x: cgPoint.x, y: mainDisplayHeight - cgPoint.y)
    }
}