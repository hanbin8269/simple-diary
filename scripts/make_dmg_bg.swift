// DMG 설치 창 배경 이미지 생성.
// 사용: swift scripts/make_dmg_bg.swift <출력.png> <가로픽셀> <세로픽셀>
// 디자인 좌표계는 640x400, top-left 원점(아래로 +y) 기준. 출력 크기에 맞춰 스케일된다.
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
) else { fatalError("비트맵 생성 실패") }

guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("컨텍스트 실패") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

// 글자가 뒤집히지 않도록 전역 플립은 쓰지 않는다.
// 디자인 좌표(top-down)는 그릴 때 픽셀 스케일 + y반전으로 변환한다.
let sx = CGFloat(outW) / DW
let sy = CGFloat(outH) / DH
// 디자인 점(top-left) → 출력 픽셀(AppKit, bottom-left)
func P(_ x: CGFloat, _ yTop: CGFloat) -> NSPoint { NSPoint(x: x * sx, y: CGFloat(outH) - yTop * sy) }
func L(_ w: CGFloat) -> CGFloat { w * (sx + sy) / 2 } // 선 두께 스케일

// 배경: 아이보리
NSColor(calibratedRed: 0.980, green: 0.976, blue: 0.961, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: outW, height: outH)).fill()

// 노트 실선 (웹사이트와 동일: 32px 간격, 옅은 테라코타)
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

// 디자인 top-y에 가로 가운데 정렬로 텍스트 그리기 (비반전 컨텍스트 → 글자 정상)
func centered(_ s: String, size: CGFloat, weight: NSFont.Weight, _ color: NSColor, topY: CGFloat) {
    let font = NSFont.systemFont(ofSize: size * sy, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let dim = (s as NSString).size(withAttributes: attrs)
    let x = (CGFloat(outW) - dim.width) / 2
    let y = CGFloat(outH) - topY * sy - dim.height // bottom-left 기준
    (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

centered("Simple Diary", size: 30, weight: .bold, ink, topY: 44)
centered("Drag the app into your Applications folder to install",
         size: 14, weight: .regular, inkSoft, topY: 88)

// 아이콘 사이 화살표 (앱 170 → Applications 470, 중심 y=210)
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

guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("PNG 실패") }
try! png.write(to: URL(fileURLWithPath: outPath))
print("DMG 배경 생성: \(outPath) (\(outW)x\(outH))")
