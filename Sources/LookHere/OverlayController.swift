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

    func updateVisuals() {
        let color = settings.effectiveColor
        for window in windows {
            window.haloView.configureRing(
                color: color,
                radius: CGFloat(settings.ringRadius),
                opacity: settings.ringOpacity,
                lineWidth: CGFloat(settings.ringLineWidth),
                trailEnabled: settings.trailEnabled,
                trailDuration: settings.trailDuration
            )
        }
    }

    func setEnabled(_ enabled: Bool) {
        for window in windows {
            window.haloView.hideRing()
            window.haloView.clearRipples()
            if enabled {
                window.orderFrontRegardless()
            } else {
                window.orderOut(nil)
            }
        }
    }

    func updateCursor(_ cgPoint: CGPoint) {
        guard settings.isEnabled else { return }
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

    func spawnRipple(at cgPoint: CGPoint) {
        guard settings.isEnabled else { return }
        let point = appKitPoint(from: cgPoint)
        for window in windows where window.frame.contains(point) {
            let local = NSPoint(x: point.x - window.frame.minX, y: point.y - window.frame.minY)
            window.haloView.spawnRipple(
                at: local,
                color: settings.effectiveColor,
                lineWidth: CGFloat(settings.ringLineWidth),
                maxRadius: CGFloat(settings.ringRadius)
            )
            break
        }
    }

    private func appKitPoint(from cgPoint: CGPoint) -> NSPoint {
        NSPoint(x: cgPoint.x, y: mainDisplayHeight - cgPoint.y)
    }
}