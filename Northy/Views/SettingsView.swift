import SwiftUI
import UIKit

// MARK: - Tab 02: SETTINGS (Appearance, Network & Routing, DNS, Diagnostics, Core/DPI, Subscriptions, Authors, About — v0.2.0)

public struct SettingsView: View {
    @Bindable var vpnManager: VPNTunnelManager
    @Bindable var localization: LocalizationManager

    @State private var theme = ThemeManager.shared
    @State private var showCoreJSONPreview = false
    @State private var customHexInput: String = ""
    @State private var newCIDRInput: String = ""

    public static let marketingVersion = "0.2.0"
    public static let buildNumber = "2"

    public init(vpnManager: VPNTunnelManager, localization: LocalizationManager) {
        self.vpnManager = vpnManager
        self.localization = localization
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                appearanceSection
                networkAndRoutingSection
                dnsResolverSection
                pingDiagnosticsSection
                connectionAndCoreSection
                subscriptionGroupsSection
                supportAuthorsSection
                languageSwitcherSection
                versionFooterBadge
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .background(NothingPalette.trueBlack)
        .onAppear {
            customHexInput = theme.accentHex
        }
    }

    // MARK: - 1. Appearance Section (Rounded Corners & Accent Theme)

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.tr("settings.appearance.header"))

            NothingIndustrialCard(isHighlighted: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Rounded Corners Toggle
                    VStack(alignment: .leading, spacing: 6) {
                        NothingMechanicalSwitch(
                            label: localization.tr("settings.appearance.rounded_corners"),
                            isOn: Binding(
                                get: { theme.isRoundedCorners },
                                set: { theme.isRoundedCorners = $0 }
                            )
                        )

                        Text(localization.tr("settings.appearance.rounded_corners_desc"))
                            .font(NothingTypography.technicalMono(size: 9, weight: .regular))
                            .foregroundStyle(NothingPalette.mutedGrey)
                            .lineLimit(2)
                    }

                    dividerLine

                    // Accent Theme Swatches
                    VStack(alignment: .leading, spacing: 10) {
                        subLabel(localization.tr("settings.appearance.accent_color"))

                        HStack(spacing: 8) {
                            ForEach(ThemeManager.presetSwatches, id: \.hex) { swatch in
                                let isSelected = theme.accentHex.uppercased() == swatch.hex.uppercased()
                                Button {
                                    withAnimation(.snappy(duration: 0.18)) {
                                        theme.accentHex = swatch.hex
                                        customHexInput = swatch.hex
                                    }
                                } label: {
                                    VStack(spacing: 5) {
                                        Circle()
                                            .fill(swatch.color)
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: isSelected ? 2 : 1)
                                            )

                                        Rectangle()
                                            .fill(isSelected ? swatch.color : Color.clear)
                                            .frame(height: 2)
                                    }
                                    .padding(.top, 6)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(isSelected ? NothingPalette.surfaceElevated : NothingPalette.trueBlack)
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Custom HEX Input & Live Swatch
                        HStack(spacing: 8) {
                            Circle()
                                .fill(theme.accentColor)
                                .frame(width: 18, height: 18)

                            TextField("#D71921", text: $customHexInput)
                                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                .foregroundStyle(NothingPalette.pureWhite)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .background(NothingPalette.surfaceElevated)
                                .overlay(
                                    Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))

                            Button {
                                if let valid = Color(hex: customHexInput) {
                                    _ = valid
                                    theme.accentHex = customHexInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                }
                            } label: {
                                Text("[SET]")
                                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)
                                    .padding(.horizontal, 12)
                                    .frame(height: 32)
                                    .background(theme.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - 2. Network & Routing Section (Global, Split LAN/RU, Direct, CIDRs, Kill Switch)

    private var networkAndRoutingSection: some View {
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
                VStack(alignment: .leading, spacing: 14) {
                    // Custom CIDR Bypass List
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("settings.routing.cidrs.header"))

                        HStack(spacing: 8) {
                            TextField("192.168.1.0/24", text: $newCIDRInput)
                                .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                                .foregroundStyle(NothingPalette.pureWhite)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(.horizontal, 10)
                                .frame(height: 32)
                                .background(NothingPalette.surfaceElevated)
                                .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))

                            Button {
                                let trimmed = newCIDRInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty && !vpnManager.routingConfig.customExcludedCIDRs.contains(trimmed) {
                                    var updated = vpnManager.routingConfig
                                    updated.customExcludedCIDRs.append(trimmed)
                                    vpnManager.updateRoutingConfiguration(updated)
                                    newCIDRInput = ""
                                }
                            } label: {
                                Text("[ADD]")
                                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)
                                    .padding(.horizontal, 10)
                                    .frame(height: 32)
                                    .background(NothingPalette.surfaceElevated)
                                    .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                            }
                            .buttonStyle(.plain)
                        }

                        if !vpnManager.routingConfig.customExcludedCIDRs.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(vpnManager.routingConfig.customExcludedCIDRs, id: \.self) { cidr in
                                        HStack(spacing: 4) {
                                            Text(cidr)
                                                .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                                .foregroundStyle(NothingPalette.pureWhite)

                                            Button {
                                                var updated = vpnManager.routingConfig
                                                updated.customExcludedCIDRs.removeAll { $0 == cidr }
                                                vpnManager.updateRoutingConfiguration(updated)
                                            } label: {
                                                Text("✕")
                                                    .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                                    .foregroundStyle(NothingPalette.accentRed)
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(NothingPalette.surfaceElevated)
                                        .overlay(Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1))
                                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                                    }
                                }
                            }
                        }
                    }

                    dividerLine

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

    // MARK: - 3. DNS Configuration (DoH & Presets)

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

    // MARK: - 4. Latency & Diagnostics Settings

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
                                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
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
                                    .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Timeout Selector
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
                                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Display Format
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
                                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
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

    // MARK: - 5. Connection, DPI Bypass & Xray Core Settings

    private var connectionAndCoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.tr("settings.connection.header"))

            NothingIndustrialCard(isHighlighted: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Tunnel Mode (TUN vs Proxy-Only)
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("connection.mode"))

                        HStack(spacing: 8) {
                            ForEach(TunnelExecutionMode.allCases, id: \.rawValue) { mode in
                                let isSelected = vpnManager.connectionSettings.tunnelMode == mode
                                Button {
                                    var updated = vpnManager.connectionSettings
                                    updated.tunnelMode = mode
                                    vpnManager.updateConnectionSettings(updated)
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
                                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    dividerLine

                    // TLS Fragmentation (DPI Bypass)
                    VStack(alignment: .leading, spacing: 8) {
                        subLabel(localization.tr("connection.tlsfragment"))

                        HStack(spacing: 6) {
                            ForEach(TLSFragmentPreset.allCases, id: \.rawValue) { preset in
                                let isSelected = vpnManager.connectionSettings.enableTLSFragment && vpnManager.connectionSettings.tlsFragmentPreset == preset
                                Button {
                                    var updated = vpnManager.connectionSettings
                                    if preset == .off {
                                        updated.enableTLSFragment = false
                                    } else {
                                        updated.enableTLSFragment = true
                                        updated.tlsFragmentPreset = preset
                                    }
                                    vpnManager.updateConnectionSettings(updated)
                                } label: {
                                    Text(preset.displayName)
                                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                        .foregroundStyle(isSelected ? NothingPalette.trueBlack : NothingPalette.pureWhite)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 32)
                                        .background(isSelected ? NothingPalette.pureWhite : NothingPalette.surfaceElevated)
                                        .overlay(
                                            Rectangle()
                                                .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                                }
                                .buttonStyle(.plain)
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

                    // TCP Fast Open
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

                    // TUN MTU Selector
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
                                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    dividerLine

                    // JSON Inspector Button
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
                            .frame(maxHeight: 200)
                            .background(NothingPalette.trueBlack)
                            .overlay(
                                Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6. Subscriptions Management

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

    // MARK: - 7. Support Authors Section (Поддержка авторов)

    private var supportAuthorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(localization.tr("settings.support.header"))

            // Card 1: scrt (Idea Author)
            Link(destination: URL(string: "https://pay.cloudtips.ru/p/feaf1b8f")!) {
                NothingIndustrialCard(isHighlighted: false) {
                    HStack(spacing: 14) {
                        ZStack {
                            Rectangle()
                                .fill(NothingPalette.surfaceElevated)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1)
                                )

                            Text("💡")
                                .font(.system(size: 18))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text("scrt")
                                    .font(NothingTypography.technicalMono(size: 14, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)

                                Text("IDEA // CONCEPT")
                                    .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(NothingPalette.trueBlack)
                                    .background(NothingPalette.pureWhite)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                            }

                            Text(localization.tr("settings.support.scrt_role"))
                                .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                                .foregroundStyle(NothingPalette.mutedGrey)
                        }

                        Spacer()

                        Text("↗")
                            .font(NothingTypography.technicalMono(size: 18, weight: .bold))
                            .foregroundStyle(NothingPalette.accentRed)
                    }
                }
            }
            .buttonStyle(.plain)

            // Card 2: Vitya#kolbaska (App Developer)
            Link(destination: URL(string: "https://pay.cloudtips.ru/p/450b8509")!) {
                NothingIndustrialCard(isHighlighted: false) {
                    HStack(spacing: 14) {
                        ZStack {
                            Rectangle()
                                .fill(NothingPalette.surfaceElevated)
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Rectangle().strokeBorder(NothingPalette.gridStroke, lineWidth: 1)
                                )

                            Text("⚡")
                                .font(.system(size: 18))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text("Vitya#kolbaska")
                                    .font(NothingTypography.technicalMono(size: 14, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)

                                Text("DEV // CODE")
                                    .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(NothingPalette.trueBlack)
                                    .background(NothingPalette.accentRed)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                            }

                            Text(localization.tr("settings.support.vitya_role"))
                                .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                                .foregroundStyle(NothingPalette.mutedGrey)
                        }

                        Spacer()

                        Text("↗")
                            .font(NothingTypography.technicalMono(size: 18, weight: .bold))
                            .foregroundStyle(NothingPalette.accentRed)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 8. Instant Language Switcher (SYSTEM / РУССКИЙ / ENGLISH)

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
                            .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 9. Dot-Matrix Build Version Indicator (v0.2.0)

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

                Text("BUILD \(Self.buildNumber) // XRAY-TUN // SWIFT 6")
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
