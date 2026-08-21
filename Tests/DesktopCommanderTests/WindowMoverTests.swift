import Foundation
import Testing
@testable import DesktopCommander

@MainActor
@Suite("WindowMover")
struct WindowMoverTests {
    /// One screen 1000 by 600, with a menu bar 40 high at the top.
    private static let single = [
        WindowMover.Screen(
            frame: CGRect(x: 0, y: 0, width: 1000, height: 600),
            visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 560)
        ),
    ]

    /// A second screen of the same size, to the right.
    private static let double = single + [
        WindowMover.Screen(
            frame: CGRect(x: 1000, y: 0, width: 1000, height: 600),
            visibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 560)
        ),
    ]

    private func makeMover(
        window: FakeFocusedWindow,
        screens: [WindowMover.Screen] = WindowMoverTests.single,
        gap: CGFloat = 0
    ) -> WindowMover {
        WindowMover(window: window, gap: gap, screens: { screens })
    }

    // MARK: - The move

    @Test("The left half lands on the left of the usable area")
    func leftHalf() {
        // A window 200 by 100 at the top left, in Accessibility coordinates.
        let window = FakeFocusedWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let mover = makeMover(window: window)

        #expect(mover.move(to: .leftHalf))

        // The usable area is 560 high, from y 0 to y 560 in AppKit. Flipped for
        // Accessibility that is y 40 to y 600.
        #expect(window.written.last == CGRect(x: 0, y: 40, width: 500, height: 560))
    }

    @Test("The right half lands on the right")
    func rightHalf() {
        let window = FakeFocusedWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let mover = makeMover(window: window)

        mover.move(to: .rightHalf)

        #expect(window.written.last == CGRect(x: 500, y: 40, width: 500, height: 560))
    }

    @Test("Maximize fills the usable area, not the whole screen")
    func maximize() {
        let window = FakeFocusedWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let mover = makeMover(window: window)

        mover.move(to: .maximize)

        // It stops under the menu bar: y 40, height 560.
        #expect(window.written.last == CGRect(x: 0, y: 40, width: 1000, height: 560))
    }

    @Test("The gap reaches the result")
    func gap() {
        let window = FakeFocusedWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        let mover = makeMover(window: window, gap: 10)

        mover.move(to: .maximize)

        #expect(window.written.last == CGRect(x: 10, y: 50, width: 980, height: 540))
    }

    @Test("A window on the second screen stays on the second screen")
    func staysOnItsScreen() {
        // In Accessibility coordinates, x 1200 is the second screen.
        let window = FakeFocusedWindow(frame: CGRect(x: 1200, y: 100, width: 200, height: 100))
        let mover = makeMover(window: window, screens: Self.double)

        mover.move(to: .leftHalf)

        #expect(window.written.last?.minX == 1000)
    }

    @Test("No window, no move")
    func noWindow() {
        let window = FakeFocusedWindow(frame: nil)
        let mover = makeMover(window: window)

        #expect(!mover.move(to: .leftHalf))
        #expect(window.written.isEmpty)
    }

    @Test("No screen, no move")
    func noScreens() {
        let window = FakeFocusedWindow()
        let mover = makeMover(window: window, screens: [])

        #expect(!mover.move(to: .leftHalf))
    }

    // MARK: - The next screen

    @Test("With one screen the move to the next one does nothing")
    func nextScreenAlone() {
        let window = FakeFocusedWindow(frame: CGRect(x: 0, y: 40, width: 500, height: 560))
        let mover = makeMover(window: window)

        #expect(!mover.moveToNextScreen())
        #expect(window.written.isEmpty)
    }

    @Test("The window keeps its relative place on the next screen")
    func nextScreen() {
        // The left half of the first screen.
        let window = FakeFocusedWindow(frame: CGRect(x: 0, y: 40, width: 500, height: 560))
        let mover = makeMover(window: window, screens: Self.double)

        #expect(mover.moveToNextScreen())

        // The left half of the second screen.
        #expect(window.written.last == CGRect(x: 1000, y: 40, width: 500, height: 560))
    }

    @Test("The next screen after the last one is the first one")
    func wrapsAround() {
        let window = FakeFocusedWindow(frame: CGRect(x: 1000, y: 40, width: 500, height: 560))
        let mover = makeMover(window: window, screens: Self.double)

        mover.moveToNextScreen()

        #expect(window.written.last?.minX == 0)
    }

    // MARK: - The undo

    @Test("The undo puts the window back")
    func undo() {
        let start = CGRect(x: 123, y: 45, width: 300, height: 200)
        let window = FakeFocusedWindow(frame: start)
        let mover = makeMover(window: window)

        #expect(!mover.canUndo)

        mover.move(to: .leftHalf)
        #expect(mover.canUndo)
        #expect(window.frame != start)

        #expect(mover.undo())
        #expect(window.frame == start)
    }

    @Test("A second undo does nothing")
    func undoOnce() {
        let window = FakeFocusedWindow(frame: CGRect(x: 1, y: 2, width: 3, height: 4))
        let mover = makeMover(window: window)

        mover.move(to: .leftHalf)
        mover.undo()

        #expect(!mover.canUndo)
        #expect(!mover.undo())
    }

    @Test("The undo leaves another window alone")
    func undoOnlyTheSameWindow() {
        let window = FakeFocusedWindow(frame: CGRect(x: 1, y: 2, width: 3, height: 4))
        let mover = makeMover(window: window)

        mover.move(to: .leftHalf)
        let afterMove = window.frame

        // The user goes to another application.
        window.identifier = "another app:another window"

        #expect(!mover.undo())
        #expect(window.frame == afterMove)
    }
}
