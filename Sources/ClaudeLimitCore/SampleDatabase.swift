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
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { return nil }
        let schema = """
        CREATE TABLE IF NOT EXISTS samples (
            t REAL NOT NULL, five_pct REAL, five_resets REAL, week_pct REAL, week_resets REAL, source TEXT);
        CREATE INDEX IF NOT EXISTS samples_t ON samples(t);
        CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
        """
        guard exec(schema) else { return nil }
    }

    deinit { sqlite3_close(db) }

    @discardableResult
    private func exec(_ sql: String) -> Bool { sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK }

    public func insert(_ snap: Snapshot, source: String) {
        var stmt: OpaquePointer?
        let sql = "INSERT INTO samples (t, five_pct, five_resets, week_pct, week_resets, source) VALUES (?,?,?,?,?,?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, snap.t)
        func bind(_ i: Int32, _ v: Double?) {
            if let v { sqlite3_bind_double(stmt, i, v) } else { sqlite3_bind_null(stmt, i) }
        }
        bind(2, snap.fiveHour?.pct); bind(3, snap.fiveHour?.resetsAt)
        bind(4, snap.sevenDay?.pct); bind(5, snap.sevenDay?.resetsAt)
        sqlite3_bind_text(stmt, 6, source, -1, transient)
        sqlite3_step(stmt)
    }

    /// Samples taken at or after `since`, oldest first.
    public func load(since: TimeInterval = 0) -> [Snapshot] {
        var stmt: OpaquePointer?
        let sql = "SELECT t, five_pct, five_resets, week_pct, week_resets FROM samples WHERE t >= ? ORDER BY t"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, since)
        func window(_ a: Int32, _ b: Int32) -> LimitWindow? {
            sqlite3_column_type(stmt, a) == SQLITE_NULL ? nil
                : LimitWindow(pct: sqlite3_column_double(stmt, a), resetsAt: sqlite3_column_double(stmt, b))
        }
        var out: [Snapshot] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(Snapshot(t: sqlite3_column_double(stmt, 0), fiveHour: window(1, 2), sevenDay: window(3, 4)))
        }
        return out
    }

    public func count() -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM samples", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int64(stmt, 0)) : 0
    }

    /// Runs `work` once per database (tracked under `key` in the meta table).
    public func once(_ key: String, _ work: () -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM meta WHERE key = ?", -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, key, -1, transient)
        let done = sqlite3_step(stmt) == SQLITE_ROW
        sqlite3_finalize(stmt)
        guard !done else { return }
        exec("BEGIN")
        work()
        exec("INSERT INTO meta (key, value) VALUES ('\(key.replacingOccurrences(of: "'", with: "''"))', '1')")
        exec("COMMIT")
    }
}
