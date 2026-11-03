import AppKit

// Native vector artwork; render both appearances from the same geometry.
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for dark in [false, true] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    let top = NSColor(calibratedRed: dark ? 0.23 : 0.91, green: dark ? 0.26 : 0.95, blue: dark ? 0.32 : 1.0, alpha: 1)
    let bottom = NSColor(calibratedRed: dark ? 0.10 : 0.70, green: dark ? 0.12 : 0.81, blue: dark ? 0.17 : 0.94, alpha: 1)
    NSGraphicsContext.saveGraphicsState()
    let outerShadow = NSShadow()
    outerShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    outerShadow.shadowBlurRadius = 16
    outerShadow.shadowOffset = NSSize(width: 0, height: -7)
    outerShadow.set()
    bottom.setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: bottom, ending: top)!.draw(in: tile, angle: 90)
    NSColor.white.withAlphaComponent(dark ? 0.14 : 0.7).setStroke()
    tile.lineWidth = 2; tile.stroke()

    // A softly raised key with enough negative space to read at Finder sizes.
    let base = NSBezierPath(roundedRect: NSRect(x: 243, y: 240, width: 538, height: 528), xRadius: 112, yRadius: 112)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.5 : 0.22)
    shadow.shadowBlurRadius = 38
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    NSColor(white: dark ? 0.12 : 0.69, alpha: 1).setFill(); base.fill()
    NSGraphicsContext.restoreGraphicsState()
    let face = NSBezierPath(roundedRect: NSRect(x: 243, y: 258, width: 538, height: 510), xRadius: 112, yRadius: 112)
    NSGradient(starting: NSColor(white: dark ? 0.20 : 0.91, alpha: 1),
        ending: NSColor(white: dark ? 0.31 : 1.0, alpha: 1))!.draw(in: face, angle: 90)
    NSColor.white.withAlphaComponent(dark ? 0.18 : 0.9).setStroke()
    face.lineWidth = 2; face.stroke()
    let font = NSFont.systemFont(ofSize: 214, weight: .medium)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(white: dark ? 0.95 : 0.18, alpha: 1)
    ]
    let legend = "fn" as NSString
    let size = legend.size(withAttributes: attributes)
    legend.draw(at: NSPoint(x: 512 - size.width / 2, y: 432), withAttributes: attributes)
    let arrows = NSBezierPath()
    arrows.move(to: NSPoint(x: 442, y: 389)); arrows.line(to: NSPoint(x: 582, y: 389))
    arrows.move(to: NSPoint(x: 558, y: 413)); arrows.line(to: NSPoint(x: 582, y: 389)); arrows.line(to: NSPoint(x: 558, y: 365))
    arrows.move(to: NSPoint(x: 582, y: 334)); arrows.line(to: NSPoint(x: 442, y: 334))
    arrows.move(to: NSPoint(x: 466, y: 358)); arrows.line(to: NSPoint(x: 442, y: 334)); arrows.line(to: NSPoint(x: 466, y: 310))
    NSColor(calibratedRed: dark ? 0.42 : 0.12, green: dark ? 0.70 : 0.42, blue: 0.98, alpha: 1).setStroke()
    arrows.lineWidth = 12; arrows.lineCapStyle = .round; arrows.lineJoinStyle = .round
    arrows.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: destination).appendingPathComponent("AppIcon-\(dark ? "dark" : "light").png"))
}
