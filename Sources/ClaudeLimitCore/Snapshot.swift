import Foundation

/// One rate-limit window as reported by `claude -p "/usage"`.
public struct LimitWindow: Equatable, Sendable {
    /// Percent of the limit used, 0...100.
    public var percent: Double
    /// Unix time at which the window resets.
    public var resetsAt: TimeInterval

    public init(percent: Double, resetsAt: TimeInterval) {
        self.percent = percent
        self.resetsAt = resetsAt
    }
}

/// The state of both limit windows at one point in time.
public struct Snapshot: Equatable, Sendable {
    /// Unix time the sample was taken.
    public var timestamp: TimeInterval
    public var fiveHour: LimitWindow?
    public var sevenDay: LimitWindow?

    public init(timestamp: TimeInterval, fiveHour: LimitWindow? = nil, sevenDay: LimitWindow? = nil) {
        self.timestamp = timestamp
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }
}
