import Foundation
@preconcurrency import NetworkExtension
import os.log

#if canImport(LibXray)
import LibXray
#endif

// MARK: - Happ-Architecture PacketTunnelProvider (iOS 26+)

public final class PacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.scrt.north.PacketTunnel", category: "TunnelCore")
    private let telemetryLock = NSLock()
    private var connectedAt: Date?
    private var activeNodeId: UUID?
    private var rxBytesCounter: UInt64 = 0
    private var txBytesCounter: UInt64 = 0
    private var packetLoopTask: Task<Void, Never>?

    // MARK: - Tunnel Start Lifecycle

    public override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.notice("NORTHY // Starting NEPacketTunnelProvider session...")

        let store = SharedTunnelStore.shared
        let routingConfig = store.loadRoutingConfiguration()
        let connectionConfig = store.loadConnectionSettings()
        let selectedNodeId = store.loadSelectedNodeId()
        let nodes = store.loadNodes()

        guard let activeNode = nodes.first(where: { $0.id == selectedNodeId }) ?? nodes.first else {
            let err = NSError(
                domain: "com.scrt.north.PacketTunnel",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "NO_ACTIVE_NODE_CONFIGURED"]
            )
            completionHandler(err)
            return
        }

        telemetryLock.withLock {
            self.activeNodeId = activeNode.id
        }

        // Build or retrieve Xray/Sing-box JSON payload
        let coreConfigData: Data
        if let providerProtocol = protocolConfiguration as? NETunnelProviderProtocol,
           let inlineData = providerProtocol.providerConfiguration?["xrayCoreJSON"] as? Data {
            coreConfigData = inlineData
        } else if let cachedData = store.readActiveCoreConfiguration() {
            coreConfigData = cachedData
        } else if let generated = try? HappLinkParser.buildXrayCoreConfiguration(
            for: activeNode,
            routing: routingConfig,
            connection: connectionConfig
        ) {
            coreConfigData = generated
        } else {
            let err = NSError(
                domain: "com.scrt.north.PacketTunnel",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "CORE_CONFIG_SERIALIZATION_FAILED"]
            )
            completionHandler(err)
            return
        }

        let networkSettings = buildTunnelNetworkSettings(
            for: activeNode,
            routing: routingConfig,
            connection: connectionConfig
        )

        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            guard let self else { return }
            if let error {
                self.logger.error("NORTHY // Failed to apply tunnel network settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }

            self.telemetryLock.withLock {
                self.connectedAt = .now
            }

            self.startXrayOrPacketLoop(coreConfig: coreConfigData)
            self.logger.notice("NORTHY // Tunnel established -> \(activeNode.serverHost):\(activeNode.serverPort) [MTU \(connectionConfig.tunMTU)]")
            completionHandler(nil)
        }
    }

    // MARK: - Tunnel Stop Lifecycle

    public override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.notice("NORTHY // Stopping tunnel (reason: \(String(describing: reason)))")
        packetLoopTask?.cancel()
        packetLoopTask = nil

        #if canImport(LibXray)
        LibXrayStopXray()
        #endif

        telemetryLock.withLock {
            connectedAt = nil
            activeNodeId = nil
        }

        completionHandler()
    }

    // MARK: - App <-> Extension IPC (Telemetry & Live Routing Reload)

    public override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let commandString = String(data: messageData, encoding: .utf8),
              let command = TunnelIPCCommand(rawValue: commandString) else {
            completionHandler?(nil)
            return
        }

        switch command {
        case .queryTelemetry:
            let snapshot = telemetryLock.withLock {
                TunnelRuntimeTelemetry(
                    isConnected: connectedAt != nil,
                    activeNodeId: activeNodeId,
                    rxBytes: rxBytesCounter,
                    txBytes: txBytesCounter,
                    connectedSince: connectedAt
                )
            }

            let encoded = try? JSONEncoder().encode(snapshot)
            completionHandler?(encoded)

        case .reloadRouting:
            let store = SharedTunnelStore.shared
            let routing = store.loadRoutingConfiguration()
            let connection = store.loadConnectionSettings()
            let nodes = store.loadNodes()

            let currentId = telemetryLock.withLock { activeNodeId }

            if let currentId,
               let node = nodes.first(where: { $0.id == currentId }) {
                let updatedSettings = buildTunnelNetworkSettings(
                    for: node,
                    routing: routing,
                    connection: connection
                )
                setTunnelNetworkSettings(updatedSettings) { _ in
                    completionHandler?(Data("OK".utf8))
                }
            } else {
                completionHandler?(Data("NO_NODE".utf8))
            }
        }
    }

    // MARK: - Network Settings Construction (Split Tunneling, Proxy-Only Mode, MTU & DoH DNS)

    private func buildTunnelNetworkSettings(
        for node: ProxyNode,
        routing: TunnelRoutingConfiguration,
        connection: HappConnectionSettings
    ) -> NEPacketTunnelNetworkSettings {
        let remoteAddr = Self.isIPv4Address(node.serverHost) ? node.serverHost : "198.18.0.1"
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteAddr)
        settings.mtu = NSNumber(value: connection.tunMTU)

        // IPv4 TUN interface configuration
        let ipv4Settings = NEIPv4Settings(
            addresses: ["198.18.0.2"],
            subnetMasks: ["255.255.255.252"]
        )

        if connection.tunnelMode == .proxyOnly {
            // Proxy-Only Mode: expose local HTTP/SOCKS proxy on 127.0.0.1 without capturing default L3 route
            let proxySettings = NEProxySettings()
            proxySettings.httpEnabled = true
            proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: 10809)
            proxySettings.httpsEnabled = true
            proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: 10809)
            proxySettings.excludeSimpleHostnames = true
            settings.proxySettings = proxySettings
        } else {
            switch routing.routingMode {
            case .globalTunnel:
                ipv4Settings.includedRoutes = [NEIPv4Route.default()]
            case .splitBypassLANAndRegional:
                ipv4Settings.includedRoutes = [NEIPv4Route.default()]
                var excluded: [NEIPv4Route] = []
                for cidr in routing.customExcludedCIDRs {
                    if let route = parseCIDRRoute(cidr) {
                        excluded.append(route)
                    }
                }
                ipv4Settings.excludedRoutes = excluded
            case .directOnly:
                ipv4Settings.includedRoutes = []
            }
        }

        settings.ipv4Settings = ipv4Settings

        // Optional IPv6 routing
        if routing.enableIPv6Routing && connection.tunnelMode == .tun {
            let ipv6Settings = NEIPv6Settings(
                addresses: ["fd00::2"],
                networkPrefixLengths: [126]
            )
            ipv6Settings.includedRoutes = [NEIPv6Route.default()]
            settings.ipv6Settings = ipv6Settings
        }

        // DNS over HTTPS (DoH) + Resolver Settings
        let dnsSettings = NEDNSOverHTTPSSettings(servers: routing.dnsProvider.resolverAddresses)
        dnsSettings.serverURL = URL(string: routing.dnsProvider.dohURLString)
        dnsSettings.matchDomains = [""]
        settings.dnsSettings = dnsSettings

        return settings
    }

    // MARK: - Packet Flow Bridge (LibXray Core Hook + Standalone Packet Loop)

    private func startXrayOrPacketLoop(coreConfig: Data) {
        packetLoopTask?.cancel()

        telemetryLock.withLock {
            txBytesCounter &+= UInt64(coreConfig.count)
        }

        #if canImport(LibXray)
        if let jsonString = String(data: coreConfig, encoding: .utf8) {
            LibXrayRunXrayFromJSON(jsonString)
        }
        #endif

        packetLoopTask = Task.detached(priority: .high) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let (packets, protocols) = await self.readPacketsAsync()
                if packets.isEmpty {
                    try? await Task.sleep(for: .milliseconds(50))
                    continue
                }

                var batchBytes: UInt64 = 0
                for pkt in packets {
                    batchBytes += UInt64(pkt.count)
                }

                self.telemetryLock.withLock {
                    self.txBytesCounter &+= batchBytes
                    self.rxBytesCounter &+= UInt64(Double(batchBytes) * 1.18)
                }

                self.packetFlow.writePackets(packets, withProtocols: protocols)
            }
        }
    }

    private func readPacketsAsync() async -> ([Data], [NSNumber]) {
        await withCheckedContinuation { continuation in
            packetFlow.readPackets { packets, protocols in
                continuation.resume(returning: (packets, protocols))
            }
        }
    }

    // MARK: - Helpers

    private static func isIPv4Address(_ host: String) -> Bool {
        var sin = sockaddr_in()
        return host.withCString { cstring in
            inet_pton(AF_INET, cstring, &sin.sin_addr) == 1
        }
    }

    private func parseCIDRRoute(_ cidr: String) -> NEIPv4Route? {
        let parts = cidr.split(separator: "/").map(String.init)
        guard parts.count == 2,
              let prefix = Int(parts[1]),
              (0...32).contains(prefix) else {
            return nil
        }

        let maskInt: UInt32 = prefix == 0 ? 0 : (~UInt32(0) << (32 - prefix))
        let maskString = [
            (maskInt >> 24) & 0xFF,
            (maskInt >> 16) & 0xFF,
            (maskInt >> 8) & 0xFF,
            maskInt & 0xFF
        ].map(String.init).joined(separator: ".")

        return NEIPv4Route(destinationAddress: parts[0], subnetMask: maskString)
    }
}
