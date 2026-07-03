#!/usr/bin/env swift
//
//  generate_appicon.swift
//  Standup Timer — Pulse / "Le Signal" app icon generator
//
//  Pure Core Graphics + ImageIO. No external art, no SwiftUI ImageRenderer
//  (which is unreliable headless). Draws the icon at 1024×1024 and exports
//  every size required by the macOS and iOS AppIcon asset catalogs.
//
//  Design ("Pulse / Le Signal"):
//   - Night gradient background: deep charcoal (#0A0B0D) → lifted dark (#131519),
//     top-left → bottom-right.
//   - A soft green radial halo/glow behind the ring.
//   - A near-full countdown timer ring (arc) in signal green (#00E08A).
//   - A centered "go" play triangle (signal green) evoking "start".
//
//  Usage:  swift scripts/generate_appicon.swift  [outputDir]
//
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)])!
}

let nightTop    = rgb(0x0A/255.0, 0x0B/255.0, 0x0D/255.0)   // #0A0B0D
let nightBottom = rgb(0x13/255.0, 0x15/255.0, 0x19/255.0)   // #131519
let signalGreen = rgb(0x00/255.0, 0xE0/255.0, 0x8A/255.0)   // #00E08A
let greenBright = rgb(0x4C/255.0, 0xFF/255.0, 0xB8/255.0)   // lifted highlight on the ring
let ringTrack   = rgb(1, 1, 1, 0.06)                        // faint full-circle track

// MARK: - Icon modes (iOS 18 appearances)

// iOS 17+ single-size AppIcon supports light / dark / tinted appearances.
//   .standard : full-color night icon on the night-gradient square (light/default).
//   .dark     : green ring + triangle (+ glow) on a TRANSPARENT background — the
//               system supplies its own dark backdrop behind the art.
//   .tinted   : grayscale (luminance-based) ring + triangle on TRANSPARENT — the
//               system tints the art using the user's chosen tint color.
enum IconMode {
    case standard
    case dark
    case tinted
}

// Per-mode palette. The geometry/drawing is shared; only colors + whether the
// night-gradient background is painted change.
struct IconPalette {
    let drawBackground: Bool
    let strokeBright: CGColor     // bright stop of the ring/triangle gradient
    let strokeBase:   CGColor     // base stop of the ring/triangle gradient
    let halo:  (r: Double, g: Double, b: Double)   // radial halo accent
    let haloMaxAlpha: Double      // peak halo opacity at center
    let glow:  CGColor            // soft shadow/glow under the triangle + head dot
    let head:  CGColor            // bright leading "now" dot
}

func palette(for mode: IconMode) -> IconPalette {
    switch mode {
    case .standard, .dark:
        // Same signal-green art; .dark just drops the night-gradient square so the
        // system backdrop shows through.
        return IconPalette(
            drawBackground: mode == .standard,
            strokeBright: greenBright,
            strokeBase:   signalGreen,
            halo: (0x00/255.0, 0xE0/255.0, 0x8A/255.0),
            haloMaxAlpha: 0.55,
            glow: rgb(0x00/255.0, 0xE0/255.0, 0x8A/255.0, 0.8),
            head: greenBright)
    case .tinted:
        // Monochrome / luminance-based: the system applies the user's tint. Render
        // the art in white→light-gray so the tint reads cleanly. Transparent bg.
        let white     = rgb(1, 1, 1)
        let lightGray = rgb(0.62, 0.62, 0.62)
        return IconPalette(
            drawBackground: false,
            strokeBright: white,
            strokeBase:   lightGray,
            halo: (1, 1, 1),
            haloMaxAlpha: 0.28,
            glow: rgb(1, 1, 1, 0.8),
            head: white)
    }
}

// MARK: - Drawing

func drawIcon(into ctx: CGContext, size S: CGFloat, mode: IconMode = .standard) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let c  = S / 2.0
    let pal = palette(for: mode)

    // High-quality scaling/interpolation.
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)

    // --- 1. Night gradient background (full-bleed square) ---
    // Only painted for the standard/light icon. For dark + tinted appearances the
    // background stays fully transparent so the system supplies the backdrop.
    if pal.drawBackground {
        let bgGradient = CGGradient(colorsSpace: cs,
                                    colors: [nightTop, nightBottom] as CFArray,
                                    locations: [0.0, 1.0])!
        ctx.saveGState()
        ctx.addRect(CGRect(x: 0, y: 0, width: S, height: S))
        ctx.clip()
        ctx.drawLinearGradient(bgGradient,
                               start: CGPoint(x: 0, y: S),       // top-left (flipped CG y)
                               end:   CGPoint(x: S, y: 0),       // bottom-right
                               options: [])
        ctx.restoreGState()
    }

    // Geometry: keep the ring within ~80% safe area, key elements ~60% center.
    let ringRadius   = S * 0.325            // ring sits inside ~80% safe zone
    let ringWidth    = S * 0.072
    let center       = CGPoint(x: c, y: c)

    // --- 2. Radial halo/glow behind the ring (mode-tinted) ---
    let haloRadius = ringRadius + ringWidth * 2.2
    let haloGradient = CGGradient(colorsSpace: cs,
        colors: [
            rgb(pal.halo.r, pal.halo.g, pal.halo.b, pal.haloMaxAlpha),
            rgb(pal.halo.r, pal.halo.g, pal.halo.b, pal.haloMaxAlpha * 0.4),
            rgb(pal.halo.r, pal.halo.g, pal.halo.b, 0.0),
        ] as CFArray,
        locations: [0.0, 0.55, 1.0])!
    ctx.saveGState()
    ctx.drawRadialGradient(haloGradient,
                           startCenter: center, startRadius: ringRadius * 0.55,
                           endCenter:   center, endRadius:   haloRadius,
                           options: [])
    ctx.restoreGState()

    // --- 3a. Faint full-circle track (the "remaining" part of the dial) ---
    ctx.saveGState()
    ctx.setLineWidth(ringWidth)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(ringTrack)
    ctx.addArc(center: center, radius: ringRadius,
               startAngle: 0, endAngle: 2 * .pi, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // --- 3b. Near-full countdown ring (sweeps most of the circle) ---
    // Start near the top, sweep clockwise ~300° leaving a small gap (countdown feel).
    // CG angles are counter-clockwise; we draw clockwise for a depleting-dial look.
    let startAngle: CGFloat = .pi / 2 + 0.40          // just past top
    let sweep:      CGFloat = 2 * .pi * 0.84          // ~302°
    let endAngle             = startAngle - sweep

    // Gradient stroke: emulate a conic feel by stroking with a bright→base
    // along the arc using a clipped linear gradient.
    ctx.saveGState()
    let ringPath = CGMutablePath()
    ringPath.addArc(center: center, radius: ringRadius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: true)
    ctx.addPath(ringPath)
    ctx.setLineWidth(ringWidth)
    ctx.setLineCap(.round)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let ringGradient = CGGradient(colorsSpace: cs,
                                  colors: [pal.strokeBright, pal.strokeBase] as CFArray,
                                  locations: [0.0, 1.0])!
    ctx.drawLinearGradient(ringGradient,
                           start: CGPoint(x: c - ringRadius, y: c + ringRadius),
                           end:   CGPoint(x: c + ringRadius, y: c - ringRadius),
                           options: [])
    ctx.restoreGState()

    // Bright leading dot at the head of the ring (the "now" marker).
    let headX = c + cos(startAngle) * ringRadius
    let headY = c + sin(startAngle) * ringRadius
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: S * 0.02, color: pal.head)
    ctx.setFillColor(pal.head)
    ctx.fillEllipse(in: CGRect(x: headX - ringWidth * 0.5, y: headY - ringWidth * 0.5,
                               width: ringWidth, height: ringWidth))
    ctx.restoreGState()

    // --- 4. Centered "go" play triangle ---
    // Equilateral-ish triangle pointing right, optically centered, within ~60% zone.
    let triH = ringRadius * 0.95            // total visual width of the triangle
    let triHalf = triH * 0.86 / 2.0          // half-height
    // Optical centering: shift left a touch so the visual mass is centered.
    let tx = c - triH * 0.06
    let p1 = CGPoint(x: tx - triH * 0.42, y: c + triHalf)   // top-left
    let p2 = CGPoint(x: tx - triH * 0.42, y: c - triHalf)   // bottom-left
    let p3 = CGPoint(x: tx + triH * 0.58, y: c)             // right point

    let triPath = CGMutablePath()
    triPath.move(to: p1)
    triPath.addLine(to: p2)
    triPath.addLine(to: p3)
    triPath.closeSubpath()
    // Rounded join for a softer, geometric look.
    let rounded = roundedTrianglePath([p1, p2, p3], cornerRadius: S * 0.022)

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: S * 0.018, color: pal.glow)
    ctx.addPath(rounded)
    ctx.clip()
    let triGradient = CGGradient(colorsSpace: cs,
                                 colors: [pal.strokeBright, pal.strokeBase] as CFArray,
                                 locations: [0.0, 1.0])!
    ctx.drawLinearGradient(triGradient,
                           start: CGPoint(x: tx, y: c + triHalf),
                           end:   CGPoint(x: tx, y: c - triHalf),
                           options: [])
    ctx.restoreGState()
    _ = triPath
}

// MARK: - Rounded triangle helper

func roundedTrianglePath(_ pts: [CGPoint], cornerRadius r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let n = pts.count
    for i in 0..<n {
        let prev = pts[(i + n - 1) % n]
        let curr = pts[i]
        let next = pts[(i + 1) % n]
        let v1 = CGPoint(x: curr.x - prev.x, y: curr.y - prev.y)
        let v2 = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
        let l1 = max(hypot(v1.x, v1.y), 0.0001)
        let l2 = max(hypot(v2.x, v2.y), 0.0001)
        let rr = min(r, l1 / 2, l2 / 2)
        let start = CGPoint(x: curr.x - v1.x / l1 * rr, y: curr.y - v1.y / l1 * rr)
        let end   = CGPoint(x: curr.x + v2.x / l2 * rr, y: curr.y + v2.y / l2 * rr)
        if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
        path.addQuadCurve(to: end, control: curr)
    }
    path.closeSubpath()
    return path
}

// MARK: - Render & write

func renderPNG(size: Int, to url: URL, mode: IconMode = .standard) {
    let S = CGFloat(size)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil,
                              width: size, height: size,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("Could not create CGContext for size \(size)")
    }
    drawIcon(into: ctx, size: S, mode: mode)
    guard let image = ctx.makeImage() else { fatalError("makeImage failed for \(size)") }
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString,
                                                     1, nil) else {
        fatalError("Could not create PNG destination at \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        fatalError("Failed to finalize PNG at \(url.path)")
    }
    print("  wrote \(url.lastPathComponent) (\(size)×\(size))")
}

// MARK: - Main

let args = CommandLine.arguments
let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outDir = args.count > 1
    ? URL(fileURLWithPath: args[1])
    : repoRoot.appendingPathComponent("scripts/_icon_out")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// All sizes needed across both catalogs (standard / light appearance).
let sizes = [16, 32, 64, 128, 256, 512, 1024]
print("Generating Pulse icon PNGs into \(outDir.path)")
for s in sizes {
    renderPNG(size: s, to: outDir.appendingPathComponent("icon_\(s).png"))
}

// --- iOS 18 dark + tinted AppIcon appearance variants ---
// Emitted directly into the iOS AppIcon asset catalog at the single universal
// 1024 size. The standard light icon (AppIcon-1024.png) is left untouched.
let iosAppIcon = repoRoot.appendingPathComponent(
    "StandupTimer-iOS/Assets.xcassets/AppIcon.appiconset")
if FileManager.default.fileExists(atPath: iosAppIcon.path) {
    print("Generating iOS appearance variants into \(iosAppIcon.path)")
    renderPNG(size: 1024,
              to: iosAppIcon.appendingPathComponent("AppIcon-1024-dark.png"),
              mode: .dark)
    renderPNG(size: 1024,
              to: iosAppIcon.appendingPathComponent("AppIcon-1024-tinted.png"),
              mode: .tinted)
} else {
    print("note: iOS AppIcon.appiconset not found at \(iosAppIcon.path); skipping variants")
}
print("Done.")
