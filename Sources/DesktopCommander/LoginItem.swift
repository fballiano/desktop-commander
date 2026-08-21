import Foundation
import Observation
import ServiceManagement

/// Starts the app when the user logs in.
///
/// `SMAppService` is the replacement for the old login item API. The system
/// holds the real state, so the value is read back from it at start up.
@MainActor
@Observable
final class LoginItem {
    /// The reason the last change failed, if it failed.
    private(set) var lastError: String?

    @ObservationIgnored
    private var isApplying = false

    var isEnabled: Bool {
        didSet {
            guard !isApplying else { return }
            apply(isEnabled)
        }
    }

    init() {
        isEnabled = !RuntimeEnvironment.isRunningTests && SMAppService.mainApp.status == .enabled
    }

    private func apply(_ value: Bool) {
        guard !RuntimeEnvironment.isRunningTests else { return }

        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            revert(to: !value)
        }
    }

    private func revert(to value: Bool) {
        isApplying = true
        isEnabled = value
        isApplying = false
    }
}
