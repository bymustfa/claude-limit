import XCTest
@testable import ClaudeLimitCore

final class SampleDatabaseTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("usage-\(UUID().uuidString).db")
    }

    func testRoundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let db = try XCTUnwrap(SampleDatabase(url: url))
        db.insert(Snapshot(t: 20, fiveHour: nil, sevenDay: LimitWindow(pct: 6, resetsAt: 99)), source: "t")
        db.insert(Snapshot(t: 10, fiveHour: LimitWindow(pct: 1, resetsAt: 50), sevenDay: LimitWindow(pct: 5, resetsAt: 99)), source: "t")
        let all = db.load()
        XCTAssertEqual(all.map(\.t), [10, 20])
        XCTAssertEqual(all[0].fiveHour?.pct, 1)
        XCTAssertNil(all[1].fiveHour)
        XCTAssertEqual(db.load(since: 15).count, 1)
    }

    func testOnceRunsOnlyOnce() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let db = try XCTUnwrap(SampleDatabase(url: url))
        var n = 0
        db.once("import") { n += 1 }
        db.once("import") { n += 1 }
        XCTAssertEqual(n, 1)
    }
}
