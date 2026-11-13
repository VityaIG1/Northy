import Foundation
@preconcurrency import NetworkExtension
import Observation
import UIKit

// MARK: - Happ-Inspired Tunnel, Ping & Subscription Controller (iOS 26+)

@Observable
@MainActor
public final class VPNTunnelManager {

    public var nodes: [ProxyNode] = []
    public var selectedNodeId: UUID?
    public var subscriptions: [SubscriptionSource] = []
    public var routingConfig: TunnelRoutingConfiguration
    public var pingSettings: HappPingSettings
    public var connectionSettings: HappConnectionSettings
    public var subscriptionSettings: HappSubscriptionSettings

    public var connectionStatus: NEVPNStatus = .disconnected
    public var telemetry = TunnelRuntimeTelemetry()
    public var connectedSince: Date?
    public var rxSpeedBytesPerSec: UInt64 = 0
    public var txSpeedBytesPerSec: UInt64 = 0
    public var statusBannerMessage: String?
    public var isPingingAll: Bool = false
    public var isSyncingSubscriptions: Bool = false

    private var providerManager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var telemetryTimerTask: Task<Void, Never>?
    private var lastRxBytes: UInt64 = 0
    private var lastTxBytes: UInt64 = 0

    public var selectedNode: ProxyNode? {
        nodes.first(where: { $0.id == selectedNodeId }) ?? nodes.first
    }

    public var isConnected: Bool {
        connectionStatus == .connected
    }

    public var isTransitioning: Bool {
        connectionStatus == .connecting || connectionStatus == .disconnecting || connectionStatus == .reasserting
    }

    public var totalSessionBytes: UInt64 {
        telemetry.rxBytes &+ telemetry.txBytes
    }

    /// Generates a live formatted preview of the Xray-core JSON configuration for the active node & settings.
    public var activeCoreJSONPreview: String {
        guard let node = selectedNode,
              let data = try? HappLinkParser.buildXrayCoreConfiguration(
                  for: node,
                  routing: routingConfig,
                  connection: connectionSettings
              ),
              let text = String(data: data, encoding: .utf8) else {
            return "// NO ACTIVE NODE"
        }
        return text
    }

    public init() {
        let store = SharedTunnelStore.shared
        let loadedNodes = store.loadNodes()
        self.nodes = loadedNodes
        self.selectedNodeId = store.loadSelectedNodeId() ?? loadedNodes.first?.id
        self.subscriptions = store.loadSubscriptions()
        self.routingConfig = store.loadRoutingConfiguration()
        self.pingSettings = store.loadPingSettings()
        self.connectionSettings = store.loadConnectionSettings()
        self.subscriptionSettings = store.loadSubscriptionSettings()

        observeSystemVPNStatus()
        Task {
            await bootstrapProviderManager()
            if subscriptionSettings.autoUpdateOnLaunch && !subscriptions.isEmpty {
                await refreshAllSubscriptions()
            } else if pingSettings.autoPingOnStartup {
                await measureAllNodeLatencies()
            }
        }
    }

    // MARK: - Paste-to-Connect One-Click Workflow

    public func pasteFromClipboardAndConnect() async {
        guard let rawClipboard = UIPasteboard.general.string,
              !rawClipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusBannerMessage = "CLIPBOARD EMPTY // COPY VLESS, VMESS, TROJAN OR SS URI"
            return
        }

        await importPayloadAndPrepare(rawClipboard, autoConnect: true)
    }

    public func importPayloadAndPrepare(_ rawPayload: String, autoConnect: Bool) async {
        do {
            let result = try HappLinkParser.parseClipboardPayload(rawPayload)
            switch result {
            case .nodes(let parsedNodes):
                mergeParsedNodes(parsedNodes)
                if let firstNew = parsedNodes.first {
                    selectNode(firstNew.id)
                }
                statusBannerMessage = "PARSED \(parsedNodes.count) NODE(S) // READY"
                if subscriptionSettings.pingAfterSync {
                    Task { await measureAllNodeLatencies() }
                }
                if autoConnect {
                    await toggleTunnelConnection()
                }

            case .remoteSubscriptionURL(let subURL):
                statusBannerMessage = "SYNCING SUBSCRIPTION // \(subURL.host() ?? "REMOTE")"
                try await fetchRemoteSubscription(from: subURL)
                if subscriptionSettings.pingAfterSync {
                    Task { await measureAllNodeLatencies() }
                }
                if autoConnect {
                    await toggleTunnelConnection()
                }
            }
        } catch {
            statusBannerMessage = error.localizedDescription
        }
    }

    // MARK: - Remote Subscription Fetch & Refresh All (Happ User-Agent & Header Parsing)

    public func refreshAllSubscriptions() async {
        guard !isSyncingSubscriptions, !subscriptions.isEmpty else { return }
        isSyncingSubscriptions = true
        defer { isSyncingSubscriptions = false }

        let currentList = subscriptions
        for sub in currentList {
            if let url = URL(string: sub.urlString) {
                try? await fetchRemoteSubscription(from: url, existingId: sub.id)
            }
        }

        if subscriptionSettings.pingAfterSync {
            await measureAllNodeLatencies()
        }
    }

    public func fetchRemoteSubscription(from url: URL, existingId: UUID? = nil) async throws {
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue(subscriptionSettings.userAgentProfile.rawValue, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let body = String(data: data, encoding: .utf8) else {
            throw HappParserError.networkSubscriptionFailure("INVALID_ENCODING")
        }

        let subId = existingId ?? UUID()
        let parsedResult = try HappLinkParser.parseClipboardPayload(body, subscriptionId: subId)
        guard case .nodes(let subNodes) = parsedResult, !subNodes.isEmpty else {
            throw HappParserError.networkSubscriptionFailure("NO_NODES_IN_SUBSCRIPTION")
        }

        // Parse optional `Subscription-Userinfo` header (upload=...; download=...; total=...; expire=...)
        var upload: Int64?
        var download: Int64?
        var total: Int64?
        var expire: TimeInterval?

        if let httpResponse = response as? HTTPURLResponse,
           let userInfo = httpResponse.value(forHTTPHeaderField: "Subscription-Userinfo") {
            let pairs = userInfo.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            for pair in pairs {
                let kv = pair.split(separator: "=").map(String.init)
                guard kv.count == 2, let number = Int64(kv[1]) else { continue }
                switch kv[0].lowercased() {
                case "upload": upload = number
                case "download": download = number
                case "total": total = number
                case "expire": expire = TimeInterval(number)
                default: break
                }
            }
        }

        let subTitle = url.host() ?? "SUBSCRIPTION"
        let source = SubscriptionSource(
            id: subId,
            title: subTitle.uppercased(),
            urlString: url.absoluteString,
            lastUpdated: .now,
            nodeCount: subNodes.count,
            uploadBytes: upload,
            downloadBytes: download,
            totalQuotaBytes: total,
            expireTimestamp: expire
        )

        subscriptions.removeAll { $0.urlString == url.absoluteString || $0.id == subId }
        subscriptions.insert(source, at: 0)
        SharedTunnelStore.shared.saveSubscriptions(subscriptions)

        // Replace older nodes from this subscription and merge new ones
        nodes.removeAll { $0.subscriptionId == subId }
        mergeParsedNodes(subNodes)
        if let first = subNodes.first, selectedNodeId == nil {
            selectNode(first.id)
        }
        statusBannerMessage = "SUBSCRIPTION UPDATED // \(subNodes.count) NODES"
    }

    // MARK: - Node Selection & Persistence

    public func selectNode(_ id: UUID) {
        selectedNodeId = id
        SharedTunnelStore.shared.saveSelectedNodeId(id)

        if isConnected {
            Task {
                await restartTunnelWithActiveNode()
            }
        }
    }

    public func deleteNode(_ id: UUID) {
        nodes.removeAll { $0.id == id }
        SharedTunnelStore.shared.saveNodes(nodes)
        if selectedNodeId == id {
            selectedNodeId = nodes.first?.id
            SharedTunnelStore.shared.saveSelectedNodeId(selectedNodeId)
        }
    }

    public func removeSubscription(_ id: UUID) {
        subscriptions.removeAll { $0.id == id }
        SharedTunnelStore.shared.saveSubscriptions(subscriptions)
        nodes.removeAll { $0.subscriptionId == id }
        SharedTunnelStore.shared.saveNodes(nodes)
    }

    // MARK: - Settings Mutations (Routing, Ping, Connection, Subscriptions)

    public func updateRoutingConfiguration(_ updated: TunnelRoutingConfiguration) {
        routingConfig = updated
        SharedTunnelStore.shared.saveRoutingConfiguration(updated)
        syncCoreConfigAndNotifyTunnel()
    }

    public func updatePingSettings(_ updated: HappPingSettings) {
        let shouldResort = !pingSettings.sortNodesByLatency && updated.sortNodesByLatency
        pingSettings = updated
        SharedTunnelStore.shared.savePingSettings(updated)
        if shouldResort {
            sortNodesByCurrentLatency()
        }
    }

    public func updateConnectionSettings(_ updated: HappConnectionSettings) {
        connectionSettings = updated
        SharedTunnelStore.shared.saveConnectionSettings(updated)
        syncCoreConfigAndNotifyTunnel()
    }

    public func updateSubscriptionSettings(_ updated: HappSubscriptionSettings) {
        subscriptionSettings = updated
        SharedTunnelStore.shared.saveSubscriptionSettings(updated)
    }

    private func syncCoreConfigAndNotifyTunnel() {
        if let node = selectedNode,
           let coreJSON = try? HappLinkParser.buildXrayCoreConfiguration(
               for: node,
               routing: routingConfig,
               connection: connectionSettings
           ) {
            SharedTunnelStore.shared.writeActiveCoreConfiguration(coreJSON)
        }

        if isConnected, let session = providerManager?.connection as? NETunnelProviderSession {
            let cmdData = Data(TunnelIPCCommand.reloadRouting.rawValue.utf8)
            try? session.sendProviderMessage(cmdData) { _ in }
        }
    }

    // MARK: - Concurrent Ping Matrix Engine (TCP / HTTP 204 URLTest / ICMP + Auto-Sort)

    public func measureAllNodeLatencies() async {
        guard !isPingingAll, !nodes.isEmpty else { return }
        isPingingAll = true
        defer { isPingingAll = false }

        let snapshotNodes = nodes
        let currentPingSettings = pingSettings

        let results: [UUID: Int?] = await withTaskGroup(of: (UUID, Int?).self) { group in
            for node in snapshotNodes {
                group.addTask {
                    let ms = await TCPNodePinger.measureNode(node, settings: currentPingSettings)
                    return (node.id, ms)
                }
            }

            var collected: [UUID: Int?] = [:]
            for await (id, ms) in group {
                collected[id] = ms
            }
            return collected
        }

        for index in nodes.indices {
            let id = nodes[index].id
            if let measuredOptional = results[id] {
                nodes[index].latencyMs = measuredOptional
            }
        }

        if pingSettings.sortNodesByLatency {
            sortNodesByCurrentLatency()
        } else {
            SharedTunnelStore.shared.saveNodes(nodes)
        }
    }

    public func sortNodesByCurrentLatency() {
        nodes.sort { lhs, rhs in
            switch (lhs.latencyMs, rhs.latencyMs) {
            case let (l?, r?):
                return l < r
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.remark < rhs.remark
            }
        }
        SharedTunnelStore.shared.saveNodes(nodes)
    }

    // MARK: - NETunnelProviderManager Lifecycle

    public func toggleTunnelConnection() async {
        if isConnected || isTransitioning {
            providerManager?.connection.stopVPNTunnel()
            connectionStatus = .disconnected
            telemetry = TunnelRuntimeTelemetry()
            connectedSince = nil
            rxSpeedBytesPerSec = 0
            txSpeedBytesPerSec = 0
            lastRxBytes = 0
            lastTxBytes = 0
            return
        }

        guard let node = selectedNode else {
            statusBannerMessage = "NO SERVER SELECTED"
            return
        }

        connectionStatus = .connecting

        do {
            let coreJSONData = try HappLinkParser.buildXrayCoreConfiguration(
                for: node,
                routing: routingConfig,
                connection: connectionSettings
            )
            SharedTunnelStore.shared.writeActiveCoreConfiguration(coreJSONData)

            let manager = try await ensureTunnelManagerConfigured(for: node, coreJSONData: coreJSONData)
            try manager.connection.startVPNTunnel()
        } catch {
            connectionStatus = .disconnected
            statusBannerMessage = "TUNNEL ERROR // \(error.localizedDescription.uppercased())"
        }
    }

    private func restartTunnelWithActiveNode() async {
        providerManager?.connection.stopVPNTunnel()
        try? await Task.sleep(for: .milliseconds(350))
        await toggleTunnelConnection()
    }

    private func bootstrapProviderManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first {
                self.providerManager = existing
                self.connectionStatus = existing.connection.status
                if existing.connection.status == .connected {
                    self.connectedSince = existing.connection.connectedDate ?? .now
                    self.startTelemetryPolling()
                }
            }
        } catch {
            // System VPN preferences unavailable until first tunnel activation
        }
    }

    private func ensureTunnelManagerConfigured(
        for node: ProxyNode,
        coreJSONData: Data
    ) async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let manager = managers.first ?? NETunnelProviderManager()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = SharedTunnelStore.tunnelBundleIdentifier
        proto.serverAddress = "\(node.serverHost):\(node.serverPort)"
        proto.providerConfiguration = [
            "xrayCoreJSON": coreJSONData,
            "nodeRemark": node.remark,
            "protocolType": node.protocolType.rawValue,
            "tunnelMode": connectionSettings.tunnelMode.rawValue,
            "tunMTU": connectionSettings.tunMTU
        ]
        proto.disconnectOnSleep = connectionSettings.disconnectOnSleep
        if #available(iOS 26.0, *) {
            proto.includeAllNetworks = routingConfig.strictKillSwitch && connectionSettings.tunnelMode == .tun
            proto.excludeLocalNetworks = routingConfig.bypassLocalNetwork
        }

        manager.protocolConfiguration = proto
        manager.localizedDescription = "NOTHING // VPN (\(node.remark))"
        manager.isEnabled = true

        // Happ Connect-On-Demand Rules
        if connectionSettings.connectOnDemand {
            let connectRule = NEOnDemandRuleConnect()
            connectRule.interfaceTypeMatch = .any
            manager.onDemandRules = [connectRule]
            manager.isOnDemandEnabled = true
        } else {
            manager.onDemandRules = []
            manager.isOnDemandEnabled = false
        }

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()
        self.providerManager = manager
        return manager
    }

    private func observeSystemVPNStatus() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let session = notification.object as? NEVPNConnection else { return }
            let status = session.status
            let connectedDate = session.connectedDate
            Task { @MainActor in
                self.connectionStatus = status
                if status == .connected {
                    if self.connectedSince == nil {
                        self.connectedSince = connectedDate ?? .now
                    }
                    self.startTelemetryPolling()
                } else if status == .disconnected {
                    self.telemetryTimerTask?.cancel()
                    self.telemetry = TunnelRuntimeTelemetry()
                    self.connectedSince = nil
                    self.rxSpeedBytesPerSec = 0
                    self.txSpeedBytesPerSec = 0
                    self.lastRxBytes = 0
                    self.lastTxBytes = 0
                }
            }
        }
    }

    private func startTelemetryPolling() {
        telemetryTimerTask?.cancel()
        telemetryTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let session = self.providerManager?.connection as? NETunnelProviderSession {
                    let msg = Data(TunnelIPCCommand.queryTelemetry.rawValue.utf8)
                    try? session.sendProviderMessage(msg) { responseData in
                        guard let responseData,
                              let decoded = try? JSONDecoder().decode(TunnelRuntimeTelemetry.self, from: responseData) else {
                            return
                        }
                        Task { @MainActor in
                            let deltaRx = decoded.rxBytes >= self.lastRxBytes ? (decoded.rxBytes - self.lastRxBytes) : decoded.rxBytes
                            let deltaTx = decoded.txBytes >= self.lastTxBytes ? (decoded.txBytes - self.lastTxBytes) : decoded.txBytes
                            self.rxSpeedBytesPerSec = deltaRx
                            self.txSpeedBytesPerSec = deltaTx
                            self.lastRxBytes = decoded.rxBytes
                            self.lastTxBytes = decoded.txBytes
                            self.telemetry = decoded
                            if let remoteDate = decoded.connectedSince, self.connectedSince == nil {
                                self.connectedSince = remoteDate
                            }
                        }
                    }
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func mergeParsedNodes(_ incoming: [ProxyNode]) {
        for node in incoming {
            if let existingIndex = nodes.firstIndex(where: { $0.rawURI == node.rawURI }) {
                nodes[existingIndex] = node
            } else {
                nodes.insert(node, at: 0)
            }
        }
        SharedTunnelStore.shared.saveNodes(nodes)
    }
}
