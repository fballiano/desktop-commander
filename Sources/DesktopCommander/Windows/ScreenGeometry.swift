import Foundation

/// Turns an AppKit rectangle into an Accessibility rectangle, and back.
///
/// The two systems disagree about the y axis:
///
/// - AppKit puts the origin at the **bottom left** of the primary screen, and y
///   grows **upwards**. `NSScreen.frame` speaks this language.
/// - The Accessibility API puts the origin at the **top left** of the primary
///   screen, and y grows **downwards**. `kAXPositionAttribute` speaks this one.
///
/// The x axis is the same in both. Only y changes, and the flip needs the top
/// edge of the primary screen, not of the screen the window is on. A window on a
/// second display above the primary one has a negative y in both systems, but
/// not the same negative y.
///
/// A sign error here throws a window off the screen, so this is a function with
/// its own tests, not a line inside a bigger method.
enum ScreenGeometry {
    /// AppKit to Accessibility.
    /// - Parameter primaryMaxY: the top edge of the primary screen in AppKit
    ///   coordinates, which is `NSScreen.screens[0].frame.maxY`.
    static func accessibilityFrame(from appKitFrame: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(
            x: appKitFrame.minX,
            y: primaryMaxY - appKitFrame.maxY,
            width: appKitFrame.width,
            height: appKitFrame.height
        )
    }

    /// Accessibility to AppKit.
    static func appKitFrame(from accessibilityFrame: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(
            x: accessibilityFrame.minX,
            y: primaryMaxY - accessibilityFrame.maxY,
            width: accessibilityFrame.width,
            height: accessibilityFrame.height
        )
    }

    /// The screen that holds most of the window.
    ///
    /// A window can lie over two screens. The one with the largest part of it
    /// wins, which is the rule the user expects: the window goes where they see
    /// it. A window that touches no screen falls back to the first one.
    /// - Parameter frames: the `frame` of each screen, in AppKit coordinates.
    /// - Returns: the index in `frames`, or `nil` when the list is empty.
    static func screenIndex(holding frame: CGRect, in frames: [CGRect]) -> Int? {
        guard !frames.isEmpty else { return nil }

        var best = 0
        var bestArea: CGFloat = -1

        for (index, screen) in frames.enumerated() {
            let overlap = screen.intersection(frame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height

            if area > bestArea {
                bestArea = area
                best = index
            }
        }

        return best
    }

    /// The same window on another screen, in the same relative place.
    ///
    /// The window keeps its position and its size as a share of the usable area,
    /// so a window on the right half of one display arrives on the right half of
    /// the next one, whatever the two sizes are.
    static func moved(
        _ frame: CGRect,
        from source: CGRect,
        to target: CGRect
    ) -> CGRect {
        guard source.width > 0, source.height > 0 else { return frame }

        let scaleX = target.width / source.width
        let scaleY = target.height / source.height

        return CGRect(
            x: target.minX + (frame.minX - source.minX) * scaleX,
            y: target.minY + (frame.minY - source.minY) * scaleY,
            width: frame.width * scaleX,
            height: frame.height * scaleY
        )
    }
}
