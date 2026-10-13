import AppKit
import Foundation

let pixelSize = 1024
let destination = "NAVA/Assets.xcassets/AppIcon.appiconset"
try FileManager.default.createDirectory(
    atPath: destination,
    withIntermediateDirectories: true
)
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let canvas = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
NSColor.black.setFill()
canvas.fill()

let glow = NSBezierPath(ovalIn: NSRect(x: 153, y: 171, width: 720, height: 720))
NSGradient(
    starting: NSColor(calibratedRed: 0.44, green: 0.11, blue: 0.035, alpha: 0.34),
    ending: NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0)
)?.draw(in: glow, relativeCenterPosition: .zero)

func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x, y: y) }

// Original liquid-metal-inspired symbol without VAYUO WORLD lettering.
let emblem = NSBezierPath()
emblem.move(to: p(205, 555))
emblem.curve(to: p(792, 719), controlPoint1: p(297, 903), controlPoint2: p(641, 881))
emblem.curve(to: p(387, 609), controlPoint1: p(656, 784), controlPoint2: p(491, 694))
emblem.curve(to: p(675, 300), controlPoint1: p(364, 336), controlPoint2: p(561, 162))
emblem.curve(to: p(844, 562), controlPoint1: p(744, 347), controlPoint2: p(834, 456))
emblem.curve(to: p(568, 160), controlPoint1: p(910, 274), controlPoint2: p(704, 97))
emblem.curve(to: p(205, 555), controlPoint1: p(360, 158), controlPoint2: p(131, 349))
emblem.close()

NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.17, alpha: 1),
    NSColor(calibratedRed: 0.78, green: 0.81, blue: 0.85, alpha: 1),
    NSColor(calibratedRed: 0.98, green: 0.91, blue: 0.78, alpha: 1),
    NSColor(calibratedRed: 0.31, green: 0.35, blue: 0.40, alpha: 1)
])?.draw(in: emblem, angle: -42)

let sphere = NSBezierPath(ovalIn: NSRect(x: 736, y: 667, width: 98, height: 98))
NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.14, alpha: 1),
    NSColor(calibratedRed: 0.64, green: 0.65, blue: 0.68, alpha: 1)
])?.draw(in: sphere, angle: 52)

NSGraphicsContext.restoreGraphicsState()

let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: destination + "/AppIcon.png"))
print("Generated NAVA iOS icon (\(png.count) bytes)")
