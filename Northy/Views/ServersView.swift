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
                // 1. Top Action Bar: Settings on left, Northy dot-matrix center, Add (+) on right
                topNavigationBar

                // 2. Center Hero Power Control & Active Tunnel Status
                centralHeroPowerControl

                // 3. Quick Telemetry Matrix (Uptime & Live KB/MB Speeds)
                liveSessionTelemetryStrip

                if let banner = vpnManager.statusBannerMessage {
                    diagnosticBanner(banner)
                }

                // 4. Quick Visibility Toggle ("Hide everything" / "Show everything")
                quickVisibilityToggleRow

                // 5. Expandable Subscription Cards & Metadata System
                subscriptionCardsStack

                // 6. Manual / Unassigned Nodes (if any)
                manualNodesCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(NothingPalette.trueBlack)
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.8), trigger: vpnManager.isConnected)
        .sheet(isPresented: $showAddSubscriptionSheet) {
            AddSubscriptionSheet(vpnManager: vpnManager, localization: localization)
        }
        .sheet(item: $selectedSubscriptionForDetails) { sub in
            SubscriptionDetailsSheet(subscription: sub, vpnManager: vpnManager, localization: localization)
        }
        .sheet(item: $editingSubscription) { sub in
            EditSubscriptionSheet(subscription: sub, vpnManager: vpnManager, localization: localization)
        }
    }

    // MARK: - 1. Top Action Bar

    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            // Top-Left: Settings Button
            Button {
                onOpenSettings?()
            } label: {
                ZStack {
                    Rectangle()
                        .fill(NothingPalette.surfaceElevated)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1)
                        )

                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NothingPalette.pureWhite)
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

            Spacer()

            // Center Branding Dot-Matrix
            NothingDotMatrixLabel(
                text: "NORTHY",
                dotSize: 2.4,
                spacing: 1.1,
                activeColor: NothingPalette.pureWhite
            )

            Spacer()

            // Top-Right: Add / Import Subscription Button (+)
            Button {
                showAddSubscriptionSheet = true
            } label: {
                ZStack {
                    Rectangle()
                        .fill(NothingPalette.surfaceElevated)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1)
                        )

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Subscription")
        }
    }

    // MARK: - 2. Center Hero Power Control

    private var centralHeroPowerControl: some View {
        VStack(spacing: 14) {
            // Prominent Circular / Dot-Matrix Power Button
            Button {
                launchPulseCount += 1
                Task {
                    await vpnManager.toggleTunnelConnection()
                }
            } label: {
                ZStack {
                    // Outer animated status ring
                    Circle()
                        .strokeBorder(
                            vpnManager.isConnected ? theme.accentColor.opacity(0.35) : NothingPalette.gridStroke.opacity(0.6),
                            lineWidth: 1
                        )
                        .frame(width: 154, height: 154)

                    // Concentric breathing status ring
                    if vpnManager.isConnected || vpnManager.isTransitioning {
                        Circle()
                            .strokeBorder(
                                theme.accentColor.opacity(vpnManager.isTransitioning ? 0.75 : 0.45),
                                style: StrokeStyle(lineWidth: 2, dash: [4, 6])
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(vpnManager.isTransitioning ? Double(launchPulseCount * 90) : 0))
                            .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: vpnManager.isConnected)
                    }

                    // Central Button Core
                    Circle()
                        .fill(vpnManager.isConnected ? theme.accentColor.opacity(0.18) : NothingPalette.surfaceElevated)
                        .frame(width: 116, height: 116)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    vpnManager.isConnected ? theme.accentColor : NothingPalette.gridStroke,
                                    lineWidth: vpnManager.isConnected ? 2 : 1
                                )
                        )
                        .shadow(
                            color: vpnManager.isConnected ? theme.accentColor.opacity(0.4) : Color.clear,
                            radius: 18,
                            x: 0,
                            y: 0
                        )

                    // Power Glyph
                    Image(systemName: "power")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(
                            vpnManager.isConnected
                                ? theme.accentColor
                                : (vpnManager.isTransitioning ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                        )
                }
                .frame(height: 164)
            }
            .buttonStyle(.plain)

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
                    Text(node.remark)
                        .font(NothingTypography.technicalMono(size: 14, weight: .bold))
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - 3. Live Session Telemetry Strip (Speed & Volume)

    private var liveSessionTelemetryStrip: some View {
        NothingIndustrialCard(isHighlighted: vpnManager.isConnected) {
            VStack(spacing: 10) {
                // Top Row: Real-Time Download & Upload Speed
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
                        .frame(width: 1, height: 32)

                    speedMetricBlock(
                        arrowSymbol: "↑",
                        title: localization.tr("telemetry.speed.up"),
                        value: Self.formatTransferRate(vpnManager.txSpeedBytesPerSec),
                        isActive: vpnManager.isConnected,
                        accentColor: theme.accentColor
                    )
                }

                Rectangle()
                    .fill(NothingPalette.gridStroke)
                    .frame(height: 1)

                // Bottom Row: Live Session Uptime & Cumulative Volume
                TimelineView(.periodic(from: .now, by: 1.0)) { context in
                    let uptime = Self.formatUptime(
                        since: vpnManager.connectedSince,
                        now: context.date,
                        isConnected: vpnManager.isConnected
                    )

                    HStack(spacing: 8) {
                        volumeMetricColumn(
                            label: localization.tr("telemetry.uptime"),
                            value: uptime,
                            isActive: vpnManager.isConnected
                        )

                        Rectangle()
                            .fill(NothingPalette.gridStroke)
                            .frame(width: 1, height: 26)

                        volumeMetricColumn(
                            label: localization.tr("telemetry.down"),
                            value: Self.formatByteCount(vpnManager.telemetry.rxBytes),
                            isActive: vpnManager.isConnected
                        )

                        Rectangle()
                            .fill(NothingPalette.gridStroke)
                            .frame(width: 1, height: 26)

                        volumeMetricColumn(
                            label: localization.tr("telemetry.up"),
                            value: Self.formatByteCount(vpnManager.telemetry.txBytes),
                            isActive: vpnManager.isConnected
                        )
                    }
                }
            }
        }
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
                        withAnimation(.snappy(duration: 0.2)) {
                            if isCollapsed {
                                collapsedSubscriptionIds.remove(sub.id)
                            } else {
                                collapsedSubscriptionIds.insert(sub.id)
                            }
                        }
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Title & Subtitle (Last sync + Auto-update interval)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sub.title)
                            .font(NothingTypography.technicalMono(size: 14, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .lineLimit(1)

                        let syncDateString = Self.formatSyncDate(sub.lastUpdated)
                        let intervalHours = sub.updateIntervalHours ?? vpnManager.subscriptionSettings.updateIntervalHours
                        Text("\(syncDateString) | Autoupdate - \(intervalHours) h.")
                            .font(NothingTypography.technicalMono(size: 9, weight: .regular))
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
                            Image(systemName: "gauge.with.dots.needle.33percent")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(pingingSubId == sub.id ? theme.accentColor : NothingPalette.pureWhite)
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

                // Quota & Expiration Bar
                HStack(spacing: 8) {
                    // Info Icon (i) -> Opens full subscription modal
                    Button {
                        selectedSubscriptionForDetails = sub
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(NothingPalette.mutedGrey)
                    }
                    .buttonStyle(.plain)

                    // Visual Progress Bar (Used / Total)
                    let usedBytes = (sub.uploadBytes ?? 0) + (sub.downloadBytes ?? 0)
                    let totalBytes = sub.totalQuotaBytes
                    let progressRatio = Self.calculateProgress(used: usedBytes, total: totalBytes)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: theme.chipCornerRadius)
                                .fill(NothingPalette.surfaceElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.chipCornerRadius)
                                        .strokeBorder(NothingPalette.gridStroke, lineWidth: 1)
                                )

                            RoundedRectangle(cornerRadius: theme.chipCornerRadius)
                                .fill(theme.accentColor)
                                .frame(width: max(4, geo.size.width * CGFloat(progressRatio)))

                            Text(Self.formatQuotaDisplay(used: usedBytes, total: totalBytes))
                                .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                .foregroundStyle(NothingPalette.pureWhite)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .frame(height: 22)

                    // Expiration Date Label
                    if let exp = sub.formattedExpirationDate {
                        Text("Expires: \(exp)")
                            .font(NothingTypography.technicalMono(size: 9, weight: .medium))
                            .foregroundStyle(NothingPalette.mutedGrey)
                            .lineLimit(1)
                    }

                    // Telegram / Support Airplane Action Button
                    if let support = sub.effectiveSupportURL {
                        Link(destination: support) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(theme.accentColor)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                    }
                }

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

    private func announcementBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(theme.accentColor)
                .frame(width: 3)

            Text(text)
                .font(NothingTypography.technicalMono(size: 9, weight: .regular))
                .foregroundStyle(NothingPalette.pureWhite)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(NothingPalette.surfaceElevated.opacity(0.8))
        .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
    }

    // MARK: - Nested Server Node Row

    private func serverNodeRow(_ node: ProxyNode) -> some View {
        let isSelected = vpnManager.selectedNode?.id == node.id

        return Button {
            vpnManager.selectNode(node.id)
        } label: {
            HStack(spacing: 10) {
                // Country Flag or Globe Icon
                Text(Self.countryFlagOrIcon(for: node.remark))
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)

                // Server Name and Badge Line
                VStack(alignment: .leading, spacing: 3) {
                    Text(node.remark)
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
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
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
        VStack(alignment: .trailing, spacing: 3) {
            if let latencyMs {
                Text("\(latencyMs) MS")
                    .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                    .foregroundStyle(latencyMs < 100 ? NothingPalette.pureWhite : theme.accentColor)
            } else {
                Text("-- MS")
                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                    .foregroundStyle(NothingPalette.mutedGrey)
            }

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { bar in
                    let isLit = Self.isSignalBarLit(barIndex: bar, latencyMs: latencyMs)
                    Rectangle()
                        .fill(isLit ? (latencyMs ?? 999 < 100 ? NothingPalette.pureWhite : theme.accentColor) : NothingPalette.dimMatrixDot)
                        .frame(width: 3, height: CGFloat(4 + bar * 3))
                }
            }
        }
    }

    // MARK: - Metric Helpers

    private func speedMetricBlock(
        arrowSymbol: String,
        title: String,
        value: String,
        isActive: Bool,
        accentColor: Color
    ) -> some View {
        HStack(spacing: 8) {
            Text(arrowSymbol)
                .font(NothingTypography.technicalMono(size: 13, weight: .black))
                .foregroundStyle(isActive ? accentColor : NothingPalette.mutedGrey)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NothingTypography.technicalMono(size: 8, weight: .semibold))
                    .foregroundStyle(NothingPalette.mutedGrey)
                    .tracking(0.8)

                Text(value)
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func volumeMetricColumn(label: String, value: String, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(NothingTypography.technicalMono(size: 8, weight: .regular))
                .foregroundStyle(NothingPalette.mutedGrey)
                .lineLimit(1)

            Text(value)
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(isActive ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diagnosticBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(theme.accentColor)
                .frame(width: 3, height: 26)

            Text(message)
                .font(NothingTypography.technicalMono(size: 10, weight: .medium))
                .foregroundStyle(NothingPalette.pureWhite)
                .lineLimit(2)

            Spacer()

            Button {
                vpnManager.statusBannerMessage = nil
            } label: {
                Text("[X]")
                    .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NothingPalette.surfaceElevated)
        .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
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

    public static func countryFlagOrIcon(for remark: String) -> String {
        for scalar in remark.unicodeScalars {
            if scalar.properties.isEmoji && (0x1F1E6...0x1F1FF).contains(scalar.value) {
                return String(remark.filter { $0.isEmoji })
            }
        }
        let upper = remark.uppercased()
        if upper.contains("TRAFFIC") || upper.contains("LIMIT") || upper.contains("INFO") || upper.contains("GIB") || upper.contains("GB") {
            return "🌐"
        }
        if upper.contains("FINLAND") || upper.contains(" FI ") || upper.hasPrefix("FI-") || upper.hasPrefix("FI ") { return "🇫🇮" }
        if upper.contains("GERMANY") || upper.contains(" DE ") || upper.hasPrefix("DE-") || upper.hasPrefix("DE ") { return "🇩🇪" }
        if upper.contains("NETHERLANDS") || upper.contains(" HOLLAND") || upper.contains(" NL ") || upper.hasPrefix("NL-") { return "🇳🇱" }
        if upper.contains("RUSSIA") || upper.contains(" RU ") || upper.hasPrefix("RU-") || upper.hasPrefix("RU ") { return "🇷🇺" }
        if upper.contains("USA") || upper.contains("UNITED STATES") || upper.contains(" US ") || upper.hasPrefix("US-") { return "🇺🇸" }
        if upper.contains("UK") || upper.contains("UNITED KINGDOM") || upper.contains(" GB ") || upper.hasPrefix("GB-") { return "🇬🇧" }
        if upper.contains("TURKEY") || upper.contains(" TR ") || upper.hasPrefix("TR-") { return "🇹🇷" }
        if upper.contains("SWEDEN") || upper.contains(" SE ") || upper.hasPrefix("SE-") { return "🇸🇪" }
        if upper.contains("POLAND") || upper.contains(" PL ") || upper.hasPrefix("PL-") { return "🇵🇱" }
        if upper.contains("FRANCE") || upper.contains(" FR ") || upper.hasPrefix("FR-") { return "🇫🇷" }
        if upper.contains("SINGAPORE") || upper.contains(" SG ") || upper.hasPrefix("SG-") { return "🇸🇬" }
        if upper.contains("JAPAN") || upper.contains(" JP ") || upper.hasPrefix("JP-") { return "🇯🇵" }
        if upper.contains("KAZAKHSTAN") || upper.contains(" KZ ") || upper.hasPrefix("KZ-") { return "🇰🇿" }
        return "🌐"
    }

    public static func nodeBadgeLine(for node: ProxyNode) -> String {
        var parts: [String] = [node.protocolType.badgeLabel]
        parts.append(node.transport.rawValue.uppercased())
        if node.security == .reality {
            parts.append("Reality")
        } else if node.security == .tls {
            parts.append("TLS")
        }
        return parts.joined(separator: " | ")
    }

    public static func formatSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }

    public static func formatQuotaDisplay(used: Int64, total: Int64?) -> String {
        let usedGB = Double(used) / (1024.0 * 1024.0 * 1024.0)
        let formattedUsed = usedGB < 1.0 ? String(format: "%.1f GB", max(0.1, usedGB)) : String(format: "%.0f GB", usedGB)

        guard let total, total > 0 else {
            return "\(formattedUsed)/∞"
        }
        let totalGB = Double(total) / (1024.0 * 1024.0 * 1024.0)
        let formattedTotal = totalGB < 1.0 ? String(format: "%.1f GB", totalGB) : String(format: "%.0f GB", totalGB)
        return "\(formattedUsed)/\(formattedTotal)"
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
