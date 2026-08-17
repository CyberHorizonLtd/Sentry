import Foundation
import AppKit
import QuartzCore

final class SentryOverlayWindow: NSWindow {
    private var brandingView: CyberHorizonBrandingView?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let bounds = NSRect(origin: .zero, size: screen.frame.size)

        // Use .statusBar level for high-priority floating overlay across all spaces
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.setFrame(screen.frame, display: true)

        let visualEffectView = NSVisualEffectView(frame: bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active

        // Dark tint overlay to enhance backdrop blur contrast
        let darkOverlay = NSView(frame: bounds)
        darkOverlay.wantsLayer = true
        darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
        darkOverlay.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(darkOverlay)

        // Centered CyberHorizon Sentry Branding View
        let bView = CyberHorizonBrandingView(frame: NSRect(x: (bounds.width - 560) / 2,
                                                           y: (bounds.height - 420) / 2,
                                                           width: 560,
                                                           height: 420))
        bView.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        visualEffectView.addSubview(bView)
        self.brandingView = bView

        self.contentView = visualEffectView
    }

    func showTriggeredStatus(reason: String, isTestMode: Bool) {
        brandingView?.setTriggered(reason: reason, isTestMode: isTestMode)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class CyberHorizonBrandingView: NSView {
    private let logoImageView = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "ARMED • DO NOT TOUCH")
    private let titleLabel = NSTextField(labelWithString: "CYBERHORIZON SENTRY")
    private let subtitleLabel = NSTextField(labelWithString: "PROTECTED BY CYBERHORIZON SENTRY")
    private var hasCustomLogo = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
        loadLocalFaviconLogo()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        loadLocalFaviconLogo()
    }

    private func setupView() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(white: 0.05, alpha: 0.65).cgColor
        self.layer?.cornerRadius = 24.0
        self.layer?.borderWidth = 1.0
        self.layer?.borderColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.3).cgColor

        // Subtitle / Header
        titleLabel.frame = NSRect(x: 20, y: 110, width: 520, height: 48)
        titleLabel.font = NSFont.systemFont(ofSize: 32, weight: .black)
        titleLabel.textColor = .white
        titleLabel.alignment = .center

        subtitleLabel.frame = NSRect(x: 20, y: 75, width: 520, height: 28)
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        subtitleLabel.textColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.9)
        subtitleLabel.alignment = .center

        // Pulsing Status Badge
        statusLabel.frame = NSRect(x: 20, y: 35, width: 520, height: 24)
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        statusLabel.textColor = NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        statusLabel.alignment = .center

        // Logo Image View
        logoImageView.frame = NSRect(x: (bounds.width - 100) / 2, y: bounds.height - 145, width: 100, height: 100)
        logoImageView.imageScaling = .scaleProportionallyUpOrDown

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(statusLabel)
        addSubview(logoImageView)
    }

    func setTriggered(reason: String, isTestMode: Bool) {
        let tag = isTestMode ? "[TEST MODE - SILENT]" : "[ALARM ACTIVATED]"
        titleLabel.stringValue = "🚨 ALARM TRIGGERED!"
        titleLabel.textColor = NSColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)

        subtitleLabel.stringValue = "\(tag) \(reason.uppercased())"
        subtitleLabel.textColor = NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)

        statusLabel.stringValue = "ENTER PASSCODE ON KEYBOARD TO DISARM"
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .black)
        statusLabel.textColor = NSColor(red: 1.0, green: 0.9, blue: 0.0, alpha: 1.0)

        self.layer?.borderColor = NSColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 0.9).cgColor
        self.layer?.backgroundColor = NSColor(red: 0.25, green: 0.02, blue: 0.02, alpha: 0.85).cgColor
    }

    private func loadLocalFaviconLogo() {
        let fileManager = FileManager.default
        var possiblePaths: [String] = []

        if let bundlePath = Bundle.main.path(forResource: "favicon", ofType: "png") {
            possiblePaths.append(bundlePath)
        }
        if let resourcePath = Bundle.main.resourcePath {
            possiblePaths.append((resourcePath as NSString).appendingPathComponent("favicon.png"))
        }

        let execPath = CommandLine.arguments[0]
        let execDir = (execPath as NSString).deletingLastPathComponent
        possiblePaths.append((execDir as NSString).appendingPathComponent("favicon.png"))
        possiblePaths.append((execDir as NSString).appendingPathComponent("../Resources/favicon.png"))

        let currentDir = fileManager.currentDirectoryPath
        possiblePaths.append((currentDir as NSString).appendingPathComponent("favicon.png"))
        possiblePaths.append("./favicon.png")
        possiblePaths.append("favicon.png")

        for path in possiblePaths {
            let normalizedPath = (path as NSString).standardizingPath
            if fileManager.fileExists(atPath: normalizedPath), let image = NSImage(contentsOfFile: normalizedPath) {
                print("[Sentry] Loaded logo from: \(normalizedPath)")
                self.logoImageView.image = image
                self.hasCustomLogo = true
                self.needsDisplay = true
                return
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw CyberHorizon Shield Vector Emblem if logo image is unavailable
        if !hasCustomLogo {
            let center = NSPoint(x: bounds.midX, y: bounds.height - 100)
            let shieldPath = NSBezierPath()
            shieldPath.move(to: NSPoint(x: center.x, y: center.y + 45))
            shieldPath.curve(to: NSPoint(x: center.x + 40, y: center.y + 15),
                             controlPoint1: NSPoint(x: center.x + 20, y: center.y + 45),
                             controlPoint2: NSPoint(x: center.x + 35, y: center.y + 35))
            shieldPath.curve(to: NSPoint(x: center.x, y: center.y - 45),
                             controlPoint1: NSPoint(x: center.x + 40, y: center.y - 15),
                             controlPoint2: NSPoint(x: center.x + 25, y: center.y - 35))
            shieldPath.curve(to: NSPoint(x: center.x - 40, y: center.y + 15),
                             controlPoint1: NSPoint(x: center.x - 25, y: center.y - 35),
                             controlPoint2: NSPoint(x: center.x - 40, y: center.y - 15))
            shieldPath.curve(to: NSPoint(x: center.x, y: center.y + 45),
                             controlPoint1: NSPoint(x: center.x - 35, y: center.y + 35),
                             controlPoint2: NSPoint(x: center.x - 20, y: center.y + 45))
            shieldPath.close()

            let gradient = NSGradient(starting: NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.9),
                                      ending: NSColor(red: 0.0, green: 0.4, blue: 0.9, alpha: 0.9))
            gradient?.draw(in: shieldPath, angle: -45)

            NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0).setStroke()
            shieldPath.lineWidth = 3.0
            shieldPath.stroke()

            // Draw Inner Lock Icon
            let lockBody = NSBezierPath(roundedRect: NSRect(x: center.x - 12, y: center.y - 20, width: 24, height: 18), xRadius: 4, yRadius: 4)
            NSColor.white.setFill()
            lockBody.fill()

            let lockArc = NSBezierPath()
            lockArc.appendArc(withCenter: NSPoint(x: center.x, y: center.y - 2), radius: 7, startAngle: 0, endAngle: 180)
            lockArc.lineWidth = 3.0
            NSColor.white.setStroke()
            lockArc.stroke()
        }
    }
}
