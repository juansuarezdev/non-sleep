import Testing
@testable import NonSleepCore

@Suite struct SessionMathTests {
    @Test(arguments: [
        ("90", 5_400.0), ("45m", 2_700), ("2h", 7_200), ("1h30m", 5_400),
        ("1d2h", 93_600), (" 2H ", 7_200),
    ])
    func parsesValid(text: String, seconds: Double) {
        #expect(SessionMath.parse(text) == seconds)
    }

    @Test(arguments: ["", "0", "0m", "abc", "1x", "h", "1h1h", "30m1h x", "-5", "1.5h", "5 m"])
    func rejectsInvalid(text: String) {
        #expect(SessionMath.parse(text) == nil)
    }

    @Test func formats() {
        #expect(SessionMath.format(3_900) == "1h 05m")
        #expect(SessionMath.format(249) == "4m 09s")
        #expect(SessionMath.format(-3) == "0m 00s")
    }
}
