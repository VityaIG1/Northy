import SwiftUI

// MARK: - Northy Main Application Entry Point

@main
public struct NorthyApp: App {
    @State private var localization = LocalizationManager()
    @State private var vpnManager = VPNTunnelManager()
    @State private var theme = ThemeManager.shared
    @State private var activeTab: NothingNavigationTab = .servers

    public init() {
        SharedTunnelLogger.log("Northy app launched. Version: 0.4.0 (Build 4)", tag: "APP")
    }

    public var body: some Scene {
        WindowGroup {
            NothingRootShellView(
                vpnManager: vpnManager,
                localization: localization,
                theme: theme,
                activeTab: $activeTab
            )
            .preferredColorScheme(.dark)
            .environment(\.locale, localization.activeLocale)
        }
    }
}

public struct NothingRootShellView: View {
    @Bindable var vpnManager: VPNTunnelManager
    @Bindable var localization: LocalizationManager
    @Bindable var theme: ThemeManager
    @Binding var activeTab: NothingNavigationTab

    public var body: some View {
        TabView(selection: $activeTab) {
            NavigationStack {
                ServersView(
                    vpnManager: vpnManager,
                    localization: localization,
                    onOpenSettings: { activeTab = .settings }
                )
            }
            .tabItem {
                Label(localization.tr("tab.servers"), systemImage: "network")
            }
            .tag(NothingNavigationTab.servers)

            NavigationStack {
                SettingsView(
                    vpnManager: vpnManager,
                    localization: localization
                )
            }
            .tabItem {
                Label(localization.tr("tab.settings"), systemImage: "gearshape")
            }
            .tag(NothingNavigationTab.settings)
        }
        .tint(theme.accentColor)
        .onAppear {
            theme.applyUIKitAppearance()
        }
        .onChange(of: theme.accentHex) { _, _ in
            theme.applyUIKitAppearance()
        }
    }
}
