import SwiftUI

// MARK: - Nothing OS 360° Dot-Matrix Radar Connect Button with Radial Glow

public struct NothingRadarConnectButton: View {
    public let isConnected: Bool
    public let isTransitioning: Bool
    public let accentColor: Color
    public let onToggle: () -> Void

    public init(
        isConnected: Bool,
        isTransitioning: Bool,
        accentColor: Color,
        onToggle: @escaping () -> Void
    ) {
        self.isConnected = isConnected
        self.isTransitioning = isTransitioning
        self.accentColor = accentColor
        self.onToggle = onToggle
    }

    // Geometry of concentric dot rings: (radius, dotCount)
    private static let rings: [(radius: CGFloat, count: Int)] = [
        (32, 12),
        (52, 20),
        (70, 28),
        (88, 36)
    ]

    public var body: some View {
        Button(action: onToggle) {
            ZStack {
                // Radial glow backing
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isConnected || isTransitioning ? accentColor.opacity(isTransitioning ? 0.32 : 0.22) : Color.white.opacity(0.04)),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 92
                        )
                    )
                    .frame(width: 184, height: 184)
                    .blur(radius: isTransitioning ? 14 : 10)
                    .allowsHitTesting(false)

                // 360° Dot-Matrix Radar Canvas
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate

                    // Angular velocity
                    let speed: Double = {
                        if isTransitioning {
                            return 3.6
                        } else if isConnected {
                            return 1.8
                        } else {
                            return 0.6
                        }
                    }()

                    let sweepAngle = (now * speed).truncatingRemainder(dividingBy: 2.0 * .pi)
                    let beamWidth: Double = .pi / 3.0 // 60-degree sweep sector

                    Canvas { context, size in
                        let cx = size.width / 2.0
                        let cy = size.height / 2.0
                        let baseDotRadius: CGFloat = 1.6

                        // 1. Draw 8-spoke radial crosshair dots
                        for spoke in 0..<8 {
                            let spokeAngle = Double(spoke) * (.pi / 4.0)
                            for step in 1...6 {
                                let r = CGFloat(step) * 14.5 + 4
                                let px = cx + cos(spokeAngle) * r
                                let py = cy + sin(spokeAngle) * r

                                var diff = sweepAngle - spokeAngle
                                while diff < 0 { diff += 2.0 * .pi }
                                while diff >= 2.0 * .pi { diff -= 2.0 * .pi }

                                let isLit = diff <= beamWidth
                                let dotColor: Color = {
                                    if isLit {
                                        let factor = pow(1.0 - diff / beamWidth, 1.8)
                                        return (isConnected || isTransitioning)
                                            ? accentColor.opacity(0.4 + 0.6 * factor)
                                            : NothingPalette.pureWhite.opacity(0.25 + 0.5 * factor)
                                    } else {
                                        return NothingPalette.dimMatrixDot.opacity(0.20)
                                    }
                                }()

                                let rect = CGRect(x: px - 1.1, y: py - 1.1, width: 2.2, height: 2.2)
                                context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                            }
                        }

                        // 2. Draw Concentric Dot-Matrix Rings
                        for ring in Self.rings {
                            let r = ring.radius
                            for i in 0..<ring.count {
                                let dotAngle = Double(i) / Double(ring.count) * 2.0 * .pi
                                let px = cx + cos(dotAngle) * r
                                let py = cy + sin(dotAngle) * r

                                var diff = sweepAngle - dotAngle
                                while diff < 0 { diff += 2.0 * .pi }
                                while diff >= 2.0 * .pi { diff -= 2.0 * .pi }

                                let isLit = diff <= beamWidth
                                let dotColor: Color
                                let radiusScale: CGFloat

                                if isLit {
                                    let factor = pow(1.0 - diff / beamWidth, 1.5)
                                    radiusScale = 1.0 + CGFloat(factor) * 0.45
                                    if diff < 0.08 {
                                        // Leading edge sparks white
                                        dotColor = NothingPalette.pureWhite
                                    } else {
                                        dotColor = (isConnected || isTransitioning)
                                            ? accentColor.opacity(0.35 + 0.65 * factor)
                                            : NothingPalette.pureWhite.opacity(0.3 + 0.5 * factor)
                                    }
                                } else {
                                    radiusScale = 1.0
                                    dotColor = isConnected
                                        ? accentColor.opacity(0.18)
                                        : NothingPalette.dimMatrixDot.opacity(0.32)
                                }

                                let d = baseDotRadius * radiusScale
                                let rect = CGRect(x: px - d, y: py - d, width: d * 2, height: d * 2)
                                context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                            }
                        }

                        // 3. Subtle sweep scanline
                        let scanlineLength: CGFloat = 90.0
                        var scanPath = Path()
                        scanPath.move(to: CGPoint(x: cx, y: cy))
                        scanPath.addLine(to: CGPoint(x: cx + cos(sweepAngle) * scanlineLength, y: cy + sin(sweepAngle) * scanlineLength))
                        let scanColor = (isConnected || isTransitioning ? accentColor : NothingPalette.pureWhite).opacity(0.4)
                        context.stroke(scanPath, with: .color(scanColor), lineWidth: 1.0)
                    }
                }
                .frame(width: 184, height: 184)
                .allowsHitTesting(false)

                // Center Power Glyph & Button Core
                Circle()
                    .fill(NothingPalette.surfaceElevated)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isConnected
                                    ? accentColor
                                    : (isTransitioning ? accentColor.opacity(0.6) : NothingPalette.gridStroke),
                                lineWidth: isConnected ? 1.5 : 1.0
                            )
                    )
                    .shadow(
                        color: isConnected ? accentColor.opacity(0.4) : Color.clear,
                        radius: 8,
                        x: 0,
                        y: 0
                    )

                // Power Glyph
                Image(systemName: "power")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        isConnected
                            ? accentColor
                            : (isTransitioning ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                    )
            }
            .frame(width: 184, height: 184)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isConnected ? "Disconnect VPN" : "Connect VPN")
    }
}
