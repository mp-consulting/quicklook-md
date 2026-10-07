#!/usr/bin/env swift
// Draws the QuickLook MD app icon and writes App/Assets.xcassets/AppIcon.appiconset.
// Usage: swift scripts/make-icon.swift [output-directory]

import AppKit
import CoreGraphics

let canvas: CGFloat = 1024

/// Shadows are specified in device pixels, not user space, so they're scaled per output size.
var shadowScale: CGFloat = 1

extension CGContext {
    func setScaledShadow(offset: CGSize, blur: CGFloat, color: CGColor) {
        setShadow(offset: CGSize(width: offset.width * shadowScale, height: offset.height * shadowScale), blur: blur * shadowScale, color: color)
    }
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func linearGradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

/// A rectangle with rounded corners, except a folded top-right corner of size `fold`.
func pagePath(_ rect: CGRect, radius: CGFloat, fold: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
    path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: radius)
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
    path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.maxY))
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: radius)
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: radius)
    path.closeSubpath()
    return path
}

/// The Markdown mark (CC0, github.com/dcurtis/markdown-mark), in its 208×128 view box with a y-down origin.
func markdownGlyph() -> CGPath {
    let path = CGMutablePath()
    // "M"
    path.addLines(between: [
        CGPoint(x: 30, y: 98), CGPoint(x: 30, y: 30), CGPoint(x: 50, y: 30), CGPoint(x: 70, y: 55),
        CGPoint(x: 90, y: 30), CGPoint(x: 110, y: 30), CGPoint(x: 110, y: 98), CGPoint(x: 90, y: 98),
        CGPoint(x: 90, y: 59), CGPoint(x: 70, y: 84), CGPoint(x: 50, y: 59), CGPoint(x: 50, y: 98),
    ])
    path.closeSubpath()
    // Down arrow
    path.addLines(between: [
        CGPoint(x: 155, y: 98), CGPoint(x: 125, y: 65), CGPoint(x: 145, y: 65), CGPoint(x: 145, y: 30),
        CGPoint(x: 165, y: 30), CGPoint(x: 165, y: 65), CGPoint(x: 185, y: 65),
    ])
    path.closeSubpath()
    return path
}

func drawIcon(in context: CGContext) {
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Tile with drop shadow and a vertical indigo gradient.
    context.saveGState()
    context.setScaledShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    context.addPath(tilePath)
    context.setFillColor(color(0x4338CA))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    context.drawLinearGradient(
        linearGradient([color(0x6D7BFF), color(0x4F46E5), color(0x3523A8)]),
        start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: []
    )
    // Soft glow in the upper left.
    context.drawRadialGradient(
        linearGradient([color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)]),
        startCenter: CGPoint(x: 300, y: 860), startRadius: 0,
        endCenter: CGPoint(x: 300, y: 860), endRadius: 520, options: []
    )
    context.restoreGState()

    // Document page.
    let page = CGRect(x: 236, y: 214, width: 470, height: 600)
    let fold: CGFloat = 120
    let pageOutline = pagePath(page, radius: 40, fold: fold)
    context.saveGState()
    context.setScaledShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: color(0x140B4F, 0.45))
    context.addPath(pageOutline)
    context.setFillColor(color(0xFFFFFF))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(pageOutline)
    context.clip()
    context.drawLinearGradient(
        linearGradient([color(0xFFFFFF), color(0xEEF0FB)]),
        start: CGPoint(x: 0, y: page.maxY), end: CGPoint(x: 0, y: page.minY), options: []
    )
    context.restoreGState()

    // Folded corner.
    let foldPath = CGMutablePath()
    foldPath.move(to: CGPoint(x: page.maxX - fold, y: page.maxY))
    foldPath.addLine(to: CGPoint(x: page.maxX - fold, y: page.maxY - fold + 22))
    foldPath.addQuadCurve(to: CGPoint(x: page.maxX - fold + 22, y: page.maxY - fold), control: CGPoint(x: page.maxX - fold, y: page.maxY - fold))
    foldPath.addLine(to: CGPoint(x: page.maxX, y: page.maxY - fold))
    foldPath.closeSubpath()
    context.saveGState()
    context.setScaledShadow(offset: CGSize(width: -6, height: -6), blur: 12, color: color(0x1E1B4B, 0.25))
    context.addPath(foldPath)
    context.setFillColor(color(0xD9DCF2))
    context.fillPath()
    context.restoreGState()

    // Markdown mark: rounded outline plus glyph, scaled from its 208×128 view box.
    let markWidth: CGFloat = 330
    let scale = markWidth / 208
    let markOrigin = CGPoint(x: page.minX + 52, y: page.maxY - 70)
    var transform = CGAffineTransform(translationX: markOrigin.x, y: markOrigin.y).scaledBy(x: scale, y: -scale)
    let ink = color(0x1F2347)
    let outline = CGPath(roundedRect: CGRect(x: 5, y: 5, width: 198, height: 118), cornerWidth: 12, cornerHeight: 12, transform: &transform)
    context.addPath(outline)
    context.setStrokeColor(ink)
    context.setLineWidth(10 * scale)
    context.strokePath()
    if let glyph = markdownGlyph().copy(using: &transform) {
        context.addPath(glyph)
        context.setFillColor(ink)
        context.fillPath()
    }

    // Lines of text below the mark.
    let lineX = page.minX + 56
    for (index, width) in [330, 280, 310, 200].enumerated() {
        let y = page.maxY - 340 - CGFloat(index) * 58
        let line = CGPath(roundedRect: CGRect(x: lineX, y: y, width: CGFloat(width), height: 26), cornerWidth: 13, cornerHeight: 13, transform: nil)
        context.addPath(line)
        context.setFillColor(color(index == 0 ? 0x8B93C9 : 0xC3C8E6))
        context.fillPath()
    }

    // Quick Look magnifier.
    let lensCenter = CGPoint(x: 668, y: 372)
    let lensRadius: CGFloat = 150
    let ringWidth: CGFloat = 40
    let angle = -CGFloat.pi / 4

    // Handle, drawn first so the ring overlaps it.
    context.saveGState()
    context.translateBy(x: lensCenter.x, y: lensCenter.y)
    context.rotate(by: angle)
    context.setScaledShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: color(0x0B0630, 0.45))
    let handle = CGPath(roundedRect: CGRect(x: lensRadius - 6, y: -34, width: 140, height: 68), cornerWidth: 34, cornerHeight: 34, transform: nil)
    context.addPath(handle)
    context.setFillColor(color(0x2A1F6E))
    context.fillPath()
    context.restoreGState()

    // Lens glass.
    let lensRect = CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2)
    context.saveGState()
    context.addEllipse(in: lensRect)
    context.clip()
    context.drawLinearGradient(
        linearGradient([color(0xFFFFFF, 0.55), color(0xC7D2FE, 0.30)]),
        start: CGPoint(x: lensRect.minX, y: lensRect.maxY), end: CGPoint(x: lensRect.maxX, y: lensRect.minY), options: []
    )
    // Specular highlight: a thin crescent along the upper-left inner edge.
    context.addArc(center: lensCenter, radius: lensRadius - 42, startAngle: .pi * 0.62, endAngle: .pi * 1.05, clockwise: false)
    context.setStrokeColor(color(0xFFFFFF, 0.85))
    context.setLineWidth(18)
    context.setLineCap(.round)
    context.strokePath()
    context.restoreGState()

    // Ring with an orange gradient.
    context.saveGState()
    context.setScaledShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0x0B0630, 0.40))
    let ring = CGMutablePath()
    ring.addEllipse(in: lensRect.insetBy(dx: -ringWidth / 2, dy: -ringWidth / 2))
    ring.addEllipse(in: lensRect.insetBy(dx: ringWidth / 2, dy: ringWidth / 2))
    context.addPath(ring)
    context.setFillColor(color(0xFF8A1F))
    context.fillPath(using: .evenOdd)
    context.restoreGState()

    context.saveGState()
    context.addPath(ring)
    context.clip(using: .evenOdd)
    context.drawLinearGradient(
        linearGradient([color(0xFFC24B), color(0xFF7A1A), color(0xE8590C)]),
        start: CGPoint(x: 0, y: lensRect.maxY + ringWidth), end: CGPoint(x: 0, y: lensRect.minY - ringWidth), options: []
    )
    context.restoreGState()
}

func renderPNG(size: Int) -> Data {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    shadowScale = CGFloat(size) / canvas
    context.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(in: context)
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    return bitmap.representation(using: .png, properties: [:])!
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let filename = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try renderPNG(size: pixels).write(to: outputDirectory.appendingPathComponent(filename))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: outputDirectory.appendingPathComponent("Contents.json"))

let catalogContents = outputDirectory.deletingLastPathComponent().appendingPathComponent("Contents.json")
if !FileManager.default.fileExists(atPath: catalogContents.path) {
    try Data(#"{"info":{"author":"xcode","version":1}}"#.utf8).write(to: catalogContents)
}
print("Wrote \(images.count) icon images to \(outputDirectory.path)")
