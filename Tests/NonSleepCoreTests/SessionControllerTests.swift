import Foundation
import Testing
@testable import NonSleepCore

final class FakeAssertion: SleepAssertion {
    var held = false
    var failAcquire = false
    func acquire() throws { if failAcquire { throw NonSleepError("nope") }; held = true }
    func release() { held = false }
}

final class FakeLid: LidControl {
    var isAvailable = true
    var enabled = false
    var failDisable = false
    var failEnable = false
    func setEnabled(_ on: Bool) throws {
        if on && failEnable { throw NonSleepError("enable failed") }
        if !on && failDisable { throw NonSleepError("disable failed") }
        enabled = on
    }
}

final class FakePower: PowerSource {
    var value = PowerSnapshot(onBattery: false, batteryPercent: 100, thermal: .nominal)
    func snapshot() -> PowerSnapshot { value }
}

final class Clock { var date = Date(timeIntervalSince1970: 1_000_000) }

@MainActor
struct Rig {
    let a = FakeAssertion(), l = FakeLid(), p = FakePower(), clock = Clock()
    let journal: Journal
    let c: SessionController

    init(journalEntry: JournalEntry? = nil, lidStartsEnabled: Bool = false) {
        l.enabled = lidStartsEnabled
        journal = Journal(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("nonsleep-test-\(UUID().uuidString)/journal.json"))
        if let journalEntry { try? journal.write(journalEntry) }
        let clock = self.clock
        c = SessionController(assertion: a, lid: l, power: p, journal: journal, now: { clock.date })
    }
}

@MainActor
@Suite struct SessionControllerTests {
    @Test func startHoldsAssertionAndEndsOnTime() throws {
        let r = Rig()
        try r.c.start(duration: 600, lidMode: false)
        #expect(r.a.held && r.c.isRunning)
        r.clock.date += 599; r.c.tick()
        #expect(r.c.isRunning)
        r.clock.date += 2; r.c.tick()
        #expect(!r.a.held && !r.c.isRunning && r.c.lastEndReason == "Time is up")
    }

    @Test func rejectsBadDurationsAndDoubleStart() throws {
        let r = Rig()
        #expect(throws: NonSleepError.self) { try r.c.start(duration: 0, lidMode: false) }
        #expect(throws: NonSleepError.self) { try r.c.start(duration: SessionMath.maxDuration + 1, lidMode: false) }
        try r.c.start(duration: 60, lidMode: false)
        #expect(throws: NonSleepError.self) { try r.c.start(duration: 60, lidMode: false) }
    }

    @Test func lowBatteryEndsSession() throws {
        let r = Rig()
        try r.c.start(duration: 3_600, lidMode: false)
        r.p.value = PowerSnapshot(onBattery: true, batteryPercent: 5, thermal: .nominal)
        r.c.tick()
        #expect(!r.c.isRunning && r.c.lastEndReason == "Battery below 10%")
    }

    @Test func extendMovesEndTime() throws {
        let r = Rig()
        try r.c.start(duration: 600, lidMode: false)
        r.c.extend(by: 300)
        #expect(r.c.remaining() == 900)
    }

    @Test func lidModeRefusedWhenUnavailable() {
        let r = Rig(); r.l.isAvailable = false
        #expect(throws: NonSleepError.self) { try r.c.start(duration: 60, lidMode: true) }
        #expect(r.journal.read() == nil && !r.a.held)
    }

    @Test func lidModeWritesJournalAndRestoresOnStop() throws {
        let r = Rig()
        try r.c.start(duration: 600, lidMode: true)
        #expect(r.l.enabled && r.journal.read()?.lidModeEnabled == true)
        r.c.stop()
        #expect(!r.l.enabled && r.journal.read() == nil && r.c.needsAttention == nil)
    }

    @Test func failedRestoreKeepsJournalAndFlagsAttention() throws {
        let r = Rig()
        try r.c.start(duration: 600, lidMode: true)
        r.l.failDisable = true
        r.c.stop()
        #expect(r.journal.read() != nil && r.c.needsAttention != nil)
    }

    @Test func failedEnableLeavesNothingBehind() {
        let r = Rig(); r.l.failEnable = true
        #expect(throws: NonSleepError.self) { try r.c.start(duration: 60, lidMode: true) }
        #expect(!r.c.isRunning && !r.a.held && r.journal.read() == nil)
    }

    @Test func failedAssertionUndoesLidMode() {
        let r = Rig(); r.a.failAcquire = true
        #expect(throws: NonSleepError.self) { try r.c.start(duration: 60, lidMode: true) }
        #expect(!r.l.enabled && r.journal.read() == nil)
    }

    @Test func leftoverJournalIsRecoveredOnLaunch() {
        // The controller recovers during init, as at app launch.
        let r = Rig(journalEntry: JournalEntry(lidModeEnabled: true, endsAt: Date()), lidStartsEnabled: true)
        #expect(!r.l.enabled && r.journal.read() == nil)
    }
}
