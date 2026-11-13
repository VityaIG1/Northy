import SwiftUI

// MARK: - NothingVPN Main Application Entry Point (iOS 26.0+)

@main
public struct NothingVPNApp: App {
    @State private var localization = LocalizationManager()
    @State private var vpnManager = VPNTunnelManager()
    @State private var activeTab: NothingNavigationTab = .servers

    public init() {}

    public var body: some Scene {
        WindowGroup {
            NothingRootShellView(
                vpnManager: vpnManager,
                localization: localization,
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
    @Binding var activeTab: NothingNavigationTab

    public var body: some View {
        VStack(spacing: 0) {
            Group {
                switch activeTab {
                case .servers:
                    ServersView(
                        vpnManager: vpnManager,
                        localization: localization
                    )
                case .settings:
                    SettingsView(
                        vpnManager: vpnManager,
                        localization: localization
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            NothingBottomTabBar(
                activeTab: $activeTab,
                serversTitle: localization.tr("tab.servers"),
                settingsTitle: localization.tr("tab.settings"),
                isTunnelActive: vpnManager.isConnected
            )
        }
        .background(NothingPalette.trueBlack.ignoresSafeArea())
    }
}
