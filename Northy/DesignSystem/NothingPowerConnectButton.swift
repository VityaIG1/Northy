import SwiftUI
import UIKit

// MARK: - Nothing OS Dot-Matrix Power Control Button (Concentric Energy & LED Ignition)

public struct NothingPowerConnectButton: View {
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

    // Geometry of concentric dot rings: (radius, dotCount, dotSize)
    private static let rings: [(radius: CGFloat, count: Int, size: CGFloat)] = [
        (42, 16, 2.0),
        (60, 24, 2.2),
        (78, 32, 2.4),
        (94, 40, 2.6)
    ]

    public var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onToggle()
        }) {
            ZStack {
                // Dynamic Radial Glow and Dot-Matrix Canvas in a single TimelineView
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ambientGlow(now: now)

                        Canvas { context, size in
                            drawPowerMatrix(context: &context, size: size, now: now)
                        }
                        .frame(width: 208, height: 208)
                    }
                }
                .allowsHitTesting(false)

                // Center Elevated Nothing OS Power Button Core
                Circle()
                    .fill(NothingPalette.surfaceElevated)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isConnected
                                    ? accentColor
                                    : (isTransitioning ? accentColor.opacity(0.7) : NothingPalette.gridStroke),
                                lineWidth: isConnected ? 1.8 : 1.0
                            )
                    )
                    .shadow(
                        color: isConnected ? accentColor.opacity(0.45) : (isTransitioning ? accentColor.opacity(0.25) : Color.clear),
                        radius: isConnected ? 12 : 6,
                        x: 0,
                        y: 0
                    )

                // Center Power Glyph
                Image(systemName: "power")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        isConnected
                            ? accentColor
                            : (isTransitioning ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                    )
                    .scaleEffect(isConnected ? 1.04 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isConnected)
            }
            .frame(width: 208, height: 208)
        }
        .buttonStyle(NothingPowerButtonStyle())
        .accessibilityLabel(isConnected ? "Disconnect VPN" : "Connect VPN")
    }

    // MARK: - Ambient Radial Glow

    @ViewBuilder
    private func ambientGlow(now: TimeInterval) -> some View {
        let pulse: CGFloat = {
            if isTransitioning {
                return 0.85 + 0.25 * CGFloat(sin(now * 6.0))
            } else if isConnected {
                return 0.90 + 0.15 * CGFloat(sin(now * 2.2))
            } else {
                return 0.45 + 0.10 * CGFloat(sin(now * 1.5))
            }
        }()

        let glowColor: Color = isConnected
            ? accentColor.opacity(0.28 * pulse)
            : (isTransitioning ? accentColor.opacity(0.35 * pulse) : NothingPalette.pureWhite.opacity(0.04 * pulse))

        Circle()
            .fill(
                RadialGradient(
                    colors: [glowColor, Color.clear],
                    center: .center,
                    startRadius: 24,
                    endRadius: 104
                )
            )
            .frame(width: 208, height: 208)
            .blur(radius: isTransitioning ? 18 : 14)
    }

    // MARK: - Precision Matrix & Orbital Burst Drawing

    private func drawPowerMatrix(context: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        let cx = size.width / 2.0
        let cy = size.height / 2.0

        // A. Connecting Energy Wave Expansion Ring
        if isTransitioning {
            let waveProgress = (now * 1.4).truncatingRemainder(dividingBy: 1.0)
            let waveRadius = 40.0 + CGFloat(waveProgress) * 58.0
            let waveAlpha = (1.0 - waveProgress) * 0.5
            var wavePath = Path()
            wavePath.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: waveRadius,
                startAngle: .zero,
                endAngle: .radians(2.0 * .pi),
                clockwise: false
            )
            context.stroke(
                wavePath,
                with: .color(accentColor.opacity(waveAlpha)),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
            )
        }

        // B. Cardinal LED Guides (N, E, S, W crosshair pins)
        let cardinalRadius: CGFloat = 100.0
        let cardinalPulse = 0.5 + 0.5 * sin(now * (isConnected ? 2.5 : 1.2))
        let cardinalColor: Color = isConnected ? accentColor : (isTransitioning ? NothingPalette.pureWhite : NothingPalette.dimMatrixDot)

        for angle in [0.0, .pi / 2.0, .pi, 3.0 * .pi / 2.0] {
            let kx = cx + cos(angle) * cardinalRadius
            let ky = cy + sin(angle) * cardinalRadius
            let kRect = CGRect(x: kx - 1.5, y: ky - 1.5, width: 3.0, height: 3.0)
            context.fill(Path(kRect), with: .color(cardinalColor.opacity(0.35 + 0.45 * cardinalPulse)))
        }

        // C. Concentric Rings of Precision Matrix Dots
        for (ringIdx, ring) in Self.rings.enumerated() {
            let r = ring.radius
            let baseSize = ring.size

            let orbitalSpeed = ringIdx.isMultiple(of: 2) ? 2.4 : -2.0
            let orbitalAngle = (now * orbitalSpeed).truncatingRemainder(dividingBy: 2.0 * .pi)

            for i in 0..<ring.count {
                let dotAngle = Double(i) / Double(ring.count) * 2.0 * .pi
                let px = cx + cos(dotAngle) * r
                let py = cy + sin(dotAngle) * r

                let dotColor: Color
                let dotScale: CGFloat

                if isTransitioning {
                    var diff = orbitalAngle - dotAngle
                    while diff < 0 { diff += 2.0 * .pi }
                    while diff >= 2.0 * .pi { diff -= 2.0 * .pi }

                    let headSpan = .pi / 2.5
                    if diff < headSpan {
                        let factor = pow(1.0 - diff / headSpan, 2.0)
                        dotScale = 1.0 + CGFloat(factor) * 0.6
                        dotColor = (diff < 0.12) ? NothingPalette.pureWhite : accentColor.opacity(0.4 + 0.6 * factor)
                    } else {
                        dotScale = 1.0
                        dotColor = NothingPalette.dimMatrixDot.opacity(0.25)
                    }
                } else if isConnected {
                    let breathe = sin(now * 2.2 + Double(ringIdx) * 0.5)
                    let intensity = 0.55 + 0.45 * breathe
                    dotScale = 1.0 + CGFloat(breathe) * 0.12
                    dotColor = accentColor.opacity(0.40 + 0.55 * intensity)
                } else {
                    let idleBreathe = 0.5 + 0.5 * sin(now * 1.4 + Double(i) * 0.2)
                    dotScale = 1.0
                    dotColor = NothingPalette.dimMatrixDot.opacity(0.22 + 0.16 * idleBreathe)
                }

                let d = baseSize * dotScale
                let rect = CGRect(x: px - d / 2, y: py - d / 2, width: d, height: d)
                context.fill(Path(ellipseIn: rect), with: .color(dotColor))
            }
        }
    }
}

// MARK: - Crisp Tactile Spring Button Style

private struct NothingPowerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
