import AppIntents
import Foundation
import Testing
@testable import DesktopCommander

@Suite("WindowSlot")
struct WindowSlotTests {
    /// A screen 1000 wide and 600 high, at the origin. Every number below comes
    /// out whole, so a failure shows a real mistake and not a rounding error.
    private let area = CGRect(x: 0, y: 0, width: 1000, height: 600)

    private func frame(_ slot: WindowSlot, gap: CGFloat = 0, current: CGSize = .zero) -> CGRect {
        slot.frame(in: area, gap: gap, current: current)
    }

    /// A third of a screen is not a whole number, so two numbers that should be
    /// equal can differ in the last bit. `WindowMover` rounds the frame before a
    /// window ever sees it.
    private func isClose(_ first: CGFloat, _ second: CGFloat) -> Bool {
        abs(first - second) < 0.0001
    }

    // MARK: - Halves

    @Test("The halves split the screen in two and leave nothing")
    func halves() {
        #expect(frame(.leftHalf) == CGRect(x: 0, y: 0, width: 500, height: 600))
        #expect(frame(.rightHalf) == CGRect(x: 500, y: 0, width: 500, height: 600))
        #expect(frame(.topHalf) == CGRect(x: 0, y: 300, width: 1000, height: 300))
        #expect(frame(.bottomHalf) == CGRect(x: 0, y: 0, width: 1000, height: 300))
    }

    @Test("The left half and the right half touch")
    func halvesTouch() {
        #expect(frame(.leftHalf).maxX == frame(.rightHalf).minX)
    }

    // MARK: - Quarters

    @Test("The four quarters cover the screen")
    func quarters() {
        #expect(frame(.topLeftQuarter) == CGRect(x: 0, y: 300, width: 500, height: 300))
        #expect(frame(.topRightQuarter) == CGRect(x: 500, y: 300, width: 500, height: 300))
        #expect(frame(.bottomLeftQuarter) == CGRect(x: 0, y: 0, width: 500, height: 300))
        #expect(frame(.bottomRightQuarter) == CGRect(x: 500, y: 0, width: 500, height: 300))
    }

    // MARK: - Thirds

    @Test("The three thirds cover the screen and touch")
    func thirds() {
        let left = frame(.leftThird)
        let centre = frame(.centreThird)
        let right = frame(.rightThird)

        #expect(isClose(left.width, 1000.0 / 3))
        #expect(left.minX == 0)
        #expect(isClose(left.maxX, centre.minX))
        #expect(isClose(centre.maxX, right.minX))
        #expect(isClose(right.maxX, 1000))
    }

    @Test("Two thirds are two thirds")
    func twoThirds() {
        #expect(frame(.firstTwoThirds).minX == 0)
        #expect(isClose(frame(.firstTwoThirds).width, 2000.0 / 3))
        #expect(isClose(frame(.lastTwoThirds).maxX, 1000))
        #expect(isClose(frame(.lastTwoThirds).width, 2000.0 / 3))
    }

    @Test("The last two thirds start where the left third ends")
    func twoThirdsMeetTheThird() {
        #expect(isClose(frame(.leftThird).maxX, frame(.lastTwoThirds).minX))
        #expect(isClose(frame(.firstTwoThirds).maxX, frame(.rightThird).minX))
    }

    // MARK: - The whole screen

    @Test("Maximize fills the screen")
    func maximize() {
        #expect(frame(.maximize) == area)
    }

    @Test("Centre keeps the size")
    func centre() {
        let result = frame(.centre, current: CGSize(width: 400, height: 200))

        #expect(result == CGRect(x: 300, y: 200, width: 400, height: 200))
    }

    @Test("A window bigger than the screen is cut down to the screen")
    func centreTooBig() {
        let result = frame(.centre, current: CGSize(width: 5000, height: 5000))

        #expect(result == area)
    }

    // MARK: - The gap

    @Test("The gap sits once at each edge and once between two windows")
    func gap() {
        let left = frame(.leftHalf, gap: 10)
        let right = frame(.rightHalf, gap: 10)

        #expect(left.minX == 10)                    // The edge of the screen.
        #expect(right.maxX == 990)                  // The other edge.
        #expect(right.minX - left.maxX == 10)       // One gap between them.
        #expect(left.width == right.width)
    }

    @Test("The gap works for the thirds as well")
    func gapWithThirds() {
        let left = frame(.leftThird, gap: 12)
        let centre = frame(.centreThird, gap: 12)
        let right = frame(.rightThird, gap: 12)

        #expect(left.minX == 12)
        #expect(isClose(right.maxX, 988))
        #expect(isClose(centre.minX - left.maxX, 12))
        #expect(isClose(right.minX - centre.maxX, 12))
        #expect(isClose(left.width, centre.width))
        #expect(isClose(centre.width, right.width))
    }

    @Test("Two thirds with a gap end where the third with a gap starts")
    func gapWithTwoThirds() {
        #expect(isClose(frame(.leftThird, gap: 12).maxX, frame(.lastTwoThirds, gap: 12).minX - 12))
        #expect(frame(.maximize, gap: 12) == CGRect(x: 12, y: 12, width: 976, height: 576))
    }

    // MARK: - A screen that is not at the origin

    @Test("A second display keeps the same shape")
    func offsetScreen() {
        let second = CGRect(x: 1000, y: 200, width: 800, height: 400)

        #expect(WindowSlot.leftHalf.frame(in: second)
            == CGRect(x: 1000, y: 200, width: 400, height: 400))
        #expect(WindowSlot.rightHalf.frame(in: second)
            == CGRect(x: 1400, y: 200, width: 400, height: 400))
        #expect(WindowSlot.maximize.frame(in: second) == second)
    }

    @Test("A display below the primary one, with a negative y")
    func negativeScreen() {
        let below = CGRect(x: 0, y: -600, width: 1000, height: 600)

        #expect(WindowSlot.bottomHalf.frame(in: below)
            == CGRect(x: 0, y: -600, width: 1000, height: 300))
        #expect(WindowSlot.topHalf.frame(in: below)
            == CGRect(x: 0, y: -300, width: 1000, height: 300))
    }

    // MARK: - Every slot

    @Test("No slot ever leaves the screen", arguments: WindowSlot.allCases)
    func staysOnScreen(slot: WindowSlot) {
        let result = slot.frame(in: area, gap: 8, current: CGSize(width: 300, height: 200))

        #expect(result.minX >= area.minX)
        #expect(result.minY >= area.minY)
        #expect(result.maxX <= area.maxX)
        #expect(result.maxY <= area.maxY)
        #expect(result.width > 0)
        #expect(result.height > 0)
    }

    @Test("Every slot has a title")
    func titles() {
        for slot in WindowSlot.allCases {
            #expect(!slot.title.isEmpty)
        }
    }

    @Test("The groups of the menu hold every slot exactly once")
    func groupsAreComplete() {
        let inGroups = WindowSlot.groups.flatMap(\.slots)

        #expect(Set(inGroups) == Set(WindowSlot.allCases))
        #expect(inGroups.count == WindowSlot.allCases.count)
    }

    @Test("The list that Shortcuts shows holds every slot")
    func shortcutsListIsComplete() {
        // `caseDisplayRepresentations` is written out case by case, because the
        // tool that builds the App Intents metadata reads it at build time and
        // refuses a loop. This test is what stops a new slot from being
        // forgotten there.
        #expect(Set(WindowSlot.caseDisplayRepresentations.keys) == Set(WindowSlot.allCases))
    }
}
