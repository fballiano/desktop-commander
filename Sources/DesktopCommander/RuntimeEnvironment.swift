import Foundation

/// Tells the app when it runs inside the test host.
///
/// The unit tests load the test bundle into the real application, so the app
/// launches for real. This flag stops the app from asking for notification
/// permission, registering global hot keys, taking a power assertion, or
/// changing a setting of the system during a test run.
enum RuntimeEnvironment {
    static let isRunningTests: Bool = {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }()
}
