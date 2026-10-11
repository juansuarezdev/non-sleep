import Foundation
import IOKit.pwr_mgt
import IOKit.ps

/// Real sleep prevention through IOKit. The kernel drops it if the process dies.
public final class IOKitSleepAssertion: SleepAssertion {
    private var id: IOPMAssertionID = 0
    private var held = false

    public init() {}

    public func acquire() throws {
        guard !held else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Vigil timed awake session" as CFString,
            &id)
        guard result == kIOReturnSuccess else { throw VigilError("Could not hold the Mac awake (IOKit \(result))") }
        held = true
    }

    public func release() {
        guard held else { return }
        IOPMAssertionRelease(id)
        held = false
    }

    deinit { release() }
}

/// Runs `sudo -n /usr/bin/pmset -a disablesleep 0|1`. Works only if the opt-in sudoers rule exists.
public final class PmsetLidControl: LidControl {
    private let sudo = "/usr/bin/sudo"
    private let pmset = "/usr/bin/pmset"

    public init() {}

    public var isAvailable: Bool {
        Self.run(sudo, ["-n", "-l", pmset, "-a", "disablesleep", "1"]) == 0
            && Self.run(sudo, ["-n", "-l", pmset, "-a", "disablesleep", "0"]) == 0
    }

    public func setEnabled(_ enabled: Bool) throws {
        let status = Self.run(sudo, ["-n", pmset, "-a", "disablesleep", enabled ? "1" : "0"])
        guard status == 0 else { throw VigilError("pmset disablesleep \(enabled ? 1 : 0) failed (exit \(status))") }
    }

    private static func run(_ path: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
}

public final class SystemPowerSource: PowerSource {
    public init() {}

    public func snapshot() -> PowerSnapshot {
        var onBattery = false
        var percent: Int?
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in list {
                guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                      d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
                onBattery = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue
                if let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 {
                    percent = cur * 100 / max
                }
            }
        }
        let thermal: ThermalLevel = switch ProcessInfo.processInfo.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .nominal
        }
        return PowerSnapshot(onBattery: onBattery, batteryPercent: percent, thermal: thermal)
    }
}
