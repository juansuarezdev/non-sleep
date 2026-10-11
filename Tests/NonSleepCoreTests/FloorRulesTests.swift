import Testing
@testable import NonSleepCore

@Suite struct FloorRulesTests {
    let rules = FloorRules(batteryFloor: 10)

    func snap(battery: Bool = true, pct: Int? = 50, thermal: ThermalLevel = .nominal) -> PowerSnapshot {
        PowerSnapshot(onBattery: battery, batteryPercent: pct, thermal: thermal)
    }

    @Test func healthyKeepsGoing() {
        #expect(rules.evaluate(snap(), lidMode: true) == .keepGoing)
    }

    @Test func lowBatteryEnds() {
        #expect(rules.evaluate(snap(pct: 9), lidMode: false) == .end(reason: "Battery below 10%"))
    }

    @Test func lowBatteryOnChargerKeepsGoing() {
        #expect(rules.evaluate(snap(battery: false, pct: 3), lidMode: false) == .keepGoing)
    }

    @Test func floorZeroDisablesBatteryRule() {
        #expect(FloorRules(batteryFloor: 0).evaluate(snap(pct: 1), lidMode: false) == .keepGoing)
    }

    @Test func criticalHeatAlwaysEnds() {
        if case .end = rules.evaluate(snap(thermal: .critical), lidMode: false) {} else { Issue.record("expected end") }
    }

    @Test func seriousHeatEndsOnlyInLidMode() {
        #expect(rules.evaluate(snap(thermal: .serious), lidMode: false) == .keepGoing)
        if case .end = rules.evaluate(snap(thermal: .serious), lidMode: true) {} else { Issue.record("expected end") }
    }
}
