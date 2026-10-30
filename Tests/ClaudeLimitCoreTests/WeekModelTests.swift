import XCTest
@testable import ClaudeLimitCore

final class WeekModelTests: XCTestCase {
    // Real reset observed on 2026-10-25: Sat 2026-10-31 23:00 +03.
    let reset: TimeInterval = 1_793_476_800
    var start: TimeInterval { reset - 7 * 86_400 }

    func snap(_ time: TimeInterval, _ percent: Double, resets: TimeInterval? = nil) -> Snapshot {
        Snapshot(timestamp: time, sevenDay: LimitWindow(percent: percent, resetsAt: resets ?? reset))
    }

    func calendar(_ zone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        return c
    }

    /// Defaults to +04, where that reset falls on midnight, so every day is exactly 24h.
    func summary(snapshots: [Snapshot], now: Date,
                 zone: TimeZone = TimeZone(secondsFromGMT: 4 * 3600)!) -> WeekSummary {
        WeekModel.summary(snapshots: snapshots, now: now, calendar: calendar(zone))
    }

    func testDaysChangeAtLocalMidnight() {
        let istanbul = TimeZone(identifier: "Europe/Istanbul")!
        // Wed 2026-10-28 23:18 +03: still Wednesday, although the reset-aligned slice already turned at 23:00.
        let now = Date(timeIntervalSince1970: start + 4 * 86_400 + 18 * 60)
        let s = [snap(start + 4 * 86_400 - 3600, 40), snap(start + 4 * 86_400 + 600, 43)]
        let w = summary(snapshots: s, now: now, zone: istanbul)
        let names = w.days.map { calendar(istanbul).component(.weekday, from: $0.start.addingTimeInterval(43_200)) }
        XCTAssertEqual(names, [1, 2, 3, 4, 5, 6, 7]) // Sun ... Sat
        XCTAssertEqual(w.today.index, 3) // Wednesday
        XCTAssertEqual(w.todayUsed, 43, accuracy: 1e-9) // both snapshots fall on Wednesday
        // Sunday takes the hour before midnight, Saturday ends at the 23:00 reset.
        XCTAssertEqual(w.days[0].start.timeIntervalSince1970, start)
        XCTAssertEqual(w.days[1].start.timeIntervalSince1970, start + 86_400 + 3600)
        XCTAssertEqual(w.days[6].end.timeIntervalSince1970, reset)
        XCTAssertEqual(w.days[6].end.timeIntervalSince(w.days[6].start), 23 * 3600)
    }

    func testMidnightRollsToNextDay() {
        let istanbul = TimeZone(identifier: "Europe/Istanbul")!
        let s = [snap(start + 3 * 86_400 + 7200, 10)]
        let before = summary(snapshots: s, now: Date(timeIntervalSince1970: start + 4 * 86_400 + 3599), zone: istanbul)
        let after = summary(snapshots: s, now: Date(timeIntervalSince1970: start + 4 * 86_400 + 3600), zone: istanbul)
        XCTAssertEqual(before.today.index, 3)
        XCTAssertEqual(after.today.index, 4)
    }

    func testDailyDeltas() {
        let s = [snap(start + 3600, 2), snap(start + 20_000, 5),
                 snap(start + 86_400 + 100, 6), snap(start + 86_400 + 40_000, 20)]
        let now = Date(timeIntervalSince1970: start + 86_400 + 50_000)
        let w = summary(snapshots: s, now: now)
        XCTAssertEqual(w.weeklyPercent, 20)
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
        let w = summary(snapshots: s, now: Date(timeIntervalSince1970: start + 86_400 + 5000))
        XCTAssertEqual(w.days[0].carry, 0, accuracy: 1e-9)
        XCTAssertGreaterThan(w.days[1].carry, 0)
        XCTAssertEqual(w.days[1].carry, 95.0 / 6 - 100.0 / 7, accuracy: 1e-9)
        // Future days: remaining pool after today (94) over 5 days.
        XCTAssertEqual(w.days[3].allowance, 94.0 / 5, accuracy: 1e-9)
    }

    func testOverusePenalisesLaterDays() {
        let s = [snap(start + 100, 30)]
        let w = summary(snapshots: s, now: Date(timeIntervalSince1970: start + 86_400 + 5000))
        XCTAssertTrue(w.isOver(w.days[0]))
        XCTAssertLessThan(w.days[1].carry, 0)
        XCTAssertTrue(w.days[0].isFull)
    }

    func testPoolExhausted() {
        let s = [snap(start + 100, 100)]
        let w = summary(snapshots: s, now: Date(timeIntervalSince1970: start + 86_400 + 5000))
        XCTAssertEqual(w.days[1].allowance, 0)
        XCTAssertTrue(w.days[1].isFull)
    }

    func testNoSnapshots() {
        let w = summary(snapshots: [], now: Date(timeIntervalSince1970: start))
        XCTAssertFalse(w.hasData)
        XCTAssertEqual(w.weeklyPercent, 0)
    }

    func testWeekRolloverWithoutNewData() {
        let s = [snap(start + 100, 40)]
        let now = Date(timeIntervalSince1970: reset + 3600)
        let w = summary(snapshots: s, now: now)
        XCTAssertEqual(w.weeklyPercent, 0)
        XCTAssertEqual(w.weekEnd.timeIntervalSince1970, reset + 7 * 86_400)
        XCTAssertEqual(w.todayUsed, 0)
    }

    func testPreviousWeekSnapshotsIgnored() {
        let prevReset = reset - 7 * 86_400
        let s = [snap(prevReset - 1000, 90, resets: prevReset), snap(start + 500, 3)]
        let w = summary(snapshots: s, now: Date(timeIntervalSince1970: start + 1000))
        XCTAssertEqual(w.weeklyPercent, 3)
        XCTAssertEqual(w.days[0].used, 3)
    }

    func testDayHelpers() {
        let s = [snap(start + 100, 5), snap(start + 86_400 + 100, 6)]
        let w = summary(snapshots: s, now: Date(timeIntervalSince1970: start + 86_400 + 5000))
        XCTAssertFalse(w.days[0].hasCarry)
        XCTAssertTrue(w.days[1].hasCarry)
        XCTAssertEqual(w.days[1].fillRatio, 1 / w.days[1].allowance, accuracy: 1e-9)
        XCTAssertEqual(w.days[1].labelDate.timeIntervalSince(w.days[1].start), 12 * 3600)
    }
}
