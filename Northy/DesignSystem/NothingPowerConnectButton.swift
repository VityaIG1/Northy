import SwiftUI
import UIKit

// MARK: - Nothing OS Mechanical Glyph Reactor Button (Turbine Iris & Glyph Arc)

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

    public var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.impactOccurred()
            onToggle()
        }) {
            ZStack {
                // 1. Dynamic Hardware Canvas (60fps TimelineView)
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        ambientEnergyGlow(now: now)

                        Canvas { context, size in
                            drawMechanicalReactor(context: &context, size: size, now: now)
                        }
                        .frame(width: 216, height: 216)
                    }
                }
                .allowsHitTesting(false)

                // 2. Center Tactile Reactor Core (Physical Bezel & Power Switch)
                ZStack {
                    // Recessed Base Rim
                    Circle()
                        .fill(NothingPalette.surfaceElevated)
                        .frame(width: 66, height: 66)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isConnected
                                        ? accentColor
                                        : (isTransitioning ? accentColor.opacity(0.8) : NothingPalette.gridStroke),
                                    lineWidth: isConnected ? 1.8 : 1.0
                                )
                        )
                        .shadow(
                            color: isConnected ? accentColor.opacity(0.55) : (isTransitioning ? accentColor.opacity(0.3) : Color.clear),
                            radius: isConnected ? 14 : 6,
                            x: 0,
                            y: 0
                        )

                    // Inner Matte Core
                    Circle()
                        .fill(NothingPalette.surfacePrimary)
                        .frame(width: 54, height: 54)

                    // Center Mechanical Power Glyph
                    Image(systemName: isConnected ? "power.circle.fill" : (isTransitioning ? "arrow.triangle.2.circlepath" : "power"))
                        .font(.system(size: isConnected ? 26 : 22, weight: .bold))
                        .foregroundStyle(
                            isConnected
                                ? accentColor
                                : (isTransitioning ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                        )
                        .scaleEffect(isConnected ? 1.05 : 1.0)
                        .rotationEffect(.degrees(isTransitioning ? 360 : 0))
                        .animation(
                            isTransitioning
                                ? .linear(duration: 1.5).repeatForever(autoreverses: false)
                                : .spring(response: 0.28, dampingFraction: 0.72),
                            value: isConnected || isTransitioning
                        )
                }
            }
            .frame(width: 216, height: 216)
        }
        .buttonStyle(NothingReactorButtonStyle())
        .accessibilityLabel(isConnected ? "Disconnect VPN" : "Connect VPN")
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 1.0), trigger: isConnected)
    }

    // MARK: - Ambient Energy Halo

    @ViewBuilder
    private func ambientEnergyGlow(now: TimeInterval) -> some View {
        let pulse: CGFloat = {
            if isTransitioning {
                return 0.85 + 0.25 * CGFloat(sin(now * 7.0))
            } else if isConnected {
                return 0.90 + 0.18 * CGFloat(sin(now * 2.2))
            } else {
                return 0.40 + 0.10 * CGFloat(sin(now * 1.2))
            }
        }()

        let glowColor: Color = isConnected
            ? accentColor.opacity(0.35 * pulse)
            : (isTransitioning ? accentColor.opacity(0.40 * pulse) : NothingPalette.pureWhite.opacity(0.04 * pulse))

        Circle()
            .fill(
                RadialGradient(
                    colors: [glowColor, Color.clear],
                    center: .center,
                    startRadius: 28,
                    endRadius: 108
                )
            )
            .frame(width: 216, height: 216)
            .blur(radius: isTransitioning ? 20 : 16)
    }

    // MARK: - Canvas Vector Geometry & Turbine Mechanics

    private func drawMechanicalReactor(context: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        let cx = size.width / 2.0
        let cy = size.height / 2.0
        let center = CGPoint(x: cx, y: cy)

        // -------------------------------------------------------------
        // LAYER 1: Outer Calibrated Technical Dial (360° Notches & Markings)
        // -------------------------------------------------------------
        let outerRadius: CGFloat = 104.0
        let tickInnerRadius: CGFloat = 97.0
        let cardinalRadius: CGFloat = 93.0

        for i in 0..<72 {
            let angle = Double(i) * (2.0 * .pi / 72.0)
            let isMajor = (i % 6 == 0)      // Every 30 degrees
            let isCardinal = (i % 18 == 0)  // 0, 90, 180, 270 degrees

            let r1 = isCardinal ? cardinalRadius : (isMajor ? (tickInnerRadius - 2.0) : tickInnerRadius)
            let r2 = outerRadius

            let p1 = CGPoint(x: cx + cos(angle) * r1, y: cy + sin(angle) * r1)
            let p2 = CGPoint(x: cx + cos(angle) * r2, y: cy + sin(angle) * r2)

            var tickPath = Path()
            tickPath.move(to: p1)
            tickPath.addLine(to: p2)

            let tickColor: Color
            let tickWidth: CGFloat
            if isCardinal {
                tickColor = isConnected ? accentColor : (isTransitioning ? NothingPalette.pureWhite : NothingPalette.pureWhite.opacity(0.7))
                tickWidth = 1.8
            } else if isMajor {
                tickColor = isConnected ? accentColor.opacity(0.6) : NothingPalette.mutedGrey.opacity(0.5)
                tickWidth = 1.0
            } else {
                tickColor = NothingPalette.mutedGrey.opacity(0.25)
                tickWidth = 0.8
            }

            context.stroke(tickPath, with: .color(tickColor), lineWidth: tickWidth)
        }

        // Outer chassis border ring
        var outerRingPath = Path()
        outerRingPath.addArc(center: center, radius: outerRadius, startAngle: .zero, endAngle: .radians(2.0 * .pi), clockwise: false)
        context.stroke(outerRingPath, with: .color(NothingPalette.gridStroke), lineWidth: 1.0)

        // -------------------------------------------------------------
        // LAYER 2: 4 Cardinal Hex Screws / Rivets (45°, 135°, 225°, 315°)
        // -------------------------------------------------------------
        let screwRadius: CGFloat = 88.0
        for screwAngle in [Double.pi / 4.0, 3.0 * Double.pi / 4.0, 5.0 * Double.pi / 4.0, 7.0 * Double.pi / 4.0] {
            let sx = cx + cos(screwAngle) * screwRadius
            let sy = cy + sin(screwAngle) * screwRadius
            let screwRect = CGRect(x: sx - 2.5, y: sy - 2.5, width: 5.0, height: 5.0)

            context.fill(Path(ellipseIn: screwRect), with: .color(NothingPalette.surfacePrimary))
            context.stroke(Path(ellipseIn: screwRect), with: .color(NothingPalette.gridStroke), lineWidth: 1.0)

            // Cross-slot on screw head
            var slotPath = Path()
            slotPath.move(to: CGPoint(x: sx - 1.5, y: sy))
            slotPath.addLine(to: CGPoint(x: sx + 1.5, y: sy))
            context.stroke(slotPath, with: .color(NothingPalette.mutedGrey.opacity(0.7)), lineWidth: 0.8)
        }

        // -------------------------------------------------------------
        // LAYER 3: Segmented Mechanical Turbine Blades / Aperture Iris
        // -------------------------------------------------------------
        let bladeCount = 8
        let bladeSpinAngle: Double = {
            if isTransitioning {
                return (now * 3.8).truncatingRemainder(dividingBy: 2.0 * .pi)
            } else if isConnected {
                return 0.35 // Locked at 20° engagement offset
            } else {
                return 0.0  // Dormant at 0°
            }
        }()

        let irisOpeningFactor: CGFloat = {
            if isTransitioning {
                return 0.65 + 0.35 * CGFloat(sin(now * 5.5))
            } else if isConnected {
                return 1.0 // Fully engaged clamped core
            } else {
                return 0.35 // Dormant retracted
            }
        }()

        let innerIrisRadius: CGFloat = 46.0 + (1.0 - irisOpeningFactor) * 8.0
        let outerIrisRadius: CGFloat = 78.0

        for b in 0..<bladeCount {
            let baseAngle = Double(b) * (2.0 * .pi / Double(bladeCount)) + bladeSpinAngle
            let bladeWidthAngle = (2.0 * .pi / Double(bladeCount)) * 0.82

            let p0 = CGPoint(x: cx + cos(baseAngle) * innerIrisRadius, y: cy + sin(baseAngle) * innerIrisRadius)
            let p1 = CGPoint(x: cx + cos(baseAngle + bladeWidthAngle) * (innerIrisRadius + 4.0), y: cy + sin(baseAngle + bladeWidthAngle) * (innerIrisRadius + 4.0))
            let p2 = CGPoint(x: cx + cos(baseAngle + bladeWidthAngle * 1.15) * outerIrisRadius, y: cy + sin(baseAngle + bladeWidthAngle * 1.15) * outerIrisRadius)
            let p3 = CGPoint(x: cx + cos(baseAngle * 1.05) * outerIrisRadius, y: cy + sin(baseAngle * 1.05) * outerIrisRadius)

            var bladePath = Path()
            bladePath.move(to: p0)
            bladePath.addLine(to: p1)
            bladePath.addLine(to: p2)
            bladePath.addLine(to: p3)
            bladePath.closeSubpath()

            let bladeFillColor: Color = {
                if isConnected {
                    return accentColor.opacity(0.18)
                } else if isTransitioning {
                    let highlight = (b == Int(now * 8.0) % bladeCount)
                    return highlight ? accentColor.opacity(0.35) : NothingPalette.surfacePrimary.opacity(0.8)
                } else {
                    return NothingPalette.surfacePrimary.opacity(0.65)
                }
            }()

            let bladeEdgeColor: Color = {
                if isConnected {
                    return accentColor.opacity(0.85)
                } else if isTransitioning {
                    return accentColor.opacity(0.6)
                } else {
                    return NothingPalette.gridStroke
                }
            }()

            context.fill(bladePath, with: .color(bladeFillColor))
            context.stroke(bladePath, with: .color(bladeEdgeColor), lineWidth: isConnected ? 1.4 : 0.9)
        }

        // -------------------------------------------------------------
        // LAYER 4: Authentic Nothing Phone Glyph Dot-Matrix Arc (Tachometer Strip)
        // -------------------------------------------------------------
        let glyphDotCount = 36
        let glyphRadius: CGFloat = 84.0
        let activeGlyphDots: Int = {
            if isConnected {
                return glyphDotCount
            } else if isTransitioning {
                let progress = (now * 1.5).truncatingRemainder(dividingBy: 1.0)
                return Int(Double(glyphDotCount) * progress)
            } else {
                return 4 // Subtle idle dots
            }
        }()

        for d in 0..<glyphDotCount {
            let dotAngle = Double(d) * (2.0 * .pi / Double(glyphDotCount)) - (.pi / 2.0)
            let dx = cx + cos(dotAngle) * glyphRadius
            let dy = cy + sin(dotAngle) * glyphRadius

            let isLit = (d <= activeGlyphDots)
            let dotSize: CGFloat = isLit ? 2.8 : 2.0

            let dotColor: Color = {
                if isConnected {
                    let breathe = 0.75 + 0.25 * sin(now * 2.4 + Double(d) * 0.15)
                    return accentColor.opacity(breathe)
                } else if isTransitioning {
                    if d == activeGlyphDots {
                        return NothingPalette.pureWhite // Lead photon spark
                    } else if isLit {
                        return accentColor.opacity(0.85)
                    } else {
                        return NothingPalette.dimMatrixDot.opacity(0.2)
                    }
                } else {
                    return isLit ? NothingPalette.mutedGrey.opacity(0.4) : NothingPalette.dimMatrixDot.opacity(0.15)
                }
            }()

            let dotRect = CGRect(x: dx - dotSize / 2, y: dy - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Path(dotRect), with: .color(dotColor))
        }

        // -------------------------------------------------------------
        // LAYER 5: Core Orbiting Ticks & Status Indicator
        // -------------------------------------------------------------
        if isConnected {
            let chronometerTick = Int(now * 12.0) % 12
            let clockRadius: CGFloat = 38.0
            for k in 0..<12 {
                let kAngle = Double(k) * (2.0 * .pi / 12.0)
                let kx = cx + cos(kAngle) * clockRadius
                let ky = cy + sin(kAngle) * clockRadius
                let isClockActive = (k == chronometerTick)
                let cSize: CGFloat = isClockActive ? 2.5 : 1.5
                let cColor = isClockActive ? NothingPalette.pureWhite : accentColor.opacity(0.4)
                let cRect = CGRect(x: kx - cSize / 2, y: ky - cSize / 2, width: cSize, height: cSize)
                context.fill(Path(cRect), with: .color(cColor))
            }
        }
    }
}

// MARK: - Mechanical Spring Button Style

private struct NothingReactorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
