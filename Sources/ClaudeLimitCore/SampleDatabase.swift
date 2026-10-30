import Foundation
import SQLite3

private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Append-only history of limit samples, kept in a local SQLite file. Not thread-safe: use from one actor.
public final class SampleDatabase {
    private var db: OpaquePointer?

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClaudeLimit/usage.db")
    }

    public init?(url: URL = SampleDatabase.defaultURL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            // sqlite3_open allocates a handle even on failure.
            sqlite3_close(db)
            db = nil
            return nil
        }
        // Column names are kept as-is so databases created by earlier versions keep loading.
        let schema = """
        CREATE TABLE IF NOT EXISTS samples (
            t REAL NOT NULL, five_pct REAL, five_resets REAL, week_pct REAL, week_resets REAL, source TEXT);
        CREATE INDEX IF NOT EXISTS samples_t ON samples(t);
        """
        guard exec(schema) else { return nil }
    }

    deinit { sqlite3_close(db) }

    @discardableResult
    private func exec(_ sql: String) -> Bool { sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK }

    public func insert(_ snapshot: Snapshot, source: String) {
        var statement: OpaquePointer?
        let sql = "INSERT INTO samples (t, five_pct, five_resets, week_pct, week_resets, source) VALUES (?,?,?,?,?,?)"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, snapshot.timestamp)
        func bind(_ index: Int32, _ value: Double?) {
            if let value { sqlite3_bind_double(statement, index, value) } else { sqlite3_bind_null(statement, index) }
        }
        bind(2, snapshot.fiveHour?.percent); bind(3, snapshot.fiveHour?.resetsAt)
        bind(4, snapshot.sevenDay?.percent); bind(5, snapshot.sevenDay?.resetsAt)
        sqlite3_bind_text(statement, 6, source, -1, transient)
        sqlite3_step(statement)
    }

    /// Samples taken at or after `since`, oldest first.
    public func load(since: TimeInterval = 0) -> [Snapshot] {
        var statement: OpaquePointer?
        let sql = "SELECT t, five_pct, five_resets, week_pct, week_resets FROM samples WHERE t >= ? ORDER BY t"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, since)
        func window(percentColumn: Int32, resetsColumn: Int32) -> LimitWindow? {
            sqlite3_column_type(statement, percentColumn) == SQLITE_NULL ? nil
                : LimitWindow(percent: sqlite3_column_double(statement, percentColumn),
                              resetsAt: sqlite3_column_double(statement, resetsColumn))
        }
        var snapshots: [Snapshot] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            snapshots.append(Snapshot(timestamp: sqlite3_column_double(statement, 0),
                                      fiveHour: window(percentColumn: 1, resetsColumn: 2),
                                      sevenDay: window(percentColumn: 3, resetsColumn: 4)))
        }
        return snapshots
    }
}
