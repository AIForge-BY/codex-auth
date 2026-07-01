#!/usr/bin/env swift
import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.icns")
let fileManager = FileManager.default
let iconsetURL = outputURL
    .deletingLastPathComponent()
    .appendingPathComponent("AppIcon.iconset", isDirectory: true)

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconSize {
    let fileName: String
    let pixels: CGFloat
}

let sizes = [
    IconSize(fileName: "icon_16x16.png", pixels: 16),
    IconSize(fileName: "icon_16x16@2x.png", pixels: 32),
    IconSize(fileName: "icon_32x32.png", pixels: 32),
    IconSize(fileName: "icon_32x32@2x.png", pixels: 64),
    IconSize(fileName: "icon_128x128.png", pixels: 128),
    IconSize(fileName: "icon_128x128@2x.png", pixels: 256),
    IconSize(fileName: "icon_256x256.png", pixels: 256),
    IconSize(fileName: "icon_256x256@2x.png", pixels: 512),
    IconSize(fileName: "icon_512x512.png", pixels: 512),
    IconSize(fileName: "icon_512x512@2x.png", pixels: 1024),
]

for size in sizes {
    let image = drawIcon(size: size.pixels)
    let pngURL = iconsetURL.appendingPathComponent(size.fileName)
    try writePNG(image, to: pngURL)
}

try? fileManager.removeItem(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus))
}

try? fileManager.removeItem(at: iconsetURL)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let scale = size / 1024
    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: x * scale, y: y * scale)
    }

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let background = NSBezierPath(roundedRect: rect(96, 96, 832, 832), xRadius: 210 * scale, yRadius: 210 * scale)
    let bgGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.04, green: 0.21, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.46, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.55, alpha: 1),
    ])!
    bgGradient.draw(in: background, angle: 38)

    NSColor(calibratedWhite: 1, alpha: 0.14).setFill()
    NSBezierPath(roundedRect: rect(150, 148, 724, 728), xRadius: 160 * scale, yRadius: 160 * scale).fill()

    drawAccountCircle(center: point(360, 620), radius: 118 * scale, color: NSColor(calibratedRed: 0.93, green: 0.97, blue: 1, alpha: 1), scale: scale)
    drawAccountCircle(center: point(664, 412), radius: 118 * scale, color: NSColor(calibratedRed: 0.90, green: 1.00, blue: 0.95, alpha: 1), scale: scale)

    drawSwitchArrow(
        start: point(395, 760),
        control: point(610, 865),
        end: point(735, 635),
        color: NSColor(calibratedRed: 0.94, green: 0.99, blue: 1, alpha: 0.96),
        scale: scale,
        clockwise: true
    )
    drawSwitchArrow(
        start: point(630, 275),
        control: point(410, 172),
        end: point(285, 405),
        color: NSColor(calibratedRed: 0.91, green: 1.00, blue: 0.95, alpha: 0.96),
        scale: scale,
        clockwise: false
    )

    let terminal = NSBezierPath(roundedRect: rect(264, 244, 496, 176), xRadius: 46 * scale, yRadius: 46 * scale)
    NSColor(calibratedWhite: 0.03, alpha: 0.82).setFill()
    terminal.fill()
    NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
    terminal.lineWidth = 8 * scale
    terminal.stroke()

    drawPrompt(scale: scale)

    return image
}

func drawAccountCircle(center: NSPoint, radius: CGFloat, color: NSColor, scale: CGFloat) {
    let outer = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    color.setFill()
    outer.fill()

    NSColor(calibratedRed: 0.04, green: 0.22, blue: 0.46, alpha: 0.18).setStroke()
    outer.lineWidth = 8 * scale
    outer.stroke()

    NSColor(calibratedRed: 0.04, green: 0.27, blue: 0.53, alpha: 0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 34 * scale, y: center.y + 18 * scale, width: 68 * scale, height: 68 * scale)).fill()
    NSBezierPath(roundedRect: NSRect(x: center.x - 58 * scale, y: center.y - 70 * scale, width: 116 * scale, height: 88 * scale), xRadius: 44 * scale, yRadius: 44 * scale).fill()
}

func drawSwitchArrow(start: NSPoint, control: NSPoint, end: NSPoint, color: NSColor, scale: CGFloat, clockwise: Bool) {
    let path = NSBezierPath()
    path.move(to: start)
    path.curve(to: end, controlPoint1: control, controlPoint2: control)
    color.setStroke()
    path.lineWidth = 42 * scale
    path.lineCapStyle = .round
    path.stroke()

    let angle: CGFloat = clockwise ? -0.78 : 2.36
    let tip = NSBezierPath()
    tip.move(to: end)
    tip.line(to: NSPoint(x: end.x + cos(angle + 2.5) * 88 * scale, y: end.y + sin(angle + 2.5) * 88 * scale))
    tip.line(to: NSPoint(x: end.x + cos(angle - 2.5) * 88 * scale, y: end.y + sin(angle - 2.5) * 88 * scale))
    tip.close()
    color.setFill()
    tip.fill()
}

func drawPrompt(scale: CGFloat) {
    let chevron = NSBezierPath()
    chevron.move(to: NSPoint(x: 336 * scale, y: 324 * scale))
    chevron.line(to: NSPoint(x: 400 * scale, y: 362 * scale))
    chevron.line(to: NSPoint(x: 336 * scale, y: 400 * scale))
    NSColor(calibratedRed: 0.28, green: 0.85, blue: 0.64, alpha: 1).setStroke()
    chevron.lineWidth = 20 * scale
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    chevron.stroke()

    NSColor(calibratedRed: 0.88, green: 0.96, blue: 1, alpha: 1).setStroke()
    let cursor = NSBezierPath()
    cursor.move(to: NSPoint(x: 438 * scale, y: 324 * scale))
    cursor.line(to: NSPoint(x: 575 * scale, y: 324 * scale))
    cursor.lineWidth = 20 * scale
    cursor.lineCapStyle = .round
    cursor.stroke()
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try png.write(to: url)
}
