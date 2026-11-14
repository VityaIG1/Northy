import SwiftUI
import UIKit

// MARK: - Tab 02: SETTINGS (Native Apple InsetGrouped Form + Nothing OS Hybrid Styling — v0.3.0)

public struct SettingsView: View {
    @Bindable var vpnManager: VPNTunnelManager
    @Bindable var localization: LocalizationManager

    @State private var theme = ThemeManager.shared
    @State private var showCoreJSONPreview = false
    @State private var customHexInput: String = ""
    @State private var newCIDRInput: String = ""
    @State private var customUAText: String = ""
    @State private var hwidCopied: Bool = false

    public static let marketingVersion = "0.3.0"
    public static let buildNumber = "3"

    public init(vpnManager: VPNTunnelManager, localization: LocalizationManager) {
        self.vpnManager = vpnManager
        self.localization = localization
    }

    public var body: some View {
        Form {
            appearanceSection
            networkAndRoutingSection
            dnsResolverSection
            pingDiagnosticsSection
            connectionAndCoreSection
            subscriptionGroupsSection
            supportAuthorsSection
            openSourceLicensesSection
            languageSwitcherSection
            versionFooterSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(NothingPalette.trueBlack.ignoresSafeArea())
        .navigationTitle(localization.tr("tab.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCoreJSONPreview) {
            coreJSONPreviewSheet
        }
        .onAppear {
            customHexInput = theme.accentHex
            customUAText = vpnManager.subscriptionSettings.customUserAgent ?? ""
        }
    }

    // MARK: - 1. Appearance Section (Native Toggle, ColorPicker & Swatches)

    private var appearanceSection: some View {
        Section(header: Text("// \(localization.tr("settings.appearance.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            // Rounded corners toggle
            Toggle(isOn: Binding(
                get: { theme.isRoundedCorners },
                set: { theme.isRoundedCorners = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.tr("settings.appearance.rounded_corners"))
                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                    Text(localization.tr("settings.appearance.rounded_corners_desc"))
                        .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }
            }
            .tint(theme.accentColor)

            // Native Apple ColorPicker row
            ColorPicker(selection: Binding(
                get: { theme.accentColor },
                set: { newColor in
                    theme.accentHex = newColor.toHex()
                    customHexInput = theme.accentHex
                }
            )) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 14, height: 14)
                    Text(localization.tr("settings.appearance.accent_color"))
                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                }
            }

            // Preset Swatches
            HStack(spacing: 8) {
                ForEach(ThemeManager.presetSwatches, id: \.hex) { swatch in
                    let isSelected = theme.accentHex.uppercased() == swatch.hex.uppercased()
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            theme.accentHex = swatch.hex
                            customHexInput = swatch.hex
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(swatch.color)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle().strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: isSelected ? 2 : 1)
                                )
                            Rectangle()
                                .fill(isSelected ? swatch.color : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(isSelected ? NothingPalette.surfaceElevated : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Hex Code Input
            HStack(spacing: 8) {
                TextField("#D71921", text: $customHexInput)
                    .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)

                Button {
                    if Color(hex: customHexInput) != nil {
                        theme.accentHex = customHexInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    }
                } label: {
                    Text("[SET]")
                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: theme.chipCornerRadius))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 2. Network & Routing Section

    private var networkAndRoutingSection: some View {
        Section(header: Text("// \(localization.tr("settings.routing.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            Picker(localization.tr("settings.routing.header"), selection: Binding(
                get: { vpnManager.routingConfig.routingMode },
                set: { mode in
                    var updated = vpnManager.routingConfig
                    updated.routingMode = mode
                    vpnManager.updateRoutingConfiguration(updated)
                }
            )) {
                ForEach(RoutingMode.allCases, id: \.rawValue) { mode in
                    Text(localization.tr(mode.localizationKey)).tag(mode)
                }
            }
            .pickerStyle(.navigationLink)

            // Kill Switch
            Toggle(isOn: Binding(
                get: { vpnManager.routingConfig.strictKillSwitch },
                set: { val in
                    var updated = vpnManager.routingConfig
                    updated.strictKillSwitch = val
                    vpnManager.updateRoutingConfiguration(updated)
                }
            )) {
                Text(localization.tr("settings.killswitch"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            // IPv6 Routing
            Toggle(isOn: Binding(
                get: { vpnManager.routingConfig.enableIPv6Routing },
                set: { val in
                    var updated = vpnManager.routingConfig
                    updated.enableIPv6Routing = val
                    vpnManager.updateRoutingConfiguration(updated)
                }
            )) {
                Text(localization.tr("settings.ipv6"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            // Custom CIDRs
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("192.168.1.0/24", text: $newCIDRInput)
                        .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                        .foregroundStyle(NothingPalette.pureWhite)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

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
                            .foregroundStyle(theme.accentColor)
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
                                            .foregroundStyle(theme.accentColor)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(NothingPalette.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 3. DNS Resolver Section

    private var dnsResolverSection: some View {
        Section(header: Text("// \(localization.tr("settings.dns.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            Picker(localization.tr("settings.dns.header"), selection: Binding(
                get: { vpnManager.routingConfig.dnsProvider },
                set: { val in
                    var updated = vpnManager.routingConfig
                    updated.dnsProvider = val
                    vpnManager.updateRoutingConfiguration(updated)
                }
            )) {
                ForEach(DNSProviderOption.allCases, id: \.rawValue) { dns in
                    Text(dns.displayName).tag(dns)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    // MARK: - 4. Ping Diagnostics & Latency Section

    private var pingDiagnosticsSection: some View {
        Section(header: Text("// \(localization.tr("settings.ping.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            Picker(localization.tr("ping.method.header"), selection: Binding(
                get: { vpnManager.pingSettings.method },
                set: { val in
                    var updated = vpnManager.pingSettings
                    updated.method = val
                    vpnManager.updatePingSettings(updated)
                }
            )) {
                ForEach(PingMeasurementMethod.allCases, id: \.rawValue) { m in
                    Text(localization.tr(m.localizationKey)).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Picker(localization.tr("ping.url.header"), selection: Binding(
                get: { vpnManager.pingSettings.testURLPreset },
                set: { val in
                    var updated = vpnManager.pingSettings
                    updated.testURLPreset = val
                    vpnManager.updatePingSettings(updated)
                }
            )) {
                ForEach(PingTestURLPreset.allCases, id: \.rawValue) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.navigationLink)

            Picker(localization.tr("ping.timeout.header"), selection: Binding(
                get: { vpnManager.pingSettings.timeoutSeconds },
                set: { val in
                    var updated = vpnManager.pingSettings
                    updated.timeoutSeconds = val
                    vpnManager.updatePingSettings(updated)
                }
            )) {
                ForEach(HappPingSettings.availableTimeouts, id: \.self) { timeout in
                    Text(String(format: "%.1fS", timeout)).tag(timeout)
                }
            }

            Toggle(isOn: Binding(
                get: { vpnManager.pingSettings.sortNodesByLatency },
                set: { val in
                    var updated = vpnManager.pingSettings
                    updated.sortNodesByLatency = val
                    vpnManager.updatePingSettings(updated)
                }
            )) {
                Text(localization.tr("ping.sort"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            Toggle(isOn: Binding(
                get: { vpnManager.pingSettings.autoPingOnStartup },
                set: { val in
                    var updated = vpnManager.pingSettings
                    updated.autoPingOnStartup = val
                    vpnManager.updatePingSettings(updated)
                }
            )) {
                Text(localization.tr("ping.autostart"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            Button {
                Task {
                    await vpnManager.measureAllNodeLatencies()
                }
            } label: {
                HStack {
                    Text(vpnManager.isPingingAll ? "[PINGING...]" : "[TEST ALL LATENCIES NOW]")
                        .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                    Spacer()
                    if vpnManager.isPingingAll {
                        ProgressView().tint(theme.accentColor)
                    }
                }
            }
        }
    }

    // MARK: - 5. Connection, DPI Bypass & Xray Core Section

    private var connectionAndCoreSection: some View {
        Section(header: Text("// \(localization.tr("settings.connection.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            Picker(localization.tr("connection.mode"), selection: Binding(
                get: { vpnManager.connectionSettings.tunnelMode },
                set: { val in
                    var updated = vpnManager.connectionSettings
                    updated.tunnelMode = val
                    vpnManager.updateConnectionSettings(updated)
                }
            )) {
                ForEach(TunnelExecutionMode.allCases, id: \.rawValue) { mode in
                    Text(localization.tr(mode.localizationKey)).tag(mode)
                }
            }

            Toggle(isOn: Binding(
                get: { vpnManager.connectionSettings.enableTLSFragment },
                set: { val in
                    var updated = vpnManager.connectionSettings
                    updated.enableTLSFragment = val
                    vpnManager.updateConnectionSettings(updated)
                }
            )) {
                Text(localization.tr("connection.tlsfragment"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            if vpnManager.connectionSettings.enableTLSFragment {
                Picker("TLS Fragment Preset", selection: Binding(
                    get: { vpnManager.connectionSettings.tlsFragmentPreset },
                    set: { val in
                        var updated = vpnManager.connectionSettings
                        updated.tlsFragmentPreset = val
                        vpnManager.updateConnectionSettings(updated)
                    }
                )) {
                    ForEach(TLSFragmentPreset.allCases, id: \.rawValue) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
            }

            Toggle(isOn: Binding(
                get: { vpnManager.connectionSettings.enableMux },
                set: { val in
                    var updated = vpnManager.connectionSettings
                    updated.enableMux = val
                    vpnManager.updateConnectionSettings(updated)
                }
            )) {
                Text(localization.tr("connection.mux"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            Toggle(isOn: Binding(
                get: { vpnManager.connectionSettings.enableTCPFastOpen },
                set: { val in
                    var updated = vpnManager.connectionSettings
                    updated.enableTCPFastOpen = val
                    vpnManager.updateConnectionSettings(updated)
                }
            )) {
                Text(localization.tr("connection.tfo"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            Picker(localization.tr("connection.mtu"), selection: Binding(
                get: { vpnManager.connectionSettings.tunMTU },
                set: { val in
                    var updated = vpnManager.connectionSettings
                    updated.tunMTU = val
                    vpnManager.updateConnectionSettings(updated)
                }
            )) {
                ForEach(HappConnectionSettings.availableMTUs, id: \.self) { mtu in
                    Text("\(mtu)").tag(mtu)
                }
            }

            Button {
                showCoreJSONPreview = true
            } label: {
                Text(localization.tr("connection.corejson.preview"))
                    .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                    .foregroundStyle(theme.accentColor)
            }
        }
    }

    // MARK: - 6. Subscriptions Management Section

    private var subscriptionGroupsSection: some View {
        Section(header: Text("// \(localization.tr("settings.subscriptions.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            Toggle(isOn: Binding(
                get: { vpnManager.subscriptionSettings.enableHappMasquerading },
                set: { val in
                    var updated = vpnManager.subscriptionSettings
                    updated.enableHappMasquerading = val
                    vpnManager.updateSubscriptionSettings(updated)
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.tr("subscription.happ_masquerade"))
                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                    Text(localization.tr("subscription.happ_masquerade_desc"))
                        .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }
            }
            .tint(theme.accentColor)

            if vpnManager.subscriptionSettings.enableHappMasquerading {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.tr("subscription.hwid"))
                            .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                            .foregroundStyle(NothingPalette.mutedGrey)
                        Text(vpnManager.hwid)
                            .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        UIPasteboard.general.string = vpnManager.hwid
                        hwidCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            hwidCopied = false
                        }
                    } label: {
                        Text(hwidCopied ? "[COPIED!]" : "[COPY]")
                            .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                            .foregroundStyle(theme.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                Picker(localization.tr("subscription.custom_ua"), selection: Binding(
                    get: { vpnManager.subscriptionSettings.userAgentProfile },
                    set: { profile in
                        var updated = vpnManager.subscriptionSettings
                        updated.userAgentProfile = profile
                        vpnManager.updateSubscriptionSettings(updated)
                    }
                )) {
                    ForEach(SubscriptionUserAgentProfile.allCases, id: \.self) { profile in
                        Text(profile.shortLabel).tag(profile)
                    }
                }
            }

            Toggle(isOn: Binding(
                get: { vpnManager.subscriptionSettings.autoUpdateOnLaunch },
                set: { val in
                    var updated = vpnManager.subscriptionSettings
                    updated.autoUpdateOnLaunch = val
                    vpnManager.updateSubscriptionSettings(updated)
                }
            )) {
                Text(localization.tr("subscription.autoupdate"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            Toggle(isOn: Binding(
                get: { vpnManager.subscriptionSettings.pingAfterSync },
                set: { val in
                    var updated = vpnManager.subscriptionSettings
                    updated.pingAfterSync = val
                    vpnManager.updateSubscriptionSettings(updated)
                }
            )) {
                Text(localization.tr("subscription.pingafter"))
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
            }
            .tint(theme.accentColor)

            Button {
                Task {
                    await vpnManager.refreshAllSubscriptions()
                }
            } label: {
                HStack {
                    Text(vpnManager.isSyncingSubscriptions ? "[SYNCING...]" : "[\(localization.tr("subscription.syncall"))]")
                        .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                    Spacer()
                    if vpnManager.isSyncingSubscriptions {
                        ProgressView().tint(theme.accentColor)
                    }
                }
            }

            ForEach(vpnManager.subscriptions) { sub in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sub.title)
                            .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                        Text("[\(sub.nodeCount) NODES]")
                            .font(NothingTypography.technicalMono(size: 10, weight: .medium))
                            .foregroundStyle(NothingPalette.mutedGrey)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        vpnManager.removeSubscription(sub.id)
                    } label: {
                        Text("[DEL]")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                            .foregroundStyle(theme.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 7. Support Authors Section

    private var supportAuthorsSection: some View {
        Section(header: Text("// \(localization.tr("settings.support.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            Link(destination: URL(string: "https://pay.cloudtips.ru/p/feaf1b8f")!) {
                HStack(spacing: 12) {
                    Text("💡")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("scrt // IDEA & CONCEPT")
                            .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                        Text(localization.tr("settings.support.scrt_role"))
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.mutedGrey)
                    }
                    Spacer()
                    Text("↗")
                        .font(NothingTypography.technicalMono(size: 14, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                }
            }

            Link(destination: URL(string: "https://pay.cloudtips.ru/p/450b8509")!) {
                HStack(spacing: 12) {
                    Text("⚡")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vitya#kolbaska // DEV & CODE")
                            .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                        Text(localization.tr("settings.support.vitya_role"))
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.mutedGrey)
                    }
                    Spacer()
                    Text("↗")
                        .font(NothingTypography.technicalMono(size: 14, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                }
            }
        }
    }

    // MARK: - 8. Open Source Licenses & Upstream Attribution

    private var openSourceLicensesSection: some View {
        Section(header: Text("// \(localization.tr("settings.licenses.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            Link(destination: URL(string: "https://github.com/INCY-DEV")!) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("INCY CORE")
                                .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                                .foregroundStyle(NothingPalette.pureWhite)
                            Text("MIT")
                                .font(NothingTypography.technicalMono(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .background(NothingPalette.pureWhite)
                                .foregroundStyle(NothingPalette.trueBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Text("Fork of open-source Incy client powered by Xray-core.")
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.mutedGrey)
                    }
                    Spacer()
                    Text("GITHUB ↗")
                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                }
            }
        }
    }

    // MARK: - 9. Language Switcher Section

    private var languageSwitcherSection: some View {
        Section(header: Text("// \(localization.tr("settings.language.header"))").font(NothingTypography.technicalMono(size: 11, weight: .bold)).foregroundStyle(NothingPalette.mutedGrey)) {
            Picker(localization.tr("settings.language.header"), selection: Binding(
                get: { localization.selectedOption },
                set: { localization.selectedOption = $0 }
            )) {
                ForEach(AppLanguageOption.allCases) { option in
                    Text(localization.tr(option.titleKey)).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 10. Version & Build Footer

    private var versionFooterSection: some View {
        Section {
            VStack(alignment: .center, spacing: 6) {
                HStack {
                    NothingDotMatrixLabel(
                        text: "V\(Self.marketingVersion)",
                        dotSize: 2.2,
                        spacing: 1.0,
                        activeColor: theme.accentColor
                    )
                    Spacer()
                    Text("BUILD \(Self.buildNumber) // XRAY-TUN // SWIFT 6")
                        .font(NothingTypography.technicalMono(size: 10, weight: .medium))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }
                HStack {
                    Text("Fork of incy")
                        .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                    Spacer()
                    Text("OPEN SOURCE // CORE ENGINE")
                        .font(NothingTypography.technicalMono(size: 9, weight: .regular))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Core JSON Preview Sheet

    private var coreJSONPreviewSheet: some View {
        NavigationStack {
            ScrollView {
                Text(vpnManager.activeCoreJSONPreview)
                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .padding(14)
            }
            .background(NothingPalette.trueBlack)
            .navigationTitle("// XRAY CONFIG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("[COPY]") {
                        UIPasteboard.general.string = vpnManager.activeCoreJSONPreview
                    }
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(theme.accentColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("[CLOSE]") {
                        showCoreJSONPreview = false
                    }
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                }
            }
        }
    }
}
