import AppKit
import QuartzCore

final class HaloLayerView: NSView {
    private let ringLayer = CAShapeLayer()
    private var ripples: [CAShapeLayer] = []
    private var trailSegments: [TrailSegment] = []
    private var trailTimer: Timer?

    private var radius: CGFloat = 30
    private var strokeWidth: CGFloat = 3
    private var ringColorValue: NSColor = .systemOrange
    private var trailEnabled = false
    private var trailDuration: Double = 2.0
    private var lastTrailPoint: CGPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false

        ringLayer.fillColor = NSColor.clear.cgColor
        ringLayer.lineWidth = strokeWidth
        ringLayer.isHidden = true
        layer?.addSublayer(ringLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public API

    func showRing(at point: CGPoint) {
        if trailEnabled {
            if let last = lastTrailPoint {
                let distance = hypot(point.x - last.x, point.y - last.y)
                if distance > 1 {
                    spawnTrailSegment(from: last, to: point)
                }
            }
            lastTrailPoint = point
        }
        ringLayer.isHidden = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.position = point
        CATransaction.commit()
    }

    func hideRing() {
        ringLayer.isHidden = true
        lastTrailPoint = nil
    }

    func configureRing(
        color: NSColor,
        radius: CGFloat,
        opacity: Double,
        lineWidth: CGFloat,
        trailEnabled: Bool,
        trailDuration: Double
    ) {
        self.radius = radius
        self.strokeWidth = lineWidth
        self.ringColorValue = color
        self.trailEnabled = trailEnabled
        self.trailDuration = trailDuration

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.strokeColor = color.withAlphaComponent(CGFloat(opacity)).cgColor
        ringLayer.lineWidth = lineWidth
        let side = radius * 2
        let rect = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        ringLayer.path = CGPath(ellipseIn: rect, transform: nil)
        ringLayer.bounds = rect
        ringLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        CATransaction.commit()
    }

    func spawnRipple(at point: CGPoint, color: NSColor, lineWidth: CGFloat, maxRadius: CGFloat) {
        if ripples.count >= 10 {
            ripples.removeFirst().removeFromSuperlayer()
        }

        let ripple = CAShapeLayer()
        let startRadius: CGFloat = 6
        let rect = CGRect(origin: .zero, size: CGSize(width: startRadius * 2, height: startRadius * 2))
        ripple.path = CGPath(ellipseIn: rect, transform: nil)
        ripple.bounds = rect
        ripple.position = point
        ripple.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        ripple.fillColor = NSColor.clear.cgColor
        ripple.strokeColor = color.cgColor
        ripple.lineWidth = max(lineWidth, 2)

        layer?.addSublayer(ripple)
        ripples.append(ripple)

        let finalScale = (maxRadius + 8) / startRadius

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = finalScale
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.9
        fade.toValue = 0.0
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.4
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        group.delegate = RippleAnimationDelegate { [weak ripple, weak self] in
            ripple?.removeFromSuperlayer()
            self?.ripples.removeAll { $0 === ripple }
        }

        // Model end-state matches the animation's final values so the layer
        // never reverts to its initial (small, opaque) state on completion.
        ripple.opacity = 0
        ripple.setAffineTransform(CGAffineTransform(scaleX: finalScale, y: finalScale))

        ripple.add(group, forKey: "ripple")
    }

    func clearRipples() {
        ripples.forEach { $0.removeFromSuperlayer() }
        ripples.removeAll()
        trailSegments.forEach { $0.removeAll() }
        trailSegments.removeAll()
        stopTrailTimer()
        lastTrailPoint = nil
    }

    // MARK: - Trail (continuous polyline)

    private func spawnTrailSegment(from: CGPoint, to: CGPoint) {
        if trailSegments.count >= 300 {
            trailSegments.removeFirst().removeAll()
        }

        let baseWidth = max(radius * 0.16, 2.5)
        let pad = baseWidth * 2.6
        let minX = min(from.x, to.x) - pad
        let minY = min(from.y, to.y) - pad
        let w = abs(to.x - from.x) + pad * 2
        let h = abs(to.y - from.y) + pad * 2
        let bounds = CGRect(x: 0, y: 0, width: max(w, 0.01), height: max(h, 0.01))

        let path = CGMutablePath()
        path.move(to: CGPoint(x: from.x - minX, y: from.y - minY))
        path.addLine(to: CGPoint(x: to.x - minX, y: to.y - minY))

        let core = CAShapeLayer()
        core.path = path
        core.bounds = bounds
        core.position = CGPoint(x: minX + w / 2, y: minY + h / 2)
        core.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        core.fillColor = NSColor.clear.cgColor
        core.strokeColor = ringColorValue.cgColor
        core.lineWidth = baseWidth
        core.lineCap = .round

        let glow = CAShapeLayer()
        glow.path = path
        glow.bounds = bounds
        glow.position = core.position
        glow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        glow.fillColor = NSColor.clear.cgColor
        glow.strokeColor = ringColorValue.cgColor
        glow.lineWidth = baseWidth * 2.4
        glow.lineCap = .round
        glow.opacity = 0.35

        layer?.addSublayer(glow)
        layer?.addSublayer(core)
        trailSegments.append(
            TrailSegment(core: core, glow: glow, birthTime: CACurrentMediaTime(), baseWidth: baseWidth)
        )
        startTrailTimer()
    }

    private func startTrailTimer() {
        guard trailTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advanceTrail()
            }
        }
        trailTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTrailTimer() {
        trailTimer?.invalidate()
        trailTimer = nil
    }

    private func advanceTrail() {
        let now = CACurrentMediaTime()
        for segment in trailSegments {
            let progress = min(1.0, (now - segment.birthTime) / trailDuration)
            let eased = 1 - pow(1 - progress, 2)
            let width = max(segment.baseWidth * (1 - eased), 0.1)
            let alpha = (1 - eased) * 0.9

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            segment.core.opacity = Float(alpha)
            segment.core.lineWidth = width
            segment.glow.opacity = Float(alpha * 0.4)
            segment.glow.lineWidth = width * 2.4
            CATransaction.commit()
        }
        trailSegments.removeAll { now - $0.birthTime >= trailDuration }
        if trailSegments.isEmpty {
            stopTrailTimer()
        }
    }
}

private final class TrailSegment {
    let core: CAShapeLayer
    let glow: CAShapeLayer
    let birthTime: TimeInterval
    let baseWidth: CGFloat

    init(core: CAShapeLayer, glow: CAShapeLayer, birthTime: TimeInterval, baseWidth: CGFloat) {
        self.core = core
        self.glow = glow
        self.birthTime = birthTime
        self.baseWidth = baseWidth
    }

    func removeAll() {
        core.removeFromSuperlayer()
        glow.removeFromSuperlayer()
    }
}

private final class RippleAnimationDelegate: NSObject, CAAnimationDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        onFinish()
    }
}