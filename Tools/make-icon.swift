#!/usr/bin/env swift
//
// Draws the desktop-commander application icon.
//
//   swift Tools/make-icon.swift
//
// It writes two things:
//
//   Resources/AppIcon.icon/Assets/adjustments.svg  the glyph layer of the icon
//   Docs/icon-light.png, Docs/icon-dark.png        the previews for the README
//
// The previews live outside Resources, because everything in Resources goes
// into the application bundle.
//
// `Resources/AppIcon.icon/icon.json` is written by hand, not by this script. It
// holds the colours: a dark glyph on a light plate, and a light glyph on a dark
// plate. macOS 26 picks the one that matches the system.
//
// The glyph is the "adjustments" icon from Tabler Icons, MIT licensed,
// Copyright (c) 2020-2026 Pawel Kuna. See https://tabler.io/icons.
//
// The menu bar draws the same path from
// Sources/DesktopCommander/Views/CommanderGlyph.swift. This script runs on its
// own, outside the application, so it cannot import that file. Change the two
// together.

import CoreGraphics
import Foundation

let iconPackage = "Resources/AppIcon.icon"
let canvas: CGFloat = 1024

/// The Tabler "adjustments" outline, in its own 24 x 24 space. The y axis points
/// down, as in SVG.
///
/// Three sliders. Each one is a knob with a piece of rail above it and a piece
/// below it.
func tablerAdjustments() -> CGMutablePath {
    let path = CGMutablePath()

    // The centre of the knob, then the two ends of the rail above it and the
    // two ends of the rail below it.
    let sliders: [(CGPoint, ClosedRange<CGFloat>, ClosedRange<CGFloat>)] = [
        (CGPoint(x: 6, y: 10), 4 ... 8, 12 ... 20),
        (CGPoint(x: 12, y: 16), 4 ... 14, 18 ... 20),
        (CGPoint(x: 18, y: 7), 4 ... 5, 9 ... 20),
    ]
    let radius: CGFloat = 2

    for (centre, above, below) in sliders {
        path.addEllipse(in: CGRect(
            x: centre.x - radius,
            y: centre.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        path.move(to: CGPoint(x: centre.x, y: above.lowerBound))
        path.addLine(to: CGPoint(x: centre.x, y: above.upperBound))

        path.move(to: CGPoint(x: centre.x, y: below.lowerBound))
        path.addLine(to: CGPoint(x: centre.x, y: below.upperBound))
    }

    return path
}

/// The glyph as one filled shape, in the 1024 x 1024 space of the icon.
///
/// A layer of a `.icon` package is filled, not stroked, and Icon Composer
/// recolours it per appearance. The stroke therefore becomes an outline here.
func glyphOutline() -> CGPath {
    let box = canvas * 0.586 // The share of the plate the glyph covers.
    let scale = box / 24
    let offset = (canvas - box) / 2

    var transform = CGAffineTransform(translationX: offset, y: offset)
        .scaledBy(x: scale, y: scale)
    let placed = tablerAdjustments().copy(using: &transform)!

    // Tabler ships the icon at stroke-width 2, with round caps and joins.
    return placed.copy(strokingWithWidth: 2 * scale, lineCap: .round, lineJoin: .round, miterLimit: 10)
}

func svgPathData(_ path: CGPath) -> String {
    func number(_ value: CGFloat) -> String { String(format: "%.2f", value) }

    var data = ""
    path.applyWithBlock { element in
        let points = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint:
            data += "M\(number(points[0].x)) \(number(points[0].y)) "
        case .addLineToPoint:
            data += "L\(number(points[0].x)) \(number(points[0].y)) "
        case .addQuadCurveToPoint:
            data += "Q\(number(points[0].x)) \(number(points[0].y)) "
            data += "\(number(points[1].x)) \(number(points[1].y)) "
        case .addCurveToPoint:
            data += "C\(number(points[0].x)) \(number(points[0].y)) "
            data += "\(number(points[1].x)) \(number(points[1].y)) "
            data += "\(number(points[2].x)) \(number(points[2].y)) "
        case .closeSubpath:
            data += "Z "
        @unknown default:
            break
        }
    }
    return data.trimmingCharacters(in: .whitespaces)
}

func writeGlyph() {
    let size = Int(canvas)
    let svg = """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg width="\(size)" height="\(size)" viewBox="0 0 \(size) \(size)" xmlns="http://www.w3.org/2000/svg">
    <path fill="#000000" fill-rule="nonzero" stroke="none" d="\(svgPathData(glyphOutline()))"/>
    </svg>
    """

    let directory = "\(iconPackage)/Assets"
    try! FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
    try! svg.write(toFile: "\(directory)/adjustments.svg", atomically: true, encoding: .utf8)
    print("wrote \(directory)/adjustments.svg")
}

/// `ictool` ships inside Icon Composer, which ships inside Xcode.
func ictoolPath() -> String? {
    let which = Process()
    which.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
    which.arguments = ["-p"]
    let pipe = Pipe()
    which.standardOutput = pipe
    try? which.run()
    which.waitUntilExit()

    let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let developer = output.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !developer.isEmpty else { return nil }

    let tool = URL(fileURLWithPath: developer)
        .deletingLastPathComponent()
        .appendingPathComponent("Applications/Icon Composer.app/Contents/Executables/ictool")
        .path
    return FileManager.default.isExecutableFile(atPath: tool) ? tool : nil
}

/// The README shows the icon, so export one preview of each appearance.
func writePreviews() {
    guard let ictool = ictoolPath() else {
        print("skipped the previews: ictool not found")
        return
    }

    try! FileManager.default.createDirectory(atPath: "Docs", withIntermediateDirectories: true)

    for (rendition, name) in [("Default", "icon-light.png"), ("Dark", "icon-dark.png")] {
        let export = Process()
        export.executableURL = URL(fileURLWithPath: ictool)
        export.arguments = [
            iconPackage, "--export-image",
            "--output-file", "Docs/\(name)",
            "--platform", "macOS", "--rendition", rendition,
            "--width", "512", "--height", "512", "--scale", "1",
        ]
        export.standardOutput = FileHandle.nullDevice
        try! export.run()
        export.waitUntilExit()
        print("wrote Docs/\(name)")
    }
}

writeGlyph()
writePreviews()
