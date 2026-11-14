import SwiftUI
import UIKit

// MARK: - Tab 02: SETTINGS (Native Apple InsetGrouped Form + Nothing OS Aesthetics)

public struct SettingsView: View {
    @Bindable var vpnManager: VPNTunnelManager
    @Bindable var localization: LocalizationManager

    @State private var theme = ThemeManager.shared
    @State private var showLogsSheet: Bool = false
    @State private var hwidCopied: Bool = false
    @State private var customHexInput: String = ""

    public static let marketingVersion = "0.4.0"
    public static let buildNumber = "4"

    public init(vpnManager: VPNTunnelManager, localization: LocalizationManager) {
        self.vpnManager = vpnManager
        self.localization = localization
    }

    public var body: some View {
        Form {
            // 1. General & Appearance
            generalAndAppearanceSection

            // 2. Connection & Routing
            connectionAndRoutingSection

            // 3. Latency & Diagnostics
            latencyAndDiagnosticsSection

            // 4. Subscriptions & Compatibility
            subscriptionsAndCompatibilitySection

            // 5. Support Authors
            supportAuthorsSection

            // 6. Centered Version & Attribution Footer
            versionFooterSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(NothingPalette.trueBlack.ignoresSafeArea())
        .navigationTitle(localization.tr("tab.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogsSheet) {
            ConnectionLogsView(vpnManager: vpnManager, localization: localization)
        }
        .onAppear {
            customHexInput = theme.accentHex
        }
    }

    // MARK: - 1. General & Appearance Section

    private var generalAndAppearanceSection: some View {
        Section {
            // Language selector
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Язык интерфейса" : "Language")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Picker("", selection: Binding(
                    get: { localization.selectedOption },
                    set: { localization.selectedOption = $0 }
                )) {
                    ForEach(AppLanguageOption.allCases) { option in
                        Text(localization.tr(option.titleKey)).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)

            // Accent Theme Color Picker (defaulting to Red #D71921)
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Цвет акцента" : "Accent Color")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Text(theme.accentHex)
                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                        .foregroundStyle(NothingPalette.mutedGrey)

                    ColorPicker("", selection: Binding(
                        get: { theme.accentColor },
                        set: { newColor in
                            theme.accentHex = newColor.toHex()
                            customHexInput = theme.accentHex
                        }
                    ))
                    .labelsHidden()
                }
            }
            .frame(minHeight: 44)

            // Preset Swatches Row
            HStack(spacing: 12) {
                ForEach(ThemeManager.presetSwatches, id: \.hex) { swatch in
                    let isSelected = theme.accentHex.uppercased() == swatch.hex.uppercased()
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            theme.accentHex = swatch.hex
                            customHexInput = swatch.hex
                        }
                    } label: {
                        Circle()
                            .fill(swatch.color)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .strokeBorder(isSelected ? NothingPalette.pureWhite : NothingPalette.gridStroke, lineWidth: isSelected ? 2.5 : 1)
                            )
                            .overlay(
                                Circle()
                                    .fill(NothingPalette.pureWhite)
                                    .frame(width: 6, height: 6)
                                    .opacity(isSelected ? 1.0 : 0.0)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
            .frame(minHeight: 44)

            // Rounded Corners toggle (Containers only — never icons)
            HStack(spacing: 12) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Скругленные углы" : "Rounded Corners")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { theme.isRoundedCorners },
                    set: { theme.isRoundedCorners = $0 }
                ))
                .labelsHidden()
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)
        } header: {
            Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "// ОСНОВНЫЕ И ОФОРМЛЕНИЕ" : "// GENERAL & APPEARANCE")
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .foregroundStyle(NothingPalette.mutedGrey)
        }
    }

    // MARK: - 2. Connection & Routing Section

    private var connectionAndRoutingSection: some View {
        Section {
            // Routing mode
            NavigationLink {
                RoutingModeSelectionView(vpnManager: vpnManager, localization: localization)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 24, height: 24, alignment: .center)

                    Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Маршрутизация" : "Routing Mode")
                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 8)

                    Text(routingModeDisplayLabel(vpnManager.routingConfig.routingMode))
                        .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                        .foregroundStyle(theme.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(minHeight: 44)
            }

            // DNS / DoH server selection
            NavigationLink {
                DNSSelectionView(vpnManager: vpnManager, localization: localization)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "network")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 24, height: 24, alignment: .center)

                    Text("DNS / DoH Server")
                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 8)

                    Text(dnsShortDisplay(vpnManager.routingConfig.dnsProvider))
                        .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                        .foregroundStyle(NothingPalette.mutedGrey)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(minHeight: 44)
            }

            // Auto-connect / On-Demand rules
            HStack(spacing: 12) {
                Image(systemName: "bolt.shield")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Автоподключение On-Demand" : "Auto-Connect On Demand")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { vpnManager.connectionSettings.connectOnDemand },
                    set: { val in
                        var updated = vpnManager.connectionSettings
                        updated.connectOnDemand = val
                        vpnManager.updateConnectionSettings(updated)
                    }
                ))
                .labelsHidden()
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)

            // Strict Kill Switch
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text("Kill Switch")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { vpnManager.routingConfig.strictKillSwitch },
                    set: { val in
                        var updated = vpnManager.routingConfig
                        updated.strictKillSwitch = val
                        vpnManager.updateRoutingConfiguration(updated)
                    }
                ))
                .labelsHidden()
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)

            // IPv6 Routing
            HStack(spacing: 12) {
                Image(systemName: "number.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Маршрутизация IPv6" : "IPv6 Routing")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { vpnManager.routingConfig.enableIPv6Routing },
                    set: { val in
                        var updated = vpnManager.routingConfig
                        updated.enableIPv6Routing = val
                        vpnManager.updateRoutingConfiguration(updated)
                    }
                ))
                .labelsHidden()
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)
        } header: {
            Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "// ПОДКЛЮЧЕНИЕ И МАРШРУТИЗАЦИЯ" : "// CONNECTION & ROUTING")
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .foregroundStyle(NothingPalette.mutedGrey)
        }
    }

    // MARK: - 3. Latency & Diagnostics Section

    private var latencyAndDiagnosticsSection: some View {
        Section {
            // Ping method selector
            HStack(spacing: 12) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Метод пинга" : "Ping Method")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Picker("", selection: Binding(
                    get: { vpnManager.pingSettings.method },
                    set: { val in
                        var updated = vpnManager.pingSettings
                        updated.method = val
                        vpnManager.updatePingSettings(updated)
                    }
                )) {
                    Text("TCP Ping").tag(PingMeasurementMethod.tcp)
                    Text("URL Test").tag(PingMeasurementMethod.urlTest)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
            }
            .frame(minHeight: 44)

            // Test endpoint URL
            HStack(spacing: 12) {
                Image(systemName: "link")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Тестовый URL" : "Test Endpoint")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Picker("", selection: Binding(
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
                .pickerStyle(.menu)
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)

            // Connection logs viewer
            Button {
                showLogsSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 24, height: 24, alignment: .center)

                    Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Журнал и конфиг ядра" : "Connection Logs & Core")
                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                        .foregroundStyle(NothingPalette.pureWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            // Test all latencies action row
            Button {
                Task {
                    await vpnManager.measureAllNodeLatencies()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 24, height: 24, alignment: .center)

                    Text(vpnManager.isPingingAll
                        ? (localization.selectedOption.resolvedLanguageCode == "ru" ? "[ИЗМЕРЕНИЕ...]" : "[TESTING...]")
                        : (localization.selectedOption.resolvedLanguageCode == "ru" ? "Измерить задержку всех" : "Test All Latencies Now"))
                        .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 8)

                    if vpnManager.isPingingAll {
                        ProgressView().tint(theme.accentColor)
                    }
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(vpnManager.isPingingAll)
        } header: {
            Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "// ЗАДЕРЖКА И ДИАГНОСТИКА" : "// LATENCY & DIAGNOSTICS")
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .foregroundStyle(NothingPalette.mutedGrey)
        }
    }

    // MARK: - 4. Subscriptions & Compatibility Section

    private var subscriptionsAndCompatibilitySection: some View {
        Section {
            // Happ client masquerading toggle
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Маскировка под Happ" : "Happ Client Masquerade")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { vpnManager.subscriptionSettings.enableHappMasquerading },
                    set: { val in
                        var updated = vpnManager.subscriptionSettings
                        updated.enableHappMasquerading = val
                        vpnManager.updateSubscriptionSettings(updated)
                    }
                ))
                .labelsHidden()
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)

            // X-HWID copy & regenerate
            HStack(spacing: 12) {
                Image(systemName: "cpu")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text("X-HWID")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Text(hwidShortDisplay(vpnManager.hwid))
                        .font(NothingTypography.technicalMono(size: 10, weight: .medium))
                        .foregroundStyle(NothingPalette.mutedGrey)
                        .lineLimit(1)

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

                    Menu {
                        Button(role: .destructive) {
                            vpnManager.regenerateHWID()
                        } label: {
                            Label("Regenerate HWID", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.mutedGrey)
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .frame(minHeight: 44)

            // Auto-update interval
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Интервал автообновления" : "Auto-Update Interval")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Picker("", selection: Binding(
                    get: { vpnManager.subscriptionSettings.updateIntervalHours },
                    set: { val in
                        var updated = vpnManager.subscriptionSettings
                        updated.updateIntervalHours = val
                        vpnManager.updateSubscriptionSettings(updated)
                    }
                )) {
                    Text("1 Hour").tag(1)
                    Text("3 Hours").tag(3)
                    Text("6 Hours").tag(6)
                    Text("12 Hours").tag(12)
                    Text("24 Hours").tag(24)
                }
                .pickerStyle(.menu)
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)

            // Update on app launch
            HStack(spacing: 12) {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                    .frame(width: 24, height: 24, alignment: .center)

                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Обновлять при запуске" : "Update On Launch")
                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                    .foregroundStyle(NothingPalette.pureWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { vpnManager.subscriptionSettings.autoUpdateOnLaunch },
                    set: { val in
                        var updated = vpnManager.subscriptionSettings
                        updated.autoUpdateOnLaunch = val
                        vpnManager.updateSubscriptionSettings(updated)
                    }
                ))
                .labelsHidden()
                .tint(theme.accentColor)
            }
            .frame(minHeight: 44)
        } header: {
            Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "// ПОДПИСКИ И СОВМЕСТИМОСТЬ" : "// SUBSCRIPTIONS & COMPATIBILITY")
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .foregroundStyle(NothingPalette.mutedGrey)
        }
    }

    // MARK: - 5. Support Authors Section

    private var supportAuthorsSection: some View {
        Section {
            Link(destination: URL(string: "https://pay.cloudtips.ru/p/feaf1b8f")!) {
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 24, height: 24, alignment: .center)

                    HStack(spacing: 6) {
                        Text("scrt")
                            .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)

                        Text("—")
                            .font(NothingTypography.technicalMono(size: 12, weight: .medium))
                            .foregroundStyle(NothingPalette.mutedGrey)

                        Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Автор идеи" : "Idea Author")
                            .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                            .foregroundStyle(NothingPalette.mutedGrey)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                    Spacer(minLength: 8)

                    Text("↗")
                        .font(NothingTypography.technicalMono(size: 14, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                }
                .frame(minHeight: 44)
            }

            Link(destination: URL(string: "https://pay.cloudtips.ru/p/450b8509")!) {
                HStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                        .frame(width: 24, height: 24, alignment: .center)

                    HStack(spacing: 6) {
                        Text("Vitya#kolbaska")
                            .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)

                        Text("—")
                            .font(NothingTypography.technicalMono(size: 12, weight: .medium))
                            .foregroundStyle(NothingPalette.mutedGrey)

                        Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "Разработчик приложения" : "App Developer")
                            .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                            .foregroundStyle(NothingPalette.mutedGrey)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                    Spacer(minLength: 8)

                    Text("↗")
                        .font(NothingTypography.technicalMono(size: 14, weight: .bold))
                        .foregroundStyle(theme.accentColor)
                }
                .frame(minHeight: 44)
            }
        } header: {
            Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "// ПОДДЕРЖКА АВТОРОВ" : "// SUPPORT AUTHORS")
                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                .foregroundStyle(NothingPalette.mutedGrey)
        }
    }

    // MARK: - 6. Centered Version & Attribution Footer

    private var versionFooterSection: some View {
        Section {
            VStack(spacing: 6) {
                NothingDotMatrixLabel(
                    text: "NORTHY",
                    dotSize: 2.2,
                    spacing: 1.1,
                    activeColor: NothingPalette.pureWhite
                )

                Text("VERSION 0.4.0 // BUILD 4")
                    .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                    .foregroundStyle(theme.accentColor)
                    .tracking(1.4)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 14)
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Helpers

    private func hwidShortDisplay(_ hwid: String) -> String {
        if hwid.count > 12 {
            return "\(hwid.prefix(6))...\(hwid.suffix(4))"
        }
        return hwid
    }

    private func routingModeDisplayLabel(_ mode: RoutingMode) -> String {
        switch mode {
        case .globalTunnel:
            return localization.selectedOption.resolvedLanguageCode == "ru" ? "GLOBAL" : "GLOBAL"
        case .splitBypassLANAndRegional:
            return localization.selectedOption.resolvedLanguageCode == "ru" ? "BYPASS LAN & RU" : "BYPASS LAN"
        case .directOnly:
            return localization.selectedOption.resolvedLanguageCode == "ru" ? "DIRECT" : "DIRECT"
        }
    }

    private func dnsShortDisplay(_ provider: DNSProviderOption) -> String {
        switch provider {
        case .cloudflare: return "CLOUDFLARE"
        case .google: return "GOOGLE"
        case .quad9: return "QUAD9"
        case .adguard: return "ADGUARD"
        }
    }
}

// MARK: - Sub-Screen 1: Routing Mode & Custom Subnets Selection

public struct RoutingModeSelectionView: View {
    @Bindable var vpnManager: VPNTunnelManager
    let localization: LocalizationManager

    @State private var newCIDRInput: String = ""

    public var body: some View {
        Form {
            Section {
                ForEach(RoutingMode.allCases, id: \.rawValue) { mode in
                    let isSelected = vpnManager.routingConfig.routingMode == mode
                    Button {
                        var updated = vpnManager.routingConfig
                        updated.routingMode = mode
                        vpnManager.updateRoutingConfiguration(updated)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: iconForMode(mode))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isSelected ? ThemeManager.shared.accentColor : NothingPalette.mutedGrey)
                                .frame(width: 24, height: 24, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(localization.tr(mode.localizationKey))
                                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text(localization.tr(mode.subtitleKey))
                                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                                    .foregroundStyle(NothingPalette.mutedGrey)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }

                            Spacer(minLength: 8)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(ThemeManager.shared.accentColor)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "// РЕЖИМ МАРШРУТИЗАЦИИ" : "// ROUTING POLICY")
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
            }

            // Custom Excluded Subnets (CIDRs)
            Section {
                HStack(spacing: 8) {
                    TextField("192.168.1.0/24", text: $newCIDRInput)
                        .font(NothingTypography.technicalMono(size: 12, weight: .medium))
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
                            .foregroundStyle(ThemeManager.shared.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .frame(minHeight: 44)

                ForEach(vpnManager.routingConfig.customExcludedCIDRs, id: \.self) { cidr in
                    HStack {
                        Text(cidr)
                            .font(NothingTypography.technicalMono(size: 12, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            var updated = vpnManager.routingConfig
                            updated.customExcludedCIDRs.removeAll { $0 == cidr }
                            vpnManager.updateRoutingConfiguration(updated)
                        } label: {
                            Text("[DEL]")
                                .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                                .foregroundStyle(ThemeManager.shared.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(minHeight: 44)
                }
            } header: {
                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "// ИСКЛЮЧЕННЫЕ ПОДСЕТИ (CIDR)" : "// EXCLUDED SUBNETS (CIDR)")
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(NothingPalette.trueBlack.ignoresSafeArea())
        .navigationTitle(localization.selectedOption.resolvedLanguageCode == "ru" ? "Маршрутизация" : "Routing Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func iconForMode(_ mode: RoutingMode) -> String {
        switch mode {
        case .globalTunnel: return "globe"
        case .splitBypassLANAndRegional: return "arrow.triangle.branch"
        case .directOnly: return "arrow.forward.circle"
        }
    }
}

// MARK: - Sub-Screen 2: DNS / DoH Server Selection

public struct DNSSelectionView: View {
    @Bindable var vpnManager: VPNTunnelManager
    let localization: LocalizationManager

    public var body: some View {
        Form {
            Section {
                ForEach(DNSProviderOption.allCases, id: \.rawValue) { dns in
                    let isSelected = vpnManager.routingConfig.dnsProvider == dns
                    Button {
                        var updated = vpnManager.routingConfig
                        updated.dnsProvider = dns
                        vpnManager.updateRoutingConfiguration(updated)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "network")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(isSelected ? ThemeManager.shared.accentColor : NothingPalette.mutedGrey)
                                .frame(width: 24, height: 24, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dns.displayName)
                                    .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                                    .foregroundStyle(NothingPalette.pureWhite)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                Text(dns.resolverAddresses.joined(separator: ", "))
                                    .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                                    .foregroundStyle(NothingPalette.mutedGrey)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }

                            Spacer(minLength: 8)

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(ThemeManager.shared.accentColor)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(localization.selectedOption.resolvedLanguageCode == "ru" ? "// ВЫБОР DNS-ПРОВАЙДЕРА" : "// DNS PROVIDER")
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(NothingPalette.mutedGrey)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(NothingPalette.trueBlack.ignoresSafeArea())
        .navigationTitle("DNS / DoH Server")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sub-Screen 3: Connection Logs & Xray Core Viewer

public struct ConnectionLogsView: View {
    @Bindable var vpnManager: VPNTunnelManager
    let localization: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var copied: Bool = false

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(vpnManager.isConnected ? ThemeManager.shared.accentColor : NothingPalette.mutedGrey)
                            .frame(width: 24, height: 24, alignment: .center)

                        Text("Tunnel Status")
                            .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(vpnManager.isConnected ? "CONNECTED" : "DISCONNECTED")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                            .foregroundStyle(vpnManager.isConnected ? ThemeManager.shared.accentColor : NothingPalette.mutedGrey)
                            .lineLimit(1)
                    }
                    .frame(minHeight: 44)

                    if let node = vpnManager.selectedNode {
                        HStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(ThemeManager.shared.accentColor)
                                .frame(width: 24, height: 24, alignment: .center)

                            Text("Active Node")
                                .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                                .foregroundStyle(NothingPalette.pureWhite)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text("\(node.serverHost):\(node.serverPort)")
                                .font(NothingTypography.technicalMono(size: 11, weight: .medium))
                                .foregroundStyle(NothingPalette.mutedGrey)
                                .lineLimit(1)
                        }
                        .frame(minHeight: 44)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ThemeManager.shared.accentColor)
                            .frame(width: 24, height: 24, alignment: .center)

                        Text("Core Latency")
                            .font(NothingTypography.technicalMono(size: 13, weight: .bold))
                            .foregroundStyle(NothingPalette.pureWhite)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(vpnManager.selectedNode?.latencyMs.map { "\($0) MS" } ?? "-- MS")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                            .foregroundStyle(ThemeManager.shared.accentColor)
                            .lineLimit(1)
                    }
                    .frame(minHeight: 44)
                } header: {
                    Text("// RUNTIME TELEMETRY")
                        .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                        .foregroundStyle(NothingPalette.mutedGrey)
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(vpnManager.activeCoreJSONPreview)
                            .font(NothingTypography.technicalMono(size: 10, weight: .regular))
                            .foregroundStyle(NothingPalette.pureWhite.opacity(0.9))
                            .padding(.vertical, 6)
                    }
                } header: {
                    HStack {
                        Text("// XRAY CORE CONFIGURATION")
                            .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                            .foregroundStyle(NothingPalette.mutedGrey)

                        Spacer()

                        Button {
                            UIPasteboard.general.string = vpnManager.activeCoreJSONPreview
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copied = false
                            }
                        } label: {
                            Text(copied ? "[COPIED!]" : "[COPY]")
                                .font(NothingTypography.technicalMono(size: 10, weight: .bold))
                                .foregroundStyle(ThemeManager.shared.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(NothingPalette.trueBlack.ignoresSafeArea())
            .navigationTitle("Connection Logs & Core")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("[CLOSE]") {
                        dismiss()
                    }
                    .font(NothingTypography.technicalMono(size: 11, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.accentColor)
                }
            }
        }
    }
}
