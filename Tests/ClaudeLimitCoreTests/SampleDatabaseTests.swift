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
        db.insert(Snapshot(timestamp: 20, fiveHour: nil, sevenDay: LimitWindow(percent: 6, resetsAt: 99)), source: "t")
        db.insert(Snapshot(timestamp: 10, fiveHour: LimitWindow(percent: 1, resetsAt: 50), sevenDay: LimitWindow(percent: 5, resetsAt: 99)), source: "t")
        let all = db.load()
        XCTAssertEqual(all.map(\.timestamp), [10, 20])
        XCTAssertEqual(all[0].fiveHour?.percent, 1)
        XCTAssertNil(all[1].fiveHour)
        XCTAssertEqual(db.load(since: 15).count, 1)
    }
}
