import Foundation
import AppKit
import IOKit
import IOKit.pwr_mgt
import IOKit.ps
import IOKit.hid
import CoreGraphics

private var globalSensorsManagerInstance: SensorsManager?

final class SensorsManager {
    static let shared = SensorsManager()

    var onTamperDetected: (() -> Void)?

    private var initialClamshellState: Bool?
    private var initialPowerSourceState: String?
    private var initialIsCharging: Bool?
    private var timer: Timer?
    private var notifyPort: IONotificationPortRef?
    private var isDisplayReconfigRegistered = false
    private var isArmingGracePeriod = true
    private var hidManager: IOHIDManager?
    private var lastHIDReportBytes: [UInt8] = []

    private init() {
        globalSensorsManagerInstance = self
    }

    func startMonitoring() {
        isArmingGracePeriod = true
        initialClamshellState = currentClamshellState()
        initialPowerSourceState = currentPowerSourceState()
        initialIsCharging = currentIsChargingState()

        print("[Sentry] Hardware Sensors Arming (Grace Period 2.0s)... Lid Closed: \(initialClamshellState ?? false), Power: \(initialPowerSourceState ?? "Unknown"), Charging: \(initialIsCharging ?? false)")

        // Prevent Mac from sleeping when lid is closed (Amphetamine style)
        SleepPreventer.shared.preventSleep()

        // 1. CoreGraphics Display Reconfiguration Callback (Fires on display lid angle move / re-config)
        setupCGDisplayCallback()

        // 2. IOHIDManager Hinge Angle & Motion Sensor Tracking (Usage Page 65280)
        setupHIDMotionSensorMonitoring()

        // 3. Observe Workspace Sleep & Screen Parameter Notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleLidAngleOrScreenChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleLidAngleOrScreenChange), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleLidAngleOrScreenChange), name: NSWorkspace.screensDidSleepNotification, object: nil)

        // 4. Register IOKit Hardware Interest Notification on IOPMrootDomain for instant lid/clamshell events
        setupIOKitInterestNotification()

        // End arming grace period after 2.0s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.isArmingGracePeriod = false
            // Re-capture fresh baseline after startup UI settles
            self.initialClamshellState = self.currentClamshellState()
            self.initialPowerSourceState = self.currentPowerSourceState()
            self.initialIsCharging = self.currentIsChargingState()
            print("[Sentry] Hardware Sensors FULLY ARMED & ACTIVE.")
        }

        // 5. High-frequency polling (every 100ms) for state verification
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkHardwareState()
        }
    }

    func stopMonitoring() {
        SleepPreventer.shared.allowSleep()
        teardownCGDisplayCallback()
        teardownHIDMotionSensorMonitoring()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        
        if let notifyPort = notifyPort {
            IONotificationPortDestroy(notifyPort)
            self.notifyPort = nil
        }

        timer?.invalidate()
        timer = nil
    }

    @objc private func handleLidAngleOrScreenChange() {
        guard !isArmingGracePeriod else { return }
        print("[Sentry] Lid angle change / Screen parameter event triggered by macOS!")
        onTamperDetected?()
    }

    private func setupCGDisplayCallback() {
        guard !isDisplayReconfigRegistered else { return }
        isDisplayReconfigRegistered = true

        CGDisplayRegisterReconfigurationCallback({ (display, flags, userInfo) in
            guard let instance = globalSensorsManagerInstance, !instance.isArmingGracePeriod else { return }
            print("[Sentry] CoreGraphics Display Reconfig Event (display: \(display), flags: \(flags.rawValue))!")
            instance.onTamperDetected?()
        }, nil)
    }

    private func teardownCGDisplayCallback() {
        guard isDisplayReconfigRegistered else { return }
        isDisplayReconfigRegistered = false

        CGDisplayRemoveReconfigurationCallback({ (display, flags, userInfo) in }, nil)
    }

    private func setupHIDMotionSensorMonitoring() {
        guard hidManager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        
        // Match Apple SPU Motion / Hinge / Sensor Usage Pages (0x65280 / 0x20)
        let matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: 65280
        ]
        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)

        let inputCallback: IOHIDReportCallback = { (context, result, sender, type, reportID, report, reportLength) in
            guard reportLength > 4 else { return }
            let buffer = UnsafeBufferPointer(start: report, count: reportLength)
            let currentBytes = Array(buffer)

            if let instance = globalSensorsManagerInstance {
                guard !instance.isArmingGracePeriod else {
                    instance.lastHIDReportBytes = currentBytes
                    return
                }

                if !instance.lastHIDReportBytes.isEmpty && instance.lastHIDReportBytes.count == currentBytes.count {
                    // Check if bytes changed significantly (hinge tilt / motion delta)
                    var diffCount = 0
                    for i in 0..<currentBytes.count {
                        if instance.lastHIDReportBytes[i] != currentBytes[i] {
                            diffCount += 1
                        }
                    }
                    if diffCount > 8 {
                        print("[Sentry] Hinge Angle / Motion HID Sensor Delta detected (\(diffCount) byte shift)!")
                        instance.onTamperDetected?()
                    }
                }
                instance.lastHIDReportBytes = currentBytes
            }
        }

        IOHIDManagerRegisterInputReportCallback(manager, inputCallback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        self.hidManager = manager
        print("[Sentry] IOHIDManager Hinge & Motion Sensor Tracking Active.")
    }

    private func teardownHIDMotionSensorMonitoring() {
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            self.hidManager = nil
        }
    }

    private func setupIOKitInterestNotification() {
        guard notifyPort == nil else { return }
        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort = notifyPort else { return }

        let runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)

        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IOPMrootDomain")
        guard entry != 0 else { return }
        defer { IOObjectRelease(entry) }

        var object: io_object_t = 0
        IOServiceAddInterestNotification(
            notifyPort,
            entry,
            kIOGeneralInterest,
            { (context, service, messageType, messageArgument) in
                guard let context = context else { return }
                let manager = Unmanaged<SensorsManager>.fromOpaque(context).takeUnretainedValue()
                guard !manager.isArmingGracePeriod else { return }
                print("[Sentry] IOKit Hardware Clamshell/Power Notification received (type: \(messageType))!")
                manager.onTamperDetected?()
            },
            Unmanaged.passUnretained(self).toOpaque(),
            &object
        )
    }

    private func checkHardwareState() {
        guard !isArmingGracePeriod else { return }

        let currentLid = currentClamshellState()
        if let initialLid = initialClamshellState, currentLid != initialLid {
            print("[Sentry] Lid state change detected! Initial: \(initialLid), Current: \(currentLid)")
            onTamperDetected?()
            return
        }

        let currentPower = currentPowerSourceState()
        if let initialPower = initialPowerSourceState, currentPower != initialPower {
            print("[Sentry] Power source state change detected! Initial: \(initialPower), Current: \(currentPower)")
            onTamperDetected?()
            return
        }

        let currentCharging = currentIsChargingState()
        if let initialCharging = initialIsCharging, currentCharging != initialCharging {
            print("[Sentry] Charging cable state change detected! Initial: \(initialCharging), Current: \(currentCharging)")
            onTamperDetected?()
            return
        }
    }

    private func currentClamshellState() -> Bool {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IOService:/IOResources/IOPMrootDomain")
        guard entry != 0 else { return false }
        defer { IOObjectRelease(entry) }

        if let cfProperty = IORegistryEntryCreateCFProperty(entry, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0) {
            let unmanaged = cfProperty.takeRetainedValue()
            if let state = unmanaged as? Bool {
                return state
            }
        }
        return false
    }

    private func currentPowerSourceState() -> String {
        guard let infoUnmanaged = IOPSCopyPowerSourcesInfo() else { return "Unknown" }
        let infoSnapshot = infoUnmanaged.takeRetainedValue()

        guard let listUnmanaged = IOPSCopyPowerSourcesList(infoSnapshot) else { return "Unknown" }
        let sourcesList = listUnmanaged.takeRetainedValue() as [CFTypeRef]

        for source in sourcesList {
            if let descUnmanaged = IOPSGetPowerSourceDescription(infoSnapshot, source) {
                if let description = descUnmanaged.takeUnretainedValue() as? [String: Any],
                   let state = description["Power Source State"] as? String {
                    return state
                }
            }
        }
        return "Battery"
    }

    private func currentIsChargingState() -> Bool {
        guard let infoUnmanaged = IOPSCopyPowerSourcesInfo() else { return false }
        let infoSnapshot = infoUnmanaged.takeRetainedValue()

        guard let listUnmanaged = IOPSCopyPowerSourcesList(infoSnapshot) else { return false }
        let sourcesList = listUnmanaged.takeRetainedValue() as [CFTypeRef]

        for source in sourcesList {
            if let descUnmanaged = IOPSGetPowerSourceDescription(infoSnapshot, source) {
                if let description = descUnmanaged.takeUnretainedValue() as? [String: Any],
                   let isCharging = description[kIOPSIsChargingKey as String] as? Bool {
                    return isCharging
                }
            }
        }
        return false
    }
}
