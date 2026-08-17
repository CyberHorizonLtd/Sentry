import Foundation
import AppKit

let width: CGFloat = 600
let height: CGFloat = 400

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    exit(1)
}

// 1. Draw Dark Gradient Background
let colorSpace = CGColorSpaceCreateDeviceRGB()
let colors = [
    NSColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1.0).cgColor,
    NSColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1.0).cgColor
] as CFArray

if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
}

// 2. Draw Subtle Border Line around window
let borderPath = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: width - 2, height: height - 2), xRadius: 12, yRadius: 12)
NSColor(white: 0.2, alpha: 0.5).setStroke()
borderPath.lineWidth = 1.5
borderPath.stroke()

// 3. Draw Title Text
let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 22, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraphStyle
]
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.9),
    .paragraphStyle: paragraphStyle
]

let titleString = "CYBERHORIZON SENTRY"
titleString.draw(in: NSRect(x: 0, y: height - 60, width: width, height: 30), withAttributes: titleAttrs)

let subtitleString = "Drag CyberHorizon Sentry to Applications to Install"
subtitleString.draw(in: NSRect(x: 0, y: height - 85, width: width, height: 20), withAttributes: subtitleAttrs)

// 4. Draw Glowing Arrow between Left (x=160) and Right (x=440)
let arrowY: CGFloat = 200
let startX: CGFloat = 250
let endX: CGFloat = 350

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: startX, y: arrowY))
arrowPath.line(to: NSPoint(x: endX, y: arrowY))
// Arrow head
arrowPath.line(to: NSPoint(x: endX - 12, y: arrowY + 8))
arrowPath.move(to: NSPoint(x: endX, y: arrowY))
arrowPath.line(to: NSPoint(x: endX - 12, y: arrowY - 8))

NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.7).setStroke()
arrowPath.lineWidth = 3.5
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

image.unlockFocus()

if let tiffData = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData), let pngData = bitmap.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "dmg_background.png"))
    print("[+] Generated dmg_background.png successfully.")
}
