import SwiftUI

// MARK: - Nothing OS Dot-Matrix Snake Wave (Live Network Throughput Visualizer)

public struct NothingDotMatrixSnakeWave: View {
    public let isConnected: Bool
    public let isTransitioning: Bool
    public let rxSpeedBytesPerSec: UInt64
    public let txSpeedBytesPerSec: UInt64
    public let accentColor: Color

    public init(
        isConnected: Bool,
        isTransitioning: Bool,
        rxSpeedBytesPerSec: UInt64,
        txSpeedBytesPerSec: UInt64,
        accentColor: Color
    ) {
        self.isConnected = isConnected
        self.isTransitioning = isTransitioning
        self.rxSpeedBytesPerSec = rxSpeedBytesPerSec
        self.txSpeedBytesPerSec = txSpeedBytesPerSec
        self.accentColor = accentColor
    }

    private let cols = 32
    private let rows = 7

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let totalSpeed = rxSpeedBytesPerSec + txSpeedBytesPerSec

            // Dynamic speed & frequency modulation based on live network activity
            let speedFactor: Double = {
                if !isConnected && !isTransitioning {
                    return 1.4 // slow undulating idle wave
                } else if isTransitioning {
                    return 4.2 // fast searching wave
                } else {
                    let activity = min(Double(totalSpeed) / 1_000_000.0, 5.0)
                    return 2.4 + activity * 1.2
                }
            }()

            let amplitudeFactor: Double = {
                if !isConnected && !isTransitioning {
                    return 1.6
                } else if isTransitioning {
                    return 2.2
                } else {
                    let activity = min(Double(totalSpeed) / 1_500_000.0, 1.2)
                    return 1.8 + activity * 0.8
                }
            }()

            Canvas { context, size in
                let cellW = size.width / CGFloat(cols)
                let cellH = size.height / CGFloat(rows)
                let dotRadius: CGFloat = min(cellW, cellH) * 0.32

                for c in 0..<cols {
                    let normX = Double(c) / Double(cols)

                    // Fluid sine-wave with 2 harmonic components
                    let phase = now * speedFactor
                    let wave1 = sin(normX * .pi * 2.8 - phase)
                    let wave2 = sin(normX * .pi * 5.2 + phase * 0.4) * 0.35
                    let combinedWave = (wave1 + wave2) / 1.35

                    // Target row center (0..<rows)
                    let targetCenterRow = Double(rows - 1) / 2.0 + combinedWave * amplitudeFactor

                    for r in 0..<rows {
                        let rowDist = abs(Double(r) - targetCenterRow)
                        let cx = CGFloat(c) * cellW + cellW / 2
                        let cy = CGFloat(r) * cellH + cellH / 2

                        let rect = CGRect(
                            x: cx - dotRadius,
                            y: cy - dotRadius,
                            width: dotRadius * 2,
                            height: dotRadius * 2
                        )

                        let dotColor: Color
                        if rowDist < 0.85 {
                            // Peak crest of the snake wave
                            if isConnected {
                                dotColor = accentColor
                            } else if isTransitioning {
                                dotColor = accentColor.opacity(0.85)
                            } else {
                                dotColor = NothingPalette.pureWhite.opacity(0.65)
                            }
                        } else if rowDist < 1.75 {
                            // Secondary glow falloff
                            let falloff = 1.0 - (rowDist - 0.85) / 0.9
                            if isConnected || isTransitioning {
                                dotColor = accentColor.opacity(0.25 * falloff)
                            } else {
                                dotColor = NothingPalette.pureWhite.opacity(0.20 * falloff)
                            }
                        } else {
                            // Inactive matrix LED dot
                            dotColor = NothingPalette.dimMatrixDot.opacity(0.20)
                        }

                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 16)
        .overlay(
            // Subtle hairline top and bottom guidelines
            VStack {
                Rectangle()
                    .fill(NothingPalette.gridStroke.opacity(0.5))
                    .frame(height: 1)
                Spacer()
                Rectangle()
                    .fill(NothingPalette.gridStroke.opacity(0.5))
                    .frame(height: 1)
            }
        )
    }
}
