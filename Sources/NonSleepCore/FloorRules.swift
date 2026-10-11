import Foundation

public enum ThermalLevel: Int, Sendable, Comparable {
    case nominal, fair, serious, critical
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public struct PowerSnapshot: Equatable, Sendable {
    public var onBattery: Bool
    public var batteryPercent: Int?
    public var thermal: ThermalLevel

    public init(onBattery: Bool, batteryPercent: Int?, thermal: ThermalLevel) {
        self.onBattery = onBattery
        self.batteryPercent = batteryPercent
        self.thermal = thermal
    }
}

public enum FloorDecision: Equatable, Sendable {
    case keepGoing
    case end(reason: String)
}

/// Decides whether a running session must end because of battery or heat.
public struct FloorRules: Sendable {
    /// End on battery below this percent. 0 turns the battery rule off.
    public var batteryFloor: Int

    public init(batteryFloor: Int = 10) { self.batteryFloor = batteryFloor }

    public func evaluate(_ snapshot: PowerSnapshot, lidMode: Bool) -> FloorDecision {
        if snapshot.thermal >= .critical {
            return .end(reason: "Mac is critically hot")
        }
        if lidMode, snapshot.thermal >= .serious {
            return .end(reason: "Mac is running hot with the lid closed")
        }
        if batteryFloor > 0, snapshot.onBattery, let pct = snapshot.batteryPercent, pct < batteryFloor {
            return .end(reason: "Battery below \(batteryFloor)%")
        }
        return .keepGoing
    }
}
