import AppKit
import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

@MainActor
final class SettingsStore: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Keys.isEnabled) }
    }

    @Published var ringColor: NSColor {
        didSet { persistColor() }
    }

    @Published var ringRadius: Double {
        didSet { defaults.set(ringRadius, forKey: Keys.ringRadius) }
    }

    @Published var ringOpacity: Double {
        didSet { defaults.set(ringOpacity, forKey: Keys.ringOpacity) }
    }

    @Published var ringLineWidth: Double {
        didSet { defaults.set(ringLineWidth, forKey: Keys.ringLineWidth) }
    }

    @Published var hotkeyEnabled: Bool {
        didSet { defaults.set(hotkeyEnabled, forKey: Keys.hotkeyEnabled) }
    }

    @Published var hotkeyKeyCode: UInt32 {
        didSet { defaults.set(Int(hotkeyKeyCode), forKey: Keys.hotkeyKeyCode) }
    }

    @Published var hotkeyCarbonModifiers: UInt32 {
        didSet { defaults.set(Int(hotkeyCarbonModifiers), forKey: Keys.hotkeyCarbonModifiers) }
    }

    @Published var trailEnabled: Bool {
        didSet { defaults.set(trailEnabled, forKey: Keys.trailEnabled) }
    }

    @Published var trailDuration: Double {
        didSet { defaults.set(trailDuration, forKey: Keys.trailDuration) }
    }

    // Persisted by SMAppService itself — never stored in UserDefaults.
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    var effectiveColor: NSColor {
        ringColor.usingColorSpace(NSColorSpace.deviceRGB) ?? ringColor
    }

    init() {
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        ringRadius = defaults.object(forKey: Keys.ringRadius) as? Double ?? 30
        ringOpacity = defaults.object(forKey: Keys.ringOpacity) as? Double ?? 0.85
        ringLineWidth = defaults.object(forKey: Keys.ringLineWidth) as? Double ?? 3
        hotkeyEnabled = defaults.object(forKey: Keys.hotkeyEnabled) as? Bool ?? true
        let storedCode = defaults.integer(forKey: Keys.hotkeyKeyCode)
        hotkeyKeyCode = UInt32(storedCode == 0 ? 37 : storedCode)
        let storedMods = defaults.integer(forKey: Keys.hotkeyCarbonModifiers)
        hotkeyCarbonModifiers = UInt32(storedMods == 0 ? Int(cmdKey | shiftKey) : storedMods)
        trailEnabled = defaults.object(forKey: Keys.trailEnabled) as? Bool ?? false
        trailDuration = defaults.object(forKey: Keys.trailDuration) as? Double ?? 2.0
        let launchStatus = SMAppService.mainApp.status
        launchAtLogin = launchStatus == .enabled || launchStatus == .requiresApproval

        let red = defaults.double(forKey: Keys.red)
        let green = defaults.double(forKey: Keys.green)
        let blue = defaults.double(forKey: Keys.blue)
        let alpha = defaults.double(forKey: Keys.alpha)
        if defaults.object(forKey: Keys.red) != nil || defaults.object(forKey: Keys.green) != nil {
            ringColor = NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
        } else {
            ringColor = NSColor.systemOrange
        }
    }

    // MARK: - Reset

    func resetSettings() {
        defaults.removePersistentDomain(forName: "com.lookhere.LookHere")
        isEnabled = true
        ringColor = NSColor.systemOrange
        ringRadius = 30
        ringOpacity = 0.85
        ringLineWidth = 3
        hotkeyEnabled = true
        hotkeyKeyCode = 37
        hotkeyCarbonModifiers = UInt32(cmdKey | shiftKey)
        trailEnabled = false
        trailDuration = 2.0
        launchAtLogin = false
    }

    // MARK: - Launch at Login

    /// True when the app is registered as a login item (or awaiting the
    /// user's approval in System Settings).
    var isRegisteredForLaunch: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        guard enabled != isRegisteredForLaunch else { return }
        if enabled {
            try? service.register()
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } else {
            try? service.unregister()
        }
    }

    /// Re-reads the real system state (e.g. after the user toggled the login
    /// item in System Settings directly).
    func syncLaunchAtLogin() {
        let registered = isRegisteredForLaunch
        if launchAtLogin != registered {
            launchAtLogin = registered
        }
    }

    private func persistColor() {
        let nsColor = ringColor.usingColorSpace(NSColorSpace.deviceRGB) ?? ringColor
        defaults.set(nsColor.redComponent, forKey: Keys.red)
        defaults.set(nsColor.greenComponent, forKey: Keys.green)
        defaults.set(nsColor.blueComponent, forKey: Keys.blue)
        defaults.set(nsColor.alphaComponent, forKey: Keys.alpha)
    }

    // MARK: - Hotkey display

    var hotkeyDisplayString: String {
        var parts: [String] = []
        if hotkeyCarbonModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if hotkeyCarbonModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if hotkeyCarbonModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if hotkeyCarbonModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append(HotKeyManager.displayName(for: hotkeyKeyCode))
        return parts.joined()
    }

    func applyHotkey(from event: NSEvent) -> (keyCode: UInt32, carbonModifiers: UInt32)? {
        var carbon: UInt32 = 0
        if event.modifierFlags.contains(.command) { carbon |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.option) { carbon |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { carbon |= UInt32(controlKey) }
        guard carbon != 0 else { return nil }
        return (UInt32(event.keyCode), carbon)
    }

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let red = "ringColor.red"
        static let green = "ringColor.green"
        static let blue = "ringColor.blue"
        static let alpha = "ringColor.alpha"
        static let ringRadius = "ringRadius"
        static let ringOpacity = "ringOpacity"
        static let ringLineWidth = "ringLineWidth"
        static let hotkeyEnabled = "hotkeyEnabled"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyCarbonModifiers = "hotkeyCarbonModifiers"
        static let trailEnabled = "trailEnabled"
        static let trailDuration = "trailDuration"
    }
}