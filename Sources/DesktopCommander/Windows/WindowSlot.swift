import Foundation

/// Where a window goes on its screen.
///
/// The type is pure. It holds no state, it touches no system, and it uses no
/// AppKit. Every rule of the layout lives in `frame(in:gap:)`, so a test reads a
/// rule with one rectangle and nothing else. A mistake here sends a window off
/// the screen, which is why the maths is separate from the code that moves it.
enum WindowSlot: String, CaseIterable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf

    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter

    case leftThird
    case centreThird
    case rightThird
    case firstTwoThirds
    case lastTwoThirds

    case maximize
    case centre

    /// The name in the menu and in the settings.
    var title: String {
        switch self {
        case .leftHalf: "Left half"
        case .rightHalf: "Right half"
        case .topHalf: "Top half"
        case .bottomHalf: "Bottom half"
        case .topLeftQuarter: "Top left quarter"
        case .topRightQuarter: "Top right quarter"
        case .bottomLeftQuarter: "Bottom left quarter"
        case .bottomRightQuarter: "Bottom right quarter"
        case .leftThird: "Left third"
        case .centreThird: "Centre third"
        case .rightThird: "Right third"
        case .firstTwoThirds: "First two thirds"
        case .lastTwoThirds: "Last two thirds"
        case .maximize: "Maximize"
        case .centre: "Centre"
        }
    }

    /// The groups of the Windows submenu, in order.
    static let groups: [(name: String, slots: [WindowSlot])] = [
        ("Halves", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("Quarters", [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter]),
        ("Thirds", [.leftThird, .centreThird, .rightThird, .firstTwoThirds, .lastTwoThirds]),
        ("Whole screen", [.maximize, .centre]),
    ]

    /// The rectangle for this slot.
    ///
    /// - Parameters:
    ///   - area: the usable part of the screen. The caller passes
    ///     `NSScreen.visibleFrame`, which already leaves out the menu bar and
    ///     the Dock.
    ///   - gap: the space between two windows, and between a window and the edge
    ///     of the screen. `0` gives windows that touch.
    ///   - current: the size the window has now. Only `.centre` reads it,
    ///     because centring keeps the size.
    func frame(in area: CGRect, gap: CGFloat = 0, current: CGSize = .zero) -> CGRect {
        // The gap sits once at each edge of the screen and once between two
        // windows that meet.
        let left = area.minX + gap
        let right = area.maxX - gap
        let bottom = area.minY + gap
        let top = area.maxY - gap

        let width = right - left
        let height = top - bottom

        // Two windows and one gap fill the width: 2h + gap = width.
        let halfWidth = width / 2 - gap / 2
        let halfHeight = height / 2 - gap / 2

        // Three windows and two gaps fill the width: 3t + 2 gap = width.
        let thirdWidth = width / 3 - gap * 2 / 3

        // Two of those thirds and the gap between them.
        let twoThirdsWidth = thirdWidth * 2 + gap

        switch self {
        case .leftHalf:
            return CGRect(x: left, y: bottom, width: halfWidth, height: height)
        case .rightHalf:
            return CGRect(x: right - halfWidth, y: bottom, width: halfWidth, height: height)
        case .topHalf:
            return CGRect(x: left, y: top - halfHeight, width: width, height: halfHeight)
        case .bottomHalf:
            return CGRect(x: left, y: bottom, width: width, height: halfHeight)

        case .topLeftQuarter:
            return CGRect(x: left, y: top - halfHeight, width: halfWidth, height: halfHeight)
        case .topRightQuarter:
            return CGRect(x: right - halfWidth, y: top - halfHeight, width: halfWidth, height: halfHeight)
        case .bottomLeftQuarter:
            return CGRect(x: left, y: bottom, width: halfWidth, height: halfHeight)
        case .bottomRightQuarter:
            return CGRect(x: right - halfWidth, y: bottom, width: halfWidth, height: halfHeight)

        case .leftThird:
            return CGRect(x: left, y: bottom, width: thirdWidth, height: height)
        case .centreThird:
            return CGRect(
                x: left + (width - thirdWidth) / 2,
                y: bottom,
                width: thirdWidth,
                height: height
            )
        case .rightThird:
            return CGRect(x: right - thirdWidth, y: bottom, width: thirdWidth, height: height)
        case .firstTwoThirds:
            return CGRect(x: left, y: bottom, width: twoThirdsWidth, height: height)
        case .lastTwoThirds:
            return CGRect(x: right - twoThirdsWidth, y: bottom, width: twoThirdsWidth, height: height)

        case .maximize:
            return CGRect(x: left, y: bottom, width: width, height: height)

        case .centre:
            // Centring keeps the size, but a window bigger than the screen is
            // cut down, otherwise it would hang over both edges.
            let size = CGSize(
                width: min(current.width, width),
                height: min(current.height, height)
            )
            return CGRect(
                x: left + (width - size.width) / 2,
                y: bottom + (height - size.height) / 2,
                width: size.width,
                height: size.height
            )
        }
    }
}
