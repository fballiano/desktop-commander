import Foundation
import UserNotifications

/// Shows the short status messages of the app.
///
/// The app has no window, so a banner is the only way to confirm a command that
/// a global hot key started.
@MainActor
final class Notifier: NSObject {
    private var isAuthorized = false
    private var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && !RuntimeEnvironment.isRunningTests
    }

    /// Asks for permission once, and becomes the presentation delegate.
    func prepare() {
        guard isAvailable else { return }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert]) { [weak self] granted, _ in
            Task { @MainActor in
                self?.isAuthorized = granted
            }
        }
    }

    /// Posts a banner. Does nothing when the user turned notifications off.
    func post(_ body: String, enabled: Bool) {
        guard enabled, isAvailable, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "desktop-commander"
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
