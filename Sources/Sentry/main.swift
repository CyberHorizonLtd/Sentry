import Foundation
import AppKit

private var strongAppDelegate: SentryApp?

final class SentryApp: NSObject, NSApplicationDelegate {
    private var windows: [SentryOverlayWindow] = []
    private var passcodeManager: PasscodeManager!
    private let eventMonitor = EventMonitor()
    private var isAlarmTriggered = false
    private var focusLockTimer: Timer?
    private let isTestingMode: Bool

    init(passcodeHashes: [String], isTestingMode: Bool) {
        self.isTestingMode = isTestingMode
        super.init()
        self.passcodeManager = PasscodeManager(hashes: passcodeHashes)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[Sentry] Activating frontmost application focus...")
        claimFocus()

        // 1. Automatically re-claim focus if another app tries to become active
        NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.claimFocus()
        }

        // 2. Automatically re-claim focus when system / screens wake up (e.g. lid opened)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            print("[Sentry] System woke up! Re-claiming focus...")
            self?.claimFocus()
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            print("[Sentry] Screens woke up! Re-claiming focus...")
            self?.claimFocus()
        }

        // 3. Periodic focus lock timer while armed (prevents focus loss on lid open)
        focusLockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if !NSApp.isActive {
                self?.claimFocus()
            }
        }

        print("[Sentry] Creating security overlay windows across \(NSScreen.screens.count) screen(s)...")

        // Create overlay windows across all screens
        for (index, screen) in NSScreen.screens.enumerated() {
            print("[Sentry] Creating overlay window #\(index + 1)...")
            let window = SentryOverlayWindow(screen: screen)
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
            window.makeMain()
            windows.append(window)
        }

        print("[Sentry] Hiding cursor...")
        DispatchQueue.main.async {
            NSCursor.hide()
            self.claimFocus()
        }

        // Configure Raw Input Monitoring
        print("[Sentry] Starting event monitor...")
        eventMonitor.onKeyTyped = { [weak self] char in
            self?.handleTypedCharacter(char)
        }
        eventMonitor.onTamperDetected = { [weak self] in
            self?.triggerAlarm(reason: "Input Tamper (Mouse / Invalid Key)")
        }
        eventMonitor.startMonitoring()

        // Configure Hardware Sensors Monitoring
        print("[Sentry] Starting hardware sensors monitor...")
        SensorsManager.shared.onTamperDetected = { [weak self] in
            self?.triggerAlarm(reason: "Hardware Tamper (Lid / Power)")
        }
        SensorsManager.shared.startMonitoring()

        print("\n=======================================================")
        print(" [SENTRY] CyberHorizon Sentry ARMED & ACTIVE")
        if isTestingMode {
            print(" [MODE]   🧪 TESTING = true (Silent Visual Alarm Only)")
        } else {
            print(" [MODE]   🔊 PRODUCTION (Full 100% Volume Audio Siren)")
        }
        print(" [SENTRY] Stealth SHA-256 passcode protection running...")
        print("=======================================================\n")
    }

    private func claimFocus() {
        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
            window.makeMain()
        }
    }

    private func handleTypedCharacter(_ char: String) {
        let result = passcodeManager.processCharacter(char)
        switch result {
        case .matchingNext:
            // Silent progress, no visual response
            break
        case .unlocked:
            print("[Sentry] Valid passcode entered! Unlocking Sentry...")
            disarmAndExit()
        case .wrongKey:
            triggerAlarm(reason: "Wrong Key Pressed ('\(char)')")
        }
    }

    private func triggerAlarm(reason: String) {
        guard !isAlarmTriggered else { return }
        isAlarmTriggered = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for window in self.windows {
                window.showTriggeredStatus(reason: reason, isTestMode: self.isTestingMode)
            }
        }

        if isTestingMode {
            print("\n[ALARM - TEST MODE] 🚨 TRIGGERED (SILENT): Reason: \(reason)")
            print("[Sentry] Audio muted due to TESTING=true in .env file.")
        } else {
            print("\n[ALARM] 🚨 SIREN ACTIVATED! Reason: \(reason)")
            SirenEngine.shared.startAlarm()
        }
    }

    private func disarmAndExit() {
        print("[Sentry] Disarming Sentry security engine...")

        focusLockTimer?.invalidate()
        focusLockTimer = nil

        // 1. Instantly stop sound and sensor monitoring
        SirenEngine.shared.stopAlarm()
        SensorsManager.shared.stopMonitoring()
        eventMonitor.stopMonitoring()

        // 2. Perform main queue UI teardown and exit cleanly
        DispatchQueue.main.async { [weak self] in
            NSCursor.unhide()

            if let windows = self?.windows {
                for window in windows {
                    window.orderOut(nil)
                    window.close()
                }
            }
            self?.windows.removeAll()

            print("[Sentry] Disarmed successfully. Goodbye!")
            fflush(stdout)

            NSApp.terminate(nil)
            exit(0)
        }
    }
}

private func promptForPasscodeGUI() -> String? {
    let alert = NSAlert()
    alert.messageText = "CyberHorizon Sentry Setup"
    alert.informativeText = "Please enter the passcode you will type to unlock your MacBook. This will be saved as SHA-256 hashes to ~/.sentry/.env for future launches."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Save & Arm Sentry")
    alert.addButton(withTitle: "Cancel")

    let inputField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    inputField.placeholderString = "Enter unlock passcode"
    alert.accessoryView = inputField

    NSApp.activate(ignoringOtherApps: true)
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
    return nil
}

// Entry Point logic
func main() {
    let args = CommandLine.arguments
    var hashes: [String]? = nil

    // 1. Command Line Argument
    if args.count > 1 {
        let plain = args[1]
        hashes = PasscodeManager.generateHashes(for: plain)
        print("[Sentry] Passcode loaded from command line argument.")
    }

    // 2. Load Hashes from ~/.sentry/.env or dev file
    if hashes == nil {
        hashes = DotEnvLoader.loadPasscodeHashes()
    }

    // 3. Environment Variable
    if hashes == nil {
        if let sysEnv = ProcessInfo.processInfo.environment["SENTRY_PASSWORD"] ?? ProcessInfo.processInfo.environment["PASSWORD"] {
            hashes = PasscodeManager.generateHashes(for: sysEnv)
            print("[Sentry] Passcode loaded from system environment variable.")
        }
    }

    // 4. GUI / Terminal Prompt Fallback
    if hashes == nil || hashes!.isEmpty {
        var rawPasscode: String? = nil
        if isatty(STDIN_FILENO) != 0 {
            print("CyberHorizon Sentry - Laptop Security & Anti-Theft Guard")
            print("---------------------------------------------------------")
            print("Set your unlock passcode: ", terminator: "")
            fflush(stdout)
            
            if let input = readLine(), !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rawPasscode = input.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            // Prompt GUI Modal for App Bundle / Finder launch
            print("[Sentry] Prompting user for passcode via GUI modal...")
            rawPasscode = promptForPasscodeGUI()
        }

        // Save entered passcode as prefix SHA-256 hashes to ~/.sentry/.env
        if let enteredPasscode = rawPasscode, !enteredPasscode.isEmpty {
            DotEnvLoader.savePasscodeToUserHome(enteredPasscode)
            hashes = PasscodeManager.generateHashes(for: enteredPasscode)
        }
    }

    guard let finalHashes = hashes, !finalHashes.isEmpty else {
        print("[Sentry] No passcode provided or setup cancelled. Exiting.")
        exit(0)
    }

    let isTestingMode = DotEnvLoader.loadTestingMode()

    print("[Sentry] Starting AppKit event loop...")
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    
    strongAppDelegate = SentryApp(passcodeHashes: finalHashes, isTestingMode: isTestingMode)
    app.delegate = strongAppDelegate
    
    app.activate(ignoringOtherApps: true)
    app.run()
}

main()
