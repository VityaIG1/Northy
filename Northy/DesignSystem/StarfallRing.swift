import SwiftUI

// MARK: - Starfall / Meteor-Shower Particle Ring (Nothing OS Connecting Animation)

public struct StarfallRing: View {
    public let isActive: Bool
    public let accentColor: Color

    public init(isActive: Bool, accentColor: Color) {
        self.isActive = isActive
        self.accentColor = accentColor
    }

    private static let particleCount = 18
    private static let orbitRadius: Double = 70.0

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                guard isActive else { return }
                let cx = size.width / 2
                let cy = size.height / 2

                for i in 0..<Self.particleCount {
                    let baseAngle = (Double(i) / Double(Self.particleCount)) * .pi * 2
                    let angle = baseAngle + t * 1.8
                    let r = Self.orbitRadius + sin(t * 2.5 + Double(i)) * 6.0
                    let x = cx + CGFloat(cos(angle) * r)
                    let y = cy + CGFloat(sin(angle) * r)

                    let pulseFactor = abs(sin(t * 3.0 + Double(i) * 0.7))
                    let opacity = 0.35 + 0.65 * pulseFactor
                    let dotSize = CGFloat(1.8 + 2.8 * abs(sin(t * 2.2 + Double(i) * 1.1)))

                    // Main particle dot
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(accentColor.opacity(opacity)))

                    // Comet tail — 4 trailing smaller dots
                    for j in 1...4 {
                        let tailAngle = angle - Double(j) * 0.11
                        let tx = cx + CGFloat(cos(tailAngle) * r)
                        let ty = cy + CGFloat(sin(tailAngle) * r)
                        let tailOpacity = opacity * max(0, 1.0 - Double(j) * 0.24)
                        let tailSize = max(0.3, dotSize * (1.0 - CGFloat(j) * 0.22))
                        let trect = CGRect(x: tx - tailSize / 2, y: ty - tailSize / 2, width: tailSize, height: tailSize)
                        context.fill(Path(ellipseIn: trect), with: .color(accentColor.opacity(tailOpacity)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .frame(width: 164, height: 164)
    }
}
