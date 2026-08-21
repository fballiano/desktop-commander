import ApplicationServices
import AppKit
import Foundation

/// The front window of the front application.
///
/// The protocol exists for the tests. A fake one holds a rectangle, so
/// `WindowMover` runs with no window on the screen and with no Accessibility
/// permission.
///
/// Every rectangle here is in **Accessibility** coordinates: the origin is at
/// the top left of the primary screen and y grows downwards. `ScreenGeometry`
/// turns them into AppKit coordinates.
@MainActor
protocol FocusedWindowAccess: AnyObject {
    /// A value that names the window, so `WindowMover` knows whether the undo
    /// belongs to the window in front now.
    var identifier: String? { get }

    var frame: CGRect? { get }

    /// - Returns: `true` when the window took the new frame.
    @discardableResult
    func setFrame(_ frame: CGRect) -> Bool
}

/// The real front window, through the Accessibility API.
@MainActor
final class FocusedWindow: FocusedWindowAccess {
    private var element: AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        let application = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success else { return nil }

        guard let window = value, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }

        return (window as! AXUIElement)
    }

    /// The process and the title together. Two windows of one application can
    /// share a title, but the pair is good enough to say "this is still the
    /// window I moved a moment ago".
    var identifier: String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        guard let element else { return nil }

        return "\(app.processIdentifier):\(Self.string(element, kAXTitleAttribute) ?? "")"
    }

    var frame: CGRect? {
        guard let element else { return nil }
        guard let origin = Self.point(element, kAXPositionAttribute) else { return nil }
        guard let size = Self.size(element, kAXSizeAttribute) else { return nil }

        return CGRect(origin: origin, size: size)
    }

    @discardableResult
    func setFrame(_ frame: CGRect) -> Bool {
        guard let element else { return false }

        // The size goes first and then again at the end. A window with a minimum
        // size can refuse the new size while it still sits at the old place, and
        // some applications clamp the size to the screen they are on. Writing
        // the size, then the position, then the size again lands the window
        // correctly in both cases.
        var size = frame.size
        var origin = frame.origin

        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        }
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        }

        return true
    }

    // MARK: - Reading one attribute

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }

        return value as? String
    }

    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = axValue(element, attribute) else { return nil }

        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }

        return point
    }

    private static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = axValue(element, attribute) else { return nil }

        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }

        return size
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }

        return (value as! AXValue)
    }
}
