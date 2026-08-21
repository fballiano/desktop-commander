import Foundation
@testable import DesktopCommander

/// A window that lives in memory.
///
/// The tests must not move a real window: the user has windows open while the
/// tests run, and the Accessibility permission is not there in a test run
/// anyway.
///
/// The frame is in Accessibility coordinates, as the real one is.
@MainActor
final class FakeFocusedWindow: FocusedWindowAccess {
    var identifier: String?
    var frame: CGRect?

    /// Every frame the mover wrote, in order.
    private(set) var written: [CGRect] = []

    /// `false` makes every write fail, as a window with a fixed size does.
    var acceptsWrites = true

    init(identifier: String? = "app:window", frame: CGRect? = .zero) {
        self.identifier = identifier
        self.frame = frame
    }

    @discardableResult
    func setFrame(_ frame: CGRect) -> Bool {
        guard acceptsWrites else { return false }

        written.append(frame)
        self.frame = frame
        return true
    }
}
