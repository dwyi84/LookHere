# LookHere

A featherweight **macOS menu bar utility** that draws a smooth, zero-lag **halo ring** around your mouse cursor — perfect for presentations, screen recordings, teaching, and live coding.

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://www.swift.org)
[![Platform](https://img.shields.io/badge/macOS-26%2B-1f6feb?logo=apple)](https://www.apple.com/macos)
[![Architecture](https://img.shields.io/badge/Apple%20Silicon-arm64-purple)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-dwyi84d-FFDD00?logo=buymeacoffee&logoColor=black&style=flat-square)](https://buymeacoffee.com/dwyi84d)

---

<img width="372" height="720" alt="lookhere" src="https://github.com/user-attachments/assets/26710ffd-9200-479b-a704-3999a89fcbe3" />

## Features

- **Zero-Lag Halo** — a crisp circular ring that follows your cursor at full display refresh rate (powered by a `CGEvent` tap running on the main run loop; no polling, no latency).
- **Click Ripple Feedback** — subtle expanding ripples animate on every left / right / middle click so your audience always sees where you clicked.
- **Laser Trail Mode** — optionally leave a smooth, tapering neon laser trail behind the cursor (0.5–5s) that thins and fades out, perfect for laser-pointer-style highlighting.
- **One-Click Auto-Update** — LookHere checks GitHub Releases silently at launch, and "Check for Updates" (settings header or right-click menu) queries it on demand. When a newer version is found it downloads, replaces the running app in place, and relaunches — all from one click.
- **Click-Through Overlay** — fully transparent, borderless, and set to `ignoresMouseEvents`, so it never blocks a single click.
- **Runs Above Everything** — stays on top of every window, full-screen app, and every Space.
- **Menu Bar Settings (SwiftUI)** — toggle highlight on/off, pick from preset ring colors, and tune radius, opacity, and line thickness — all applied **live** with a built-in preview.
- **Global Hotkey** — press `⇧⌘L` anywhere to toggle the highlight, or record your own shortcut right from the menu.
- **Accessibility-Aware** — detects the required permission and guides you to grant it in one click. A stable local signing identity keeps the grant valid across rebuilds.
- **Reset** — restore every setting to its default with one click.
- **Tiny & Private** — a single self-contained binary, ~1 MB. No analytics, no tracking, no network access.

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon (arm64)
- Xcode Command Line Tools (for the Swift toolchain)

## Installation

Clone the repository and build:

```bash
git clone https://github.com/dwyi84/LookHere.git
cd LookHere
./build.sh
```

`build.sh` compiles the app with Swift Package Manager, assembles `LookHere.app` (with an `LSUIElement` bundle so it lives quietly in the menu bar), generates the app icon, ad-hoc signs it, and launches it.

## First Run

1. On first launch, macOS will ask for **Accessibility** permission.
   System Settings → **Privacy & Security → Accessibility** → enable **LookHere**.
2. The halo appears the moment you move your mouse. Click the orange ring icon in the menu bar to open Settings.

> The accessibility permission is required because macOS only lets trusted apps observe the global mouse position. LookHere uses it **exclusively** to read the cursor location — it never reads other apps' UI, keystrokes, or personal data.

## Usage

| Action | Result |
| --- | --- |
| Move mouse | Halo ring follows the cursor |
| Left / right / middle click | Ripple animation at the click point |
| `⇧⌘L` (default) | Toggle highlight on / off |
| Menu bar icon → Settings | Tweak color, radius, opacity, thickness |
| Menu bar icon → right-click | Highlight toggle · Launch at Login · Check for Updates · Settings · Quit |

## Settings

- **Enable Highlight** — master on/off switch.
- **Live Preview** — the ring renders in the settings panel as you adjust it.
- **Ring Color** — choose from preset swatches; changes apply instantly.
- **Radius** — ring size in points.
- **Opacity** — ring transparency.
- **Thickness** — ring stroke width.
- **Laser Trail** — toggle a smooth tapering neon laser trail and set how long it lasts (0.5–5s).
- **Global Hotkey** — toggle the shortcut, or click the hotkey button to record a new one.
- **Check for Updates** — the header shows the current version with a button that downloads and installs newer releases in one click. LookHere also checks silently at every launch and flags updates in the header.
- **Accessibility Permission** — current status plus a shortcut to System Settings.
- **Reset** — restore all settings to their defaults.

All settings are saved automatically and restored on next launch.

## Development

Pure Swift Package Manager — no Xcode project required:

```bash
swift build -c release   # compile
./build.sh               # build, bundle, sign, launch
```

```
Sources/LookHere/
├── main.swift               # App bootstrap
├── AppDelegate.swift        # Menu bar item, popover, lifecycle
├── SettingsStore.swift      # Persisted settings (UserDefaults)
├── OverlayController.swift  # Per-screen overlay window management
├── OverlayWindow.swift      # Borderless, click-through NSPanel
├── HaloLayerView.swift      # Ring + ripple rendering (Core Animation)
├── MouseTracker.swift       # CGEvent tap → cursor / click callbacks
├── HotKeyManager.swift      # Carbon global hotkey registration
├── AccessibilityHelper.swift# Accessibility permission helpers
└── SettingsView.swift       # SwiftUI settings panel
```

## Privacy

LookHere is fully offline. It collects nothing, uploads nothing, and only watches the mouse cursor position while the highlight is enabled.

## License

Released under the [MIT License](LICENSE).

## Support

If LookHere makes your presentations or videos easier to follow, consider buying me a coffee — it keeps the ring glowing. ☕

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-dwyi84d-FFDD00?logo=buymeacoffee&logoColor=black&style=for-the-badge)](https://buymeacoffee.com/dwyi84d)

<p align="center">Crafted by MelissaSoft · Made with ❤️ on Apple Silicon.</p>
<p align="center">Copyright © 2026 Dawoon Yi. All rights reserved.</p>
