import Foundation
import IOKit.pwr_mgt

final class SleepPreventer {
    static let shared = SleepPreventer()
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var caffeinateProcess: Process?
    private var userActivityTimer: Timer?

    private init() {}

    func preventSleep() {
        let reason = "CyberHorizon Sentry Clamshell Security Active" as CFString

        // 1. Set pmset disablesleep 1 (elevates automatically if not running as root)
        applyPmsetDisableSleep(true)

        // 2. Create System Idle Sleep Assertion
        if systemAssertionID == 0 {
            _ = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &systemAssertionID
            )
        }

        // 3. Create Display Idle Sleep Assertion
        if displayAssertionID == 0 {
            _ = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &displayAssertionID
            )
        }

        // 4. Launch caffeinate helper process
        if caffeinateProcess == nil {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            process.arguments = ["-i", "-s", "-d", "-u", "-w", "\(ProcessInfo.processInfo.processIdentifier)"]
            do {
                try process.run()
                self.caffeinateProcess = process
                print("[Sentry] Caffeinate background helper running (PID: \(process.processIdentifier))")
            } catch {
                print("[Sentry] Failed to launch caffeinate helper: \(error)")
            }
        }

        // 5. Declare continuous high-frequency user activity (every 100ms)
        userActivityTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            IOPMAssertionDeclareUserActivity(
                "Sentry Activity KeepAlive" as CFString,
                kIOPMUserActiveLocal,
                nil
            )
        }

        print("[Sentry] Sleep & Clamshell prevention fully active.")
    }

    func allowSleep() {
        // Restore pmset disablesleep 0
        applyPmsetDisableSleep(false)

        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
        if let process = caffeinateProcess {
            process.terminate()
            caffeinateProcess = nil
        }
        userActivityTimer?.invalidate()
        userActivityTimer = nil
        print("[Sentry] Sleep prevention released.")
    }

    private func applyPmsetDisableSleep(_ disable: Bool) {
        let value = disable ? "1" : "0"

        // Try running pmset directly first
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["-a", "disablesleep", value]
        do {
            try p.run()
            p.waitUntilExit()
            if p.terminationStatus == 0 {
                print("[Sentry] Direct pmset disablesleep \(value) succeeded.")
                return
            }
        } catch {}

        // If direct pmset failed (not root), use osascript authorization prompt
        print("[Sentry] Elevating power management assertions via macOS Security dialog...")
        let script = "do shell script \"pmset -a disablesleep \(value)\" with administrator privileges"
        let adminProc = Process()
        adminProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        adminProc.arguments = ["-e", script]
        try? adminProc.run()
    }
}
