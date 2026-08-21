import Foundation
import Testing
@testable import DesktopCommander

@Suite("ScreenGeometry")
struct ScreenGeometryTests {
    /// A primary screen 1000 wide and 600 high. Its top edge in AppKit
    /// coordinates is therefore 600.
    private let primaryMaxY: CGFloat = 600

    // MARK: - The flip of the y axis

    @Test("A window at the top left of the screen is at y zero for Accessibility")
    func topLeft() {
        // AppKit: 100 high, its top at 600, so its bottom at 500.
        let appKit = CGRect(x: 0, y: 500, width: 200, height: 100)

        let result = ScreenGeometry.accessibilityFrame(from: appKit, primaryMaxY: primaryMaxY)

        #expect(result == CGRect(x: 0, y: 0, width: 200, height: 100))
    }

    @Test("A window at the bottom of the screen has the largest y for Accessibility")
    func bottomLeft() {
        let appKit = CGRect(x: 0, y: 0, width: 200, height: 100)

        let result = ScreenGeometry.accessibilityFrame(from: appKit, primaryMaxY: primaryMaxY)

        #expect(result == CGRect(x: 0, y: 500, width: 200, height: 100))
    }

    @Test("The x axis does not change")
    func keepsX() {
        let appKit = CGRect(x: 137, y: 200, width: 200, height: 100)

        let result = ScreenGeometry.accessibilityFrame(from: appKit, primaryMaxY: primaryMaxY)

        #expect(result.minX == 137)
        #expect(result.width == 200)
        #expect(result.height == 100)
    }

    @Test("The two directions undo each other", arguments: [
        CGRect(x: 0, y: 0, width: 100, height: 100),
        CGRect(x: 1000, y: 200, width: 800, height: 400),
        CGRect(x: -500, y: -300, width: 640, height: 480),
    ])
    func roundTrip(frame: CGRect) {
        let there = ScreenGeometry.accessibilityFrame(from: frame, primaryMaxY: primaryMaxY)
        let back = ScreenGeometry.appKitFrame(from: there, primaryMaxY: primaryMaxY)

        #expect(back == frame)
    }

    @Test("A display above the primary one gives a negative y for Accessibility")
    func displayAbove() {
        // A second display sits on top of the primary one, so in AppKit its y
        // runs from 600 to 1200.
        let appKit = CGRect(x: 0, y: 1100, width: 200, height: 100)

        let result = ScreenGeometry.accessibilityFrame(from: appKit, primaryMaxY: primaryMaxY)

        #expect(result.minY == -600)
    }

    @Test("A display below the primary one gives a y past the bottom")
    func displayBelow() {
        let appKit = CGRect(x: 0, y: -600, width: 200, height: 100)

        let result = ScreenGeometry.accessibilityFrame(from: appKit, primaryMaxY: primaryMaxY)

        #expect(result.minY == 1100)
    }

    // MARK: - Which screen holds the window

    private let screens = [
        CGRect(x: 0, y: 0, width: 1000, height: 600),
        CGRect(x: 1000, y: 0, width: 800, height: 600),
    ]

    @Test("A window inside one screen belongs to that screen")
    func insideOne() {
        #expect(ScreenGeometry.screenIndex(
            holding: CGRect(x: 10, y: 10, width: 100, height: 100), in: screens) == 0)
        #expect(ScreenGeometry.screenIndex(
            holding: CGRect(x: 1200, y: 10, width: 100, height: 100), in: screens) == 1)
    }

    @Test("A window over two screens belongs to the one that holds more of it")
    func acrossTwo() {
        // 300 wide: 100 on the left screen, 200 on the right one.
        let frame = CGRect(x: 900, y: 0, width: 300, height: 100)

        #expect(ScreenGeometry.screenIndex(holding: frame, in: screens) == 1)
    }

    @Test("A window on no screen falls back to the first one")
    func outside() {
        let frame = CGRect(x: 5000, y: 5000, width: 100, height: 100)

        #expect(ScreenGeometry.screenIndex(holding: frame, in: screens) == 0)
    }

    @Test("An empty list gives nothing")
    func noScreens() {
        #expect(ScreenGeometry.screenIndex(
            holding: CGRect(x: 0, y: 0, width: 1, height: 1), in: []) == nil)
    }

    // MARK: - The move to another display

    @Test("A window keeps its relative place on a screen of the same size")
    func sameSize() {
        let source = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let target = CGRect(x: 1000, y: 0, width: 1000, height: 600)
        let frame = CGRect(x: 500, y: 0, width: 500, height: 600) // The right half.

        let result = ScreenGeometry.moved(frame, from: source, to: target)

        #expect(result == CGRect(x: 1500, y: 0, width: 500, height: 600))
    }

    @Test("A window keeps its relative place on a smaller screen")
    func smallerScreen() {
        let source = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let target = CGRect(x: 1000, y: 0, width: 500, height: 300)
        let frame = CGRect(x: 500, y: 0, width: 500, height: 600) // The right half.

        let result = ScreenGeometry.moved(frame, from: source, to: target)

        // Still the right half, at half the size.
        #expect(result == CGRect(x: 1250, y: 0, width: 250, height: 300))
    }

    @Test("A source screen with no size leaves the window alone")
    func emptySource() {
        let frame = CGRect(x: 1, y: 2, width: 3, height: 4)

        let result = ScreenGeometry.moved(frame, from: .zero, to: screens[0])

        #expect(result == frame)
    }
}
