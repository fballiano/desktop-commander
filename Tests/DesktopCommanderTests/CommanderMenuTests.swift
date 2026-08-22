import Foundation
import Testing
@testable import DesktopCommander

@MainActor
@Suite("CommanderMenu")
struct CommanderMenuTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("Under one hour it gives minutes and seconds")
    func minutes() {
        #expect(CommanderMenu.countdown(to: now.addingTimeInterval(899), from: now) == "14:59")
        #expect(CommanderMenu.countdown(to: now.addingTimeInterval(65), from: now) == "1:05")
    }

    @Test("Over one hour it gives hours, minutes and seconds")
    func hours() {
        #expect(CommanderMenu.countdown(to: now.addingTimeInterval(3600), from: now) == "1:00:00")
        #expect(CommanderMenu.countdown(to: now.addingTimeInterval(5 * 3600 - 1), from: now) == "4:59:59")
    }

    @Test("A time that has passed gives zero, never a minus")
    func past() {
        #expect(CommanderMenu.countdown(to: now.addingTimeInterval(-10), from: now) == "0:00")
        #expect(CommanderMenu.countdown(to: now, from: now) == "0:00")
    }
}
