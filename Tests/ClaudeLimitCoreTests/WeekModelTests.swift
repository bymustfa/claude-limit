import XCTest
@testable import ClaudeLimitCore

final class WeekModelTests: XCTestCase {
    // Real reset observed on 2026-10-25: Sat 2026-10-31 23:00 +03.
    let reset: TimeInterval = 1_793_476_800
    var start: TimeInterval { reset - 7 * 86_400 }

    func snap(_ t: TimeInterval, _ pct: Double, resets: TimeInterval? = nil) -> Snapshot {
        Snapshot(t: t, sevenDay: LimitWindow(pct: pct, resetsAt: resets ?? reset))
    }

    func testDailyDeltas() {
        let s = [snap(start + 3600, 2), snap(start + 20_000, 5),
                 snap(start + 86_400 + 100, 6), snap(start + 86_400 + 40_000, 20)]
        let now = Date(timeIntervalSince1970: start + 86_400 + 50_000)
        let w = WeekModel.summary(snapshots: s, now: now)
        XCTAssertEqual(w.weeklyPct, 20)
        XCTAssertEqual(w.days[0].used, 5)
        XCTAssertEqual(w.days[1].used, 15)
        XCTAssertTrue(w.days[1].isToday)
        XCTAssertNil(w.days[2].used)
        XCTAssertFalse(w.isOver(w.days[0]))
        // Day 1 may use (100 - 5) / 6.
        XCTAssertEqual(w.days[1].allowance, 95.0 / 6, accuracy: 1e-9)
        XCTAssertFalse(w.isOver(w.days[1]))
    }

    func testUnusedShareCarriesForward() {
        let s = [snap(start + 100, 5), snap(start + 86_400 + 100, 6)]
        let w = WeekModel.summary(snapshots: s, now: Date(timeIntervalSince1970: start + 86_400 + 5000))
        XCTAssertEqual(w.days[0].carry, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(w.days[1].carry, 0)
        XCTAssertEqual(w.days[1].carry, 95.0 / 6 - 100.0 / 7, accuracy: 1e-9)
        // Future days: remaining pool after today (94) over 5 days.
        XCTAssertEqual(w.days[3].allowance, 94.0 / 5, accuracy: 1e-9)
    }

    func testOverusePenalisesLaterDays() {
        let s = [snap(start + 100, 30)]
        let w = WeekModel.summary(snapshots: s, now: Date(timeIntervalSince1970: start + 86_400 + 5000))
        XCTAssertTrue(w.isOver(w.days[0]))
        XCTAssertLessThan(w.days[1].carry, 0)
        XCTAssertTrue(w.days[0].isFull)
    }

    func testPoolExhausted() {
        let s = [snap(start + 100, 100)]
        let w = WeekModel.summary(snapshots: s, now: Date(timeIntervalSince1970: start + 86_400 + 5000))
        XCTAssertEqual(w.days[1].allowance, 0)
        XCTAssertTrue(w.days[1].isFull)
    }

    func testNoSnapshots() {
        let w = WeekModel.summary(snapshots: [], now: Date(timeIntervalSince1970: start))
        XCTAssertFalse(w.hasData)
        XCTAssertEqual(w.weeklyPct, 0)
    }

    func testWeekRolloverWithoutNewData() {
        let s = [snap(start + 100, 40)]
        let now = Date(timeIntervalSince1970: reset + 3600)
        let w = WeekModel.summary(snapshots: s, now: now)
        XCTAssertEqual(w.weeklyPct, 0)
        XCTAssertEqual(w.weekEnd.timeIntervalSince1970, reset + 7 * 86_400)
        XCTAssertEqual(w.todayUsed, 0)
    }

    func testPreviousWeekSnapshotsIgnored() {
        let prevReset = reset - 7 * 86_400
        let s = [snap(prevReset - 1000, 90, resets: prevReset), snap(start + 500, 3)]
        let w = WeekModel.summary(snapshots: s, now: Date(timeIntervalSince1970: start + 1000))
        XCTAssertEqual(w.weeklyPct, 3)
        XCTAssertEqual(w.days[0].used, 3)
    }

    func testParserSkipsGarbage() {
        let text = """
        {"t":1,"five_hour":{"pct":0,"resets_at":10},"seven_day":{"pct":5,"resets_at":20}}
        not json
        {"t":0,"seven_day":{"pct":1,"resets_at":20}}
        """
        let snaps = SnapshotParser.parse(text)
        XCTAssertEqual(snaps.count, 2)
        XCTAssertEqual(snaps[0].t, 0)
        XCTAssertEqual(snaps[1].fiveHour?.pct, 0)
    }
}
