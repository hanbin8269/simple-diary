// Generate the DMG install-window background image.
// Usage: swift scripts/make_dmg_bg.swift <output.png> <widthPx> <heightPx>
// Design coordinates are 640x400 with a top-left origin (+y down); scaled to the output size.
import AppKit

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "dmg-bg.png"
let outW = args.count > 2 ? Int(args[2])! : 640
let outH = args.count > 3 ? Int(args[3])! : 400

let DW: CGFloat = 640, DH: CGFloat = 400

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: outW, pixelsHigh: outH,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("failed to create bitmap") }

guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("failed to create context") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// Avoid a global flip so glyphs aren't mirrored.
// Design coords (top-down) are converted at draw time via pixel scaling + y inversion.
let sx = CGFloat(outW) / DW
let sy = CGFloat(outH) / DH
// Design point (top-left) → output pixel (AppKit, bottom-left)
func P(_ x: CGFloat, _ yTop: CGFloat) -> NSPoint { NSPoint(x: x * sx, y: CGFloat(outH) - yTop * sy) }
func L(_ w: CGFloat) -> CGFloat { w * (sx + sy) / 2 } // line-width scale

// Background: ivory
NSColor(calibratedRed: 0.980, green: 0.976, blue: 0.961, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: outW, height: outH)).fill()

// Notebook rules (same as the website: 32px spacing, faint terracotta)
NSColor(calibratedRed: 0.752, green: 0.373, blue: 0.247, alpha: 0.06).setStroke()
var ly: CGFloat = 33
while ly < DH {
    let line = NSBezierPath()
    line.lineWidth = L(1)
    line.move(to: P(0, ly))
    line.line(to: P(DW, ly))
    line.stroke()
    ly += 32
}

let ink = NSColor(calibratedRed: 0.165, green: 0.145, blue: 0.125, alpha: 1)
let inkSoft = NSColor(calibratedRed: 0.42, green: 0.384, blue: 0.345, alpha: 1)
let terra = NSColor(calibratedRed: 0.851, green: 0.467, blue: 0.341, alpha: 1)

// Draw horizontally-centered text at a design top-y (non-flipped context → upright glyphs)
func centered(_ s: String, size: CGFloat, weight: NSFont.Weight, _ color: NSColor, topY: CGFloat) {
    let font = NSFont.systemFont(ofSize: size * sy, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let dim = (s as NSString).size(withAttributes: attrs)
    let x = (CGFloat(outW) - dim.width) / 2
    let y = CGFloat(outH) - topY * sy - dim.height // bottom-left origin
    (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

centered("Simple Diary", size: 30, weight: .bold, ink, topY: 44)
centered("Drag the app into your Applications folder to install",
         size: 14, weight: .regular, inkSoft, topY: 88)

// Arrow between the icons (app 170 → Applications 470, center y=210)
let ay: CGFloat = 210
let ax0: CGFloat = 258, ax1: CGFloat = 382
terra.setStroke(); terra.setFill()
let shaft = NSBezierPath()
shaft.lineWidth = L(7)
shaft.lineCapStyle = .round
shaft.move(to: P(ax0, ay))
shaft.line(to: P(ax1 - 10, ay))
shaft.stroke()
let head = NSBezierPath()
head.move(to: P(ax1 + 6, ay))
head.line(to: P(ax1 - 18, ay - 13))
head.line(to: P(ax1 - 18, ay + 13))
head.close()
head.fill()

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG failed") }
try! png.write(to: URL(fileURLWithPath: outPath))
print("DMG background written: \(outPath) (\(outW)x\(outH))")
