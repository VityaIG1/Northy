import Foundation
@preconcurrency import NetworkExtension
import os.log

// MARK: - Production-Grade PacketTunnelProvider (Xray-core / Sing-box & TUN Engine)

public final class PacketTunnelProvider: NEPacketTunnelProvider, @unchecked Sendable {

    private let logger = Logger(subsystem: "com.scrt.north.PacketTunnel", category: "TunnelCore")
    private let telemetryLock = NSLock()

    private let coreController = ProxyCoreController()
    private var tunBridge: TUNPacketBridge?

    private var connectedAt: Date?
    private var activeNodeId: UUID?
    private var heartbeatTask: Task<Void, Never>?

    // MARK: - Tunnel Start Lifecycle

    public override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.notice("NORTHY // Initializing production VPN PacketTunnelProvider...")

        // Optimize Go runtime memory limits immediately before any work (<50MB jetsam budget)
        ProxyCoreController.tuneGoRuntimeMemory()

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

        // Build or retrieve real Xray/Sing-box JSON configuration
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

        // 1. Launch Real Proxy Core (Xray-core / LibXray / sing-box) and fail-fast if config or core fails
        let coreResult = self.coreController.startCore(configData: coreConfigData)
        if case .failure(let coreErr) = coreResult {
            self.logger.error("NORTHY // Proxy core failed to launch: \(coreErr.localizedDescription)")
            completionHandler(coreErr)
            return
        }

        // 2. Configure virtual TUN network settings
        let networkSettings = buildTunnelNetworkSettings(
            for: activeNode,
            routing: routingConfig,
            connection: connectionConfig
        )

        nonisolated(unsafe) let startCompletion = completionHandler
        setTunnelNetworkSettings(networkSettings) { [weak self] error in
            guard let self else { return }
            if let error {
                self.logger.error("NORTHY // Failed to apply tunnel network settings: \(error.localizedDescription)")
                self.coreController.stopCore()
                startCompletion(error)
                return
            }

            self.telemetryLock.withLock {
                self.connectedAt = .now
            }

            // 3. Launch High-Throughput Stateful TUN Packet Flow Bridge
            self.startPacketFlowBridge(connectionConfig: connectionConfig)

            self.logger.notice("NORTHY // Tunnel established -> \(activeNode.serverHost):\(activeNode.serverPort) [MTU \(connectionConfig.tunMTU)]")
            startCompletion(nil)
        }
    }

    // MARK: - Tunnel Stop Lifecycle

    public override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.notice("NORTHY // Stopping tunnel (reason: \(String(describing: reason)))")

        heartbeatTask?.cancel()
        heartbeatTask = nil

        tunBridge?.stop()
        tunBridge = nil

        coreController.stopCore()

        SharedTunnelStore.shared.clearActiveTelemetry()

        telemetryLock.withLock {
            connectedAt = nil
            activeNodeId = nil
        }

        completionHandler()
    }

    // MARK: - App <-> Extension IPC (Telemetry, Real-time Metrics, Reload & Latency Test)

    public override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let commandString = String(data: messageData, encoding: .utf8),
              let command = TunnelIPCCommand(rawValue: commandString) else {
            completionHandler?(nil)
            return
        }

        nonisolated(unsafe) let reply = completionHandler

        switch command {
        case .queryTelemetry:
            let metrics = tunBridge?.currentMetrics
            let coreStatus = coreController.statusDescription
            let snapshot = telemetryLock.withLock {
                TunnelRuntimeTelemetry(
                    isConnected: connectedAt != nil,
                    activeNodeId: activeNodeId,
                    rxBytes: metrics?.rxBytes ?? 0,
                    txBytes: metrics?.txBytes ?? 0,
                    rxSpeed: metrics?.rxSpeed ?? 0,
                    txSpeed: metrics?.txSpeed ?? 0,
                    connectedSince: connectedAt,
                    coreStatus: coreStatus
                )
            }
            let encoded = try? JSONEncoder().encode(snapshot)
            reply?(encoded)

        case .reloadRouting:
            let store = SharedTunnelStore.shared
            let routing = store.loadRoutingConfiguration()
            let connection = store.loadConnectionSettings()
            let nodes = store.loadNodes()
            let currentId = telemetryLock.withLock { activeNodeId }

            if let currentId, let node = nodes.first(where: { $0.id == currentId }) {
                let updatedSettings = buildTunnelNetworkSettings(
                    for: node,
                    routing: routing,
                    connection: connection
                )
                setTunnelNetworkSettings(updatedSettings) { _ in
                    reply?(Data("OK".utf8))
                }
            } else {
                reply?(Data("NO_NODE".utf8))
            }

        case .measureLatency:
            coreController.measureOutboundLatency { latencyMs in
                let responseDict: [String: Any] = [
                    "latencyMs": latencyMs as Any,
                    "status": latencyMs != nil ? "OK" : "TIMEOUT"
                ]
                let data = try? JSONSerialization.data(withJSONObject: responseDict)
                reply?(data)
            }

        case .queryCoreStatus:
            let status = coreController.statusDescription
            reply?(Data(status.utf8))

        case .stopTunnel:
            cancelTunnelWithError(nil)
            reply?(Data("STOPPED".utf8))
        }
    }

    // MARK: - Network Settings Construction (Virtual TUN 198.18.0.1/15, DoH / FakeIP & Loop Prevention)

    private func buildTunnelNetworkSettings(
        for node: ProxyNode,
        routing: TunnelRoutingConfiguration,
        connection: HappConnectionSettings
    ) -> NEPacketTunnelNetworkSettings {
        // Resolve host to physical IPv4 to prevent routing loop blackholes
        let resolvedIP = Self.isIPv4Address(node.serverHost) ? node.serverHost : SharedTunnelStore.resolveIPv4(host: node.serverHost)
        let remoteAddr = resolvedIP ?? (Self.isIPv4Address(node.serverHost) ? node.serverHost : "198.18.0.1")

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteAddr)
        settings.mtu = NSNumber(value: connection.tunMTU)

        // Virtual TUN IPv4 configuration: 198.18.0.1/15 (RFC 2544 benchmark/tunnel subnet)
        let ipv4Settings = NEIPv4Settings(
            addresses: ["198.18.0.1"],
            subnetMasks: ["255.254.0.0"]
        )

        var excludedRoutes: [NEIPv4Route] = []

        // 1. CRITICAL: Always exclude remote proxy server physical IP to prevent infinite routing loop
        if let serverIP = resolvedIP, Self.isIPv4Address(serverIP) {
            excludedRoutes.append(NEIPv4Route(destinationAddress: serverIP, subnetMask: "255.255.255.255"))
        }

        // 2. Exclude standard LAN ranges if bypassLocalNetwork is enabled or in split tunnel mode
        if routing.bypassLocalNetwork || routing.routingMode == .splitBypassLANAndRegional {
            let privateLANs = [
                ("10.0.0.0", "255.0.0.0"),
                ("172.16.0.0", "240.0.0.0"),
                ("192.168.0.0", "255.255.0.0"),
                ("127.0.0.0", "255.0.0.0"),
                ("169.254.0.0", "255.255.0.0")
            ]
            for (addr, mask) in privateLANs {
                excludedRoutes.append(NEIPv4Route(destinationAddress: addr, subnetMask: mask))
            }
        }

        // Configure system proxy settings for instant WebKit / Safari / URLSession routing through local core
        let proxySettings = NEProxySettings()
        proxySettings.httpEnabled = true
        proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: 10809)
        proxySettings.httpsEnabled = true
        proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: 10809)
        proxySettings.excludeSimpleHostnames = false
        proxySettings.matchDomains = [""]
        settings.proxySettings = proxySettings

        if connection.tunnelMode == .proxyOnly {
            ipv4Settings.includedRoutes = []
            ipv4Settings.excludedRoutes = []
        } else {
            switch routing.routingMode {
            case .globalTunnel:
                ipv4Settings.includedRoutes = [NEIPv4Route.default()]
                ipv4Settings.excludedRoutes = excludedRoutes

            case .splitBypassLANAndRegional:
                ipv4Settings.includedRoutes = [NEIPv4Route.default()]
                for cidr in routing.customExcludedCIDRs {
                    if let route = parseCIDRRoute(cidr) {
                        excludedRoutes.append(route)
                    }
                }
                ipv4Settings.excludedRoutes = excludedRoutes

            case .directOnly:
                ipv4Settings.includedRoutes = []
                ipv4Settings.excludedRoutes = []
            }
        }

        settings.ipv4Settings = ipv4Settings

        // Virtual IPv6 routing: fd00::1/126
        if routing.enableIPv6Routing && connection.tunnelMode == .tun {
            let ipv6Settings = NEIPv6Settings(
                addresses: ["fd00::1"],
                networkPrefixLengths: [126]
            )
            ipv6Settings.includedRoutes = [NEIPv6Route.default()]
            settings.ipv6Settings = ipv6Settings
        }

        // DNS Configuration: FakeIP / Core Inbound (198.18.0.2) + DoH fallback to eliminate DNS leaks
        var dnsServers = ["198.18.0.2"]
        for s in routing.dnsProvider.resolverAddresses {
            if !dnsServers.contains(s) {
                dnsServers.append(s)
            }
        }

        if let dohURL = URL(string: routing.dnsProvider.dohURLString), !routing.dnsProvider.dohURLString.isEmpty {
            let dohSettings = NEDNSOverHTTPSSettings(servers: dnsServers)
            dohSettings.serverURL = dohURL
            dohSettings.matchDomains = [""]
            settings.dnsSettings = dohSettings
        } else {
            let dnsSettings = NEDNSSettings(servers: dnsServers)
            dnsSettings.matchDomains = [""]
            settings.dnsSettings = dnsSettings
        }

        return settings
    }

    // MARK: - Packet Flow Bridge & Telemetry Heartbeat

    private func startPacketFlowBridge(connectionConfig: HappConnectionSettings) {
        heartbeatTask?.cancel()
        tunBridge?.stop()

        // 1. Initialize and start the TUN Packet Bridge (bridges packetFlow to local core SOCKS5 & DNS)
        let bridge = TUNPacketBridge(
            packetFlow: packetFlow,
            socksHost: "127.0.0.1",
            socksPort: 10808,
            dnsHost: "127.0.0.1",
            dnsPort: 10853
        )
        bridge.start()
        self.tunBridge = bridge

        // 2. Periodic App Group Telemetry Heartbeat (1s timer)
        heartbeatTask = Task.detached(priority: .medium) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }

                let metrics = self.tunBridge?.currentMetrics
                let coreStatus = self.coreController.statusDescription

                let snapshot = self.telemetryLock.withLock {
                    TunnelRuntimeTelemetry(
                        isConnected: self.connectedAt != nil,
                        activeNodeId: self.activeNodeId,
                        rxBytes: metrics?.rxBytes ?? 0,
                        txBytes: metrics?.txBytes ?? 0,
                        rxSpeed: metrics?.rxSpeed ?? 0,
                        txSpeed: metrics?.txSpeed ?? 0,
                        connectedSince: self.connectedAt,
                        coreStatus: coreStatus
                    )
                }

                SharedTunnelStore.shared.writeActiveTelemetry(snapshot)
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
