import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @StateObject private var hotkeyRecorder = HotkeyRecorder()
    @State private var accessibilityGranted = AccessibilityHelper.isTrusted()
    @State private var showResetConfirm = false
    @State private var updateState: UpdateState = .idle
    @State private var pendingUpdate: ReleaseInfo?
    @State private var showUpdateConfirm = false

    private enum UpdateState: Equatable {
        case idle
        case checking
        case downloading
        case upToDate
        case updateAvailable
        case failed
    }

    private let coffeeURL = URL(string: "https://buymeacoffee.com/dwyi84d")!

    private let presetColors: [NSColor] = [
        NSColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1),       // orange
        NSColor(red: 0.918, green: 0.231, blue: 0.188, alpha: 1),   // red
        NSColor(red: 1.0, green: 0.177, blue: 0.333, alpha: 1),     // pink
        NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1),   // purple
        NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1),       // blue
        NSColor(red: 0.353, green: 0.784, blue: 0.98, alpha: 1),    // cyan
        NSColor(red: 0.188, green: 0.663, blue: 0.639, alpha: 1),   // teal
        NSColor(red: 0.208, green: 0.788, blue: 0.349, alpha: 1),   // green
        NSColor(red: 1.0, green: 0.843, blue: 0.0, alpha: 1),       // yellow
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1),         // white
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(alignment: .leading, spacing: 18) {
                highlightSection
                trailSection
                hotkeySection
                accessibilitySection
            }
            .padding(16)

            Divider()
            footer
        }
        .frame(width: 300)
        .onAppear {
            accessibilityGranted = AccessibilityHelper.isTrusted()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityStatusChanged)) { _ in
            accessibilityGranted = AccessibilityHelper.isTrusted()
        }
        .confirmationDialog(
            "Reset all settings to defaults?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                settings.resetSettings()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Update to v\(pendingUpdate?.version ?? "")?",
            isPresented: $showUpdateConfirm,
            titleVisibility: .visible
        ) {
            Button("Update Now") {
                confirmAndInstall()
            }
            Button("Cancel", role: .cancel) {
                updateState = .idle
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            headerMark
            Text("LookHere")
                .font(.headline)
            Text("v\(UpdateChecker.currentVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            updateIndicator
                .frame(height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var headerMark: some View {
        ZStack {
            Circle()
                .stroke(Color(nsColor: settings.ringColor), lineWidth: 2.5)
                .frame(width: 18, height: 18)
            CursorShape()
                .fill(Color.black)
                .overlay(CursorShape().stroke(Color.white, lineWidth: 1))
                .frame(width: 7.4, height: 12)
                .offset(x: 0.5, y: 0.5)
        }
    }

    @ViewBuilder
    private var updateIndicator: some View {
        switch updateState {
        case .idle:
            Button("Check for Updates") {
                checkForUpdates()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Check for updates")
        case .checking:
            ProgressView()
                .controlSize(.mini)
                .help("Checking for updates…")
        case .downloading:
            ProgressView()
                .controlSize(.mini)
                .help("Downloading update…")
        case .upToDate:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle")
                Text("Up to date")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        case .updateAvailable:
            Button("Update Available") {
                showUpdateConfirm = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Update available")
        case .failed:
            Button("Check Again") {
                checkForUpdates()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Check for updates again")
        }
    }

    // MARK: - Highlight

    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel(title)
        }
    }

    private var highlightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            switchRow("Enable Highlight", isOn: $settings.isEnabled)

            VStack(alignment: .leading, spacing: 6) {
                Text("Ring Color")
                    .font(.subheadline.weight(.medium))
                colorSwatches
            }

            sliderRow(title: "Radius", value: $settings.ringRadius, range: 12...60, step: 1) {
                "\(Int($0.rounded())) pt"
            }
            sliderRow(title: "Opacity", value: $settings.ringOpacity, range: 0.15...1.0, step: 0.05) {
                "\(Int(($0 * 100).rounded()))%"
            }
            sliderRow(title: "Thickness", value: $settings.ringLineWidth, range: 1...8, step: 0.5) {
                String(format: "%.1f pt", $0)
            }
        }
    }

    private var colorSwatches: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(presetColors, id: \.self) { color in
                let isSelected = isSameColor(settings.ringColor, color)
                Button {
                    settings.ringColor = color
                } label: {
                    Circle()
                        .fill(Color(nsColor: color))
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.accentColor : Color.gray.opacity(0.2),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 30, height: 30)
            }
        }
    }

    private func isSameColor(_ a: NSColor, _ b: NSColor) -> Bool {
        let a = a.usingColorSpace(NSColorSpace.deviceRGB) ?? a
        let b = b.usingColorSpace(NSColorSpace.deviceRGB) ?? b
        return abs(a.redComponent - b.redComponent) < 0.01
            && abs(a.greenComponent - b.greenComponent) < 0.01
            && abs(a.blueComponent - b.blueComponent) < 0.01
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        display: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(display(value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    // MARK: - Trail

    private var trailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            switchRow("Laser Trail", isOn: $settings.trailEnabled)

            sliderRow(title: "Trail Duration", value: $settings.trailDuration, range: 0.5...5.0, step: 0.5) {
                String(format: "%.1fs", $0)
            }
        }
    }

    // MARK: - Hotkey

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            switchRow("Global Hotkey", isOn: $settings.hotkeyEnabled)

            HStack {
                Text("Toggle Highlight")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: hotkeyRecorder.isRecording ? {} : startRecording) {
                    Text(hotkeyRecorder.isRecording ? "Press keys…" : settings.hotkeyDisplayString)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(hotkeyRecorder.isRecording ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!settings.hotkeyEnabled)
            }
        }
    }

    private func startRecording() {
        hotkeyRecorder.begin(store: settings) { [weak hotkeyRecorder] in
            hotkeyRecorder?.finish()
        }
    }

    // MARK: - Updates

    private func checkForUpdates() {
        updateState = .checking
        Task {
            if let release = await UpdateChecker.checkForUpdates() {
                if UpdateChecker.isNewer(release.version) {
                    pendingUpdate = release
                    updateState = .updateAvailable
                    showUpdateConfirm = true
                } else {
                    updateState = .upToDate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        if self.updateState == .upToDate {
                            self.updateState = .idle
                        }
                    }
                }
            } else {
                updateState = .failed
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    if self.updateState == .failed {
                        self.updateState = .idle
                    }
                }
            }
        }
    }

    private func confirmAndInstall() {
        guard let release = pendingUpdate, let assetURL = release.assetURL else {
            updateState = .failed
            return
        }
        updateState = .downloading
        Task {
            do {
                let zipURL = try await UpdateChecker.downloadAsset(from: assetURL)
                UpdateChecker.installAndRelaunch(zipURL: zipURL)
            } catch {
                updateState = .failed
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accessibility Permission")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 6) {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(accessibilityGranted ? Color.green : Color.orange)
                Text(accessibilityGranted
                     ? "Granted — cursor tracking active."
                     : "Required to track the cursor globally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !accessibilityGranted {
                Button("Open System Settings…") {
                    AccessibilityHelper.openSystemSettings()
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Link(destination: coffeeURL) {
                    HStack(spacing: 6) {
                        Text("☕")
                        Text("Buy me a coffee")
                            .font(.callout.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 1.0, green: 0.87, blue: 0.0))
                    )
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Reset") {
                    showResetConfirm = true
                }
                .controlSize(.small)
                .help("Reset all settings to defaults")

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .controlSize(.small)
            }

            Text("Crafted by MelissaSoft")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct CursorShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let points: [(CGFloat, CGFloat)] = [
                (0.000, 0.000),
                (0.000, 0.900),
                (0.350, 0.692),
                (0.563, 1.000),
                (0.788, 0.938),
                (0.575, 0.638),
                (1.000, 0.638),
            ]
            for (i, p) in points.enumerated() {
                let pt = CGPoint(x: p.0 * rect.width, y: p.1 * rect.height)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
        }
    }
}

@MainActor
final class HotkeyRecorder: ObservableObject {
    @Published var isRecording = false

    private var monitor: Any?
    private var onComplete: (() -> Void)?

    func begin(store: SettingsStore, onComplete: @escaping () -> Void) {
        guard monitor == nil else { return }
        self.onComplete = onComplete
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            if event.keyCode == 53 {
                self.finish()
                return nil
            }

            guard let combo = store.applyHotkey(from: event) else {
                return nil
            }

            store.hotkeyKeyCode = combo.keyCode
            store.hotkeyCarbonModifiers = combo.carbonModifiers
            self.finish()
            return nil
        }
    }

    func finish() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        let completion = onComplete
        onComplete = nil
        completion?()
    }
}