import XCTest
@testable import ClaudeLimitCore

final class UsageParserTests: XCTestCase {
    private let sample = """
    You are currently using your subscription to power your Claude Code usage

    Current session: 1% used · resets Oct 26 at 2:39pm (Europe/Istanbul)
    Current week (all models): 6% used · resets Oct 31 at 10:59pm (Europe/Istanbul)
    Current week (Fable): 0% used · resets Oct 31 at 11pm (Europe/Istanbul)

    What's contributing to your limits usage?
    """

    private var now: Date { Date(timeIntervalSince1970: 1_792_950_000) } // 2026-10-25

    func testParsesWeekAndSession() throws {
        let snap = try XCTUnwrap(UsageParser.parse(sample, now: now))
        XCTAssertEqual(snap.sevenDay?.pct, 6)
        XCTAssertEqual(snap.sevenDay?.resetsAt, 1_793_476_800) // Oct 31 23:00 Istanbul (UTC+3)
        XCTAssertEqual(snap.fiveHour?.pct, 1)
        XCTAssertEqual(snap.fiveHour?.resetsAt, 1_793_014_800) // Oct 26 14:40 Istanbul
        XCTAssertEqual(snap.t, now.timeIntervalSince1970)
    }

    func testReturnsNilWithoutWeek() {
        XCTAssertNil(UsageParser.parse("Not logged in", now: now))
    }

    func testSessionOptional() throws {
        let text = "Current week (all models): 10% used · resets Oct 31 at 11pm (Europe/Istanbul)"
        let snap = try XCTUnwrap(UsageParser.parse(text, now: now))
        XCTAssertNil(snap.fiveHour)
        XCTAssertEqual(snap.sevenDay?.pct, 10)
    }

    func testYearRollover() throws {
        let dec = Date(timeIntervalSince1970: 1_798_000_000) // late Dec 2026
        let text = "Current week (all models): 3% used · resets Jan 2 at 12am (Europe/Istanbul)"
        let snap = try XCTUnwrap(UsageParser.parse(text, now: dec))
        XCTAssertGreaterThan(snap.sevenDay!.resetsAt, dec.timeIntervalSince1970)
    }
}
