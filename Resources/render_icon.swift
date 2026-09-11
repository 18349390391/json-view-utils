import AppKit

// 图标渲染器：Resources/AppIcon.svg 的程序化实现
// 设计：蓝色立体光影底 + 白色"花括号 × 放大镜"线条（带柔和投影）
// 直接用渲染器而不是转换 SVG，保证圆角外透明、无白边
// 用法: swift render_icon.swift <output.png>

let size = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else {
    FileHandle.standardError.write("无法创建位图\n".data(using: .utf8)!)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS 图标网格：内容区 824x824 居中
let rect = NSRect(x: 100, y: 100, width: 824, height: 824)
let clip = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)

// 底色：上浅下深的蓝色渐变
clip.addClip()
NSGradient(colors: [
    NSColor(srgbRed: 0x64 / 255, green: 0xA8 / 255, blue: 0xFF / 255, alpha: 1),
    NSColor(srgbRed: 0x2F / 255, green: 0x5F / 255, blue: 0xE0 / 255, alpha: 1)
])!.draw(from: NSPoint(x: 0, y: 924), to: NSPoint(x: 0, y: 100), options: [])

// 左上半径向光晕（立体感）
NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.22),
    NSColor.white.withAlphaComponent(0)
])!.draw(in: clip, relativeCenterPosition: NSPoint(x: -0.25, y: 0.55))

// 底部轻微压暗（立体感）
NSGradient(colors: [
    NSColor(srgbRed: 0.05, green: 0.12, blue: 0.4, alpha: 0.20),
    NSColor.clear
])!.draw(from: NSPoint(x: 0, y: 100), to: NSPoint(x: 0, y: 420), options: [])

func quad(_ path: NSBezierPath, to p: NSPoint, control c: NSPoint) {
    let p0 = path.currentPoint
    path.curve(
        to: p,
        controlPoint1: NSPoint(x: p0.x + 2.0 / 3.0 * (c.x - p0.x), y: p0.y + 2.0 / 3.0 * (c.y - p0.y)),
        controlPoint2: NSPoint(x: p.x + 2.0 / 3.0 * (c.x - p.x), y: p.y + 2.0 / 3.0 * (c.y - p.y))
    )
}

// 位图上下文原点在左下：y' = 1024 - y（设计稿坐标系 y 向下）
func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: CGFloat(size) - y) }

let strokeWidth: CGFloat = 44

// 左侧花括号 {（尖端用直线，两端用圆弧）
let leftBrace = NSBezierPath()
leftBrace.move(to: pt(380, 300))
quad(leftBrace, to: pt(310, 370), control: pt(310, 300))
leftBrace.line(to: pt(310, 450))
leftBrace.line(to: pt(245, 500))
leftBrace.line(to: pt(310, 550))
leftBrace.line(to: pt(310, 630))
quad(leftBrace, to: pt(380, 700), control: pt(310, 700))

// 放大镜圆环：圆心 (600, 465)，半径 185
let lens = NSBezierPath(ovalIn: NSRect(x: 415, y: size - 465 - 185, width: 370, height: 370))

// 放大镜手柄
let handle = NSBezierPath()
handle.move(to: pt(735, 600))
handle.line(to: pt(845, 710))

// 圆环内的右花括号 }（尖端用直线）
let innerBrace = NSBezierPath()
innerBrace.move(to: pt(505, 340))
quad(innerBrace, to: pt(560, 390), control: pt(560, 340))
innerBrace.line(to: pt(560, 430))
innerBrace.line(to: pt(615, 470))
innerBrace.line(to: pt(560, 510))
innerBrace.line(to: pt(560, 550))
quad(innerBrace, to: pt(505, 600), control: pt(560, 600))

// 环绕大括号露出的上下两笔（位于圆环外侧，不与圆环相交）
let dashTop = NSBezierPath()
dashTop.move(to: pt(378, 286))
dashTop.line(to: pt(410, 318))
let dashBottom = NSBezierPath()
dashBottom.move(to: pt(378, 644))
dashBottom.line(to: pt(410, 612))

let glyphPaths = [leftBrace, lens, handle, innerBrace, dashTop, dashBottom]
for p in glyphPaths {
    p.lineWidth = strokeWidth
    p.lineCapStyle = .round
    p.lineJoinStyle = .round
}

// 白色线条 + 柔和投影（App Store 图标式的浮起立体感）
NSColor.white.setStroke()
let ctx = NSGraphicsContext.current!
ctx.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(srgbRed: 0.08, green: 0.18, blue: 0.45, alpha: 0.40)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 22
shadow.set()
for p in glyphPaths { p.stroke() }
ctx.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("渲染失败\n".data(using: .utf8)!)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("已生成 \(outputPath)")
} catch {
    FileHandle.standardError.write("写入失败: \(error.localizedDescription)\n".data(using: .utf8)!)
    exit(1)
}
