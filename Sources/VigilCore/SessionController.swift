import Foundation
import Observation

public enum SessionState: Equatable, Sendable {
    case idle
    case running(endsAt: Date, lidMode: Bool)
}

/// The session state machine. All side effects go through injected ports.
@MainActor
@Observable
public final class SessionController {
    public private(set) var state: SessionState = .idle
    /// Why the last session ended ("Time is up", "Battery below 10%", ...).
    public private(set) var lastEndReason: String?
    /// Set when something could not be undone. Cleared by a successful restore.
    public private(set) var needsAttention: String?

    /// Length of the running session including extensions. Drives the progress ring.
    public private(set) var totalDuration: TimeInterval = 0

    public var rules: FloorRules

    @ObservationIgnored private let assertion: SleepAssertion
    @ObservationIgnored private let lid: LidControl
    @ObservationIgnored private let power: PowerSource
    @ObservationIgnored private let journal: Journal
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var ticker: Task<Void, Never>?

    public init(assertion: SleepAssertion, lid: LidControl, power: PowerSource,
                journal: Journal, rules: FloorRules = FloorRules(),
                now: @escaping () -> Date = Date.init) {
        self.assertion = assertion
        self.lid = lid
        self.power = power
        self.journal = journal
        self.rules = rules
        self.now = now
        recoverIfNeeded()
    }

    public var lidModeAvailable: Bool { lid.isAvailable }

    public var isRunning: Bool { if case .running = state { true } else { false } }

    public func remaining() -> TimeInterval {
        guard case .running(let endsAt, _) = state else { return 0 }
        return max(0, endsAt.timeIntervalSince(now()))
    }

    // MARK: - Commands

    public func start(duration: TimeInterval, lidMode: Bool) throws {
        guard !isRunning else { throw VigilError("A session is already running") }
        guard duration > 0, duration <= SessionMath.maxDuration else {
            throw VigilError("Duration must be between 1 minute and 7 days")
        }
        let endsAt = now().addingTimeInterval(duration)

        if lidMode {
            guard lid.isAvailable else {
                throw VigilError("Lid mode is not set up. Run scripts/install-lid-helper.sh")
            }
            // Journal first: if we die between here and the end, the next launch undoes it.
            try journal.write(JournalEntry(lidModeEnabled: true, endsAt: endsAt))
            do { try lid.setEnabled(true) } catch {
                restoreLidOrKeepJournal()
                throw error
            }
        }
        do { try assertion.acquire() } catch {
            if lidMode { restoreLidOrKeepJournal() }
            throw error
        }
        lastEndReason = nil
        totalDuration = duration
        state = .running(endsAt: endsAt, lidMode: lidMode)
    }

    public func extend(by interval: TimeInterval) {
        guard case .running(let endsAt, let lidMode) = state, interval > 0 else { return }
        let cap = now().addingTimeInterval(SessionMath.maxDuration)
        let newEnd = min(endsAt.addingTimeInterval(interval), cap)
        totalDuration += newEnd.timeIntervalSince(endsAt)
        state = .running(endsAt: newEnd, lidMode: lidMode)
        if lidMode { try? journal.write(JournalEntry(lidModeEnabled: true, endsAt: newEnd)) }
    }

    public func stop(reason: String = "Ended by you") {
        guard case .running(_, let lidMode) = state else { return }
        assertion.release()
        if lidMode { restoreLidOrKeepJournal() }
        lastEndReason = reason
        state = .idle
    }

    /// One evaluation step. Called by the ticker; public so tests drive it directly.
    public func tick() {
        guard case .running(let endsAt, let lidMode) = state else { return }
        if now() >= endsAt { stop(reason: "Time is up"); return }
        if case .end(let reason) = rules.evaluate(power.snapshot(), lidMode: lidMode) {
            stop(reason: reason)
        }
    }

    public func startTicker(every interval: Duration = .seconds(5)) {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                self?.tick()
            }
        }
    }

    /// Call on app termination.
    public func shutdown() {
        ticker?.cancel()
        stop(reason: "Vigil quit")
    }

    // MARK: - Recovery

    /// A journal left over from a previous run means lid mode may still be on.
    public func recoverIfNeeded() {
        guard !isRunning, let entry = journal.read(), entry.lidModeEnabled else { return }
        restoreLidOrKeepJournal()
    }

    private func restoreLidOrKeepJournal() {
        do {
            try lid.setEnabled(false)
            journal.clear()
            needsAttention = nil
        } catch {
            needsAttention = "Could not turn lid mode off. Run: sudo pmset -a disablesleep 0"
        }
    }
}
