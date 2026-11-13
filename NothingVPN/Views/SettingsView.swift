import SwiftUI
import UIKit

// MARK: - Tab 02: SETTINGS (Full Happ Parity: Ping, Connection/Core, Routing, DoH DNS, Subscriptions, Language, v0.1.0)

public struct SettingsView: View {
    @Bindable var vpnManager: VPNTunnelManager
    @Bindable var localization: LocalizationManager

    @State private var showCoreJSONPreview = false

    public static let marketingVersion = "0.1.0"
    public static let buildNumber = "1"

    public init(vpnManager: VPNTunnelManager, localization: LocalizationManager) {
        self.vpnManager = vpnManager
        self.localization = localization
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                languageSwitcherSection
                pingDiagnosticsSection
                connectionAndCoreSection
                routingAndSplitTunnelSection
                dnsResolverSection
                subscriptionGroupsSection
                versionFooterBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .background(NothingPalette.trueBlack)
    }

    // MARK: - 1. Instant Language Switcher (SYSTEM / РУССКИЙ / ENGLISH)

    private var languageSwitcherSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.tr("settings.language.header"))

            NothingIndustrialCard(isHighlighted: false) {
                HStack(spacing: 8) {
                    ForEach(AppLanguageOption.allCases) { option in
                        let isSelected = localization.selectedOption == option
                        Button {
                            withAnimation(.snappy(duration: 0.16)) {
                                localization.selectedOption = option
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(localization.tr(option.titleKey))
                                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                    .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                    .tracking(1.1)

                                Rectangle()
                                    .fill(isSelected ? NothingPalette.accentRed : Color.clear)
                                    .frame(width: 14, height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 2. Happ Ping & Latency Diagnostics Settings

    private var pingDiagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.tr("settings.ping.header"))

            NothingIndustrialCard(isHighlighted: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Ping Type: TCP / VIA PROXY (HTTP 204) / ICMP
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("ping.method.header"))

                        HStack(spacing: 8) {
                            ForEach(PingMeasurementMethod.allCases, id: \.rawValue) { method in
                                let isSelected = vpnManager.pingSettings.method == method
                                Button {
                                    var updated = vpnManager.pingSettings
                                    updated.method = method
                                    vpnManager.updatePingSettings(updated)
                                } label: {
                                    Text(localization.tr(method.localizationKey))
                                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                        .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                        .overlay(
                                            Rectangle()
                                                .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Ping Test URL (HTTP 204 Endpoint)
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("ping.url.header"))

                        VStack(spacing: 6) {
                            ForEach(PingTestURLPreset.allCases, id: \.rawValue) { preset in
                                let isSelected = vpnManager.pingSettings.testURLPreset == preset
                                Button {
                                    var updated = vpnManager.pingSettings
                                    updated.testURLPreset = preset
                                    vpnManager.updatePingSettings(updated)
                                } label: {
                                    HStack(spacing: 10) {
                                        Rectangle()
                                            .fill(isSelected ? NothingPalette.accentRed : NothingPalette.dimMatrixDot)
                                            .frame(width: 7, height: 7)

                                        Text(preset.displayName)
                                            .font(NothingTypography.technicalMono(size: 10, weight: isSelected ? .bold : .regular))
                                            .foregroundStyle(isSelected ? NothingPalette.pureWhite : NothingPalette.mutedGrey)
                                            .lineLimit(1)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .frame(height: 32)
                                    .background(isSelected ? NothingPalette.surfaceElevated : NothingPalette.trueBlack)
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Timeout Selector (1.5s / 3.0s / 5.0s) & Display Format
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            subLabel(localization.tr("ping.timeout.header"))

                            HStack(spacing: 6) {
                                ForEach(HappPingSettings.availableTimeouts, id: \.self) { timeout in
                                    let isSelected = abs(vpnManager.pingSettings.timeoutSeconds - timeout) < 0.05
                                    Button {
                                        var updated = vpnManager.pingSettings
                                        updated.timeoutSeconds = timeout
                                        vpnManager.updatePingSettings(updated)
                                    } label: {
                                        Text(String(format: "%.1fS", timeout))
                                            .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                            .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 32)
                                            .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                            .overlay(
                                                Rectangle()
                                                    .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Display Format (MS + BARS vs BARS ONLY)
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("ping.display.header"))

                        HStack(spacing: 8) {
                            ForEach(PingResultDisplayMode.allCases, id: \.rawValue) { mode in
                                let isSelected = vpnManager.pingSettings.displayMode == mode
                                Button {
                                    var updated = vpnManager.pingSettings
                                    updated.displayMode = mode
                                    vpnManager.updatePingSettings(updated)
                                } label: {
                                    Text(localization.tr(mode.localizationKey))
                                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                        .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 34)
                                        .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                        .overlay(
                                            Rectangle()
                                                .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    dividerLine

                    NothingMechanicalSwitch(
                        label: localization.tr("ping.sort"),
                        isOn: Binding(
                            get: { vpnManager.pingSettings.sortNodesByLatency },
                            set: { newValue in
                                var updated = vpnManager.pingSettings
                                updated.sortNodesByLatency = newValue
                                vpnManager.updatePingSettings(updated)
                            }
                        )
                    )

                    dividerLine

                    NothingMechanicalSwitch(
                        label: localization.tr("ping.autostart"),
                        isOn: Binding(
                            get: { vpnManager.pingSettings.autoPingOnStartup },
                            set: { newValue in
                                var updated = vpnManager.pingSettings
                                updated.autoPingOnStartup = newValue
                                vpnManager.updatePingSettings(updated)
                            }
                        )
                    )
                }
            }
        }
    }

    // MARK: - 3. Happ Connection & Xray Core Settings (TUN/Proxy, Sniffing, Mux, TLS Fragment, TFO, MTU)

    private var connectionAndCoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.tr("settings.connection.header"))

            NothingIndustrialCard(isHighlighted: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Tunnel Execution Mode (TUN vs Proxy-Only)
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("connection.mode.header"))

                        VStack(spacing: 6) {
                            ForEach(TunnelExecutionMode.allCases, id: \.rawValue) { mode in
                                let isSelected = vpnManager.connectionSettings.tunnelMode == mode
                                Button {
                                    var updated = vpnManager.connectionSettings
                                    updated.tunnelMode = mode
                                    vpnManager.updateConnectionSettings(updated)
                                } label: {
                                    HStack(spacing: 10) {
                                        Rectangle()
                                            .fill(isSelected ? NothingPalette.accentRed : NothingPalette.dimMatrixDot)
                                            .frame(width: 8, height: 8)

                                        Text(localization.tr(mode.localizationKey))
                                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                            .foregroundStyle(NothingPalette.pureWhite)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: 36)
                                    .background(isSelected ? NothingPalette.surfaceElevated : NothingPalette.trueBlack)
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    dividerLine

                    // Traffic Sniffing
                    NothingMechanicalSwitch(
                        label: localization.tr("connection.sniffing"),
                        isOn: Binding(
                            get: { vpnManager.connectionSettings.enableSniffing },
                            set: { newValue in
                                var updated = vpnManager.connectionSettings
                                updated.enableSniffing = newValue
                                vpnManager.updateConnectionSettings(updated)
                            }
                        )
                    )

                    if vpnManager.connectionSettings.enableSniffing {
                        NothingMechanicalSwitch(
                            label: localization.tr("connection.sniff.override"),
                            isOn: Binding(
                                get: { vpnManager.connectionSettings.sniffOverrideDestination },
                                set: { newValue in
                                    var updated = vpnManager.connectionSettings
                                    updated.sniffOverrideDestination = newValue
                                    vpnManager.updateConnectionSettings(updated)
                                }
                            )
                        )
                    }

                    dividerLine

                    // TLS ClientHello Fragmentation (Happ DPI Bypass)
                    NothingMechanicalSwitch(
                        label: localization.tr("connection.fragment"),
                        isOn: Binding(
                            get: { vpnManager.connectionSettings.enableTLSFragment },
                            set: { newValue in
                                var updated = vpnManager.connectionSettings
                                updated.enableTLSFragment = newValue
                                vpnManager.updateConnectionSettings(updated)
                            }
                        )
                    )

                    if vpnManager.connectionSettings.enableTLSFragment {
                        VStack(alignment: .leading, spacing: 8) {
                            subLabel(localization.tr("connection.fragment.preset"))

                            HStack(spacing: 6) {
                                ForEach(TLSFragmentPreset.allCases, id: \.rawValue) { preset in
                                    let isSelected = vpnManager.connectionSettings.tlsFragmentPreset == preset
                                    Button {
                                        var updated = vpnManager.connectionSettings
                                        updated.tlsFragmentPreset = preset
                                        vpnManager.updateConnectionSettings(updated)
                                    } label: {
                                        Text(preset.label)
                                            .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                            .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 32)
                                            .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                            .overlay(
                                                Rectangle()
                                                    .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    dividerLine

                    // Mux TCP Multiplexing
                    NothingMechanicalSwitch(
                        label: localization.tr("connection.mux"),
                        isOn: Binding(
                            get: { vpnManager.connectionSettings.enableMux },
                            set: { newValue in
                                var updated = vpnManager.connectionSettings
                                updated.enableMux = newValue
                                vpnManager.updateConnectionSettings(updated)
                            }
                        )
                    )

                    dividerLine

                    // TCP Fast Open (TFO)
                    NothingMechanicalSwitch(
                        label: localization.tr("connection.tfo"),
                        isOn: Binding(
                            get: { vpnManager.connectionSettings.enableTCPFastOpen },
                            set: { newValue in
                                var updated = vpnManager.connectionSettings
                                updated.enableTCPFastOpen = newValue
                                vpnManager.updateConnectionSettings(updated)
                            }
                        )
                    )

                    dividerLine

                    // Connect On Demand
                    NothingMechanicalSwitch(
                        label: localization.tr("connection.ondemand"),
                        isOn: Binding(
                            get: { vpnManager.connectionSettings.connectOnDemand },
                            set: { newValue in
                                var updated = vpnManager.connectionSettings
                                updated.connectOnDemand = newValue
                                vpnManager.updateConnectionSettings(updated)
                            }
                        )
                    )

                    dividerLine

                    // Disconnect On Sleep
                    NothingMechanicalSwitch(
                        label: localization.tr("connection.disconnectsleep"),
                        isOn: Binding(
                            get: { vpnManager.connectionSettings.disconnectOnSleep },
                            set: { newValue in
                                var updated = vpnManager.connectionSettings
                                updated.disconnectOnSleep = newValue
                                vpnManager.updateConnectionSettings(updated)
                            }
                        )
                    )

                    dividerLine

                    // Allow Insecure TLS Certificates
                    NothingMechanicalSwitch(
                        label: localization.tr("connection.allowinsecure"),
                        isOn: Binding(
                            get: { vpnManager.connectionSettings.allowInsecureByDefault },
                            set: { newValue in
                                var updated = vpnManager.connectionSettings
                                updated.allowInsecureByDefault = newValue
                                vpnManager.updateConnectionSettings(updated)
                            }
                        )
                    )

                    dividerLine

                    // TUN MTU Selector (1280 / 1360 / 1400 / 1500)
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("connection.mtu"))

                        HStack(spacing: 6) {
                            ForEach(HappConnectionSettings.availableMTUs, id: \.self) { mtu in
                                let isSelected = vpnManager.connectionSettings.tunMTU == mtu
                                Button {
                                    var updated = vpnManager.connectionSettings
                                    updated.tunMTU = mtu
                                    vpnManager.updateConnectionSettings(updated)
                                } label: {
                                    Text("\(mtu)")
                                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                        .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 32)
                                        .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                        .overlay(
                                            Rectangle()
                                                .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Xray Domain Strategy (IPIfNonMatch / AsIs / IPOnDemand)
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("connection.domainstrategy"))

                        HStack(spacing: 6) {
                            ForEach(XrayDomainStrategy.allCases, id: \.rawValue) { strategy in
                                let isSelected = vpnManager.connectionSettings.domainStrategy == strategy
                                Button {
                                    var updated = vpnManager.connectionSettings
                                    updated.domainStrategy = strategy
                                    vpnManager.updateConnectionSettings(updated)
                                } label: {
                                    Text(strategy.rawValue.uppercased())
                                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                        .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 32)
                                        .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                        .overlay(
                                            Rectangle()
                                                .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Core Log Level (none / error / warning / info / debug)
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("connection.loglevel"))

                        HStack(spacing: 6) {
                            ForEach(XrayLogLevel.allCases, id: \.rawValue) { level in
                                let isSelected = vpnManager.connectionSettings.logLevel == level
                                Button {
                                    var updated = vpnManager.connectionSettings
                                    updated.logLevel = level
                                    vpnManager.updateConnectionSettings(updated)
                                } label: {
                                    Text(level.rawValue.uppercased())
                                        .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                        .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 30)
                                        .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                        .overlay(
                                            Rectangle()
                                                .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    dividerLine

                    // Live Generated Xray-Core JSON Inspector (Happ Config Viewer)
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            showCoreJSONPreview.toggle()
                        }
                    } label: {
                        HStack {
                            Text(localization.tr("connection.corejson.preview"))
                                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                .foregroundStyle(NothingPalette.accentRed)

                            Spacer()

                            Text(showCoreJSONPreview ? "[-]" : "[+]")
                                .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                                .foregroundStyle(NothingPalette.pureWhite)
                        }
                    }
                    .buttonStyle(.plain)

                    if showCoreJSONPreview {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("XRAY-CORE OUTBOUND CONFIG")
                                    .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                    .foregroundStyle(NothingPalette.mutedGrey)

                                Spacer()

                                Button {
                                    UIPasteboard.general.string = vpnManager.activeCoreJSONPreview
                                } label: {
                                    Text("[COPY JSON]")
                                        .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                        .foregroundStyle(NothingPalette.accentRed)
                                }
                                .buttonStyle(.plain)
                            }

                            ScrollView(.horizontal, showsIndicators: true) {
                                Text(vpnManager.activeCoreJSONPreview)
                                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                                    .foregroundStyle(NothingPalette.pureWhite)
                                    .padding(10)
                            }
                            .frame(maxHeight: 220)
                            .background(NothingPalette.trueBlack)
                            .overlay(
                                Rectangle()
                                    .strokeBorder(NothingPalette.gridStroke, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - 4. Split Tunneling & Routing Rules

    private var routingAndSplitTunnelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.tr("settings.routing.header"))

            ForEach(RoutingMode.allCases, id: \.rawValue) { mode in
                let isSelected = vpnManager.routingConfig.routingMode == mode
                Button {
                    var updated = vpnManager.routingConfig
                    updated.routingMode = mode
                    vpnManager.updateRoutingConfiguration(updated)
                } label: {
                    NothingIndustrialCard(isHighlighted: isSelected) {
                        HStack(alignment: .top, spacing: 12) {
                            Rectangle()
                                .fill(isSelected ? NothingPalette.accentRed : NothingPalette.dimMatrixDot)
                                .frame(width: 10, height: 10)
                                .padding(.top, 3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(localization.tr(mode.localizationKey))
                                    .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)
                                    .tracking(1.1)

                                Text(localization.tr(mode.subtitleKey))
                                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                                    .foregroundStyle(NothingPalette.mutedGrey)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            NothingIndustrialCard(isHighlighted: false) {
                VStack(spacing: 14) {
                    NothingMechanicalSwitch(
                        label: localization.tr("settings.killswitch"),
                        isOn: Binding(
                            get: { vpnManager.routingConfig.strictKillSwitch },
                            set: { newValue in
                                var updated = vpnManager.routingConfig
                                updated.strictKillSwitch = newValue
                                vpnManager.updateRoutingConfiguration(updated)
                            }
                        )
                    )

                    dividerLine

                    NothingMechanicalSwitch(
                        label: localization.tr("settings.ipv6"),
                        isOn: Binding(
                            get: { vpnManager.routingConfig.enableIPv6Routing },
                            set: { newValue in
                                var updated = vpnManager.routingConfig
                                updated.enableIPv6Routing = newValue
                                vpnManager.updateRoutingConfiguration(updated)
                            }
                        )
                    )
                }
            }
        }
    }

    // MARK: - 5. Custom DNS over HTTPS (DoH) Selector

    private var dnsResolverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.tr("settings.dns.header"))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(DNSProviderOption.allCases, id: \.rawValue) { dns in
                    let isSelected = vpnManager.routingConfig.dnsProvider == dns
                    Button {
                        var updated = vpnManager.routingConfig
                        updated.dnsProvider = dns
                        vpnManager.updateRoutingConfiguration(updated)
                    } label: {
                        NothingIndustrialCard(isHighlighted: isSelected) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Circle()
                                        .fill(isSelected ? NothingPalette.accentRed : NothingPalette.dimMatrixDot)
                                        .frame(width: 6, height: 6)
                                    Spacer()
                                    Text("DOH")
                                        .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                        .foregroundStyle(NothingPalette.mutedGrey)
                                }

                                Text(dns.displayName)
                                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 6. Subscription Groups & Auto-Update Settings

    private var subscriptionGroupsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(localization.tr("settings.subscriptions.header"))

                Spacer()

                if !vpnManager.subscriptions.isEmpty {
                    Button {
                        Task {
                            await vpnManager.refreshAllSubscriptions()
                        }
                    } label: {
                        Text(vpnManager.isSyncingSubscriptions ? "[SYNCING...]" : "[\(localization.tr("subscription.syncall"))]")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                            .foregroundStyle(NothingPalette.accentRed)
                    }
                    .buttonStyle(.plain)
                }
            }

            NothingIndustrialCard(isHighlighted: false) {
                VStack(alignment: .leading, spacing: 14) {
                    NothingMechanicalSwitch(
                        label: localization.tr("subscription.autoupdate"),
                        isOn: Binding(
                            get: { vpnManager.subscriptionSettings.autoUpdateOnLaunch },
                            set: { newValue in
                                var updated = vpnManager.subscriptionSettings
                                updated.autoUpdateOnLaunch = newValue
                                vpnManager.updateSubscriptionSettings(updated)
                            }
                        )
                    )

                    dividerLine

                    NothingMechanicalSwitch(
                        label: localization.tr("subscription.pingafter"),
                        isOn: Binding(
                            get: { vpnManager.subscriptionSettings.pingAfterSync },
                            set: { newValue in
                                var updated = vpnManager.subscriptionSettings
                                updated.pingAfterSync = newValue
                                vpnManager.updateSubscriptionSettings(updated)
                            }
                        )
                    )

                    dividerLine

                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("subscription.useragent"))

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 6),
                                GridItem(.flexible(), spacing: 6)
                            ],
                            spacing: 6
                        ) {
                            ForEach(SubscriptionUserAgentProfile.allCases, id: \.rawValue) { profile in
                                let isSelected = vpnManager.subscriptionSettings.userAgentProfile == profile
                                Button {
                                    var updated = vpnManager.subscriptionSettings
                                    updated.userAgentProfile = profile
                                    vpnManager.updateSubscriptionSettings(updated)
                                } label: {
                                    Text(profile.shortLabel)
                                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                        .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 32)
                                        .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                        .overlay(
                                            Rectangle()
                                                .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if vpnManager.subscriptions.isEmpty {
                NothingIndustrialCard(isHighlighted: false) {
                    Text(localization.tr("settings.subscriptions.empty"))
                        .font(NothingTypography.technicalMono(size: 11, weight: .regular))
                        .foregroundStyle(NothingPalette.mutedGrey)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(vpnManager.subscriptions) { sub in
                    NothingIndustrialCard(isHighlighted: false) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(sub.title) // [\(sub.nodeCount) NODES]")
                                    .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)

                                Text(sub.urlString)
                                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                                    .foregroundStyle(NothingPalette.mutedGrey)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button {
                                vpnManager.removeSubscription(sub.id)
                            } label: {
                                Text("[DEL]")
                                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                    .foregroundStyle(NothingPalette.accentRed)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 7. Dot-Matrix Build Version Indicator (v0.1.0)

    private var versionFooterBadge: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(NothingPalette.gridStroke)
                .frame(height: 1)
                .padding(.top, 8)

            HStack {
                NothingDotMatrixLabel(
                    text: "V\(Self.marketingVersion)",
                    dotSize: 2.5,
                    spacing: 1.1,
                    activeColor: NothingPalette.accentRed
                )

                Spacer()

                Text("BUILD \(Self.buildNumber) // IOS 26.0 // XRAY-TUN")
                    .font(NothingTypography.technicalMono(size: 10, weight: .medium))
                    .foregroundStyle(NothingPalette.mutedGrey)
                    .tracking(1.2)
            }
        }
    }

    // MARK: - Shared Helpers

    private var dividerLine: some View {
        Rectangle()
            .fill(NothingPalette.gridStroke)
            .frame(height: 1)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text("// \(text)")
            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
            .foregroundStyle(NothingPalette.mutedGrey)
            .tracking(1.4)
    }

    private func subLabel(_ text: String) -> some View {
        Text(text)
            .font(NothingTypography.technicalMono(size: 10, weight: .semibold))
            .foregroundStyle(NothingPalette.mutedGrey)
            .tracking(1.0)
    }
}
