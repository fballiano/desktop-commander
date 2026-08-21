import AppKit
import Foundation
import Observation

/// One application that can be hidden.
///
/// The protocol exists for the tests. `NSRunningApplication` cannot be built by
/// hand, and a test must not hide the applications of the user.
@MainActor
protocol HideableApplication: AnyObject {
    var bundleIdentifier: String? { get }

    /// `true` for an application with a dock icon. An agent application, like
    /// this one, has no window to hide.
    var isRegular: Bool { get }

    var isHidden: Bool { get }

    @discardableResult func hideApplication() -> Bool
    @discardableResult func unhideApplication() -> Bool
}

extension NSRunningApplication: HideableApplication {
    var isRegular: Bool { activationPolicy == .regular }

    @discardableResult func hideApplication() -> Bool { hide() }
    @discardableResult func unhideApplication() -> Bool { unhide() }
}

/// Hides every window on the screen, and brings back the same ones.
///
/// The list of what it hid is the point. An application the user had already
/// hidden stays hidden when the switch goes off, because the switch did not hide
/// it. Anything else would undo a choice the user made.
@MainActor
@Observable
final class HiddenWindows {
    typealias Provider = @MainActor () -> [HideableApplication]

    @ObservationIgnored private let applications: Provider

    /// The applications this switch hid, by bundle identifier.
    @ObservationIgnored private(set) var hidden: Set<String> = []

    private(set) var isOn = false

    init(applications: @escaping Provider = HiddenWindows.systemApplications) {
        self.applications = applications
    }

    func set(_ on: Bool) {
        on ? hide() : show()
    }

    func toggle() {
        set(!isOn)
    }

    private func hide() {
        hidden = []

        for app in applications() where app.isRegular && !app.isHidden {
            guard let bundleID = app.bundleIdentifier else { continue }
            guard bundleID != Bundle.main.bundleIdentifier else { continue }

            if app.hideApplication() {
                hidden.insert(bundleID)
            }
        }

        isOn = true
    }

    private func show() {
        for app in applications() {
            guard let bundleID = app.bundleIdentifier, hidden.contains(bundleID) else { continue }
            app.unhideApplication()
        }

        hidden = []
        isOn = false
    }

    /// Every application that is running now.
    static func systemApplications() -> [HideableApplication] {
        NSWorkspace.shared.runningApplications
    }
}
