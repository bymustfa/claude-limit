import Foundation

/// One rate-limit window as reported by the Claude Code status line.
public struct LimitWindow: Codable, Equatable, Sendable {
    public var pct: Double
    public var resetsAt: TimeInterval

    public init(pct: Double, resetsAt: TimeInterval) {
        self.pct = pct
        self.resetsAt = resetsAt
    }

    enum CodingKeys: String, CodingKey {
        case pct
        case resetsAt = "resets_at"
    }
}

/// A line of `snapshots.jsonl` written by `scripts/capture.sh`.
public struct Snapshot: Codable, Equatable, Sendable {
    public var t: TimeInterval
    public var fiveHour: LimitWindow?
    public var sevenDay: LimitWindow?

    public init(t: TimeInterval, fiveHour: LimitWindow? = nil, sevenDay: LimitWindow? = nil) {
        self.t = t
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }

    enum CodingKeys: String, CodingKey {
        case t
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

public enum SnapshotParser {
    /// Parses JSONL text, skipping malformed lines, sorted by time.
    public static func parse(_ text: String) -> [Snapshot] {
        let decoder = JSONDecoder()
        return text.split(whereSeparator: \.isNewline)
            .compactMap { try? decoder.decode(Snapshot.self, from: Data($0.utf8)) }
            .sorted { $0.t < $1.t }
    }
}
