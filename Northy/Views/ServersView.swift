import SwiftUI
import UIKit
import AVFoundation

// MARK: - Tab 01: SERVERS & HAPP-STYLE SUBSCRIPTION ARCHITECTURE (Nothing OS Design)

public struct ServersView: View {
    @Bindable var vpnManager: VPNTunnelManager
    let localization: LocalizationManager
    var onOpenSettings: (() -> Void)? = nil

    @State private var theme = ThemeManager.shared
    @State private var launchPulseCount: Int = 0
    @State private var areAllCollapsed: Bool = false
    @State private var collapsedSubscriptionIds: Set<UUID> = []
    @State private var isManualNodesCollapsed: Bool = false

    // Modals
    @State private var showAddSubscriptionSheet: Bool = false
    @State private var selectedSubscriptionForDetails: SubscriptionSource? = nil
    @State private var editingSubscription: SubscriptionSource? = nil
    @State private var refreshingSubId: UUID? = nil
    @State private var pingingSubId: UUID? = nil

    // Header Tap & Secret Diagnostics
    @State private var headerTapCount: Int = 0
    @State private var lastHeaderTapTime: Date = .distantPast
    @State private var isHeaderBouncing: Bool = false
    @State private var showSecretDiagnostics: Bool = false

    public init(
        vpnManager: VPNTunnelManager,
        localization: LocalizationManager,
        onOpenSettings: (() -> Void)? = nil
    ) {
        self.vpnManager = vpnManager
        self.localization = localization
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Center Hero Power Control & Active Tunnel Status (with Interactive World Map)
                centralHeroPowerControl

                // 2. Quick Telemetry Matrix (Uptime & Live KB/MB Speeds)
                liveSessionTelemetryStrip

                if let banner = vpnManager.statusBannerMessage {
                    diagnosticBanner(banner)
                }

                // 3. Quick Visibility Toggle ("Hide everything" / "Show everything")
                quickVisibilityToggleRow

                // 4. Expandable Subscription Cards & Metadata System
                subscriptionCardsStack

                // 5. Manual / Unassigned Nodes (if any)
                manualNodesCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(NothingPalette.trueBlack)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()

                    withAnimation(.spring(response: 0.12, dampingFraction: 0.6)) {
                        isHeaderBouncing = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.75)) {
                            isHeaderBouncing = false
                        }
                    }

                    let now = Date()
                    if now.timeIntervalSince(lastHeaderTapTime) > 1.5 {
                        headerTapCount = 0
                    }
                    lastHeaderTapTime = now
                    headerTapCount += 1

                    if headerTapCount >= 8 {
                        headerTapCount = 0
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showSecretDiagnostics = true
                    }
                } label: {
                    VStack(spacing: 4) {
                        NothingDotMatrixLabel(
                            text: "NORTHY",
                            dotSize: 2.2,
                            spacing: 1.0,
                            activeColor: NothingPalette.pureWhite
                        )

                        TimelineView(.periodic(from: .now, by: 1.0)) { ctx in
                            NothingDotMatrixLabel(
                                text: Self.formatUptime(
                                    since: vpnManager.connectedSince,
                                    now: ctx.date,
                                    isConnected: vpnManager.isConnected
                                ),
                                dotSize: 1.8,
                                spacing: 0.8,
                                activeColor: vpnManager.isConnected
                                    ? theme.accentColor
                                    : NothingPalette.mutedGrey.opacity(0.6)
                            )
                        }
                    }
                    .padding(.top, 2)
                    .scaleEffect(isHeaderBouncing ? 1.12 : 1.0)
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSubscriptionSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                }
                .accessibilityLabel("Add Subscription")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.8), trigger: vpnManager.isConnected)
        .sheet(isPresented: $showAddSubscriptionSheet) {
            AddSubscriptionSheet(vpnManager: vpnManager, localization: localization)
        }
        .sheet(isPresented: $showSecretDiagnostics) {
            TunnelDiagnosticsSheet(vpnManager: vpnManager, localization: localization)
        }
        .sheet(item: $selectedSubscriptionForDetails) { sub in
            SubscriptionDetailsSheet(subscription: sub, vpnManager: vpnManager, localization: localization)
        }
        .sheet(item: $editingSubscription) { sub in
            EditSubscriptionSheet(subscription: sub, vpnManager: vpnManager, localization: localization)
        }
    }

    // MARK: - 2. Center Hero Power Control (Snake Wave + 360° Radar)

    private var centralHeroPowerControl: some View {
        VStack(spacing: 14) {
            // Nothing OS Dot-Matrix Snake Wave (Responsive to live throughput)
            NothingDotMatrixSnakeWave(
                isConnected: vpnManager.isConnected,
                isTransitioning: vpnManager.isTransitioning,
                rxSpeedBytesPerSec: vpnManager.rxSpeedBytesPerSec,
                txSpeedBytesPerSec: vpnManager.txSpeedBytesPerSec,
                accentColor: theme.accentColor
            )
            .frame(height: 28)
            .padding(.horizontal, 20)

            // Nothing OS Concentric Dot-Matrix Power Connect Button
            NothingPowerConnectButton(
                isConnected: vpnManager.isConnected,
                isTransitioning: vpnManager.isTransitioning,
                accentColor: theme.accentColor
            ) {
                Task {
                    await vpnManager.toggleTunnelConnection()
                }
            }
            .frame(height: 216)

            // Active Node & Status Headline Label
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    NothingStatusLEDDot(
                        isConnected: vpnManager.isConnected,
                        isTransitioning: vpnManager.isTransitioning
                    )

                    Text(statusHeadlineText)
                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                        .foregroundStyle(vpnManager.isConnected ? theme.accentColor : NothingPalette.mutedGrey)
                        .tracking(1.4)
                }

                if let node = vpnManager.selectedNode {
                    Text(Self.cleanNodeRemark(node.remark))
                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                        .lineLimit(1)

                    Text(Self.nodeBadgeLine(for: node))
                        .font(NothingTypography.technicalMono(size: 10, weight: .medium))
                        .foregroundStyle(theme.accentColor)
                } else {
                    Text("NO ACTIVE NODE SELECTED")
                        .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - 3. Live Session Telemetry Strip (2x2 Grid: Speeds & Cumulative Volumes)

    private var liveSessionTelemetryStrip: some View {
        NothingIndustrialCard(isHighlighted: vpnManager.isConnected) {
            VStack(spacing: 10) {
                // Row 1: Real-Time Download & Upload Speed
                HStack(spacing: 12) {
                    telemetryGridCell(
                        icon: "↓",
                        title: localization.tr("telemetry.speed.down"),
                        value: Self.formatTransferRate(vpnManager.rxSpeedBytesPerSec),
                        isActive: vpnManager.isConnected,
                        accentColor: NothingPalette.pureWhite
                    )

                    Rectangle()
                        .fill(NothingPalette.gridStroke)
                        .frame(width: 1, height: 32)

                    telemetryGridCell(
                        icon: "↑",
                        title: localization.tr("telemetry.speed.up"),
                        value: Self.formatTransferRate(vpnManager.txSpeedBytesPerSec),
                        isActive: vpnManager.isConnected,
                        accentColor: theme.accentColor
                    )
                }

                Rectangle()
                    .fill(NothingPalette.gridStroke)
                    .frame(height: 1)

                // Row 2: Cumulative Download & Upload Volume (No duplicate session timer)
                HStack(spacing: 12) {
                    telemetryGridCell(
                        icon: "↓",
                        title: localization.tr("telemetry.down"),
                        value: Self.formatByteCount(vpnManager.telemetry.rxBytes),
                        isActive: vpnManager.isConnected,
                        accentColor: NothingPalette.pureWhite.opacity(0.85)
                    )

                    Rectangle()
                        .fill(NothingPalette.gridStroke)
                        .frame(width: 1, height: 32)

                    telemetryGridCell(
                        icon: "↑",
                        title: localization.tr("telemetry.up"),
                        value: Self.formatByteCount(vpnManager.telemetry.txBytes),
                        isActive: vpnManager.isConnected,
                        accentColor: NothingPalette.pureWhite.opacity(0.85)
                    )
                }
            }
        }
    }

    private func telemetryGridCell(
        icon: String,
        title: String,
        value: String,
        isActive: Bool,
        accentColor: Color
    ) -> some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(NothingTypography.technicalMono(size: 13, weight: .black))
                .foregroundStyle(isActive ? accentColor : NothingPalette.mutedGrey)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NothingTypography.technicalMono(size: 8, weight: .semibold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                    .tracking(0.8)
                    .lineLimit(1)

                Text(value)
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.28, dampingFraction: 0.75), value: value)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 4. Quick Visibility Toggle Row ("Hide everything" / "Show everything")

    private var quickVisibilityToggleRow: some View {
        HStack(alignment: .center) {
            Text("// SUBSCRIPTIONS [\(vpnManager.subscriptions.count)]")
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .foregroundStyle(NothingPalette.mutedGrey)
                .tracking(1.2)

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    areAllCollapsed.toggle()
                    if areAllCollapsed {
                        collapsedSubscriptionIds = Set(vpnManager.subscriptions.map(\.id))
                        isManualNodesCollapsed = true
                    } else {
                        collapsedSubscriptionIds.removeAll()
                        isManualNodesCollapsed = false
                    }
                }
            } label: {
                Text(areAllCollapsed ? localization.tr("action.show_all") : localization.tr("action.hide_all"))
                    .font(NothingTypography.technicalMono(size: 11, weight: .semibold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                    .tracking(0.8)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - 5. Expandable Subscription Cards & Metadata System

    private var subscriptionCardsStack: some View {
        VStack(spacing: 14) {
            if vpnManager.subscriptions.isEmpty && unassignedNodes.isEmpty {
                emptySubscriptionsCard
            } else {
                ForEach(vpnManager.subscriptions) { sub in
                    subscriptionCard(sub)
                }
            }
        }
    }

    private func subscriptionCard(_ sub: SubscriptionSource) -> some View {
        let isCollapsed = collapsedSubscriptionIds.contains(sub.id)
        let subNodes = vpnManager.nodes.filter { $0.subscriptionId == sub.id }

        return NothingIndustrialCard(isHighlighted: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Header Row: Chevron, Title, Subtitle, and Quick Action Buttons
                HStack(alignment: .top, spacing: 10) {
                    // Collapse Chevron Button
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            if isCollapsed {
                                collapsedSubscriptionIds.remove(sub.id)
                            } else {
                                collapsedSubscriptionIds.insert(sub.id)
                            }
                        }
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Title & Subtitle (Clean Title without emoji truncation, concise auto-update info)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Self.cleanSubscriptionTitle(sub.title))
                            .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .lineLimit(1)

                        let syncDateString = Self.formatSyncDate(sub.lastUpdated)
                        let intervalHours = sub.updateIntervalHours ?? vpnManager.subscriptionSettings.updateIntervalHours
                        HStack(spacing: 5) {
                            Text(syncDateString)
                            Text("•")
                            Text("AUTO: \(intervalHours)H")
                            Text("•")
                            Text("[\(subNodes.count)]")
                                .foregroundStyle(theme.accentColor)
                        }
                        .font(NothingTypography.technicalMono(size: 9, weight: .medium))
                        .foregroundStyle(NothingPalette.mutedGrey)
                        .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    // Right Quick Actions: Refresh, Ping All, More (...)
                    HStack(spacing: 12) {
                        // Refresh / Sync Button
                        Button {
                            guard refreshingSubId == nil else { return }
                            refreshingSubId = sub.id
                            Task {
                                if let url = URL(string: sub.urlString) {
                                    try? await vpnManager.fetchRemoteSubscription(from: url, existingId: sub.id)
                                }
                                refreshingSubId = nil
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(refreshingSubId == sub.id ? theme.accentColor : NothingPalette.pureWhite)
                                .rotationEffect(.degrees(refreshingSubId == sub.id ? 360 : 0))
                                .animation(refreshingSubId == sub.id ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: refreshingSubId)
                        }
                        .buttonStyle(.plain)

                        // Ping All Servers in Subscription Button
                        Button {
                            guard pingingSubId == nil else { return }
                            pingingSubId = sub.id
                            Task {
                                await vpnManager.measureSubscriptionLatencies(for: sub.id)
                                pingingSubId = nil
                            }
                        } label: {
                            RotatingPingIcon(
                                isRotating: pingingSubId == sub.id || vpnManager.isPingingAll,
                                color: (pingingSubId == sub.id || vpnManager.isPingingAll) ? theme.accentColor : NothingPalette.pureWhite
                            )
                        }
                        .buttonStyle(.plain)

                        // More (...) Menu
                        Menu {
                            Button {
                                editingSubscription = sub
                            } label: {
                                Label("Edit Subscription", systemImage: "pencil")
                            }

                            Button {
                                UIPasteboard.general.string = sub.urlString
                                vpnManager.statusBannerMessage = "SUBSCRIPTION URL COPIED"
                            } label: {
                                Label("Copy Link", systemImage: "doc.on.doc")
                            }

                            Divider()

                            Button(role: .destructive) {
                                vpnManager.removeSubscription(sub.id)
                            } label: {
                                Label("Delete Subscription", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(NothingPalette.mutedGrey)
                                .frame(width: 20, height: 20)
                        }
                    }
                }

                // Precision Industrial Quota & Expiration Section
                subscriptionQuotaSection(sub)

                // Provider Announcement / Notice Banner
                if let announcement = sub.announcement, !announcement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    announcementBanner(announcement)
                }

                // Nested Server List (Rendered when expanded)
                if !isCollapsed {
                    Rectangle()
                        .fill(NothingPalette.gridStroke)
                        .frame(height: 1)
                        .padding(.vertical, 2)

                    VStack(spacing: 8) {
                        ForEach(subNodes) { node in
                            serverNodeRow(node)
                        }
                    }
                }
            }
        }
    }

    private func subscriptionQuotaSection(_ sub: SubscriptionSource) -> some View {
        let usedBytes = (sub.uploadBytes ?? 0) + (sub.downloadBytes ?? 0)
        let totalBytes = sub.totalQuotaBytes
        let progressRatio = Self.calculateProgress(used: usedBytes, total: totalBytes)

        return VStack(spacing: 6) {
            // Upper Info Line: (i) Info Button + Quota Readout + Expiry Badge + Support Airplane
            HStack(spacing: 6) {
                Button {
                    selectedSubscriptionForDetails = sub
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }
                .buttonStyle(.plain)

                Text(Self.formatQuotaDisplay(used: usedBytes, total: totalBytes))
                    .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)

                Spacer(minLength: 4)

                if let exp = sub.formattedExpirationDate {
                    Text("[EXP: \(exp)]")
                        .font(NothingTypography.technicalMono(size: 9, weight: .medium))
                        .foregroundStyle(NothingPalette.mutedGrey)
                        .lineLimit(1)
                }

                if let support = sub.effectiveSupportURL {
                    Link(destination: support) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.accentColor)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Sleek Precision Meter Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NothingPalette.surfaceElevated)
                        .overlay(Capsule().strokeBorder(NothingPalette.gridStroke, lineWidth: 0.5))

                    Capsule()
                        .fill(theme.accentColor)
                        .frame(width: max(4, geo.size.width * CGFloat(progressRatio)))
                }
            }
            .frame(height: 4)
        }
    }

    private func announcementBanner(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.accentColor)

                Text("// NOTICE")
                    .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                    .foregroundStyle(theme.accentColor)
                    .tracking(1.0)
            }

            Text(text)
                .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                .foregroundStyle(NothingPalette.pureWhite.opacity(0.9))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NothingPalette.surfaceElevated.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: theme.chipCornerRadius)
                .strokeBorder(theme.accentColor.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
    }

    // MARK: - Nested Server Node Row

    private func serverNodeRow(_ node: ProxyNode) -> some View {
        let isSelected = vpnManager.selectedNode?.id == node.id
        let countryCode = Self.countryCode(for: node.remark)
        let cleanedRemark = Self.cleanNodeRemark(node.remark)

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                vpnManager.selectNode(node.id)
            }
        } label: {
            HStack(spacing: 8) {
                // Nothing OS Dot-Matrix Country Code Badge (e.g. [DE], [US], [FI])
                Text("[\(countryCode)]")
                    .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? theme.accentColor : NothingPalette.mutedGrey)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isSelected ? theme.accentColor.opacity(0.12) : NothingPalette.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(isSelected ? theme.accentColor.opacity(0.6) : NothingPalette.gridStroke, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                // Server Name and Badge Line
                VStack(alignment: .leading, spacing: 2) {
                    Text(cleanedRemark)
                        .font(NothingTypography.technicalMono(size: 12, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? NothingPalette.pureWhite : NothingPalette.pureWhite.opacity(0.9))
                        .lineLimit(1)

                    Text(Self.nodeBadgeLine(for: node))
                        .font(NothingTypography.technicalMono(size: 9, weight: .regular))
                        .foregroundStyle(isSelected ? theme.accentColor : NothingPalette.mutedGrey)
                        .lineLimit(1)
                }

                Spacer()

                // Live Ping / Latency Readout + Signal Bars
                pingIndicatorView(latencyMs: node.latencyMs)

                // Selection Chevron / Indicator
                if isSelected {
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: theme.accentColor.opacity(0.8), radius: 3)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NothingPalette.dimMatrixDot)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? NothingPalette.surfaceElevated : NothingPalette.surfacePrimary)
            .overlay(
                RoundedRectangle(cornerRadius: theme.chipCornerRadius)
                    .strokeBorder(isSelected ? theme.accentColor : NothingPalette.gridStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                vpnManager.deleteNode(node.id)
            } label: {
                Label("Delete Node", systemImage: "trash")
            }
        }
    }

    // MARK: - 6. Manual / Unassigned Nodes Card

    private var unassignedNodes: [ProxyNode] {
        vpnManager.nodes.filter { $0.subscriptionId == nil }
    }

    private var manualNodesCard: some View {
        Group {
            if !unassignedNodes.isEmpty {
                NothingIndustrialCard(isHighlighted: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button {
                                withAnimation(.snappy(duration: 0.2)) {
                                    isManualNodesCollapsed.toggle()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isManualNodesCollapsed ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(NothingPalette.pureWhite)

                                    Text(localization.tr("subscription.unassigned"))
                                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                                        .foregroundStyle(NothingPalette.pureWhite)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text("[\(unassignedNodes.count)]")
                                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                .foregroundStyle(theme.accentColor)
                        }

                        if !isManualNodesCollapsed {
                            Rectangle()
                                .fill(NothingPalette.gridStroke)
                                .frame(height: 1)

                            VStack(spacing: 8) {
                                ForEach(unassignedNodes) { node in
                                    serverNodeRow(node)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptySubscriptionsCard: some View {
        NothingIndustrialCard(isHighlighted: false) {
            VStack(spacing: 12) {
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 32))
                    .foregroundStyle(NothingPalette.mutedGrey)

                Text(localization.tr("settings.subscriptions.empty"))
                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                    .foregroundStyle(NothingPalette.mutedGrey)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Button {
                    showAddSubscriptionSheet = true
                } label: {
                    Text("+ [ADD SUBSCRIPTION]")
                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                        .foregroundStyle(NothingPalette.trueBlack)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(NothingPalette.pureWhite)
                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Ping Indicator View

    private func pingIndicatorView(latencyMs: Int?) -> some View {
        let isFast = (latencyMs ?? 999) < 100
        return VStack(alignment: .trailing, spacing: 3) {
            if let latencyMs {
                Text("\(latencyMs) MS")
                    .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                    .foregroundStyle(isFast ? NothingPalette.pureWhite : theme.accentColor)
            } else {
                Text("-- MS")
                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                    .foregroundStyle(NothingPalette.mutedGrey)
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { bar in
                    let isLit = Self.isSignalBarLit(barIndex: bar, latencyMs: latencyMs)
                    Rectangle()
                        .fill(isLit ? (isFast ? NothingPalette.pureWhite : theme.accentColor) : NothingPalette.dimMatrixDot)
                        .frame(width: 3, height: CGFloat(4 + bar * 3))
                }
            }
        }
    }

    // MARK: - Status Notification Banner (Compact Terminal-Style Pill with 4s Auto-Dismiss)

    private func diagnosticBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.accentColor)
                .frame(width: 5, height: 5)
                .shadow(color: theme.accentColor.opacity(0.8), radius: 2)

            Text("//")
                .font(NothingTypography.technicalMono(size: 9, weight: .black))
                .foregroundStyle(theme.accentColor)

            Text(message)
                .font(NothingTypography.technicalMono(size: 10, weight: .medium))
                .foregroundStyle(NothingPalette.pureWhite)
                .lineLimit(2)

            Spacer(minLength: 4)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    vpnManager.statusBannerMessage = nil
                }
            } label: {
                Text("[X]")
                    .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(NothingPalette.surfaceElevated.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: theme.chipCornerRadius)
                .strokeBorder(theme.accentColor.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
        .task(id: message) {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.snappy(duration: 0.25)) {
                if vpnManager.statusBannerMessage == message {
                    vpnManager.statusBannerMessage = nil
                }
            }
        }
    }

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

    // MARK: - Static Formatting Utilities

    public static func cleanSubscriptionTitle(_ rawTitle: String) -> String {
        var cleaned = rawTitle
        cleaned = cleaned.replacingOccurrences(of: "✅", with: "[OK]")
        cleaned = cleaned.replacingOccurrences(of: "✔", with: "[OK]")
        cleaned = cleaned.replacingOccurrences(of: "🌐", with: "")
        cleaned = cleaned.replacingOccurrences(of: "⚡", with: "")
        cleaned = cleaned.replacingOccurrences(of: "- [OK]", with: "[OK]")
        cleaned = cleaned.replacingOccurrences(of: "-  [OK]", with: "[OK]")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? rawTitle : cleaned
    }

    public static func cleanNodeRemark(_ remark: String) -> String {
        var cleaned = ""
        for char in remark {
            if char.isEmoji {
                continue
            }
            cleaned.append(char)
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? remark : cleaned
    }

    public static func countryCode(for remark: String) -> String {
        let scalars = Array(remark.unicodeScalars)
        for i in 0..<scalars.count {
            let s = scalars[i]
            if (0x1F1E6...0x1F1FF).contains(s.value) {
                if i + 1 < scalars.count && (0x1F1E6...0x1F1FF).contains(scalars[i + 1].value) {
                    if let u1 = UnicodeScalar(s.value - 0x1F1E6 + 65),
                       let u2 = UnicodeScalar(scalars[i + 1].value - 0x1F1E6 + 65) {
                        return "\(Character(u1))\(Character(u2))"
                    }
                }
            }
        }

        let upper = remark.uppercased()
        if upper.contains("TRAFFIC") || upper.contains("LIMIT") || upper.contains("GIB") || upper.contains("GB") || upper.contains("INFO") {
            return "INFO"
        }
        if upper.contains("FINLAND") || upper.contains(" FI ") || upper.hasPrefix("FI-") || upper.hasPrefix("FI ") { return "FI" }
        if upper.contains("GERMANY") || upper.contains(" DE ") || upper.hasPrefix("DE-") || upper.hasPrefix("DE ") { return "DE" }
        if upper.contains("NETHERLANDS") || upper.contains(" HOLLAND") || upper.contains(" NL ") || upper.hasPrefix("NL-") { return "NL" }
        if upper.contains("RUSSIA") || upper.contains(" RU ") || upper.hasPrefix("RU-") || upper.hasPrefix("RU ") { return "RU" }
        if upper.contains("USA") || upper.contains("UNITED STATES") || upper.contains(" US ") || upper.hasPrefix("US-") { return "US" }
        if upper.contains("UK") || upper.contains("UNITED KINGDOM") || upper.contains(" GB ") || upper.hasPrefix("GB-") { return "GB" }
        if upper.contains("TURKEY") || upper.contains(" TR ") || upper.hasPrefix("TR-") { return "TR" }
        if upper.contains("SWEDEN") || upper.contains(" SE ") || upper.hasPrefix("SE-") { return "SE" }
        if upper.contains("POLAND") || upper.contains(" PL ") || upper.hasPrefix("PL-") { return "PL" }
        if upper.contains("FRANCE") || upper.contains(" FR ") || upper.hasPrefix("FR-") { return "FR" }
        if upper.contains("SINGAPORE") || upper.contains(" SG ") || upper.hasPrefix("SG-") { return "SG" }
        if upper.contains("JAPAN") || upper.contains(" JP ") || upper.hasPrefix("JP-") { return "JP" }
        if upper.contains("KAZAKHSTAN") || upper.contains(" KZ ") || upper.hasPrefix("KZ-") { return "KZ" }
        if upper.contains("AUSTRALIA") || upper.contains(" AU ") || upper.hasPrefix("AU-") { return "AU" }
        if upper.contains("CANADA") || upper.contains(" CA ") || upper.hasPrefix("CA-") { return "CA" }
        return "NODE"
    }

    public static func countryFlagOrIcon(for remark: String) -> String {
        return countryCode(for: remark)
    }

    public static func nodeBadgeLine(for node: ProxyNode) -> String {
        var parts: [String] = [node.protocolType.badgeLabel]
        parts.append(node.transport.rawValue.uppercased())
        if node.security == .reality {
            parts.append("REALITY")
        } else if node.security == .tls {
            parts.append("TLS")
        }
        return parts.joined(separator: " // ")
    }

    public static func formatSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }

    public static func formatQuotaDisplay(used: Int64, total: Int64?) -> String {
        let usedGB = Double(used) / (1024.0 * 1024.0 * 1024.0)
        let formattedUsed = usedGB < 1.0 ? String(format: "%.1f GB", max(0.1, usedGB)) : String(format: "%.1f GB", usedGB)

        guard let total, total > 0 else {
            return "\(formattedUsed) / ∞"
        }
        let totalGB = Double(total) / (1024.0 * 1024.0 * 1024.0)
        let formattedTotal = totalGB < 1.0 ? String(format: "%.1f GB", totalGB) : String(format: "%.1f GB", totalGB)
        return "\(formattedUsed) / \(formattedTotal)"
    }

    public static func calculateProgress(used: Int64, total: Int64?) -> Double {
        guard let total, total > 0 else { return 0.15 }
        return min(1.0, max(0.02, Double(used) / Double(total)))
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
        case ..<60: return true
        case 60..<120: return barIndex < 3
        case 120..<220: return barIndex < 2
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
            return String(format: "%.1f MB", mb)
        }
        let gb = mb / 1024.0
        return String(format: "%.2f GB", gb)
    }
}

// MARK: - Add / Import Subscription Sheet

public struct AddSubscriptionSheet: View {
    @Bindable var vpnManager: VPNTunnelManager
    let localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var urlInput: String = ""
    @State private var manualConfigInput: String = ""
    @State private var activeMode: ImportMode = .url
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String? = nil

    private enum ImportMode: String, CaseIterable {
        case clipboard = "CLIPBOARD"
        case url = "URL"
        case manual = "MANUAL"
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                // Mode Switcher
                HStack(spacing: 8) {
                    ForEach(ImportMode.allCases, id: \.self) { mode in
                        let isSelected = activeMode == mode
                        Button {
                            activeMode = mode
                            errorMessage = nil
                        } label: {
                            Text(mode.rawValue)
                                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                .overlay(
                                    Rectangle().strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.chipCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let err = errorMessage {
                    Text(err)
                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                        .foregroundStyle(ThemeManager.shared.accentColor)
                }

                switch activeMode {
                case .clipboard:
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localization.tr("import.clipboard"))
                            .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)

                        Text("Paste subscription link or raw server config directly from clipboard.")
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.mutedGrey)

                        Button {
                            isProcessing = true
                            Task {
                                await vpnManager.pasteFromClipboardAndConnect()
                                isProcessing = false
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text("PASTE & IMPORT")
                                    .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                                Spacer()
                                Text("⌘V")
                                    .font(NothingTypography.technicalMono(size: 12, weight: .black))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(ThemeManager.shared.accentColor)
                            .foregroundStyle(NothingPalette.pureWhite)
                            .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.buttonCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }

                case .url:
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localization.tr("import.url"))
                            .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)

                        TextField(localization.tr("import.url.placeholder"), text: $urlInput)
                            .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(NothingPalette.surfaceElevated)
                            .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.chipCornerRadius))

                        Button {
                            guard let url = URL(string: urlInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                                errorMessage = "INVALID URL"
                                return
                            }
                            isProcessing = true
                            Task {
                                do {
                                    try await vpnManager.fetchRemoteSubscription(from: url)
                                    isProcessing = false
                                    dismiss()
                                } catch {
                                    errorMessage = "FAILED: \(error.localizedDescription)"
                                    isProcessing = false
                                }
                            }
                        } label: {
                            HStack {
                                Text(isProcessing ? "FETCHING..." : localization.tr("import.url.action"))
                                    .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                                Spacer()
                                Image(systemName: "arrow.down.doc")
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(NothingPalette.pureWhite)
                            .foregroundStyle(NothingPalette.trueBlack)
                            .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.buttonCornerRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    }

                case .manual:
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localization.tr("import.manual"))
                            .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)

                        TextEditor(text: $manualConfigInput)
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(height: 140)
                            .background(NothingPalette.surfaceElevated)
                            .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.chipCornerRadius))

                        Button {
                            let text = manualConfigInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            Task {
                                await vpnManager.importPayloadAndPrepare(text, autoConnect: false)
                                dismiss()
                            }
                        } label: {
                            Text("SAVE NODES")
                                .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(NothingPalette.pureWhite)
                                .foregroundStyle(NothingPalette.trueBlack)
                                .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.buttonCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(18)
            .background(NothingPalette.trueBlack.ignoresSafeArea())
            .navigationTitle("// " + localization.tr("import.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("[CLOSE]") {
                        dismiss()
                    }
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                }
            }
        }
    }
}

// MARK: - Subscription Details & Announcement Sheet (i)

public struct SubscriptionDetailsSheet: View {
    let subscription: SubscriptionSource
    @Bindable var vpnManager: VPNTunnelManager
    let localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title Card
                    NothingIndustrialCard(isHighlighted: false) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SUBSCRIPTION TITLE")
                                .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                .foregroundStyle(NothingPalette.mutedGrey)

                            Text(subscription.title)
                                .font(NothingTypography.technicalMono(size: 15, weight: .bold))
                                .foregroundStyle(NothingPalette.pureWhite)

                            Text(subscription.urlString)
                                .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                                .foregroundStyle(NothingPalette.mutedGrey)
                                .lineLimit(2)
                        }
                    }

                    // Announcement / Provider Notes Banner
                    if let announcement = subscription.announcement, !announcement.isEmpty {
                        NothingIndustrialCard(isHighlighted: true) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("// PROVIDER ANNOUNCEMENT")
                                    .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                    .foregroundStyle(ThemeManager.shared.accentColor)

                                Text(announcement)
                                    .font(NothingTypography.technicalMono(size: 11, weight: .regular))
                                    .foregroundStyle(NothingPalette.pureWhite)
                                    .lineSpacing(3)
                            }
                        }
                    }

                    // Quota & Traffic Breakdown
                    NothingIndustrialCard(isHighlighted: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("// TRAFFIC & QUOTA METRICS")
                                .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                .foregroundStyle(NothingPalette.mutedGrey)

                            HStack {
                                Text("DOWNLOADED:")
                                    .font(NothingTypography.technicalMono(size: 11, weight: .regular))
                                    .foregroundStyle(NothingPalette.mutedGrey)
                                Spacer()
                                Text(Self.formatBytes(subscription.downloadBytes ?? 0))
                                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)
                            }

                            HStack {
                                Text("UPLOADED:")
                                    .font(NothingTypography.technicalMono(size: 11, weight: .regular))
                                    .foregroundStyle(NothingPalette.mutedGrey)
                                Spacer()
                                Text(Self.formatBytes(subscription.uploadBytes ?? 0))
                                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)
                            }

                            HStack {
                                Text("TOTAL QUOTA:")
                                    .font(NothingTypography.technicalMono(size: 11, weight: .regular))
                                    .foregroundStyle(NothingPalette.mutedGrey)
                                Spacer()
                                if let total = subscription.totalQuotaBytes, total > 0 {
                                    Text(Self.formatBytes(total))
                                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                        .foregroundStyle(ThemeManager.shared.accentColor)
                                } else {
                                    Text("UNLIMITED (∞)")
                                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                        .foregroundStyle(NothingPalette.pureWhite)
                                }
                            }

                            if let exp = subscription.formattedExpirationDate {
                                HStack {
                                    Text("EXPIRATION DATE:")
                                        .font(NothingTypography.technicalMono(size: 11, weight: .regular))
                                        .foregroundStyle(NothingPalette.mutedGrey)
                                    Spacer()
                                    Text(exp)
                                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                        .foregroundStyle(NothingPalette.pureWhite)
                                }
                            }
                        }
                    }

                    // Support Link Button
                    if let support = subscription.effectiveSupportURL {
                        Link(destination: support) {
                            HStack {
                                Text("OPEN SUPPORT CHANNEL")
                                    .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                                Spacer()
                                Text("↗")
                                    .font(NothingTypography.technicalMono(size: 16, weight: .bold))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(ThemeManager.shared.accentColor)
                            .foregroundStyle(NothingPalette.pureWhite)
                            .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.buttonCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
            }
            .background(NothingPalette.trueBlack.ignoresSafeArea())
            .navigationTitle("// " + localization.tr("subscription.details.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("[CLOSE]") {
                        dismiss()
                    }
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                }
            }
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        }
        let mb = Double(bytes) / (1024.0 * 1024.0)
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Edit Subscription Sheet

public struct EditSubscriptionSheet: View {
    @State var subscription: SubscriptionSource
    @Bindable var vpnManager: VPNTunnelManager
    let localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var titleInput: String = ""
    @State private var intervalSelection: Int = 6

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SUBSCRIPTION TITLE")
                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                        .foregroundStyle(NothingPalette.mutedGrey)

                    TextField("Title", text: $titleInput)
                        .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                        .padding(.horizontal, 10)
                        .frame(height: 40)
                        .background(NothingPalette.surfaceElevated)
                        .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.chipCornerRadius))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("AUTO-UPDATE INTERVAL (HOURS)")
                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                        .foregroundStyle(NothingPalette.mutedGrey)

                    HStack(spacing: 8) {
                        ForEach([1, 3, 6, 12, 24], id: \.self) { hours in
                            let isSelected = intervalSelection == hours
                            Button {
                                intervalSelection = hours
                            } label: {
                                Text("\(hours)H")
                                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                    .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                    .overlay(
                                        Rectangle().strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.chipCornerRadius))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                Button {
                    var updated = subscription
                    let trimmedTitle = titleInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedTitle.isEmpty {
                        updated.title = trimmedTitle
                    }
                    updated.updateIntervalHours = intervalSelection
                    vpnManager.updateSubscription(updated)
                    dismiss()
                } label: {
                    Text("SAVE CHANGES")
                        .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(NothingPalette.pureWhite)
                        .foregroundStyle(NothingPalette.trueBlack)
                        .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.buttonCornerRadius))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(NothingPalette.trueBlack.ignoresSafeArea())
            .navigationTitle("// EDIT SUBSCRIPTION")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("[CANCEL]") {
                        dismiss()
                    }
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                }
            }
            .onAppear {
                titleInput = subscription.title
                intervalSelection = subscription.updateIntervalHours ?? 6
            }
        }
    }
}

// MARK: - Rotating Ping Indicator Icon

private struct RotatingPingIcon: View {
    let isRotating: Bool
    let color: Color
    @State private var rotationAngle: Double = 0

    var body: some View {
        Image(systemName: "gauge.with.dots.needle.33percent")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(rotationAngle))
            .onAppear {
                if isRotating {
                    startRotation()
                }
            }
            .onChange(of: isRotating) { _, rotating in
                if rotating {
                    startRotation()
                } else {
                    stopRotation()
                }
            }
    }

    private func startRotation() {
        rotationAngle = 0
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }

    private func stopRotation() {
        withAnimation(.easeOut(duration: 0.2)) {
            rotationAngle = 0
        }
    }
}

// MARK: - Character Emoji Helper

extension Character {
    fileprivate var isEmoji: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmoji && (scalar.value > 0x2388 || scalar.properties.isEmojiPresentation)
        }
    }
}


