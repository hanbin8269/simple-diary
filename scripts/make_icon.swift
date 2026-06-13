// App icon (1024px PNG) generator — terracotta leaf.
// Usage: swift scripts/make_icon.swift <output-path.png> [--ios]
//   --ios: full-bleed square with no margin/rounding (iOS rounds the corners itself)
import AppKit

let iosMode = CommandLine.arguments.contains("--ios")
let outPath = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("--") } ?? "icon_1024.png"

let S: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(S), pixelsHigh: Int(S),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else {
    fatalError("failed to create bitmap")
}
rep.size = NSSize(width: S, height: S)

guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
    fatalError("failed to create graphics context")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

// Helper that approximates a quadratic curve with a cubic one
func quadCurve(_ path: NSBezierPath, to end: NSPoint, control: NSPoint) {
    let start = path.currentPoint
    let cp1 = NSPoint(x: start.x + (control.x - start.x) * 2 / 3,
                      y: start.y + (control.y - start.y) * 2 / 3)
    let cp2 = NSPoint(x: end.x + (control.x - end.x) * 2 / 3,
                      y: end.y + (control.y - end.y) * 2 / 3)
    path.curve(to: end, controlPoint1: cp1, controlPoint2: cp2)
}

// Background: soft ivory paper (macOS rounded + margin, iOS full-bleed)
let inset: CGFloat = iosMode ? 0 : 100
let bgRect = NSRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let bgPath = iosMode
    ? NSBezierPath(rect: bgRect)
    : NSBezierPath(roundedRect: bgRect, xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(calibratedRed: 0.980, green: 0.976, blue: 0.961, alpha: 1), // Claude ivory
    NSColor(calibratedRed: 0.929, green: 0.902, blue: 0.855, alpha: 1),
])!.draw(in: bgPath, angle: -90)

// Leaf geometry: diagonal axis (bottom-left base → top-right tip)
let base = NSPoint(x: 350, y: 320)
let tip = NSPoint(x: 690, y: 715)
let mid = NSPoint(x: (base.x + tip.x) / 2, y: (base.y + tip.y) / 2)
let axis = NSPoint(x: tip.x - base.x, y: tip.y - base.y)
let axisLen = sqrt(axis.x * axis.x + axis.y * axis.y)
let unit = NSPoint(x: axis.x / axisLen, y: axis.y / axisLen)
let perp = NSPoint(x: -unit.y, y: unit.x)
let halfWidth: CGFloat = 160
let controlLeft = NSPoint(x: mid.x + perp.x * halfWidth, y: mid.y + perp.y * halfWidth)
let controlRight = NSPoint(x: mid.x - perp.x * halfWidth, y: mid.y - perp.y * halfWidth)

let stemColor = NSColor(calibratedRed: 0.659, green: 0.306, blue: 0.196, alpha: 1) // deep terracotta

// Stem (a slight curve extending below the leaf)
let stem = NSBezierPath()
stem.lineWidth = 20
stem.lineCapStyle = .round
stem.move(to: NSPoint(x: base.x - 58, y: base.y - 80))
quadCurve(stem, to: base, control: NSPoint(x: base.x - 12, y: base.y - 48))
stemColor.setStroke()
stem.stroke()

// Leaf body
let leaf = NSBezierPath()
leaf.move(to: base)
quadCurve(leaf, to: tip, control: controlLeft)
quadCurve(leaf, to: base, control: controlRight)
leaf.close()

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
NSColor(calibratedRed: 0.851, green: 0.467, blue: 0.341, alpha: 1).setFill() // #D97757
leaf.fill()
NSGraphicsContext.restoreGraphicsState()

// Leaf gradient: tip (light) → base (dark), Claude terracotta tones
NSGradient(colors: [
    NSColor(calibratedRed: 0.922, green: 0.631, blue: 0.510, alpha: 1), // #EBA182
    NSColor(calibratedRed: 0.753, green: 0.373, blue: 0.247, alpha: 1), // #C05F3F
])!.draw(in: leaf, angle: 229)

// Veins: a central main vein + smaller side veins
let veinColor = NSColor.white.withAlphaComponent(0.50)
let mainVein = NSBezierPath()
mainVein.lineWidth = 12
mainVein.lineCapStyle = .round
mainVein.move(to: NSPoint(x: base.x + unit.x * 14, y: base.y + unit.y * 14))
quadCurve(mainVein, to: NSPoint(x: tip.x - unit.x * 26, y: tip.y - unit.y * 26),
          control: NSPoint(x: mid.x + perp.x * 22, y: mid.y + perp.y * 22))
veinColor.setStroke()
mainVein.stroke()

for (t, sideSign) in [(0.28, 1.0), (0.46, -1.0), (0.62, 1.0), (0.78, -1.0)] {
    let t = CGFloat(t)
    let sign = CGFloat(sideSign)
    let p = NSPoint(x: base.x + axis.x * t + perp.x * 22 * t, y: base.y + axis.y * t + perp.y * 22 * t)
    let len: CGFloat = 105 * (1.05 - abs(t - 0.5))
    // Side-vein direction: tilted 40° outward from the axis
    let angle: CGFloat = 40 * .pi / 180
    let dir = NSPoint(
        x: unit.x * cos(angle) - sign * perp.x * sin(angle) * -1,
        y: unit.y * cos(angle) - sign * perp.y * sin(angle) * -1
    )
    let sideVein = NSBezierPath()
    sideVein.lineWidth = 7
    sideVein.lineCapStyle = .round
    sideVein.move(to: p)
    sideVein.line(to: NSPoint(x: p.x + (unit.x * 0.55 + sign * perp.x) * len * 0.7,
                              y: p.y + (unit.y * 0.55 + sign * perp.y) * len * 0.7))
    NSColor.white.withAlphaComponent(0.34).setStroke()
    sideVein.stroke()
    _ = dir
}

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG encoding failed")
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("Icon written: \(outPath)")
