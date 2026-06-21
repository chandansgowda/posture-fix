#!/usr/bin/env swift
// Generates Resources/AppIcon.icns — a green→teal squircle with a white
// "figure.stand" SF Symbol (matching the good-posture menu-bar glyph).
// Run from the project root:  swift scripts/make_icon.swift
import AppKit
import Foundation

let symbolName = "figure.stand"
let outIcns = "Resources/AppIcon.icns"
let iconsetDir = "/tmp/PostureFix-AppIcon.iconset"
let previewPath = "/tmp/posturefix-icon-preview.png"

func whiteSymbol(pointSize: CGFloat) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else {
        fatalError("SF Symbol \(symbolName) not available")
    }
    let size = base.size
    let out = NSImage(size: size)
    out.lockFocus()
    base.draw(at: .zero, from: NSRect(origin: .zero, size: size),
              operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

func drawIcon(into rep: NSBitmapImageRep, size s: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let margin = s * 0.085
    let rect = NSRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let radius = rect.width * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(
        starting: NSColor(srgbRed: 0.18, green: 0.80, blue: 0.44, alpha: 1),
        ending:   NSColor(srgbRed: 0.00, green: 0.52, blue: 0.53, alpha: 1)
    )!
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    gradient.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    let sym = whiteSymbol(pointSize: s * 0.5)
    let symSize = sym.size
    let drawRect = NSRect(x: (s - symSize.width) / 2, y: (s - symSize.height) / 2,
                          width: symSize.width, height: symSize.height)
    sym.draw(in: drawRect, from: NSRect(origin: .zero, size: symSize),
             operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
}

func renderPNG(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    drawIcon(into: rep, size: CGFloat(size))
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
var cache: [Int: Data] = [:]
for (name, size) in entries {
    let data = cache[size] ?? renderPNG(size: size)
    cache[size] = data
    try! data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name).png"))
}
try! cache[512]!.write(to: URL(fileURLWithPath: previewPath))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconsetDir, "-o", outIcns]
try! p.run()
p.waitUntilExit()
print("iconutil exit: \(p.terminationStatus)")
print("wrote \(outIcns); preview at \(previewPath)")
