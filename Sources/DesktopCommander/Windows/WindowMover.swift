import AppKit
import Foundation

/// Moves the front window.
///
/// It joins the three parts: `FocusedWindowAccess` reads and writes the window,
/// `ScreenGeometry` turns one coordinate system into the other, and `WindowSlot`
/// says where the window goes. None of the three knows about the other two, so
/// each one is tested on its own.
@MainActor
final class WindowMover {
    /// One screen, as `WindowMover` needs it.
    struct Screen: Sendable, Equatable {
        /// The whole screen, in AppKit coordinates.
        let frame: CGRect

        /// The part without the menu bar and without the Dock, in AppKit
        /// coordinates.
        let visibleFrame: CGRect
    }

    typealias ScreenProvider = @MainActor () -> [Screen]

    private let window: FocusedWindowAccess
    private let screens: ScreenProvider

    /// The place the last moved window came from. The undo puts it back.
    private var previous: (identifier: String, frame: CGRect)?

    /// The space between a window and the edge of the screen, and between two
    /// windows that meet.
    var gap: CGFloat

    init(
        window: FocusedWindowAccess,
        gap: CGFloat = 0,
        screens: @escaping ScreenProvider = { WindowMover.systemScreens() }
    ) {
        self.window = window
        self.gap = gap
        self.screens = screens
    }

    /// `true` when there is a move to undo.
    var canUndo: Bool { previous != nil }

    // MARK: - The commands

    /// Puts the front window into the slot, on the screen it is already on.
    @discardableResult
    func move(to slot: WindowSlot) -> Bool {
        let list = screens()
        guard !list.isEmpty else { return false }
        guard let current = appKitFrame(of: window.frame, in: list) else { return false }

        let index = ScreenGeometry.screenIndex(
            holding: current,
            in: list.map(\.frame)
        ) ?? 0

        let target = slot.frame(
            in: list[index].visibleFrame,
            gap: gap,
            current: current.size
        )

        return apply(target, in: list)
    }

    /// Sends the front window to the next screen, in the same relative place.
    /// With one screen it does nothing.
    @discardableResult
    func moveToNextScreen() -> Bool {
        let list = screens()
        guard list.count > 1 else { return false }
        guard let current = appKitFrame(of: window.frame, in: list) else { return false }

        let index = ScreenGeometry.screenIndex(holding: current, in: list.map(\.frame)) ?? 0
        let next = list[(index + 1) % list.count]

        let target = ScreenGeometry.moved(
            current,
            from: list[index].visibleFrame,
            to: next.visibleFrame
        )

        return apply(target, in: list)
    }

    /// Puts the last moved window back where it was.
    ///
    /// It only works while that window is still in front. A window that the user
    /// left is not brought back by surprise.
    @discardableResult
    func undo() -> Bool {
        guard let previous else { return false }
        guard window.identifier == previous.identifier else { return false }

        self.previous = nil

        return window.setFrame(previous.frame)
    }

    // MARK: - The parts

    /// Writes the new frame and remembers the old one.
    private func apply(_ target: CGRect, in list: [Screen]) -> Bool {
        guard let identifier = window.identifier else { return false }
        guard let old = window.frame else { return false }

        previous = (identifier, old)

        let frame = ScreenGeometry.accessibilityFrame(
            from: target,
            primaryMaxY: primaryMaxY(of: list)
        )

        // A third of a screen is not a whole number of points. macOS puts a
        // window on whole points anyway, so the rounding happens here, once,
        // instead of leaving a fraction in every stored frame.
        return window.setFrame(frame.integral)
    }

    private func appKitFrame(of accessibilityFrame: CGRect?, in list: [Screen]) -> CGRect? {
        guard let accessibilityFrame else { return nil }

        return ScreenGeometry.appKitFrame(
            from: accessibilityFrame,
            primaryMaxY: primaryMaxY(of: list)
        )
    }

    /// The top edge of the primary screen, which is the one whose frame starts
    /// at the origin. AppKit puts it first in the list, but a check costs
    /// nothing and a wrong value throws every window off the screen.
    private func primaryMaxY(of list: [Screen]) -> CGFloat {
        let primary = list.first { $0.frame.origin == .zero } ?? list.first
        return primary?.frame.maxY ?? 0
    }

    /// The screens of the Mac, right now.
    static func systemScreens() -> [Screen] {
        NSScreen.screens.map { Screen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
    }
}
