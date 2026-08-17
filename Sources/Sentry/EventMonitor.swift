import Foundation
import AppKit
import ApplicationServices

final class EventMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var initialMousePos: NSPoint?
    private var isArmingGracePeriod = true

    var onKeyTyped: ((String) -> Void)?
    var onTamperDetected: (() -> Void)?

    func startMonitoring() {
        initialMousePos = NSEvent.mouseLocation
        isArmingGracePeriod = true

        // Grace period of 1.5 seconds so initial mouse positioning on arming doesn't trip alarm
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isArmingGracePeriod = false
            self?.initialMousePos = NSEvent.mouseLocation
        }

        let eventMask: NSEvent.EventTypeMask = [
            .keyDown,
            .flagsChanged,
            .mouseMoved,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown,
            .scrollWheel,
            .leftMouseDragged,
            .rightMouseDragged
        ]

        // Local Event Monitor (when overlay window has focus - primary responder)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleEvent(event)
            return nil // Intercept and absorb event completely
        }

        // Global Event Monitor (only added if process is trusted for Accessibility)
        if AXIsProcessTrusted() {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
                self?.handleEvent(event)
            }
        }
    }

    func stopMonitoring() {
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            guard !isArmingGracePeriod else { return }
            let flags = event.modifierFlags
            // Trigger alarm if Command, Control, or Option (Alt) key is pressed!
            if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
                print("[Sentry] Tamper! Unauthorized modifier key pressed (Command / Control / Option)")
                onTamperDetected?()
            }

        case .keyDown:
            let flags = event.modifierFlags
            // Trigger alarm if a key is pressed while holding Command, Control, or Option!
            if flags.contains(.command) || flags.contains(.control) || flags.contains(.option) {
                print("[Sentry] Tamper! Unauthorized shortcut key combo pressed")
                onTamperDetected?()
                return
            }

            if let characters = event.characters, !characters.isEmpty {
                onKeyTyped?(characters)
            }

        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            guard !isArmingGracePeriod else { return }
            let currentPos = NSEvent.mouseLocation
            if let initial = initialMousePos {
                let dx = abs(currentPos.x - initial.x)
                let dy = abs(currentPos.y - initial.y)
                if dx > 4.0 || dy > 4.0 {
                    print("[Sentry] Mouse movement detected! Δx: \(dx), Δy: \(dy)")
                    onTamperDetected?()
                }
            }

        case .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel:
            guard !isArmingGracePeriod else { return }
            print("[Sentry] Mouse click/scroll interaction detected!")
            onTamperDetected?()

        default:
            break
        }
    }
}
