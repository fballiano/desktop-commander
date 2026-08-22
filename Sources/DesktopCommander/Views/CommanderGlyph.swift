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
///
/// The application icon draws the path as Tabler ships it. The menu bar cannot,
/// because the menu bar is small. See `MenuBarLayout` below.
@MainActor
enum CommanderGlyph {
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

    /// The measurements of the menu bar image, in points.
    ///
    /// thyme-ng and clipboard-controller draw their own Tabler outline into a
    /// box of 20 points and take the stroke of 1.67 points that comes out. That
    /// works for them and not for this glyph, and the reason is where the lines
    /// fall.
    ///
    /// A stroke of 1.67 points is 3.3 Retina pixels. The side of the clipboard
    /// sits at grid 5, which is 8.3 pixels, so its stroke covers three whole
    /// pixels and one grey one. A rail of this glyph sits at grid 6, 12 and 18,
    /// which are exactly 10, 20 and 30 pixels, and a stroke of 3.3 pixels on a
    /// whole pixel covers two whole pixels and two grey ones. Six thin rails,
    /// each one two pixels of ink between two grey, and three rings whose hole
    /// of two pixels washes out into a blob: the icon reads at the same time
    /// thinner and dirtier than the icons beside it.
    ///
    /// So the menu bar keeps its own measurements. They put every rail on three
    /// whole pixels, the weight of the neighbours, and they leave the ring a
    /// hole that survives.
    private enum MenuBarLayout {
        /// The size of the image. The menu bar draws it at this size, without a
        /// scale: the button of a status item is 22 points tall and it does not
        /// resize the image.
        static let side: CGFloat = 18

        /// The distance between two rails. It is a whole number of Retina
        /// pixels, so the three rails always come out the same width. It also
        /// makes the ink about 16.5 points tall, the height of the icons of
        /// thyme-ng and of clipboard-controller.
        static let pitch: CGFloat = 5.5

        /// One grid unit of Tabler, in points.
        static var unit: CGFloat { pitch / 6 }

        /// The stroke, in points: three whole Retina pixels. It is the weight
        /// of the icons that stand beside it in the menu bar.
        static let stroke: CGFloat = 1.5

        /// The radius of a knob, in points. Tabler makes the radius and the
        /// stroke equal, and that proportion holds here: the ring keeps a hole
        /// of three pixels, which is enough once the glyph is sharp.
        static let knob: CGFloat = 1.5

        /// The scale of a Retina display.
        static let pixelScale: CGFloat = 2
    }

    /// The image for the menu bar. It is a template, so the menu bar colours it
    /// itself: it follows light and dark, and it inverts while the menu is open.
    ///
    /// There is one image, and the state of the switches does not change it. A
    /// second image with the knobs filled used to say "a switch is on". A knob
    /// is 9 pixels wide with a hole of 3, so filling it makes a solid disc, and
    /// the menu bar then carried three blobs all day beside two outline icons.
    /// The menu says which switch is on, and it says which one.
    static let menuBar: NSImage = image()

    private static func knobRect(_ centre: CGPoint, radius: CGFloat) -> NSRect {
        NSRect(
            x: centre.x - radius,
            y: centre.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }

    /// Where a point of the 24 x 24 grid goes inside the menu bar image.
    ///
    /// The ink is centred, and then the whole glyph moves by up to a quarter of
    /// a point, so that a rail sits in the middle of a Retina pixel. A stroke of
    /// three pixels then fills three whole pixels. Without this step a rail
    /// spreads over four pixels, two of them grey, the hole of each ring washes
    /// out, and the three rails do not even blur in the same way.
    nonisolated static func menuBarOrigin() -> CGPoint {
        let layout = MenuBarLayout.self
        let half = layout.stroke / 2
        let outer = layout.knob + half

        // The ink, in points: the rails from grid 6 to grid 18, widened by a
        // knob, and from grid 4 to grid 20, widened by a round cap.
        let width = 12 * layout.unit + 2 * outer
        let height = 16 * layout.unit + layout.stroke

        var x = (layout.side - width) / 2 - (6 * layout.unit - outer)
        var y = (layout.side - height) / 2 - (4 * layout.unit - half)

        x += snap(6 * layout.unit + x)
        y += snap(4 * layout.unit + y)

        return CGPoint(x: x, y: y)
    }

    /// How far a line must move to fill whole Retina pixels.
    ///
    /// A stroke of an even number of pixels wants its centre on the edge
    /// between two pixels. A stroke of an odd number wants it in the middle of
    /// one.
    private nonisolated static func snap(_ centre: CGFloat) -> CGFloat {
        let layout = MenuBarLayout.self
        let pixels = (layout.stroke * layout.pixelScale).rounded()
        let position = centre * layout.pixelScale
        let wanted = pixels.truncatingRemainder(dividingBy: 2) == 0
            ? position.rounded()
            : (position - 0.5).rounded() + 0.5

        return (wanted - position) / layout.pixelScale
    }

    private static func image() -> NSImage {
        let layout = MenuBarLayout.self
        let side = layout.side

        // `flipped: true` points the y axis down, as SVG does, so the path
        // needs no mirroring.
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
            let origin = menuBarOrigin()

            var transform = AffineTransform()
            transform.translate(x: origin.x, y: origin.y)
            transform.scale(layout.unit)

            let glyph = NSBezierPath()

            for slider in sliders {
                // The knob keeps its own radius, in points, so the transform
                // must not touch it.
                let centre = transform.transform(NSPoint(x: slider.centre.x, y: slider.centre.y))
                glyph.appendOval(in: knobRect(centre, radius: layout.knob))

                glyph.move(to: transform.transform(NSPoint(x: slider.centre.x, y: slider.above.0)))
                glyph.line(to: transform.transform(NSPoint(x: slider.centre.x, y: slider.above.1)))

                glyph.move(to: transform.transform(NSPoint(x: slider.centre.x, y: slider.below.0)))
                glyph.line(to: transform.transform(NSPoint(x: slider.centre.x, y: slider.below.1)))
            }

            glyph.lineWidth = layout.stroke
            glyph.lineCapStyle = .round // stroke-linecap="round"
            glyph.lineJoinStyle = .round // stroke-linejoin="round"

            // A template image only keeps its shape. The colour comes from the
            // menu bar.
            NSColor.black.setStroke()
            glyph.stroke()

            return true
        }

        image.isTemplate = true
        return image
    }
}
