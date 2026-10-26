import SwiftUI

/// A body of liquid filling the bottom `level` (0...1) of its rect, with a sine-wave surface.
struct LiquidShape: Shape {
    var level: CGFloat
    var phase: Double
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = rect.height * (1 - level)
        // Calmer surface when there is little liquid, so a thin layer doesn't look torn.
        let amp = amplitude * min(1, rect.height * level / 10)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: top + CGFloat(sin(phase)) * amp))
        var x: CGFloat = 0
        while x <= rect.width {
            let angle = Double(x / rect.width) * 2 * .pi * 1.3 + phase
            p.addLine(to: CGPoint(x: rect.minX + x, y: top + CGFloat(sin(angle)) * amp))
            x += 2
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

extension View {
    /// Liquid Glass capsule on macOS 26+, a plain material capsule before that.
    @ViewBuilder func glassCapsule(tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: Capsule())
        } else {
            self.background(tint ?? Color.primary.opacity(0.08), in: Capsule())
        }
    }

    @ViewBuilder func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass).controlSize(.small)
        } else {
            self.buttonStyle(.bordered).controlSize(.small)
        }
    }
}
