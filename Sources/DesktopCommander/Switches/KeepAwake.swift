import Foundation
import IOKit.pwr_mgt
import Observation

/// Stops the Mac and its display from going to sleep.
///
/// It holds an `IOPMAssertion`, which is the way macOS itself does it. The
/// assertion dies with the process, so a crash can never leave a Mac that never
/// sleeps again.
///
/// The two IOKit calls come in as closures, so a test drives the whole type
/// without touching the power management of the Mac.
@MainActor
@Observable
final class KeepAwake {
    /// How long the assertion lasts.
    enum Duration: String, CaseIterable, Sendable, Identifiable {
        case forever
        case fifteenMinutes
        case thirtyMinutes
        case oneHour
        case twoHours
        case fiveHours

        var id: String { rawValue }

        /// The length in seconds, or `nil` when there is no end.
        var seconds: TimeInterval? {
            switch self {
            case .forever: nil
            case .fifteenMinutes: 15 * 60
            case .thirtyMinutes: 30 * 60
            case .oneHour: 60 * 60
            case .twoHours: 2 * 60 * 60
            case .fiveHours: 5 * 60 * 60
            }
        }

        var title: String {
            switch self {
            case .forever: String(localized: "No end")
            case .fifteenMinutes: String(localized: "15 minutes")
            case .thirtyMinutes: String(localized: "30 minutes")
            case .oneHour: String(localized: "1 hour")
            case .twoHours: String(localized: "2 hours")
            case .fiveHours: String(localized: "5 hours")
            }
        }
    }

    /// Takes an assertion and gives back its identifier, or `nil` on a failure.
    typealias Take = (String) -> UInt32?

    /// Releases the assertion with that identifier.
    typealias Release = (UInt32) -> Void

    private let take: Take
    private let release: Release

    private var assertion: UInt32?
    private var timer: Timer?

    /// `true` while the Mac is held awake.
    private(set) var isOn = false

    /// The length of the current, or the next, assertion.
    var duration: Duration = .forever

    /// When the assertion ends, or `nil` when it has no end or is off.
    private(set) var endsAt: Date?

    init(take: @escaping Take = KeepAwake.systemTake, release: @escaping Release = KeepAwake.systemRelease) {
        self.take = take
        self.release = release
    }

    // There is no `deinit` that releases the assertion. `deinit` is not on the
    // main actor and cannot read the stored identifier, and it is not needed:
    // macOS drops every assertion of a process when the process ends.

    // MARK: - The switch

    func set(_ on: Bool, duration: Duration? = nil) {
        if let duration { self.duration = duration }

        on ? start() : stop()
    }

    func toggle() {
        set(!isOn)
    }

    private func start() {
        // A second call must not take a second assertion. It only changes the
        // length, which means the old timer goes and a new one starts.
        if assertion == nil {
            let reason = String(localized: "desktop-commander keeps this Mac awake")

            guard let identifier = take(reason) else { return }
            assertion = identifier
        }

        isOn = true
        startTimer()
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        endsAt = nil
        isOn = false

        guard let assertion else { return }

        release(assertion)
        self.assertion = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = nil

        guard let seconds = duration.seconds else {
            endsAt = nil
            return
        }

        endsAt = Date().addingTimeInterval(seconds)

        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.set(false) }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - IOKit

    /// Keeps the display on, which also keeps the Mac awake. This is what a
    /// user means by "keep awake": the screen must not go dark.
    nonisolated static func systemTake(_ reason: String) -> UInt32? {
        guard !RuntimeEnvironment.isRunningTests else { return nil }

        var identifier: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &identifier
        )

        return result == kIOReturnSuccess ? identifier : nil
    }

    nonisolated static func systemRelease(_ identifier: UInt32) {
        IOPMAssertionRelease(identifier)
    }
}
