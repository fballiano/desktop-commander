import Foundation
import Testing
@testable import DesktopCommander

@MainActor
@Suite("KeepAwake")
struct KeepAwakeTests {
    /// Counts the calls to IOKit instead of making them.
    private final class Recorder {
        var taken: [String] = []
        var released: [UInt32] = []
        var next: UInt32 = 1
    }

    private func makeKeepAwake() -> (KeepAwake, Recorder) {
        let recorder = Recorder()

        let keepAwake = KeepAwake(
            take: { reason in
                recorder.taken.append(reason)
                defer { recorder.next += 1 }
                return recorder.next
            },
            release: { identifier in
                recorder.released.append(identifier)
            }
        )

        return (keepAwake, recorder)
    }

    @Test("It starts off")
    func startsOff() {
        let (keepAwake, recorder) = makeKeepAwake()

        #expect(!keepAwake.isOn)
        #expect(recorder.taken.isEmpty)
    }

    @Test("On takes one assertion")
    func takesAssertion() {
        let (keepAwake, recorder) = makeKeepAwake()

        keepAwake.set(true)

        #expect(keepAwake.isOn)
        #expect(recorder.taken.count == 1)
        #expect(recorder.released.isEmpty)
    }

    @Test("A second on does not take a second assertion")
    func takesOnlyOne() {
        let (keepAwake, recorder) = makeKeepAwake()

        keepAwake.set(true)
        keepAwake.set(true)
        keepAwake.set(true)

        #expect(recorder.taken.count == 1)
    }

    @Test("Off releases the assertion it took")
    func releases() {
        let (keepAwake, recorder) = makeKeepAwake()

        keepAwake.set(true)
        keepAwake.set(false)

        #expect(!keepAwake.isOn)
        #expect(recorder.released == [1])
    }

    @Test("Off without on releases nothing")
    func releasesNothing() {
        let (keepAwake, recorder) = makeKeepAwake()

        keepAwake.set(false)

        #expect(recorder.released.isEmpty)
    }

    @Test("The switch goes both ways")
    func toggles() {
        let (keepAwake, _) = makeKeepAwake()

        keepAwake.toggle()
        #expect(keepAwake.isOn)

        keepAwake.toggle()
        #expect(!keepAwake.isOn)
    }

    @Test("A failure to take the assertion leaves the switch off")
    func failure() {
        let keepAwake = KeepAwake(take: { _ in nil }, release: { _ in })

        keepAwake.set(true)

        #expect(!keepAwake.isOn)
    }

    // MARK: - The length

    @Test("No end means no end time")
    func forever() {
        let (keepAwake, _) = makeKeepAwake()

        keepAwake.set(true, duration: .forever)

        #expect(keepAwake.endsAt == nil)
    }

    @Test("A length gives an end time in the future")
    func withDuration() {
        let (keepAwake, _) = makeKeepAwake()

        keepAwake.set(true, duration: .fifteenMinutes)

        let end = try! #require(keepAwake.endsAt)
        #expect(end.timeIntervalSinceNow > 14 * 60)
        #expect(end.timeIntervalSinceNow <= 15 * 60)
    }

    @Test("A change of the length keeps the same assertion")
    func changeDuration() {
        let (keepAwake, recorder) = makeKeepAwake()

        keepAwake.set(true, duration: .fifteenMinutes)
        keepAwake.set(true, duration: .twoHours)

        #expect(recorder.taken.count == 1)
        #expect(keepAwake.duration == .twoHours)
    }

    @Test("Off clears the end time")
    func clearsEnd() {
        let (keepAwake, _) = makeKeepAwake()

        keepAwake.set(true, duration: .oneHour)
        keepAwake.set(false)

        #expect(keepAwake.endsAt == nil)
    }

    @Test("Every length has a title and a line under it")
    func titles() {
        for duration in KeepAwake.Duration.allCases {
            #expect(!duration.title.isEmpty)
            #expect(!duration.subtitle.isEmpty)
        }

        #expect(KeepAwake.Duration.forever.seconds == nil)
        #expect(KeepAwake.Duration.oneHour.seconds == 3600)
    }
}
