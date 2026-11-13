import SwiftUI
import Observation

// MARK: - Dynamic Theme State (Accent Color & Industrial Rounded Corners)

@Observable
@MainActor
public final class ThemeManager {
    public static let shared = ThemeManager()

    private enum StorageKeys {
        static let isRoundedCorners = "northy.theme.is_rounded_corners.v2"
        static let accentHex = "northy.theme.accent_hex.v2"
    }

    public static let defaultAccentHex = "#D71921"

    public var isRoundedCorners: Bool {
        didSet {
            UserDefaults.standard.set(isRoundedCorners, forKey: StorageKeys.isRoundedCorners)
        }
    }

    public var accentHex: String {
        didSet {
            UserDefaults.standard.set(accentHex, forKey: StorageKeys.accentHex)
        }
    }

    /// Card & container corner radius (0pt sharp vs 18pt rounded)
    public var cornerRadius: CGFloat {
        isRoundedCorners ? 18.0 : 0.0
    }

    /// Button corner radius (0pt sharp vs 14pt rounded)
    public var buttonCornerRadius: CGFloat {
        isRoundedCorners ? 14.0 : 0.0
    }

    /// Small badge / chip corner radius (0pt sharp vs 8pt rounded)
    public var chipCornerRadius: CGFloat {
        isRoundedCorners ? 8.0 : 0.0
    }

    public var accentColor: Color {
        Color(hex: accentHex) ?? NothingPalette.defaultAccentRed
    }

    public static let presetSwatches: [(nameKey: String, hex: String, color: Color)] = [
        ("settings.appearance.accent_red", "#D71921", Color(red: 0.843, green: 0.098, blue: 0.129)),
        ("settings.appearance.accent_white", "#EEEEEE", Color(red: 0.933, green: 0.933, blue: 0.933)),
        ("settings.appearance.accent_amber", "#FF7A00", Color(red: 1.0, green: 0.478, blue: 0.0)),
        ("settings.appearance.accent_cyan", "#00FF85", Color(red: 0.0, green: 1.0, blue: 0.522)),
        ("settings.appearance.accent_gray", "#888888", Color(red: 0.533, green: 0.533, blue: 0.533))
    ]

    private init() {
        self.isRoundedCorners = UserDefaults.standard.bool(forKey: StorageKeys.isRoundedCorners)
        let savedHex = UserDefaults.standard.string(forKey: StorageKeys.accentHex) ?? Self.defaultAccentHex
        self.accentHex = savedHex
    }
}

extension Color {
    public init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6 || cleanHex.count == 8,
              let intVal = UInt64(cleanHex, radix: 16) else {
            return nil
        }
        if cleanHex.count == 6 {
            let r = Double((intVal >> 16) & 0xFF) / 255.0
            let g = Double((intVal >> 8) & 0xFF) / 255.0
            let b = Double(intVal & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b)
        } else {
            let r = Double((intVal >> 24) & 0xFF) / 255.0
            let g = Double((intVal >> 16) & 0xFF) / 255.0
            let b = Double((intVal >> 8) & 0xFF) / 255.0
            let a = Double(intVal & 0xFF) / 255.0
            self.init(red: r, green: g, blue: b, opacity: a)
        }
    }

    public func toHex() -> String {
        #if canImport(UIKit)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb = (Int(r * 255) << 16) | (Int(g * 255) << 8) | Int(b * 255)
        return String(format: "#%06X", rgb)
        #else
        return "#D71921"
        #endif
    }
}

// MARK: - Nothing OS Industrial Design Tokens

@MainActor
public enum NothingPalette {
    /// Deep OLED Black (`#000000`)
    public static let trueBlack = Color(red: 0.0, green: 0.0, blue: 0.0)
    /// Technical Carbon Surface (`#0E0E10`)
    public static let surfacePrimary = Color(red: 0.055, green: 0.055, blue: 0.063)
    /// Elevated Module Surface (`#17171A`)
    public static let surfaceElevated = Color(red: 0.09, green: 0.09, blue: 0.102)
    /// Hairline Grid Border (`#26262B`)
    public static let gridStroke = Color(red: 0.149, green: 0.149, blue: 0.169)
    /// Pure White (`#FFFFFF`)
    public static let pureWhite = Color(red: 1.0, green: 1.0, blue: 1.0)
    /// Technical Silver (`#9E9EA6`)
    public static let mutedGrey = Color(red: 0.62, green: 0.62, blue: 0.65)
    /// Dim Matrix Dot (`#38383F`)
    public static let dimMatrixDot = Color(red: 0.22, green: 0.22, blue: 0.247)
    /// Signature Nothing OS Accent Red (`#D71921`)
    public static let defaultAccentRed = Color(red: 0.843, green: 0.098, blue: 0.129)
    /// Dynamic User Accent Color (Default Nothing Red `#D71921`)
    public static var accentRed: Color {
        ThemeManager.shared.accentColor
    }
}

// MARK: - Nothing OS Typography Modifiers

@MainActor
public enum NothingTypography {
    public static func dotMatrixDisplay(size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .monospaced)
    }

    public static func technicalMono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - 5x7 Dot-Matrix LED Banner Renderer (True Nothing OS Glyph Matrix)

public struct NothingDotMatrixLabel: View {
    public let text: String
    public var dotSize: CGFloat = 3.2
    public var spacing: CGFloat = 1.4
    public var activeColor: Color = NothingPalette.pureWhite
    public var inactiveColor: Color = NothingPalette.dimMatrixDot.opacity(0.28)

    public init(
        text: String,
        dotSize: CGFloat = 3.2,
        spacing: CGFloat = 1.4,
        activeColor: Color = NothingPalette.pureWhite,
        inactiveColor: Color = NothingPalette.dimMatrixDot.opacity(0.28)
    ) {
        self.text = text.uppercased()
        self.dotSize = dotSize
        self.spacing = spacing
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }

    public var body: some View {
        let chars = Array(text)
        let pitch = dotSize + spacing
        let charWidth = 5 * pitch + pitch
        let totalWidth = max(1, CGFloat(chars.count) * charWidth - pitch)
        let totalHeight = 7 * pitch - spacing

        Canvas { context, _ in
            for (cIndex, ch) in chars.enumerated() {
                let bitmap = Self.glyphBitmap(for: ch)
                let xOffset = CGFloat(cIndex) * charWidth

                for row in 0..<7 {
                    let rowBits = bitmap[row]
                    for col in 0..<5 {
                        let isLit = ((rowBits >> (4 - col)) & 1) == 1
                        let rect = CGRect(
                            x: xOffset + CGFloat(col) * pitch,
                            y: CGFloat(row) * pitch,
                            width: dotSize,
                            height: dotSize
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(isLit ? activeColor : inactiveColor)
                        )
                    }
                }
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .accessibilityLabel(text)
    }

    private static func glyphBitmap(for char: Character) -> [UInt8] {
        switch char {
        case "0": return [0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110]
        case "1": return [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110]
        case "2": return [0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111]
        case "3": return [0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110]
        case "4": return [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010]
        case "5": return [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110]
        case "6": return [0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110]
        case "7": return [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000]
        case "8": return [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110]
        case "9": return [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100]
        case "A": return [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001]
        case "B": return [0b11110, 0b10001, 0b10001, 0b11110, 0b10001, 0b10001, 0b11110]
        case "C": return [0b01110, 0b10001, 0b10000, 0b10000, 0b10000, 0b10001, 0b01110]
        case "D": return [0b11100, 0b10010, 0b10001, 0b10001, 0b10001, 0b10010, 0b11100]
        case "E": return [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b11111]
        case "F": return [0b11111, 0b10000, 0b10000, 0b11110, 0b10000, 0b10000, 0b10000]
        case "G": return [0b01110, 0b10001, 0b10000, 0b10111, 0b10001, 0b10001, 0b01110]
        case "H": return [0b10001, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001]
        case "I": return [0b01110, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110]
        case "L": return [0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b10000, 0b11111]
        case "M": return [0b10001, 0b11011, 0b10101, 0b10101, 0b10001, 0b10001, 0b10001]
        case "N": return [0b10001, 0b11001, 0b10101, 0b10011, 0b10001, 0b10001, 0b10001]
        case "O": return [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
        case "P": return [0b11110, 0b10001, 0b10001, 0b11110, 0b10000, 0b10000, 0b10000]
        case "R": return [0b11110, 0b10001, 0b10001, 0b11110, 0b10100, 0b10010, 0b10001]
        case "S": return [0b01111, 0b10000, 0b10000, 0b01110, 0b00001, 0b00001, 0b11110]
        case "T": return [0b11111, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100, 0b00100]
        case "U": return [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110]
        case "V": return [0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01010, 0b00100]
        case "X": return [0b10001, 0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b10001]
        case "Y": return [0b10001, 0b10001, 0b01010, 0b00100, 0b00100, 0b00100, 0b00100]
        case ".": return [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b01100, 0b01100]
        case ":": return [0b00000, 0b01100, 0b01100, 0b00000, 0b01100, 0b01100, 0b00000]
        case "/": return [0b00001, 0b00010, 0b00100, 0b00100, 0b01000, 0b10000, 0b00000]
        case "-": return [0b00000, 0b00000, 0b00000, 0b11111, 0b00000, 0b00000, 0b00000]
        default:  return [0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000, 0b00000]
        }
    }
}

// MARK: - Circular Dot-Matrix Tunnel Radar (Nothing OS Glyph Core + Mini Launch Glow)

public struct NothingGlyphMatrixCore: View {
    public let isConnected: Bool
    public let isTransitioning: Bool
    public var launchPulseTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ignitionStartDate: Date?

    public init(
        isConnected: Bool,
        isTransitioning: Bool,
        launchPulseTrigger: Int = 0
    ) {
        self.isConnected = isConnected
        self.isTransitioning = isTransitioning
        self.launchPulseTrigger = launchPulseTrigger
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !shouldAnimate)) { timeline in
            let now = timeline.date
            let phase = now.timeIntervalSinceReferenceDate
            let ignitionProgress = currentIgnitionProgress(at: now)

            ZStack {
                // Restrained OLED LED diffuser halo behind the dot matrix
                Circle()
                    .fill(
                        RadialGradient(
                            colors: glowColors(phase: phase, ignitionProgress: ignitionProgress),
                            center: .center,
                            startRadius: 2,
                            endRadius: 48
                        )
                    )
                    .scaleEffect(glowScale(phase: phase, ignitionProgress: ignitionProgress))
                    .blur(radius: isTransitioning || ignitionProgress != nil ? 12 : 8)
                    .allowsHitTesting(false)

                Canvas { context, size in
                    let gridCount = 15
                    let cellSize = size.width / CGFloat(gridCount)
                    let center = Double(gridCount - 1) / 2.0

                    // Expanding shockwave ring during launch / connecting
                    let waveRadius: Double?
                    if let ignitionProgress {
                        waveRadius = ignitionProgress * 8.2
                    } else if isTransitioning {
                        let cycle = phase.truncatingRemainder(dividingBy: 1.15) / 1.15
                        waveRadius = cycle * 8.2
                    } else {
                        waveRadius = nil
                    }

                    // Gentle breathing factor when connected
                    let breath = isConnected ? (0.78 + 0.22 * sin(phase * 2.6)) : 1.0
                    let orbitalAngle = phase * 2.2

                    for row in 0..<gridCount {
                        for col in 0..<gridCount {
                            let dx = Double(col) - center
                            let dy = Double(row) - center
                            let distance = sqrt(dx * dx + dy * dy)

                            guard distance <= 7.1 else { continue }

                            let isOuterRing = distance >= 5.8 && distance <= 7.0
                            let isInnerCore = distance <= 2.4
                            let isCrosshair = (row == Int(center) || col == Int(center)) && distance <= 5.2

                            // Radial wave highlight intensity
                            var waveIntensity = 0.0
                            if let waveRadius, !reduceMotion {
                                let delta = abs(distance - waveRadius)
                                if delta < 1.65 {
                                    waveIntensity = 1.0 - (delta / 1.65)
                                }
                            }

                            // Subtle orbital glint dot on outer ring while connected
                            var orbitalBoost = 0.0
                            if isConnected && isOuterRing && !reduceMotion {
                                let angle = atan2(dy, dx)
                                let angleDiff = abs(atan2(sin(angle - orbitalAngle), cos(angle - orbitalAngle)))
                                if angleDiff < 0.45 {
                                    orbitalBoost = 1.0 - (angleDiff / 0.45)
                                }
                            }

                            let dotColor: Color
                            var diameterScale = 1.0

                            if waveIntensity > 0.15 {
                                dotColor = waveIntensity > 0.62
                                    ? NothingPalette.pureWhite
                                    : NothingPalette.accentRed.opacity(0.45 + 0.55 * waveIntensity)
                                diameterScale = 1.0 + 0.24 * waveIntensity
                            } else if isConnected {
                                if isInnerCore {
                                    dotColor = NothingPalette.accentRed.opacity(breath)
                                    diameterScale = 1.0 + 0.1 * breath
                                } else if isOuterRing {
                                    dotColor = NothingPalette.pureWhite.opacity(0.65 + 0.35 * orbitalBoost)
                                    diameterScale = 1.0 + 0.16 * orbitalBoost
                                } else if isCrosshair {
                                    dotColor = NothingPalette.pureWhite.opacity(0.82)
                                } else {
                                    dotColor = NothingPalette.dimMatrixDot.opacity(0.55)
                                }
                            } else if isTransitioning {
                                dotColor = (isOuterRing || isInnerCore)
                                    ? NothingPalette.accentRed.opacity(0.75)
                                    : NothingPalette.dimMatrixDot.opacity(0.38)
                            } else {
                                dotColor = isOuterRing
                                    ? NothingPalette.mutedGrey.opacity(0.45)
                                    : NothingPalette.dimMatrixDot.opacity(0.28)
                            }

                            let dotDiameter = cellSize * 0.54 * diameterScale
                            let rect = CGRect(
                                x: CGFloat(col) * cellSize + (cellSize - dotDiameter) / 2,
                                y: CGFloat(row) * cellSize + (cellSize - dotDiameter) / 2,
                                width: dotDiameter,
                                height: dotDiameter
                            )
                            context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        }
                    }
                }
            }
        }
        .onChange(of: launchPulseTrigger) { _, _ in
            guard !reduceMotion else { return }
            ignitionStartDate = .now
        }
        .onChange(of: isConnected) { oldValue, newValue in
            if !oldValue && newValue && !reduceMotion {
                ignitionStartDate = .now
            }
        }
        .task(id: ignitionStartDate) {
            guard let start = ignitionStartDate else { return }
            try? await Task.sleep(for: .milliseconds(860))
            if ignitionStartDate == start {
                ignitionStartDate = nil
            }
        }
    }

    private var shouldAnimate: Bool {
        if reduceMotion { return false }
        return isConnected || isTransitioning || ignitionStartDate != nil
    }

    private func currentIgnitionProgress(at date: Date) -> Double? {
        guard let start = ignitionStartDate else { return nil }
        let elapsed = date.timeIntervalSince(start)
        let duration = 0.85
        guard elapsed < duration else { return nil }
        return max(0.0, min(1.0, elapsed / duration))
    }

    private func glowColors(phase: TimeInterval, ignitionProgress: Double?) -> [Color] {
        if let ignitionProgress {
            let intensity = sin(ignitionProgress * .pi)
            return [
                NothingPalette.accentRed.opacity(0.55 * intensity),
                NothingPalette.pureWhite.opacity(0.18 * intensity),
                Color.clear
            ]
        } else if isTransitioning {
            let pulse = 0.5 + 0.5 * sin(phase * 5.2)
            return [
                NothingPalette.accentRed.opacity(0.28 + 0.24 * pulse),
                NothingPalette.accentRed.opacity(0.08 * pulse),
                Color.clear
            ]
        } else if isConnected {
            let breath = 0.5 + 0.5 * sin(phase * 2.4)
            return [
                NothingPalette.accentRed.opacity(0.22 + 0.14 * breath),
                NothingPalette.accentRed.opacity(0.05),
                Color.clear
            ]
        } else {
            return [Color.clear, Color.clear]
        }
    }

    private func glowScale(phase: TimeInterval, ignitionProgress: Double?) -> CGFloat {
        if let ignitionProgress {
            return 0.72 + 0.55 * CGFloat(ignitionProgress)
        } else if isTransitioning {
            return 0.9 + 0.18 * CGFloat(sin(phase * 5.2))
        } else if isConnected {
            return 0.96 + 0.06 * CGFloat(sin(phase * 2.4))
        }
        return 0.8
    }
}

// MARK: - Live LED Status Dot with Mini Glow Halo

public struct NothingStatusLEDDot: View {
    public let isConnected: Bool
    public let isTransitioning: Bool

    @State private var pulseExpanded = false

    public init(isConnected: Bool, isTransitioning: Bool) {
        self.isConnected = isConnected
        self.isTransitioning = isTransitioning
    }

    public var body: some View {
        ZStack {
            if isConnected || isTransitioning {
                Circle()
                    .fill(NothingPalette.accentRed.opacity(pulseExpanded ? 0.08 : 0.42))
                    .frame(width: pulseExpanded ? 16 : 9, height: pulseExpanded ? 16 : 9)
                    .blur(radius: 2)
            }

            Circle()
                .fill(isConnected || isTransitioning ? NothingPalette.accentRed : NothingPalette.mutedGrey)
                .frame(width: 7, height: 7)
                .shadow(
                    color: (isConnected || isTransitioning) ? NothingPalette.accentRed.opacity(0.85) : .clear,
                    radius: 4
                )
        }
        .frame(width: 16, height: 16)
        .onAppear {
            updatePulseState()
        }
        .onChange(of: isConnected) { _, _ in
            updatePulseState()
        }
        .onChange(of: isTransitioning) { _, _ in
            updatePulseState()
        }
    }

    private func updatePulseState() {
        if isConnected || isTransitioning {
            withAnimation(.easeInOut(duration: isTransitioning ? 0.55 : 1.4).repeatForever(autoreverses: true)) {
                pulseExpanded = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                pulseExpanded = false
            }
        }
    }
}

// MARK: - Industrial Geometric Container with Corner Crosshairs & Optional Glow

public struct NothingIndustrialCard<Content: View>: View {
    private let isHighlighted: Bool
    private let glowAccent: Bool
    private let customBorderColor: Color?
    private let customAccentCornerColor: Color?
    private let customGlowColor: Color?
    private let content: Content

    public init(
        isHighlighted: Bool = false,
        glowAccent: Bool = false,
        borderColor: Color? = nil,
        accentCornerColor: Color? = nil,
        glowColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isHighlighted = isHighlighted
        self.glowAccent = glowAccent
        self.customBorderColor = borderColor
        self.customAccentCornerColor = accentCornerColor
        self.customGlowColor = glowColor
        self.content = content()
    }

    public var body: some View {
        let theme = ThemeManager.shared
        let accent = theme.accentColor
        let borderColor = customBorderColor ?? (isHighlighted ? NothingPalette.pureWhite : NothingPalette.gridStroke)
        let accentCornerColor = customAccentCornerColor ?? (isHighlighted ? accent : NothingPalette.mutedGrey)
        let glowColor = customGlowColor ?? (glowAccent ? accent.opacity(0.24) : Color.clear)
        let radius = theme.cornerRadius

        Group {
            if radius > 0 {
                content
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: radius)
                            .fill(NothingPalette.surfacePrimary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: radius))
            } else {
                content
                    .padding(16)
                    .background(NothingPalette.surfacePrimary)
                    .overlay(
                        Rectangle()
                            .strokeBorder(borderColor, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        CornerTick(color: accentCornerColor)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        CornerTick(color: accentCornerColor)
                            .rotationEffect(.degrees(180))
                    }
            }
        }
        .shadow(color: glowColor, radius: 14, x: 0, y: 0)
        .animation(.easeInOut(duration: 0.35), value: glowColor)
        .animation(.snappy(duration: 0.22), value: radius)
    }

    private struct CornerTick: View {
        let color: Color
        var body: some View {
            Canvas { context, _ in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: 7))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 7, y: 0))
                context.stroke(path, with: .color(color), lineWidth: 2)
            }
            .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Custom Mechanical Toggle Switch (Replaces UIKit/SwiftUI Toggle)

public struct NothingMechanicalSwitch: View {
    @Binding public var isOn: Bool
    public let label: String

    public init(label: String, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }

    public var body: some View {
        let theme = ThemeManager.shared
        let accent = theme.accentColor
        let isRounded = theme.isRoundedCorners

        Button {
            withAnimation(.snappy(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(NothingTypography.technicalMono(size: 12, weight: .semibold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .tracking(1.1)

                Spacer()

                ZStack(alignment: isOn ? .trailing : .leading) {
                    if isRounded {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(isOn ? accent.opacity(0.22) : NothingPalette.trueBlack)
                            .frame(width: 52, height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 13)
                                    .strokeBorder(isOn ? accent : NothingPalette.gridStroke, lineWidth: 1)
                            )

                        RoundedRectangle(cornerRadius: 10)
                            .fill(isOn ? accent : NothingPalette.mutedGrey)
                            .frame(width: 22, height: 20)
                            .padding(.horizontal, 3)
                    } else {
                        Rectangle()
                            .fill(isOn ? accent.opacity(0.22) : NothingPalette.trueBlack)
                            .frame(width: 52, height: 26)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(isOn ? accent : NothingPalette.gridStroke, lineWidth: 1)
                            )

                        Rectangle()
                            .fill(isOn ? accent : NothingPalette.mutedGrey)
                            .frame(width: 22, height: 20)
                            .padding(.horizontal, 3)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "ON" : "OFF")
    }
}

// MARK: - Custom 2-Tab Navigation Bar (Servers / Settings)

public enum NothingNavigationTab: String, CaseIterable, Sendable {
    case servers
    case settings
}

public struct NothingBottomTabBar: View {
    @Binding public var activeTab: NothingNavigationTab
    public let serversTitle: String
    public let settingsTitle: String
    public let isTunnelActive: Bool

    public var body: some View {
        HStack(spacing: 0) {
            tabButton(
                tab: .servers,
                indexCode: "01",
                title: serversTitle,
                showLiveDot: isTunnelActive
            )

            Rectangle()
                .fill(NothingPalette.gridStroke)
                .frame(width: 1, height: 58)

            tabButton(
                tab: .settings,
                indexCode: "02",
                title: settingsTitle,
                showLiveDot: false
            )
        }
        .frame(height: 58)
        .background(NothingPalette.trueBlack)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NothingPalette.gridStroke)
                .frame(height: 1)
        }
    }

    private func tabButton(
        tab: NothingNavigationTab,
        indexCode: String,
        title: String,
        showLiveDot: Bool
    ) -> some View {
        let isSelected = activeTab == tab
        return Button {
            withAnimation(.snappy(duration: 0.16)) {
                activeTab = tab
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("[\(indexCode)]")
                        .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                        .foregroundStyle(isSelected ? NothingPalette.accentRed : NothingPalette.mutedGrey)

                    if showLiveDot {
                        Circle()
                            .fill(NothingPalette.accentRed)
                            .frame(width: 6, height: 6)
                    }

                    Spacer()

                    Rectangle()
                        .fill(isSelected ? NothingPalette.pureWhite : Color.clear)
                        .frame(width: 16, height: 2)
                }

                Text(title)
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                    .tracking(1.6)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isSelected ? NothingPalette.surfacePrimary : NothingPalette.trueBlack)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
