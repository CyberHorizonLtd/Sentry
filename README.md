# CyberHorizon Sentry 🛡️

[![macOS](https://img.shields.io/badge/platform-macOS%2013%2B-blue.svg)](https://apple.com/macos)
[![Architecture](https://img.shields.io/badge/architecture-Apple%20Silicon%20%7C%20Intel-brightgreen.svg)]()
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Developed By](https://img.shields.io/badge/developed--by-CyberHorizon%20Ltd-cyan.svg)](https://cyberhorizon.hu)

**CyberHorizon Sentry** is a high-performance native macOS physical security and anti-theft application written in Swift/C++. It is designed to let users safely leave their MacBook unattended and unlocked in public spaces (coffee shops, libraries, airport lounges, co-working spaces).

---

## 🌟 Key Features

* **🛡️ Stealth Passcode Engine**: Zero input boxes or text fields. The user simply types their pre-set passcode directly on the keyboard to unlock.
* **🔊 Direct Built-in Speaker Siren**: Overrides connected AirPods or Bluetooth headphones and routes a synthesized dual-tone siren directly through the **MacBook's physical internal speakers** at **100% MAX volume**.
* **☕ Amphetamine-Style Clamshell Keep-Alive**: Prevents macOS system and display sleep when the lid is closed (`IOPMAssertion` & `caffeinate`).
* **📐 Lid Angle & Hinge Sensor**: Detects lid movements, hinge angle shifts, and screen tilt via low-level Apple SPU HID report tracking (`IOHIDManager`).
* **🔌 Power Cable Unplugged Alarm**: Triggers an instant alarm if the MagSafe or USB-C charging cable is disconnected.
* **🖱️ Touchpad & Cursor Protection**: Instantly trips alarm on any mouse cursor displacement (> 4px) or click event.
* **🔑 Modifier & Shortcut Guard**: Trips alarm if `Cmd`, `Ctrl`, `Option`, or system shortcuts (`Cmd+Tab`, `Cmd+Q`, `Cmd+Alt+Esc`) are pressed.
* **🧪 Testing Mode**: Set `TESTING=true` in `.env` for silent visual testing without loud audio.

---

## 🚀 Quick Start

### 1. Build from Source
Ensure you have Xcode Command Line Tools installed:
```bash
make
```
*(This builds the native binary `./Sentry`, packages `CyberHorizon Sentry.app`, and generates `CyberHorizonSentry.dmg`)*

### 2. Configure `.env`
Create a `.env` file in the project directory:
```env
# Lockscreen Unlock Passcode
SENTRY_PASSWORD=cyberhorizon123

# Set to true for silent visual testing (no loud audio)
TESTING=false
```

### 3. Run & Arm
Run Sentry directly from terminal:
```bash
./Sentry
```
> **Note**: To prevent macOS from sleeping when the lid is closed on battery power, elevated power management assertions are automatically requested via native macOS Security dialog.

---

## 📦 Packaging & Distribution

* **Build App Bundle**:
  ```bash
  make app
  ```
  *(Creates `CyberHorizon Sentry.app` with custom icon and `Info.plist`)*

* **Generate Installable `.dmg` Disk Image**:
  ```bash
  make dmg
  ```
  *(Creates `CyberHorizonSentry.dmg` for distribution)*

---

## ⚙️ Configuration Options

| Source | Parameter | Description |
| :--- | :--- | :--- |
| **`.env` file** | `SENTRY_PASSWORD=...` | Pre-set unlock passcode sequence |
| **`.env` file** | `TESTING=true` / `false` | Enable silent visual alarm testing |
| **CLI Argument** | `./Sentry yourpasscode` | Set passcode via command-line argument |
| **Environment Variable** | `export SENTRY_PASSWORD=...` | Set passcode via environment variable |

---

## 🏛️ Codebase Architecture

```
Sources/Sentry/
├── main.swift                 # AppKit entry point, focus-lock timer & lifecycle
├── SentryOverlayWindow.swift  # Glassmorphic multi-monitor backdrop & branding UI
├── PasscodeManager.swift      # Stealth state-machine keypress matching
├── EventMonitor.swift         # Raw HID keyboard, modifier flag & mouse tracking
├── SensorsManager.swift       # IOKit power, charger, lid & SPU motion sensors
├── SleepPreventer.swift       # IOPMAssertion & caffeinate clamshell keep-alive
├── SirenEngine.swift          # CoreAudio built-in speaker routing & max volume synthesizer
└── DotEnvLoader.swift         # Custom .env configuration parser
```

---

## 🔒 Security & Privacy

1. **100% Local Processing**: Zero external network transmission.
2. **RAM-Only Passcode Matching**: Passcode evaluation occurs strictly in local memory and is never logged to disk or telemetry.

---

## 📜 License

Distributed under the **Apache 2.0 License**. See [`LICENSE`](LICENSE) for more information.

Developed with ❤️ by **CyberHorizon Ltd** ([cyberhorizon.hu](https://cyberhorizon.hu)).
