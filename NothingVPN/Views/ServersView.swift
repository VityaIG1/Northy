import SwiftUI

// MARK: - Tab 01: SERVERS (Paste-to-Connect, Tunnel Core, Uptime Timer, Live Speed & Volume, Ping Matrix)

public struct ServersView: View {
    @Bindable var vpnManager: VPNTunnelManager
    let localization: LocalizationManager

    @State private var launchPulseCount: Int = 0
    @State private var shimmerPhase: CGFloat = -1.0

    public init(vpnManager: VPNTunnelManager, localization: LocalizationManager) {
        self.vpnManager = vpnManager
        self.localization = localization
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerStatusStrip
                tunnelCoreActivationWidget
                sessionUptimeAndTrafficSection
                pasteToConnectModule
                if let banner = vpnManager.statusBannerMessage {
                    diagnosticBanner(banner)
                }
                configuredNodesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(NothingPalette.trueBlack)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.8), trigger: vpnManager.isConnected)
    }

    // MARK: - 1. Dot-Matrix Header & Live Status Strip

    private var headerStatusStrip: some View {
        HStack(alignment: .center) {
            NothingDotMatrixLabel(
                text: "NOTHING VPN",
                dotSize: 2.8,
                spacing: 1.2,
                activeColor: NothingPalette.pureWhite
            )

            Spacer()

            HStack(spacing: 4) {
                NothingStatusLEDDot(
                    isConnected: vpnManager.isConnected,
                    isTransitioning: vpnManager.isTransitioning
                )

                Text(statusHeadlineText)
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(vpnManager.isConnected || vpnManager.isTransitioning ? NothingPalette.accentRed : NothingPalette.mutedGrey)
                    .tracking(1.2)
            }
        }
    }

    // MARK: - 2. Primary Tunnel Core Activation Widget

    private var tunnelCoreActivationWidget: some View {
        NothingIndustrialCard(
            isHighlighted: vpnManager.isConnected || vpnManager.isTransitioning,
            glowAccent: vpnManager.isConnected || vpnManager.isTransitioning
        ) {
            VStack(spacing: 16) {
                HStack(alignment: .center, spacing: 18) {
                    NothingGlyphMatrixCore(
                        isConnected: vpnManager.isConnected,
                        isTransitioning: vpnManager.isTransitioning,
                        launchPulseTrigger: launchPulseCount
                    )
                    .frame(width: 96, height: 96)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACTIVE NODE // XRAY-CORE")
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.mutedGrey)
                            .tracking(1.2)

                        Text(vpnManager.selectedNode?.remark ?? "NONE")
                            .font(NothingTypography.technicalMono(size: 15, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .lineLimit(1)

                        if let node = vpnManager.selectedNode {
                            Text("\(node.protocolType.badgeLabel) · \(node.transportBadge)")
                                .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                                .foregroundStyle(NothingPalette.accentRed)

                            Text(node.endpointDisplay)
                                .font(NothingTypography.technicalMono(size: 11, weight: .regular))
                                .foregroundStyle(NothingPalette.mutedGrey)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }

                // Mechanical Trigger Button with Mini Launch Glow
                Button {
                    launchPulseCount += 1
                    triggerButtonGlowSweep()
                    Task {
                        await vpnManager.toggleTunnelConnection()
                    }
                } label: {
                    HStack {
                        Text(vpnManager.isConnected ? localization.tr("action.disconnect") : localization.tr("action.connect"))
                            .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                            .tracking(2.0)

                        Spacer()

                        Text(vpnManager.isConnected ? "[STOP]" : (vpnManager.isTransitioning ? "[INIT]" : "[RUN]"))
                            .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .foregroundStyle(vpnManager.isConnected ? NothingPalette.pureWhite : NothingPalette.trueBlack)
                    .background(vpnManager.isConnected ? NothingPalette.accentRed : NothingPalette.pureWhite)
                    .overlay {
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    NothingPalette.accentRed.opacity(vpnManager.isConnected ? 0.55 : 0.35),
                                    NothingPalette.pureWhite.opacity(0.65),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 0.45)
                            .offset(x: shimmerPhase * geo.size.width)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                        }
                        .clipped()
                    }
                    .shadow(
                        color: vpnManager.isConnected ? NothingPalette.accentRed.opacity(0.45) : Color.clear,
                        radius: 10,
                        x: 0,
                        y: 0
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 3. Active VPN Uptime Timer & Live KB/MB Speed + Session Traffic (Directly Under Button)

    private var sessionUptimeAndTrafficSection: some View {
        VStack(spacing: 10) {
            // 3A. Live Session Uptime Timer Bar (Directly under the VPN button)
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let uptimeString = Self.formatUptime(
                    since: vpnManager.connectedSince,
                    now: context.date,
                    isConnected: vpnManager.isConnected
                )

                NothingIndustrialCard(isHighlighted: vpnManager.isConnected) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("// \(localization.tr("telemetry.uptime"))")
                                .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                .foregroundStyle(NothingPalette.mutedGrey)
                                .tracking(1.2)

                            Text(vpnManager.isConnected ? "LIVE TUNNEL SESSION" : "TUNNEL IDLE // 00:00:00")
                                .font(NothingTypography.technicalMono(size: 9, weight: .regular))
                                .foregroundStyle(vpnManager.isConnected ? NothingPalette.accentRed : NothingPalette.dimMatrixDot)
                                .tracking(1.0)
                        }

                        Spacer()

                        NothingDotMatrixLabel(
                            text: uptimeString,
                            dotSize: 2.6,
                            spacing: 1.1,
                            activeColor: vpnManager.isConnected ? NothingPalette.pureWhite : NothingPalette.mutedGrey
                        )
                    }
                }
            }

            // 3B. Live Throughput Speed (KB/S, MB/S) & Session Volume (Downloaded, Uploaded, Total)
            NothingIndustrialCard(isHighlighted: vpnManager.isConnected) {
                VStack(spacing: 12) {
                    // Top Row: Real-Time Download & Upload Speed (KB/S or MB/S)
                    HStack(spacing: 12) {
                        speedMetricBlock(
                            arrowSymbol: "↓",
                            title: localization.tr("telemetry.speed.down"),
                            value: Self.formatTransferRate(vpnManager.rxSpeedBytesPerSec),
                            isActive: vpnManager.isConnected,
                            accentColor: NothingPalette.pureWhite
                        )

                        Rectangle()
                            .fill(NothingPalette.gridStroke)
                            .frame(width: 1, height: 38)

                        speedMetricBlock(
                            arrowSymbol: "↑",
                            title: localization.tr("telemetry.speed.up"),
                            value: Self.formatTransferRate(vpnManager.txSpeedBytesPerSec),
                            isActive: vpnManager.isConnected,
                            accentColor: NothingPalette.accentRed
                        )
                    }

                    Rectangle()
                        .fill(NothingPalette.gridStroke)
                        .frame(height: 1)

                    // Bottom Row: Cumulative Session Volume (Downloaded / Uploaded / Total in KB, MB, GB)
                    HStack(spacing: 8) {
                        volumeMetricColumn(
                            label: localization.tr("telemetry.down"),
                            value: Self.formatByteCount(vpnManager.telemetry.rxBytes),
                            isActive: vpnManager.isConnected
                        )

                        Rectangle()
                            .fill(NothingPalette.gridStroke)
                            .frame(width: 1, height: 30)

                        volumeMetricColumn(
                            label: localization.tr("telemetry.up"),
                            value: Self.formatByteCount(vpnManager.telemetry.txBytes),
                            isActive: vpnManager.isConnected
                        )

                        Rectangle()
                            .fill(NothingPalette.gridStroke)
                            .frame(width: 1, height: 30)

                        volumeMetricColumn(
                            label: localization.tr("telemetry.total"),
                            value: Self.formatByteCount(vpnManager.totalSessionBytes),
                            isActive: vpnManager.isConnected
                        )
                    }
                }
            }
        }
    }

    private func speedMetricBlock(
        arrowSymbol: String,
        title: String,
        value: String,
        isActive: Bool,
        accentColor: Color
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Rectangle()
                    .fill(isActive ? accentColor.opacity(0.16) : NothingPalette.surfaceElevated)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Rectangle()
                            .strokeBorder(isActive ? accentColor : NothingPalette.gridStroke, lineWidth: 1)
                    )

                Text(arrowSymbol)
                    .font(NothingTypography.technicalMono(size: 13, weight: .black))
                    .foregroundStyle(isActive ? accentColor : NothingPalette.mutedGrey)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(NothingTypography.technicalMono(size: 9, weight: .semibold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                    .tracking(0.9)

                Text(value)
                    .font(NothingTypography.dotMatrixDisplay(size: 15))
                    .foregroundStyle(isActive ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func volumeMetricColumn(label: String, value: String, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(NothingTypography.technicalMono(size: 9, weight: .regular))
                .foregroundStyle(NothingPalette.mutedGrey)
                .lineLimit(1)

            Text(value)
                .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                .foregroundStyle(isActive ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func triggerButtonGlowSweep() {
        shimmerPhase = -0.6
        withAnimation(.easeInOut(duration: 0.65)) {
            shimmerPhase = 1.2
        }
    }

    // MARK: - 4. One-Click Paste-to-Connect Module (Happ Workflow)

    private var pasteToConnectModule: some View {
        Button {
            launchPulseCount += 1
            triggerButtonGlowSweep()
            Task {
                await vpnManager.pasteFromClipboardAndConnect()
            }
        } label: {
            NothingIndustrialCard(isHighlighted: false) {
                HStack(spacing: 14) {
                    ZStack {
                        Rectangle()
                            .fill(NothingPalette.accentRed)
                            .frame(width: 40, height: 40)

                        Text("⌘V")
                            .font(NothingTypography.technicalMono(size: 14, weight: .black))
                            .foregroundStyle(NothingPalette.pureWhite)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(localization.tr("paste.button"))
                            .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .tracking(1.4)

                        Text(localization.tr("paste.subtitle"))
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.mutedGrey)
                            .tracking(0.8)
                    }

                    Spacer()

                    Text("+")
                        .font(NothingTypography.technicalMono(size: 20, weight: .bold))
                        .foregroundStyle(NothingPalette.accentRed)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func diagnosticBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(NothingPalette.accentRed)
                .frame(width: 3, height: 28)

            Text(message)
                .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                .foregroundStyle(NothingPalette.pureWhite)
                .lineLimit(2)

            Spacer()

            Button {
                vpnManager.statusBannerMessage = nil
            } label: {
                Text("[X]")
                    .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NothingPalette.surfaceElevated)
        .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
    }

    // MARK: - 5. Server Nodes List with Dot-Matrix Ping Bars

    private var configuredNodesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("// \(localization.tr("servers.section.nodes")) [\(vpnManager.nodes.count)] · \(vpnManager.pingSettings.method.shortTag)")
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                    .tracking(1.2)

                Spacer()

                Button {
                    Task {
                        await vpnManager.measureAllNodeLatencies()
                    }
                } label: {
                    Text(vpnManager.isPingingAll ? "[PINGING...]" : "[\(localization.tr("servers.ping.all"))]")
                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                        .foregroundStyle(NothingPalette.accentRed)
                }
                .buttonStyle(.plain)
            }

            ForEach(vpnManager.nodes) { node in
                nodeRowCard(node)
            }
        }
    }

    private func nodeRowCard(_ node: ProxyNode) -> some View {
        let isSelected = vpnManager.selectedNode?.id == node.id
        return Button {
            vpnManager.selectNode(node.id)
        } label: {
            NothingIndustrialCard(isHighlighted: isSelected) {
                HStack(spacing: 12) {
                    // Selection Matrix Indicator
                    Rectangle()
                        .fill(isSelected ? NothingPalette.accentRed : NothingPalette.gridStroke)
                        .frame(width: 4, height: 42)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(node.protocolType.badgeLabel)
                                .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)

                            Text(node.remark)
                                .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                                .foregroundStyle(NothingPalette.pureWhite)
                                .lineLimit(1)
                        }

                        Text("\(node.endpointDisplay) // \(node.transportBadge)")
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.mutedGrey)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Dot-Matrix Ping Indicator (Happ Display Mode Aware)
                    pingIndicatorView(latencyMs: node.latencyMs)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                vpnManager.deleteNode(node.id)
            } label: {
                Text("DELETE NODE")
            }
        }
    }

    private func pingIndicatorView(latencyMs: Int?) -> some View {
        VStack(alignment: .trailing, spacing: 5) {
            if vpnManager.pingSettings.displayMode == .millisecondsAndBars {
                if let latencyMs {
                    Text("\(latencyMs) MS")
                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                        .foregroundStyle(latencyMs < 80 ? NothingPalette.pureWhite : NothingPalette.accentRed)
                } else {
                    Text("-- MS")
                        .font(NothingTypography.technicalMono(size: 11, weight: .regular))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<4, id: \.self) { bar in
                    let isLit = Self.isSignalBarLit(barIndex: bar, latencyMs: latencyMs)
                    Rectangle()
                        .fill(isLit ? NothingPalette.pureWhite : NothingPalette.dimMatrixDot)
                        .frame(width: 3, height: CGFloat(4 + bar * 3))
                }
            }
        }
    }

    // MARK: - Formatting Helpers

    private var statusHeadlineText: String {
        switch vpnManager.connectionStatus {
        case .connected:
            return localization.tr("status.connected")
        case .connecting, .reasserting:
            return localization.tr("status.connecting")
        default:
            return localization.tr("status.disconnected")
        }
    }

    private static func formatUptime(since startDate: Date?, now: Date, isConnected: Bool) -> String {
        guard isConnected, let startDate else {
            return "00:00:00"
        }
        let elapsed = max(0, Int(now.timeIntervalSince(startDate)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func formatTransferRate(_ bytesPerSec: UInt64) -> String {
        let kb = Double(bytesPerSec) / 1024.0
        if kb < 1000.0 {
            return String(format: "%.1f KB/S", kb)
        }
        let mb = kb / 1024.0
        return String(format: "%.2f MB/S", mb)
    }

    private static func isSignalBarLit(barIndex: Int, latencyMs: Int?) -> Bool {
        guard let latencyMs else { return false }
        switch latencyMs {
        case ..<45: return true
        case 45..<95: return barIndex < 3
        case 95..<180: return barIndex < 2
        default: return barIndex < 1
        }
    }

    private static func formatByteCount(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024.0
        if mb < 1024.0 {
            return String(format: "%.2f MB", mb)
        }
        let gb = mb / 1024.0
        return String(format: "%.2f GB", gb)
    }
}
