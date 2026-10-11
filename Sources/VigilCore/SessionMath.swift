import Foundation

/// Duration parsing and formatting. Pure functions.
public enum SessionMath {
    /// Longest session Vigil accepts.
    public static let maxDuration: TimeInterval = 7 * 86_400

    /// Parses "90" (minutes), "45m", "2h", "1h30m", "1d2h". Returns nil when invalid or zero.
    public static func parse(_ text: String) -> TimeInterval? {
        let s = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !s.isEmpty else { return nil }
        if let minutes = Int(s) { return minutes > 0 ? TimeInterval(minutes * 60) : nil }

        var total = 0
        var number = ""
        var seen = Set<Character>()
        for ch in s {
            if ch.isASCII, ch.isNumber {
                number.append(ch)
            } else if let unit = ["d": 86_400, "h": 3_600, "m": 60][ch], !number.isEmpty,
                      seen.insert(ch).inserted, let n = Int(number) {
                total += n * unit
                number = ""
            } else {
                return nil
            }
        }
        guard number.isEmpty, total > 0 else { return nil }
        return TimeInterval(total)
    }

    /// "1h 05m" style, or "4m 09s" under an hour.
    public static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let h = total / 3_600, m = total % 3_600 / 60, s = total % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%dm %02ds", m, s)
    }
}
