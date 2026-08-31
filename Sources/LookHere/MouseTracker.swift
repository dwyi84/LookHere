import AppKit
import CoreGraphics

final class MouseTracker {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let onMove: (CGPoint) -> Void
    private let onPress: (CGPoint) -> Void

    init(onMove: @escaping (CGPoint) -> Void, onPress: @escaping (CGPoint) -> Void) {
        self.onMove = onMove
        self.onPress = onPress
    }

    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = (UInt64(1) << UInt64(CGEventType.mouseMoved.rawValue))
            | (UInt64(1) << UInt64(CGEventType.leftMouseDragged.rawValue))
            | (UInt64(1) << UInt64(CGEventType.rightMouseDragged.rawValue))
            | (UInt64(1) << UInt64(CGEventType.otherMouseDragged.rawValue))
            | (UInt64(1) << UInt64(CGEventType.leftMouseDown.rawValue))
            | (UInt64(1) << UInt64(CGEventType.rightMouseDown.rawValue))
            | (UInt64(1) << UInt64(CGEventType.otherMouseDown.rawValue))

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }
                let tracker = Unmanaged<MouseTracker>.fromOpaque(userInfo).takeUnretainedValue()
                tracker.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPointer
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    var tapIsActive: Bool {
        eventTap != nil
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            onMove(event.location)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            onPress(event.location)
        default:
            break
        }
    }
}