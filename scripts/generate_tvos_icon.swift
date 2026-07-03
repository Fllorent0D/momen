#!/usr/bin/env swift
//
//  generate_tvos_icon.swift
//  Momen — tvOS "Brand Assets" (App Icon + Top Shelf) generator.
//
//  tvOS App Icons are PARALLAX imagestacks and must have ≥2 layers. We build:
//    • Back layer  : the night-gradient background (opaque, full-bleed).
//    • Front layer : the ring+triangle art on a TRANSPARENT canvas — reusing the
//                    already-approved "dark" icon variant (art on transparency).
//  Top Shelf images are flat imagesets (art composited on the gradient).
//
//  Usage:  swift scripts/generate_tvos_icon.swift
//
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
            components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)])!
}
let nightTop    = rgb(0x0A/255.0, 0x0B/255.0, 0x0D/255.0)
let nightBottom = rgb(0x13/255.0, 0x15/255.0, 0x19/255.0)

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func loadImage(_ rel: String) -> CGImage {
    let url = repoRoot.appendingPathComponent(rel)
    guard let s = CGImageSourceCreateWithURL(url as CFURL, nil),
          let i = CGImageSourceCreateImageAtIndex(s, 0, nil) else {
        fatalError("Could not load \(url.path)")
    }
    return i
}
// Standard (opaque, art + gradient) and dark (art on transparent) variants.
let iconFlat = loadImage("StandupTimer-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
let iconArt  = loadImage("StandupTimer-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-dark.png")

enum Mode { case gradient, art, flat }

func render(width: Int, height: Int, heightFraction: CGFloat, mode: Mode, to url: URL) {
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("CGContext \(width)x\(height)")
    }
    let W = CGFloat(width), H = CGFloat(height)

    if mode == .gradient || mode == .flat {
        let grad = CGGradient(colorsSpace: cs, colors: [nightTop, nightBottom] as CFArray,
                              locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H),
                               end: CGPoint(x: W, y: 0), options: [])
    }
    if mode == .art || mode == .flat {
        let img = mode == .art ? iconArt : iconFlat
        let side = H * heightFraction
        let rect = CGRect(x: (W - side) / 2, y: (H - side) / 2, width: side, height: side)
        ctx.interpolationQuality = .high
        ctx.draw(img, in: rect)
    }

    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL,
                        UTType.png.identifier as CFString, 1, nil) else {
        fatalError("PNG dest \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) { fatalError("finalize \(url.path)") }
    print("  wrote \(url.lastPathComponent) (\(width)×\(height))")
}

let brand = repoRoot.appendingPathComponent(
    "StandupTimer-tvOS/Assets.xcassets/App Icon & Top Shelf Image.brandassets")
func png(_ rel: String) -> URL { brand.appendingPathComponent(rel) }

// --- App Icon (on-device, 400×240) : Back gradient + Front art ---
render(width: 400, height: 240, heightFraction: 0.92, mode: .gradient, to: png("App Icon.imagestack/Back.imagestacklayer/Content.imageset/back-400.png"))
render(width: 800, height: 480, heightFraction: 0.92, mode: .gradient, to: png("App Icon.imagestack/Back.imagestacklayer/Content.imageset/back-800.png"))
render(width: 400, height: 240, heightFraction: 0.92, mode: .art, to: png("App Icon.imagestack/Front.imagestacklayer/Content.imageset/front-400.png"))
render(width: 800, height: 480, heightFraction: 0.92, mode: .art, to: png("App Icon.imagestack/Front.imagestacklayer/Content.imageset/front-800.png"))

// --- App Icon - App Store (1280×768) : Back gradient + Front art ---
render(width: 1280, height: 768, heightFraction: 0.92, mode: .gradient, to: png("App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/back-1280.png"))
render(width: 1280, height: 768, heightFraction: 0.92, mode: .art, to: png("App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/front-1280.png"))

// --- Top Shelf (flat imagesets) ---
render(width: 1920, height: 720,  heightFraction: 0.72, mode: .flat, to: png("Top Shelf Image.imageset/top-1920.png"))
render(width: 3840, height: 1440, heightFraction: 0.72, mode: .flat, to: png("Top Shelf Image.imageset/top-3840.png"))
render(width: 2320, height: 720,  heightFraction: 0.72, mode: .flat, to: png("Top Shelf Image Wide.imageset/topwide-2320.png"))
render(width: 4640, height: 1440, heightFraction: 0.72, mode: .flat, to: png("Top Shelf Image Wide.imageset/topwide-4640.png"))

print("Done.")
