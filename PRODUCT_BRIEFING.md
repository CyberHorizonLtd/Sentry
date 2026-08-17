# Product Capability Briefing & Market Strategy Analysis
**Product Name:** CyberHorizon Sentry  
**Developer:** CyberHorizon Ltd  
**Platform:** macOS 13.0+ (Native Apple Silicon & Intel)  
**Target Market:** Remote Workers, Digital Nomads, Corporate Professionals, University Students  

---

## Executive Summary

**CyberHorizon Sentry** is a native macOS physical anti-theft and laptop protection utility engineered to solve a widespread problem: **leaving a MacBook unattended in public or semi-public spaces** (coffee shops, airport lounges, libraries, co-working spaces). 

Standard macOS security features (such as `Cmd + Ctrl + Q` screen lock) lock the user account, but operate **silently**. A thief can easily close the lid, unplug the power cable, and walk away with the hardware unnoticed. 

CyberHorizon Sentry turns the MacBook into an active physical security sentry. Upon arming, it obscures display content behind a glassmorphic blur overlay, hides all input fields, monitors hardware state changes, and immediately activates a **maximum volume police siren through internal speakers** if any unauthorized interaction or physical movement occurs.

---

## Technical Capabilities & Architecture Matrix

| Feature / Module | Capability Description | Technical Implementation |
| :--- | :--- | :--- |
| **Glassmorphic Lock Screen** | Obscures all connected displays with an active backdrop blur. Content is visible as abstract shapes behind dark frosted glass, keeping the desktop private while signaling active protection. | AppKit `NSVisualEffectView` (`.hudWindow` material) across all `NSScreen.screens` at `.statusBar` floating window level. |
| **Stealth Passcode Engine** | Zero input boxes, text fields, or visual typing feedback. The user simply types their passcode on the keyboard to unlock. | State-machine character matching in Swift (`PasscodeManager`). Supports uppercase (`Shift` + letter), numbers, and special symbols. |
| **Amphetamine-Style Power Control** | Prevents macOS from going to sleep when the lid is closed, allowing Sentry to remain 100% active in clamshell mode. | IOKit Power Management (`IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleSystemSleep`) & periodic `IOPMAssertionDeclareUserActivity`. |
| **Direct Speaker Siren Routing** | If AirPods or Bluetooth headphones are connected, the alarm **bypasses headphones** and blasts directly through the **MacBook's built-in internal speakers** at **100% MAX volume**. | CoreAudio hardware registry scan for `kAudioDeviceTransportTypeBuiltIn` (`'bltn'`). `AVAudioEngine` output AudioUnit forced binding (`kAudioOutputUnitProperty_CurrentDevice`). Continuous 200ms volume locking. |
| **Lid Angle & Clamshell Sensor** | Detects lid closure or angle manipulation and immediately triggers alarm siren. | IOKit `AppleClamshellState` polling & `NSWorkspace.screensDidSleepNotification` / `willSleepNotification` observers. |
| **Charger Unplugged Sensor** | Triggers alarm immediately if the MagSafe or USB-C power cable is disconnected. | IOKit Power Source Monitoring (`IOPSCopyPowerSourcesInfo` & `kIOPSIsChargingKey`). |
| **Cursor / Touchpad Tamper Sensor** | Triggers alarm on any mouse cursor displacement (> 4px) or click/scroll event. | `NSEvent` tracking & HID delta calculations. |
| **Shortcut & Modifier Security** | Pressing `Cmd`, `Ctrl`, or `Option` or attempting shortcuts (`Cmd+Tab`, `Cmd+Q`, `Cmd+Space`, `Cmd+Alt+Esc`) immediately trips alarm. | `NSEvent.EventType.flagsChanged` & modifier flag bitmask inspection. |
| **Configuration Engine** | Flexible passcode loading from `.env` file, command-line arguments, system environment variables, or terminal prompt. | Custom `.env` parser (`DotEnvLoader.swift`). |
| **Brand Assets** | Embedded CyberHorizon Ltd vector branding with automatic local `favicon.png` logo rendering. | AppKit `NSImageView` & Quartz 2D graphics rendering. |

---

## Competitive Landscape Comparison

| Feature | CyberHorizon Sentry | Native macOS Lock (`Cmd+Ctrl+Q`) | Amphetamine / Caffeine | Legacy Alarm Apps (iAlertU) |
| :--- | :---: | :---: | :---: | :---: |
| **Physical Theft Deterrent (Siren)** | **YES (Max Vol)** | NO (Silent) | NO (None) | YES (Outdated) |
| **Bypasses Headphones to Built-in Speakers** | **YES** | N/A | N/A | NO (Plays to AirPods) |
| **Prevents Sleep with Lid Closed** | **YES** | NO | YES | NO |
| **Stealth Passcode Entry (No Input Field)** | **YES** | NO (Shows Login UI) | N/A | NO |
| **Charger Unplugged Detection** | **YES** | NO | NO | Partial |
| **Apple Silicon (M1/M2/M3/M4) Native** | **YES** | YES | YES | NO (Intel Only) |

---

## Strategic Commercial Options for Market Analyst Evaluation

### Option A: Open-Core Model (Recommended)
- **Open-Source Core Engine (GitHub)**: Free CLI binary (`./Sentry` / `brew install cyberhorizon-sentry`). Builds trust in the security developer community, eliminates keylogger concerns, and drives viral GitHub / Reddit awareness.
- **Paid Mac App Store "Sentry Pro" ($4.99 – $9.99 One-time)**: Commercial GUI wrapper with Menu Bar controls, Apple Watch / Touch ID disarm, custom siren sounds, and remote iPhone alert webhooks (Telegram / Push notifications).
- **Target Revenue**: $10,000 – $50,000 ARR with zero ad-spend due to viral open-source traction.

### Option B: Commercial Desktop Application (Paid Only)
- **Distribution**: Sold via Mac App Store & LemonSqueezy / Paddle ($9.99 purchase or $1.99/mo subscription).
- **Pros**: Direct monetization from day one.
- **Cons**: High marketing friction; closed-source security utilities face user skepticism without independent code audit.

### Option C: Enterprise B2B Lead Magnet (100% Free Open Source)
- **Distribution**: Released 100% free under MIT License by CyberHorizon Ltd.
- **Strategic Goal**: Position CyberHorizon Ltd as an elite macOS & cybersecurity consulting firm. Drives B2B client acquisition for penetration testing and corporate security contracts.

---

## Security, Privacy & Compliance Profile

1. **100% Local Processing**: Sentry makes zero external network calls. All authentication occurs in local memory.
2. **Zero Passcode Storage**: The passcode is evaluated transiently in RAM via `PasscodeManager` and is never written to disk or telemetry logs.
3. **Non-Destructive Teardown**: Releasing Sentry cleans up all `IOPMAssertion` locks, unhides the cursor, and restores default audio configuration.

---

*Document compiled by CyberHorizon Engineering Team for Executive Market Analysis.*
