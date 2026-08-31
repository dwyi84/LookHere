import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var rightClickMenu: NSMenu!

    private var overlayController: OverlayController!
    private var mouseTracker: MouseTracker?
    private let hotkeyManager = HotKeyManager()
    private var cancellables = Set<AnyCancellable>()
    private var accessibilityPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = NSMenu()

        setupStatusItem()
        setupPopover()

        overlayController = OverlayController(settings: settings)
        overlayController.updateVisuals()

        if AccessibilityHelper.isTrusted() {
            startTracking()
        } else {
            AccessibilityHelper.promptForAccessibility()
            startAccessibilityPolling()
        }

        hotkeyManager.setHandler { [weak self] in
            self?.settings.isEnabled.toggle()
        }
        settings.$isEnabled
            .sink { [weak self] enabled in
                self?.overlayController.setEnabled(enabled)
            }
            .store(in: &cancellables)
        settings.$hotkeyEnabled
            .combineLatest(settings.$hotkeyKeyCode, settings.$hotkeyCarbonModifiers)
            .sink { [weak self] enabled, keyCode, modifiers in
                self?.hotkeyManager.unregister()
                if enabled {
                    self?.hotkeyManager.register(keyCode: keyCode, modifiers: modifiers)
                }
            }
            .store(in: &cancellables)

        // Each sink passes the freshly-emitted value straight through.
        // Reading a just-mutated @Published property inside a sink returns the
        // previous value (the setter notifies before updating storage), which
        // is what caused colors to apply one tap behind.
        settings.$ringColor
            .sink { [weak self] color in
                self?.overlayController.updateVisuals(color: color)
            }
            .store(in: &cancellables)
        settings.$ringRadius
            .sink { [weak self] radius in
                self?.overlayController.updateVisuals(radius: CGFloat(radius))
            }
            .store(in: &cancellables)
        settings.$ringOpacity
            .sink { [weak self] opacity in
                self?.overlayController.updateVisuals(opacity: opacity)
            }
            .store(in: &cancellables)
        settings.$ringLineWidth
            .sink { [weak self] lineWidth in
                self?.overlayController.updateVisuals(lineWidth: CGFloat(lineWidth))
            }
            .store(in: &cancellables)
        settings.$trailEnabled
            .sink { [weak self] enabled in
                self?.overlayController.updateVisuals(trailEnabled: enabled)
            }
            .store(in: &cancellables)
        settings.$trailDuration
            .sink { [weak self] duration in
                self?.overlayController.updateVisuals(trailDuration: duration)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterAll()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        let icon = NSImage(systemSymbolName: "circle.circle", accessibilityDescription: "LookHere")
        icon?.isTemplate = true
        button.image = icon

        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        rightClickMenu = NSMenu()
        rightClickMenu.addItem(
            withTitle: settings.isEnabled ? "Hide Highlight" : "Show Highlight",
            action: #selector(toggleHighlight),
            keyEquivalent: ""
        )
        rightClickMenu.addItem(.separator())
        rightClickMenu.addItem(
            withTitle: "Settings…",
            action: #selector(showSettings),
            keyEquivalent: ""
        )
        rightClickMenu.addItem(.separator())
        rightClickMenu.addItem(
            withTitle: "Quit LookHere",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        let hosting = NSHostingController(rootView: SettingsView(settings: settings))
        popover.contentViewController = hosting

        let fitting = hosting.view.fittingSize
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 800
        let targetHeight = min(fitting.height, screenHeight - 80)
        popover.contentSize = NSSize(width: 300, height: max(targetHeight, 150))
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem.menu = rightClickMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }

    @objc private func toggleHighlight() {
        settings.isEnabled.toggle()
        rightClickMenu.item(at: 0)?.title = settings.isEnabled ? "Hide Highlight" : "Show Highlight"
    }

    @objc private func showSettings() {
        togglePopover(forceShow: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func togglePopover(forceShow: Bool = false) {
        guard let button = statusItem.button else { return }
        if popover.isShown && !forceShow {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Tracking

    func startTracking() {
        guard mouseTracker == nil else { return }
        mouseTracker = MouseTracker(
            onMove: { [weak self] location in
                self?.overlayController.updateCursor(location)
            },
            onPress: { [weak self] location in
                self?.overlayController.spawnRipple(at: location)
            }
        )
        mouseTracker?.start()
    }

    private func startAccessibilityPolling() {
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if AccessibilityHelper.isTrusted() {
                    self.accessibilityPollTimer?.invalidate()
                    self.accessibilityPollTimer = nil
                    self.startTracking()
                    NotificationCenter.default.post(name: .accessibilityStatusChanged, object: nil)
                }
            }
        }
        if let timer = accessibilityPollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    @objc private func screensChanged() {
        overlayController.rebuildForScreens()
    }
}

extension Notification.Name {
    static let accessibilityStatusChanged = Notification.Name("LookHere.accessibilityStatusChanged")
}