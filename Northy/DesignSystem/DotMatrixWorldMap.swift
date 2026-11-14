import SwiftUI

// MARK: - Dot Matrix World Map (Nothing OS Industrial Aesthetic)

public struct DotMatrixWorldMap: View {
    let connectedCountryISO: String?
    let accentColor: Color
    let isConnected: Bool

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero

    private let cols = 100
    private let rows = 55

    public init(
        connectedCountryISO: String?,
        accentColor: Color,
        isConnected: Bool
    ) {
        self.connectedCountryISO = connectedCountryISO
        self.accentColor = accentColor
        self.isConnected = isConnected
    }

    public var body: some View {
        GeometryReader { geo in
            let fitCellW = geo.size.width / CGFloat(cols)
            let fitCellH = geo.size.height / CGFloat(rows)
            let cellDim = min(fitCellW, fitCellH)
            let dotDiameter = max(1.8, cellDim * 0.72)
            let totalW = cellDim * CGFloat(cols)
            let totalH = cellDim * CGFloat(rows)
            let baseOffsetX = (geo.size.width - totalW) / 2
            let baseOffsetY = (geo.size.height - totalH) / 2

            ZStack {
                Canvas { context, size in
                    let ox = baseOffsetX + panOffset.width
                    let oy = baseOffsetY + panOffset.height

                    let highlightBounds: (lonMin: Double, lonMax: Double, latMin: Double, latMax: Double)?
                    if let iso = connectedCountryISO {
                        highlightBounds = Self.countryBounds(iso: iso)
                    } else {
                        highlightBounds = nil
                    }

                    for row in 0..<rows {
                        for col in 0..<cols {
                            guard Self.isLand(col: col, row: row) else { continue }

                            let localX = CGFloat(col) * cellDim
                            let localY = CGFloat(row) * cellDim

                            // Apply zoom & pan around center
                            let x = (localX - totalW / 2) * zoomScale + totalW / 2 + ox
                            let y = (localY - totalH / 2) * zoomScale + totalH / 2 + oy

                            let isHighlighted: Bool
                            if let bounds = highlightBounds, isConnected {
                                let lon = Double(col) * 3.6 - 180.0
                                let lat = 90.0 - Double(row) * (180.0 / 54.0)
                                isHighlighted = lon >= bounds.lonMin && lon <= bounds.lonMax &&
                                                lat >= bounds.latMin && lat <= bounds.latMax
                            } else {
                                isHighlighted = false
                            }

                            let d = (isHighlighted ? dotDiameter * 1.2 : dotDiameter) * zoomScale
                            let rect = CGRect(x: x, y: y, width: d, height: d)

                            let dotColor: Color
                            if isHighlighted {
                                dotColor = accentColor
                            } else if isConnected {
                                dotColor = NothingPalette.mutedGrey.opacity(0.3)
                            } else {
                                dotColor = NothingPalette.pureWhite.opacity(0.85)
                            }

                            context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        }
                    }
                }

                // 4 Corner brackets matching reference image
                cornerBracketsLayer
            }
            .onAppear {
                updateCamera(size: geo.size, totalW: totalW, totalH: totalH, baseOX: baseOffsetX, baseOY: baseOffsetY, cellDim: cellDim)
            }
            .onChange(of: isConnected) { _, _ in
                withAnimation(.spring(response: 0.8, dampingFraction: 0.76)) {
                    updateCamera(size: geo.size, totalW: totalW, totalH: totalH, baseOX: baseOffsetX, baseOY: baseOffsetY, cellDim: cellDim)
                }
            }
            .onChange(of: connectedCountryISO) { _, _ in
                if isConnected {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.76)) {
                        updateCamera(size: geo.size, totalW: totalW, totalH: totalH, baseOX: baseOffsetX, baseOY: baseOffsetY, cellDim: cellDim)
                    }
                }
            }
        }
        .background(NothingPalette.trueBlack)
        .clipped()
    }

    private func updateCamera(size: CGSize, totalW: CGFloat, totalH: CGFloat, baseOX: CGFloat, baseOY: CGFloat, cellDim: CGFloat) {
        if isConnected, let iso = connectedCountryISO, let bounds = Self.countryBounds(iso: iso) {
            let lonCenter = (bounds.lonMin + bounds.lonMax) / 2
            let latCenter = (bounds.latMin + bounds.latMax) / 2
            let col = (lonCenter + 180.0) / 3.6
            let row = (90.0 - latCenter) / (180.0 / 54.0)

            let targetX = CGFloat(col) * cellDim
            let targetY = CGFloat(row) * cellDim

            zoomScale = 2.4
            panOffset = CGSize(
                width: -(targetX - totalW / 2) * 2.4,
                height: -(targetY - totalH / 2) * 2.4
            )
        } else {
            zoomScale = 1.0
            panOffset = .zero
        }
    }

    // MARK: - Corner Bracket Framing Layer

    private var cornerBracketsLayer: some View {
        ZStack {
            cornerBracket(armX: 1, armY: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(6)

            cornerBracket(armX: -1, armY: 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(6)

            cornerBracket(armX: 1, armY: -1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(6)

            cornerBracket(armX: -1, armY: -1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(6)
        }
        .allowsHitTesting(false)
    }

    private func cornerBracket(armX: CGFloat, armY: CGFloat) -> some View {
        Canvas { context, _ in
            let arm: CGFloat = 12
            var path = Path()
            let origin = CGPoint(x: armX > 0 ? 0 : arm, y: armY > 0 ? 0 : arm)
            let hEnd = CGPoint(x: armX > 0 ? arm : 0, y: armY > 0 ? 0 : arm)
            let vEnd = CGPoint(x: armX > 0 ? 0 : arm, y: armY > 0 ? arm : 0)

            path.move(to: hEnd)
            path.addLine(to: origin)
            path.addLine(to: vEnd)

            context.stroke(path, with: .color(NothingPalette.pureWhite.opacity(0.8)), lineWidth: 1.5)
        }
        .frame(width: 12, height: 12)
    }

    // MARK: - Land Detection

    static func isLand(col: Int, row: Int) -> Bool {
        let lon = Double(col) * 3.6 - 180.0
        let lat = 90.0 - Double(row) * (180.0 / 54.0)

        // North America
        if lon >= -168 && lon <= -52 && lat >= 7 && lat <= 73 {
            if lat >= 25 { return true }
            if lon >= -120 && lon <= -52 && lat >= 7 { return true }
        }
        // Greenland
        if lon >= -56 && lon <= -17 && lat >= 60 && lat <= 84 { return true }
        // South America
        if lon >= -82 && lon <= -34 && lat >= -56 && lat <= 12 { return true }
        // Europe (including UK)
        if lon >= -11 && lon <= 40 && lat >= 36 && lat <= 71 { return true }
        if lon >= -6 && lon <= 2 && lat >= 50 && lat <= 60 { return true }
        // Africa
        if lon >= -18 && lon <= 52 && lat >= -35 && lat <= 37 {
            if !(lon >= 42 && lat >= 11) { return true }
        }
        // Middle East / Arabian Peninsula
        if lon >= 32 && lon <= 60 && lat >= 12 && lat <= 38 { return true }
        // Russia / Asia (northern)
        if lon >= 28 && lon <= 180 && lat >= 50 && lat <= 77 { return true }
        if lon >= -180 && lon <= -163 && lat >= 60 && lat <= 72 { return true }
        // Central/South Asia
        if lon >= 60 && lon <= 150 && lat >= 10 && lat <= 55 { return true }
        // Southeast Asia / Indonesia
        if lon >= 95 && lon <= 141 && lat >= -10 && lat <= 20 { return true }
        if lon >= 100 && lon <= 120 && lat >= -8 && lat <= -1 { return true }
        if lon >= 108 && lon <= 118 && lat >= -8 && lat <= -6 { return true }
        if lon >= 115 && lon <= 141 && lat >= -10 && lat <= 0 { return true }
        // Japan
        if lon >= 130 && lon <= 145 && lat >= 30 && lat <= 45 { return true }
        // Australia
        if lon >= 114 && lon <= 154 && lat >= -39 && lat <= -14 { return true }
        // New Zealand
        if lon >= 166 && lon <= 178 && lat >= -46 && lat <= -34 { return true }
        // Iceland
        if lon >= -24 && lon <= -13 && lat >= 63 && lat <= 67 { return true }
        // Scandinavia
        if lon >= 4 && lon <= 32 && lat >= 55 && lat <= 72 { return true }
        // Madagascar
        if lon >= 43 && lon <= 50 && lat >= -26 && lat <= -12 { return true }

        return false
    }

    // MARK: - Country Bounding Boxes

    static func countryBounds(iso: String) -> (lonMin: Double, lonMax: Double, latMin: Double, latMax: Double)? {
        switch iso.uppercased() {
        case "US": return (-125, -66, 24, 50)
        case "RU": return (28, 180, 50, 77)
        case "DE": return (6, 15, 47, 55)
        case "FR": return (-5, 8, 42, 51)
        case "GB", "UK": return (-8, 2, 50, 59)
        case "JP": return (130, 145, 30, 45)
        case "CN": return (73, 135, 18, 54)
        case "IN": return (68, 97, 8, 36)
        case "BR": return (-74, -34, -34, 5)
        case "AU": return (114, 154, -39, -14)
        case "CA": return (-140, -52, 42, 73)
        case "NL": return (3, 7, 51, 54)
        case "SE": return (11, 24, 55, 70)
        case "FI": return (19, 32, 59, 70)
        case "PL": return (14, 24, 49, 55)
        case "TR": return (26, 45, 36, 43)
        case "SG": return (103, 104, 1, 2)
        case "KZ": return (50, 87, 40, 56)
        default: return nil
        }
    }
}
