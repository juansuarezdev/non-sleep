import Foundation

/// Holds the Mac awake while acquired.
public protocol SleepAssertion: AnyObject {
    func acquire() throws
    func release()
}

/// Switches "stay awake with the lid closed" on and off. Needs root in practice.
public protocol LidControl: AnyObject {
    /// False when the privilege rule is not installed; lid mode is then refused.
    var isAvailable: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

public protocol PowerSource: AnyObject {
    func snapshot() -> PowerSnapshot
}

public struct NonSleepError: Error, LocalizedError, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
