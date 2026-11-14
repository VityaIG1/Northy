import SwiftUI
import UIKit

// MARK: - Nothing OS Secret Tunnel Diagnostics & Live Streaming Log Console

public struct TunnelDiagnosticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let vpnManager: VPNTunnelManager
    public let localization: LocalizationManager

    @State private var theme = ThemeManager.shared
    @State private var logLines: [String] = []
    @State private var isRunningTest: Bool = false
    @State private var testResult: String?
    @State private var copiedRecently: Bool = false
    @State private var autoScroll: Bool = true
    @State private var timerTask: Task<Void, Never>?

    public init(vpnManager: VPNTunnelManager, localization: LocalizationManager) {
        self.vpnManager = vpnManager
        self.localization = localization
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                NothingPalette.trueBlack.ignoresSafeArea()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            // 1. Header Metrics Card
                            statusOverviewCard

                            // 2. Network Interface & Tunnel Routing Card
                            routingTopologyCard

                            // 3. Diagnostic Action Toolbar
                            actionButtonsBar

                            // 4. Test Results Banner
                            if let testResult {
                                testResultBanner(testResult)
                            }

                            // 5. Live Streaming Log Terminal
                            terminalConsole(proxy: proxy)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("DIAGNOSTICS // LOGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(NothingPalette.mutedGrey)
                    }
                }
            }
        }
        .task {
            SharedTunnelLogger.log("Diagnostics console active. VPN state: \(vpnManager.connectionStatus)", tag: "DIAG")
            refreshLogs()
            startPeriodicRefresh()
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
        }
    }

    // MARK: - 1. Status Overview Card

    private var statusOverviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("// STATUS & TELEMETRY")
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                Spacer()
                statusPill
            }

            Divider().background(NothingPalette.gridStroke)

            HStack(spacing: 16) {
                metricItem(label: "CORE STATUS", value: vpnManager.telemetry.coreStatus)
                metricItem(label: "RX SPEED", value: formatSpeed(vpnManager.rxSpeedBytesPerSec))
                metricItem(label: "TX SPEED", value: formatSpeed(vpnManager.txSpeedBytesPerSec))
            }

            if let node = vpnManager.selectedNode {
                Divider().background(NothingPalette.gridStroke)
                HStack(spacing: 8) {
                    Text("ACTIVE NODE:")
                        .font(NothingTypography.technicalMono(size: 11, weight: .semibold))
                        .foregroundStyle(NothingPalette.mutedGrey)
                    Text("\(node.remark) [\(node.serverHost):\(node.serverPort)]")
                        .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                        .foregroundStyle(NothingPalette.pureWhite)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(NothingPalette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NothingPalette.gridStroke, lineWidth: 1))
    }

    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                .foregroundStyle(NothingPalette.mutedGrey)
            Text(value)
                .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                .foregroundStyle(NothingPalette.pureWhite)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(vpnManager.isConnected ? theme.accentColor : (vpnManager.isTransitioning ? Color.orange : NothingPalette.mutedGrey))
                .frame(width: 7, height: 7)
            Text(statusString)
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .foregroundStyle(vpnManager.isConnected ? theme.accentColor : NothingPalette.pureWhite)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(NothingPalette.surfacePrimary)
        .clipShape(Capsule())
    }

    private var statusString: String {
        switch vpnManager.connectionStatus {
        case .connected: return "CONNECTED"
        case .connecting: return "CONNECTING"
        case .disconnecting: return "DISCONNECTING"
        case .reasserting: return "REASSERTING"
        case .invalid: return "INVALID"
        case .disconnected: return "DISCONNECTED"
        @unknown default: return "UNKNOWN"
        }
    }

    // MARK: - 2. Routing Topology Card

    private var routingTopologyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("// INTERFACE & ROUTING TOPOLOGY")
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .foregroundStyle(NothingPalette.mutedGrey)

            Divider().background(NothingPalette.gridStroke)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    topoKey("TUN IPV4")
                    topoVal("198.18.0.1 / 15")
                    topoKey("TUN IPV6")
                    topoVal("fd00::1 / 126")
                }
                GridRow {
                    topoKey("MTU")
                    topoVal("\(vpnManager.connectionSettings.tunMTU)")
                    topoKey("ROUTING")
                    topoVal(vpnManager.routingConfig.routingMode.displayName.uppercased())
                }
                GridRow {
                    topoKey("SOCKS5")
                    topoVal("127.0.0.1:10808")
                    topoKey("HTTP PROXY")
                    topoVal("127.0.0.1:10809")
                }
                GridRow {
                    topoKey("DNS ENGINE")
                    topoVal("198.18.0.2:53 -> 10853")
                    topoKey("FALLBACK")
                    topoVal("1.1.1.1:53 (UDP)")
                }
            }
        }
        .padding(14)
        .background(NothingPalette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NothingPalette.gridStroke, lineWidth: 1))
    }

    private func topoKey(_ text: String) -> some View {
        Text(text)
            .font(NothingTypography.technicalMono(size: 10, weight: .bold))
            .foregroundStyle(NothingPalette.mutedGrey)
    }

    private func topoVal(_ text: String) -> some View {
        Text(text)
            .font(NothingTypography.technicalMono(size: 11, weight: .regular))
            .foregroundStyle(NothingPalette.pureWhite)
            .lineLimit(1)
    }

    // MARK: - 3. Action Toolbar

    private var actionButtonsBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Copy Logs Button
                Button(action: copyLogsToClipboard) {
                    HStack(spacing: 6) {
                        Image(systemName: copiedRecently ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .bold))
                        Text(copiedRecently ? "COPIED" : "COPY LOGS")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(NothingPalette.surfacePrimary)
                    .foregroundStyle(copiedRecently ? theme.accentColor : NothingPalette.pureWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(NothingPalette.gridStroke, lineWidth: 1))
                }

                // Export / Share Logs Button
                let logURL = SharedTunnelLogger.exportLogURL()
                ShareLink(item: logURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .bold))
                        Text("EXPORT")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(NothingPalette.surfacePrimary)
                    .foregroundStyle(NothingPalette.pureWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(NothingPalette.gridStroke, lineWidth: 1))
                }

                // Clear Logs Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    SharedTunnelLogger.clearLogs()
                    refreshLogs()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                        Text("CLEAR")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(NothingPalette.surfacePrimary)
                    .foregroundStyle(NothingPalette.pureWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(NothingPalette.gridStroke, lineWidth: 1))
                }
            }

            HStack(spacing: 8) {
                // Test Tunnel & Public IP Button
                Button(action: runDiagnosticsTest) {
                    HStack(spacing: 6) {
                        if isRunningTest {
                            ProgressView()
                                .tint(NothingPalette.pureWhite)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "network")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(isRunningTest ? "TESTING..." : "TEST TUNNEL & IP/DNS")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(NothingPalette.surfacePrimary)
                    .foregroundStyle(theme.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.accentColor.opacity(0.5), lineWidth: 1))
                }
                .disabled(isRunningTest)

                // Force Restart Tunnel Button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    Task {
                        await vpnManager.restartTunnelWithActiveNode()
                        refreshLogs()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                        Text("RESTART TUNNEL")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(NothingPalette.surfacePrimary)
                    .foregroundStyle(NothingPalette.pureWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(NothingPalette.gridStroke, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - 4. Test Results Banner

    private func testResultBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.accentColor)
            Text(text)
                .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                .foregroundStyle(NothingPalette.pureWhite)
            Spacer()
            Button(action: { testResult = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
            }
        }
        .padding(10)
        .background(NothingPalette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.accentColor.opacity(0.4), lineWidth: 1))
    }

    // MARK: - 5. Live Streaming Log Terminal

    private func terminalConsole(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("// REAL-TIME EXTENSION LOG STREAM (\(logLines.count) LINES)")
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                Spacer()
                Button(action: { autoScroll.toggle() }) {
                    Text(autoScroll ? "AUTO-SCROLL ON" : "AUTO-SCROLL OFF")
                        .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                        .foregroundStyle(autoScroll ? theme.accentColor : NothingPalette.mutedGrey)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(logLines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                        .foregroundStyle(colorForLogLine(line))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(NothingPalette.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(NothingPalette.gridStroke, lineWidth: 1))
        }
        .onChange(of: logLines.count) { _, _ in
            if autoScroll, !logLines.isEmpty {
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(logLines.count - 1, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Helpers & Actions

    private func colorForLogLine(_ line: String) -> Color {
        if line.contains("[ERROR]") {
            return theme.accentColor
        } else if line.contains("[TUNNEL]") {
            return NothingPalette.pureWhite
        } else if line.contains("[CORE]") {
            return Color.yellow.opacity(0.85)
        } else if line.contains("[BRIDGE]") || line.contains("[SOCKS]") {
            return Color.cyan.opacity(0.85)
        } else {
            return NothingPalette.mutedGrey
        }
    }

    private func refreshLogs() {
        let lines = SharedTunnelLogger.readLogs()
        if lines != self.logLines {
            self.logLines = lines
        }
    }

    private func startPeriodicRefresh() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                refreshLogs()
            }
        }
    }

    private func copyLogsToClipboard() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let full = SharedTunnelLogger.readFullLogString()
        UIPasteboard.general.string = full
        copiedRecently = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedRecently = false
        }
    }

    private func runDiagnosticsTest() {
        isRunningTest = true
        testResult = nil
        Task {
            let start = Date()
            var ipString: String?
            var latencyMs: Int?

            // Test outbound ping latency
            if let latency = await vpnManager.measureActiveTunnelLatency() {
                latencyMs = latency
            }

            // Test public IP resolution via ephemeral session
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 3.5
            let session = URLSession(configuration: config)

            if let url = URL(string: "https://api.ipify.org") {
                if let (data, resp) = try? await session.data(from: url),
                   let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200,
                   let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    ipString = body
                }
            }

            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            let latencyReport = latencyMs != nil ? "\(latencyMs!)ms" : "\(elapsed)ms (HTTP)"
            let ipReport = ipString ?? "RESOLVED DIRECT"

            testResult = "DIAGNOSTIC TEST COMPLETE // PUBLIC IP: \(ipReport) // RTT LATENCY: \(latencyReport)"
            SharedTunnelLogger.log("Diagnostic test: IP=\(ipReport), RTT=\(latencyReport)", tag: "DIAG")
            refreshLogs()
            isRunningTest = false
        }
    }

    private func formatSpeed(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec < 1024 {
            return "\(bytesPerSec) B/s"
        } else if bytesPerSec < 1024 * 1024 {
            return String(format: "%.1f KB/s", Double(bytesPerSec) / 1024.0)
        } else {
            return String(format: "%.2f MB/s", Double(bytesPerSec) / (1024.0 * 1024.0))
        }
    }
}
