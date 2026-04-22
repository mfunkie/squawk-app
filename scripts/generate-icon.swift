#!/usr/bin/env swift

import SwiftUI
import AppKit
import Foundation

let NAVY = Color(red: 0.055, green: 0.09, blue: 0.2)
let GOLD = Color(red: 1.0, green: 0.835, blue: 0.29)
let ORANGE = Color(red: 1.0, green: 0.416, blue: 0.122)
let CORNER_RATIO: CGFloat = 0.2237

struct IconView: View {
    let size: CGFloat

    var body: some View {
        let corner = CGSize(width: size * CORNER_RATIO, height: size * CORNER_RATIO)
        ZStack {
            RoundedRectangle(cornerSize: corner, style: .continuous)
                .fill(LinearGradient(
                    colors: [GOLD, ORANGE],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            RoundedRectangle(cornerSize: corner, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.32), Color.clear],
                    center: UnitPoint(x: 0.3, y: 0.18),
                    startRadius: 0,
                    endRadius: size * 0.55
                ))
                .blendMode(.plusLighter)

            VStack(spacing: size * 0.03) {
                Image(systemName: "bird.fill")
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(NAVY)
                Image(systemName: "waveform")
                    .font(.system(size: size * 0.18, weight: .medium))
                    .foregroundStyle(NAVY.opacity(0.72))
            }
            .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
    }
}

struct IconSpec {
    let pixelSize: CGFloat
    let filename: String
    let jsonSize: String
    let jsonScale: String
}

let SPECS: [IconSpec] = [
    IconSpec(pixelSize: 16,   filename: "icon_16x16.png",      jsonSize: "16x16",   jsonScale: "1x"),
    IconSpec(pixelSize: 32,   filename: "icon_16x16@2x.png",   jsonSize: "16x16",   jsonScale: "2x"),
    IconSpec(pixelSize: 32,   filename: "icon_32x32.png",      jsonSize: "32x32",   jsonScale: "1x"),
    IconSpec(pixelSize: 64,   filename: "icon_32x32@2x.png",   jsonSize: "32x32",   jsonScale: "2x"),
    IconSpec(pixelSize: 128,  filename: "icon_128x128.png",    jsonSize: "128x128", jsonScale: "1x"),
    IconSpec(pixelSize: 256,  filename: "icon_128x128@2x.png", jsonSize: "128x128", jsonScale: "2x"),
    IconSpec(pixelSize: 256,  filename: "icon_256x256.png",    jsonSize: "256x256", jsonScale: "1x"),
    IconSpec(pixelSize: 512,  filename: "icon_256x256@2x.png", jsonSize: "256x256", jsonScale: "2x"),
    IconSpec(pixelSize: 512,  filename: "icon_512x512.png",    jsonSize: "512x512", jsonScale: "1x"),
    IconSpec(pixelSize: 1024, filename: "icon_512x512@2x.png", jsonSize: "512x512", jsonScale: "2x"),
]

@MainActor
func renderPNG(size: CGFloat, to url: URL) throws {
    let renderer = ImageRenderer(content: IconView(size: size))
    renderer.scale = 1.0
    guard let cg = renderer.cgImage else {
        throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "cgImage nil for size \(size)"])
    }
    let rep = NSBitmapImageRep(cgImage: cg)
    rep.size = NSSize(width: size, height: size)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "png encode failed for size \(size)"])
    }
    try png.write(to: url)
}

func writeContentsJSON(directory: URL, specs: [IconSpec]) throws {
    var images: [[String: Any]] = []
    for s in specs {
        images.append([
            "filename": s.filename,
            "idiom": "mac",
            "scale": s.jsonScale,
            "size": s.jsonSize,
        ])
    }
    let payload: [String: Any] = [
        "images": images,
        "info": ["author": "xcode", "version": 1],
    ]
    let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: directory.appendingPathComponent("Contents.json"))
}

@MainActor
func run() {
    let fm = FileManager.default
    let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
    let appiconset = cwd.appendingPathComponent("Squawk/Squawk/Assets.xcassets/AppIcon.appiconset")

    guard fm.fileExists(atPath: appiconset.path) else {
        FileHandle.standardError.write(Data("Error: \(appiconset.path) not found. Run from repo root.\n".utf8))
        exit(1)
    }

    print("Generating icons → \(appiconset.path)")

    do {
        for spec in SPECS {
            let url = appiconset.appendingPathComponent(spec.filename)
            try renderPNG(size: spec.pixelSize, to: url)
            print("  ✓ \(spec.filename) (\(Int(spec.pixelSize))×\(Int(spec.pixelSize)))")
        }
        try writeContentsJSON(directory: appiconset, specs: SPECS)
        print("  ✓ Contents.json updated")
    } catch {
        FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
        exit(1)
    }
}

MainActor.assumeIsolated { run() }
