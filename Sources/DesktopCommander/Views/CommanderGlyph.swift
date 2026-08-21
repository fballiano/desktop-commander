import AppKit

/// The "adjustments" outline from Tabler Icons, MIT licensed, Copyright (c)
/// 2020-2026 Paweł Kuna. See https://tabler.io/icons.
///
/// Three sliders. It says "a board of controls", which is what the application
/// is: switches for the state of the Mac, and commands for the windows.
///
/// `Tools/make-icon.swift` holds the same path for the application icon. That
/// script runs on its own, outside the application, so it cannot import this
/// file. Change the two together.
@MainActor
enum CommanderGlyph {
    /// Tabler draws on a 24 x 24 grid, with the y axis pointing down.
    static let grid: CGFloat = 24

    /// The stroke width Tabler ships.
    static let strokeWidth: CGFloat = 2

    /// The centre and the radius of each knob, and the two pieces of its rail.
    private static let sliders: [(centre: CGPoint, above: (CGFloat, CGFloat), below: (CGFloat, CGFloat))] = [
        // <path d="M4 10a2 2 0 1 0 4 0a2 2 0 0 0 -4 0" /> with
        // <path d="M6 4v4" /> and <path d="M6 12v8" />
        (CGPoint(x: 6, y: 10), (4, 8), (12, 20)),
        // <path d="M10 16a2 2 0 1 0 4 0a2 2 0 0 0 -4 0" /> with
        // <path d="M12 4v10" /> and <path d="M12 18v2" />
        (CGPoint(x: 12, y: 16), (4, 14), (18, 20)),
        // <path d="M16 7a2 2 0 1 0 4 0a2 2 0 0 0 -4 0" /> with
        // <path d="M18 4v1" /> and <path d="M18 9v11" />
        (CGPoint(x: 18, y: 7), (4, 5), (9, 20)),
    ]

    private static let knobRadius: CGFloat = 2

    /// The image for the menu bar. It is a template, so the menu bar colours it
    /// itself: it follows light and dark, and it inverts while the menu is open.
    static let menuBar: NSImage = image(side: 20, active: false)

    /// The same sliders with the knobs filled. It marks that a switch is on.
    static let menuBarActive: NSImage = image(side: 20, active: true)

    /// The rails and the knobs, in their own 24 x 24 space.
    static func outline() -> NSBezierPath {
        let path = NSBezierPath()

        for slider in sliders {
            path.appendOval(in: knobRect(slider.centre))

            path.move(to: NSPoint(x: slider.centre.x, y: slider.above.0))
            path.line(to: NSPoint(x: slider.centre.x, y: slider.above.1))

            path.move(to: NSPoint(x: slider.centre.x, y: slider.below.0))
            path.line(to: NSPoint(x: slider.centre.x, y: slider.below.1))
        }

        return path
    }

    /// The three knobs alone, to fill.
    static func knobs() -> NSBezierPath {
        let path = NSBezierPath()

        for slider in sliders {
            path.appendOval(in: knobRect(slider.centre))
        }

        return path
    }

    private static func knobRect(_ centre: CGPoint) -> NSRect {
        NSRect(
            x: centre.x - knobRadius,
            y: centre.y - knobRadius,
            width: knobRadius * 2,
            height: knobRadius * 2
        )
    }

    private static func image(side: CGFloat, active: Bool) -> NSImage {
        // `flipped: true` points the y axis down, as SVG does, so the path
        // needs no mirroring.
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let scale = side / grid

            var transform = AffineTransform()
            transform.scale(scale)

            let glyph = outline()
            glyph.transform(using: transform)
            glyph.lineWidth = strokeWidth * scale
            glyph.lineCapStyle = .round // stroke-linecap="round"
            glyph.lineJoinStyle = .round // stroke-linejoin="round"

            // A template image only keeps its shape. The colour comes from the
            // menu bar.
            NSColor.black.setStroke()
            glyph.stroke()

            if active {
                let filled = knobs()
                filled.transform(using: transform)
                NSColor.black.setFill()
                filled.fill()
            }

            return true
        }

        image.isTemplate = true
        return image
    }
}
