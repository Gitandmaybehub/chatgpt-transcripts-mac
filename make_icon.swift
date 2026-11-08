import AppKit
// Draws the app icon: dark squircle with a white sound wave.
let size = 1024.0
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let inset = 100.0
let rect = NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(starting: NSColor(calibratedWhite: 0.20, alpha: 1), ending: NSColor(calibratedWhite: 0.07, alpha: 1))!.draw(in: path, angle: -90)
NSColor(calibratedWhite: 1, alpha: 0.08).setStroke(); path.lineWidth = 4; path.stroke()
let bars: [Double] = [0.28, 0.55, 0.85, 0.55, 0.95, 0.45, 0.25]
let w = 52.0, gap = 34.0
let total = Double(bars.count) * w + Double(bars.count - 1) * gap
var x = (size - total) / 2
NSColor.white.setFill()
for b in bars {
    let h = 520 * b
    NSBezierPath(roundedRect: NSRect(x: x, y: (size - h) / 2, width: w, height: h), xRadius: w/2, yRadius: w/2).fill()
    x += w + gap
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
