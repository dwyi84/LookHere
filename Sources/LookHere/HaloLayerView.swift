import AppKit
import QuartzCore

final class HaloLayerView: NSView {
    private let ringLayer = CAShapeLayer()
    private var ripples: [CAShapeLayer] = []
    private var trailSegments: [TrailSegment] = []
    private var trailTimer: Timer?

    private var radius: CGFloat = 30
    private var thicknessRatio: Double = 0.10
    private var strokeWidth: CGFloat = 3
    private var ringColorValue: NSColor = .systemOrange
    private var ringEnabled = true
    private var trailEnabled = false
    private var trailDuration: Double = 2.0
    private var lastTrailPoint: CGPoint?
    private var lastTrailActivity: TimeInterval = 0
    private var headSegment: TrailSegment?

    // A trail segment grows until it reaches this length, then a new one
    // starts at its tip. Drawing one growing stroke instead of a fresh layer
    // per mouse event keeps the line smooth instead of beaded.
    private let maxTrailSegmentLength: CGFloat = 16
    private let trailStep: CGFloat = 3
    private let trailDwellTimeout: TimeInterval = 0.15

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
            appendTrailPoint(point)
        }
        guard ringEnabled else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.isHidden = false
        ringLayer.position = point
        CATransaction.commit()
    }

    func hideRing() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.isHidden = true
        CATransaction.commit()
        lastTrailPoint = nil
        headSegment = nil
    }

    func configureRing(
        color: NSColor,
        radius: CGFloat,
        opacity: Double,
        thicknessRatio: Double,
        ringEnabled: Bool,
        trailEnabled: Bool,
        trailDuration: Double
    ) {
        self.radius = radius
        self.thicknessRatio = thicknessRatio
        self.ringColorValue = color
        self.ringEnabled = ringEnabled
        self.trailEnabled = trailEnabled
        self.trailDuration = trailDuration

        // `radius` is the OUTER radius. The band thickness is a fraction of it,
        // which places the stroked path on the band's centreline. This keeps
        // inner = outer * (1 - ratio) >= 0 for any size.
        let bandWidth = radius * CGFloat(thicknessRatio)
        self.strokeWidth = bandWidth
        let centerlineRadius = radius - bandWidth / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringLayer.strokeColor = color.withAlphaComponent(CGFloat(opacity)).cgColor
        ringLayer.lineWidth = bandWidth
        if !ringEnabled {
            ringLayer.isHidden = true
        }
        let side = centerlineRadius * 2
        let rect = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        ringLayer.path = CGPath(ellipseIn: rect, transform: nil)
        ringLayer.bounds = rect
        ringLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        CATransaction.commit()

        recolorTrail(with: color)
    }

    func spawnRipple(at point: CGPoint, color: NSColor, lineWidth: CGFloat, outerRadius: CGFloat) {
        if ripples.count >= 10 {
            ripples.removeFirst().removeFromSuperlayer()
        }

        let ripple = CAShapeLayer()
        let startRadius: CGFloat = 6
        let rect = CGRect(origin: .zero, size: CGSize(width: startRadius * 2, height: startRadius * 2))
        ripple.fillColor = NSColor.clear.cgColor
        ripple.strokeColor = color.cgColor
        ripple.lineWidth = max(lineWidth, 2)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ripple.path = CGPath(ellipseIn: rect, transform: nil)
        ripple.bounds = rect
        ripple.position = point
        ripple.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        CATransaction.commit()

        layer?.addSublayer(ripple)
        ripples.append(ripple)

        let finalScale = (outerRadius + 8) / startRadius

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
        headSegment = nil
    }

    // MARK: - Trail (smooth continuous polyline)

    private func appendTrailPoint(_ point: CGPoint) {
        guard let last = lastTrailPoint else {
            lastTrailPoint = point
            lastTrailActivity = CACurrentMediaTime()
            return
        }

        let now = CACurrentMediaTime()
        let distance = hypot(point.x - last.x, point.y - last.y)

        // Tiny, sustained movement means the cursor is dwelling in place.
        // Re-anchor now and then so a random walk can't accumulate into an
        // ink blob, but never stamp a segment for it.
        guard distance >= trailStep else {
            if now - lastTrailActivity > trailDwellTimeout {
                lastTrailPoint = point
                lastTrailActivity = now
            }
            return
        }

        lastTrailActivity = now

        if let head = headSegment {
            if head.pathLength + distance <= maxTrailSegmentLength {
                extendTrailSegment(head, to: point)
                lastTrailPoint = point
                return
            }
        }

        startTrailSegment(from: last, to: point)
        lastTrailPoint = point
    }

    private func startTrailSegment(from: CGPoint, to: CGPoint) {
        if trailSegments.count >= 300 {
            trailSegments.removeFirst().removeAll()
        }

        let baseWidth = max(radius * 0.16, 2.5)

        let core = CAShapeLayer()
        core.fillColor = NSColor.clear.cgColor
        core.strokeColor = ringColorValue.cgColor
        core.lineWidth = baseWidth
        core.lineCap = .round
        core.lineJoin = .round

        let glow = CAShapeLayer()
        glow.fillColor = NSColor.clear.cgColor
        glow.strokeColor = ringColorValue.cgColor
        glow.lineWidth = baseWidth * 2.4
        // Butt caps stop the translucent glow of neighbouring segments from
        // stacking into bright "ink dots" at every joint.
        glow.lineCap = .butt
        glow.lineJoin = .round
        glow.opacity = 0.35

        let segment = TrailSegment(
            core: core,
            glow: glow,
            birthTime: CACurrentMediaTime(),
            baseWidth: baseWidth,
            points: [from, to],
            pathLength: hypot(to.x - from.x, to.y - from.y)
        )
        layer?.addSublayer(glow)
        layer?.addSublayer(core)
        trailSegments.append(segment)
        headSegment = segment
        layoutTrailSegment(segment)
        startTrailTimer()
    }

    private func extendTrailSegment(_ segment: TrailSegment, to point: CGPoint) {
        if let tail = segment.points.last {
            segment.pathLength += hypot(point.x - tail.x, point.y - tail.y)
        }
        segment.points.append(point)
        // Keep the growing tip looking freshly drawn while the cursor moves.
        segment.birthTime = CACurrentMediaTime()
        layoutTrailSegment(segment)
    }

    private func layoutTrailSegment(_ segment: TrailSegment) {
        let points = segment.points
        guard let first = points.first else { return }

        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for p in points {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        let pad = segment.baseWidth * 2.6
        minX -= pad; minY -= pad
        maxX += pad; maxY += pad
        let width = max(maxX - minX, 0.01)
        let height = max(maxY - minY, 0.01)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: first.x - minX, y: first.y - minY))
        for p in points.dropFirst() {
            path.addLine(to: CGPoint(x: p.x - minX, y: p.y - minY))
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        segment.core.path = path
        segment.glow.path = path
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        segment.core.bounds = bounds
        segment.glow.bounds = bounds
        let position = CGPoint(x: minX + width / 2, y: minY + height / 2)
        segment.core.position = position
        segment.glow.position = position
        CATransaction.commit()
    }

    private func recolorTrail(with color: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for segment in trailSegments {
            segment.core.strokeColor = color.cgColor
            segment.glow.strokeColor = color.cgColor
        }
        CATransaction.commit()
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
        trailSegments.removeAll { segment in
            guard now - segment.birthTime >= trailDuration else { return false }
            if segment === headSegment {
                headSegment = nil
            }
            return true
        }
        if trailSegments.isEmpty {
            stopTrailTimer()
        }
    }
}

private final class TrailSegment {
    let core: CAShapeLayer
    let glow: CAShapeLayer
    var birthTime: TimeInterval
    let baseWidth: CGFloat
    var points: [CGPoint]
    var pathLength: CGFloat

    init(
        core: CAShapeLayer,
        glow: CAShapeLayer,
        birthTime: TimeInterval,
        baseWidth: CGFloat,
        points: [CGPoint],
        pathLength: CGFloat
    ) {
        self.core = core
        self.glow = glow
        self.birthTime = birthTime
        self.baseWidth = baseWidth
        self.points = points
        self.pathLength = pathLength
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