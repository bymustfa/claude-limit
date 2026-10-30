import SwiftUI

/// Colours shared by the panel views.
enum Theme {
    /// Near the daily share.
    static let warning = Color(red: 1.0, green: 0.66, blue: 0.2)
    static let over = Color(red: 0.95, green: 0.27, blue: 0.18)
    static let carryUp = Color(red: 0.3, green: 0.8, blue: 0.75)
    static let carryDown = Color(red: 1.0, green: 0.55, blue: 0.2)
    static let todayGlow = Color(red: 0.6, green: 0.85, blue: 1.0)
    static let fullGlow = Color(red: 1.0, green: 0.2, blue: 0.2)
    /// Used-up day numbers.
    static let fullText = Color(red: 1.0, green: 0.45, blue: 0.42)

    private static let liquidStops: [(at: Double, rgb: (Double, Double, Double))] = [
        (0, (0.25, 0.58, 1.0)), (0.45, (0.55, 0.80, 0.75)), (0.8, (1.0, 0.66, 0.2)), (1.0, (0.62, 0.07, 0.10)),
    ]

    /// Blue when far from the daily share, orange near it, dark red once it is reached or passed.
    static func liquidColor(ratio: Double) -> Color {
        let x = min(max(ratio, 0), 1)
        for index in 1..<liquidStops.count where x <= liquidStops[index].at {
            let (from, to) = (liquidStops[index - 1], liquidStops[index])
            let fraction = (x - from.at) / (to.at - from.at)
            return Color(red: from.rgb.0 + (to.rgb.0 - from.rgb.0) * fraction,
                         green: from.rgb.1 + (to.rgb.1 - from.rgb.1) * fraction,
                         blue: from.rgb.2 + (to.rgb.2 - from.rgb.2) * fraction)
        }
        let last = liquidStops[liquidStops.count - 1].rgb
        return Color(red: last.0, green: last.1, blue: last.2)
    }
}
