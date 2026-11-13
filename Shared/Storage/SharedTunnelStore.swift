import Foundation
import Network
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Darwin)
import Darwin
#endif

// MARK: - Shared App Group Store & IPC Protocol

public enum TunnelIPCCommand: String, Codable, Sendable {
    case queryTelemetry = "QUERY_TELEMETRY"
    case reloadRouting = "RELOAD_ROUTING"
    case measureLatency = "MEASURE_LATENCY"
    case queryCoreStatus = "QUERY_CORE_STATUS"
    case stopTunnel = "STOP_TUNNEL"
}

public final class SharedTunnelStore: Sendable {
    public static var appGroupIdentifier: String {
        if let custom = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String, !custom.isEmpty {
            return custom
        }
        if let mainId = Bundle.main.bundleIdentifier {
            let baseId = mainId.replacingOccurrences(of: ".PacketTunnel", with: "")
            return "group.\(baseId)"
        }
        return "group.com.scrt.north"
    }

    public static var tunnelBundleIdentifier: String {
        if let custom = Bundle.main.object(forInfoDictionaryKey: "TUNNEL_BUNDLE_IDENTIFIER") as? String, !custom.isEmpty {
            return custom
        }
        if let mainId = Bundle.main.bundleIdentifier {
            return mainId.hasSuffix(".PacketTunnel") ? mainId : "\(mainId).PacketTunnel"
        }
        return "com.scrt.north.PacketTunnel"
    }

    /// Shared container directory in App Group sandbox for core configurations and geo data assets.
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    public static var activeConfigFileURL: URL? {
        sharedContainerURL?.appendingPathComponent("config.json")
    }

    public static var telemetryFileURL: URL? {
        sharedContainerURL?.appendingPathComponent("telemetry.json")
    }

    public static var assetsDirectoryURL: URL? {
        let dir = sharedContainerURL?.appendingPathComponent("assets", isDirectory: true)
        if let dir, !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private enum Keys {
        static let savedNodes = "nothing.vpn.nodes.v2"
        static let selectedNodeId = "nothing.vpn.selected_node_id.v1"
        static let subscriptions = "nothing.vpn.subscriptions.v1"
        static let routingConfig = "nothing.vpn.routing_config.v1"
        static let pingSettings = "nothing.vpn.ping_settings.v1"
        static let connectionSettings = "nothing.vpn.connection_settings.v1"
        static let subscriptionSettings = "nothing.vpn.subscription_settings.v1"
        static let activeXrayConfigJSON = "nothing.vpn.active_xray_json.v1"
        static let languageOverride = "nothing.vpn.language_override.v1"
        static let activeTelemetry = "nothing.vpn.active_telemetry.v1"
        static let deviceHWID = "nothing.vpn.device_hwid.v1"
    }

    public static let shared = SharedTunnelStore()

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
    }

    private init() {}

    // MARK: - Nodes Persistence

    public func loadNodes() -> [ProxyNode] {
        guard let data = defaults.data(forKey: Keys.savedNodes),
              let nodes = try? JSONDecoder().decode([ProxyNode].self, from: data),
              !nodes.isEmpty else {
            return Self.defaultBootstrapNodes
        }
        return nodes
    }

    public func saveNodes(_ nodes: [ProxyNode]) {
        if let data = try? JSONEncoder().encode(nodes) {
            defaults.set(data, forKey: Keys.savedNodes)
        }
    }

    public func loadSelectedNodeId() -> UUID? {
        guard let raw = defaults.string(forKey: Keys.selectedNodeId) else { return nil }
        return UUID(uuidString: raw)
    }

    public func saveSelectedNodeId(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: Keys.selectedNodeId)
    }

    // MARK: - Subscriptions Persistence

    public func loadSubscriptions() -> [SubscriptionSource] {
        guard let data = defaults.data(forKey: Keys.subscriptions),
              let items = try? JSONDecoder().decode([SubscriptionSource].self, from: data) else {
            return []
        }
        return items
    }

    public func saveSubscriptions(_ items: [SubscriptionSource]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Keys.subscriptions)
        }
    }

    // MARK: - Routing Configuration Persistence

    public func loadRoutingConfiguration() -> TunnelRoutingConfiguration {
        guard let data = defaults.data(forKey: Keys.routingConfig),
              let config = try? JSONDecoder().decode(TunnelRoutingConfiguration.self, from: data) else {
            return TunnelRoutingConfiguration()
        }
        return config
    }

    public func saveRoutingConfiguration(_ config: TunnelRoutingConfiguration) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: Keys.routingConfig)
        }
    }

    // MARK: - Happ Ping Settings Persistence

    public func loadPingSettings() -> HappPingSettings {
        guard let data = defaults.data(forKey: Keys.pingSettings),
              let settings = try? JSONDecoder().decode(HappPingSettings.self, from: data) else {
            return HappPingSettings()
        }
        return settings
    }

    public func savePingSettings(_ settings: HappPingSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.pingSettings)
        }
    }

    // MARK: - Happ Connection & Core Settings Persistence

    public func loadConnectionSettings() -> HappConnectionSettings {
        guard let data = defaults.data(forKey: Keys.connectionSettings),
              let settings = try? JSONDecoder().decode(HappConnectionSettings.self, from: data) else {
            return HappConnectionSettings()
        }
        return settings
    }

    public func saveConnectionSettings(_ settings: HappConnectionSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.connectionSettings)
        }
    }

    // MARK: - Happ Subscription Settings Persistence

    public func loadSubscriptionSettings() -> HappSubscriptionSettings {
        guard let data = defaults.data(forKey: Keys.subscriptionSettings),
              let settings = try? JSONDecoder().decode(HappSubscriptionSettings.self, from: data) else {
            return HappSubscriptionSettings()
        }
        return settings
    }

    public func saveSubscriptionSettings(_ settings: HappSubscriptionSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.subscriptionSettings)
        }
    }

    // MARK: - Active Xray/Sing-box JSON Handoff for PacketTunnelProvider

    public func writeActiveCoreConfiguration(_ data: Data) {
        defaults.set(data, forKey: Keys.activeXrayConfigJSON)
        if let fileURL = Self.activeConfigFileURL {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public func readActiveCoreConfiguration() -> Data? {
        if let fileURL = Self.activeConfigFileURL,
           let data = try? Data(contentsOf: fileURL), !data.isEmpty {
            return data
        }
        return defaults.data(forKey: Keys.activeXrayConfigJSON)
    }

    // MARK: - Language Preference

    public func loadLanguageCode() -> String {
        defaults.string(forKey: Keys.languageOverride) ?? "system"
    }

    public func saveLanguageCode(_ code: String) {
        defaults.set(code, forKey: Keys.languageOverride)
    }

    // MARK: - Real-Time Tunnel Telemetry Handoff (IPC & App Group Bridge)

    public func writeActiveTelemetry(_ telemetry: TunnelRuntimeTelemetry) {
        if let data = try? JSONEncoder().encode(telemetry) {
            defaults.set(data, forKey: Keys.activeTelemetry)
            if let fileURL = Self.telemetryFileURL {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    public func readActiveTelemetry() -> TunnelRuntimeTelemetry? {
        if let data = defaults.data(forKey: Keys.activeTelemetry),
           let telemetry = try? JSONDecoder().decode(TunnelRuntimeTelemetry.self, from: data) {
            return telemetry
        }
        if let fileURL = Self.telemetryFileURL,
           let data = try? Data(contentsOf: fileURL),
           let telemetry = try? JSONDecoder().decode(TunnelRuntimeTelemetry.self, from: data) {
            return telemetry
        }
        return nil
    }

    public func clearActiveTelemetry() {
        defaults.removeObject(forKey: Keys.activeTelemetry)
        if let fileURL = Self.telemetryFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Persistent Unique Device Hardware UUID (X-HWID)

    public func getOrCreateHWID() -> String {
        if let existing = defaults.string(forKey: Keys.deviceHWID), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString.lowercased()
        defaults.set(fresh, forKey: Keys.deviceHWID)
        return fresh
    }

    @discardableResult
    public func regenerateHWID() -> String {
        let fresh = UUID().uuidString.lowercased()
        defaults.set(fresh, forKey: Keys.deviceHWID)
        return fresh
    }

    // MARK: - IP & DNS Resolution Helpers

    public static func resolveIPv4(host: String) -> String? {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &res) == 0, let first = res else {
            return nil
        }
        defer { freeaddrinfo(res) }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let sockaddrIn = first.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
        var addr = sockaddrIn.sin_addr
        guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return nil
        }
        return buffer.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return nil }
            return String(cString: base)
        }
    }

    // MARK: - Default Industrial Seed Nodes (Reachable Anycast Edge Hosts for Live Ping Testing)

    public static let defaultBootstrapNodes: [ProxyNode] = [
        ProxyNode(
            remark: "FRA-01 // REALITY CORE",
            protocolType: .vless,
            serverHost: "1.1.1.1",
            serverPort: 443,
            credential: "9f8e7d6c-5b4a-3210-fedc-ba9876543210",
            encryption: "none",
            flow: "xtls-rprx-vision",
            transport: .tcp,
            security: .reality,
            sni: "www.apple.com",
            fingerprint: "chrome",
            realityPublicKey: "mH7_XyZ91aBcDeFgHiJkLmNoPqRsTuVwXyZ01234567",
            realityShortId: "a1b2c3d4",
            rawURI: "vless://9f8e7d6c-5b4a-3210-fedc-ba9876543210@1.1.1.1:443?security=reality&encryption=none&pbk=mH7_XyZ91aBcDeFgHiJkLmNoPqRsTuVwXyZ01234567&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.apple.com&sid=a1b2c3d4#FRA-01%20//%20REALITY%20CORE",
            latencyMs: 24
        ),
        ProxyNode(
            remark: "AMS-04 // XHTTP NODE",
            protocolType: .vless,
            serverHost: "8.8.8.8",
            serverPort: 443,
            credential: "3a2b1c0d-9e8f-4765-b123-456789abcdef",
            encryption: "none",
            transport: .xhttp,
            security: .reality,
            sni: "www.cloudflare.com",
            fingerprint: "chrome",
            realityPublicKey: "kP9_QwErTyUiOpAsDfGhJkLzXcVbNm1234567890AbC",
            realityShortId: "ff01",
            path: "/mesh-stream",
            rawURI: "vless://3a2b1c0d-9e8f-4765-b123-456789abcdef@8.8.8.8:443?security=reality&type=xhttp&path=%2Fmesh-stream&sni=www.cloudflare.com#AMS-04%20//%20XHTTP%20NODE",
            latencyMs: 32
        ),
        ProxyNode(
            remark: "TYO-02 // TROJAN GRPC",
            protocolType: .trojan,
            serverHost: "9.9.9.9",
            serverPort: 443,
            credential: "n0th1ng_tr0j4n_k3y_2026",
            encryption: "tls",
            transport: .grpc,
            security: .tls,
            sni: "dns.quad9.net",
            fingerprint: "safari",
            path: "grpc-tunnel",
            rawURI: "trojan://n0th1ng_tr0j4n_k3y_2026@9.9.9.9:443?type=grpc&security=tls&serviceName=grpc-tunnel&sni=dns.quad9.net#TYO-02%20//%20TROJAN%20GRPC",
            latencyMs: 41
        )
    ]
}

// MARK: - Happ Device Fingerprinting (Hardware Identifier & Dynamic OS Version)

public enum HappDeviceFingerprint {

    /// Hardware machine identifier (e.g. "iPhone14,2", "iPhone13,4") retrieved via `uname` system call.
    public static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "iPhone14,2" : identifier
    }

    /// Dynamic system iOS version (e.g. "18.1", "17.5") via `UIDevice.current.systemVersion`.
    public static var systemVersion: String {
        #if canImport(UIKit)
        if Thread.isMainThread {
            return MainActor.assumeIsolated { UIDevice.current.systemVersion }
        } else {
            return DispatchQueue.main.sync { UIDevice.current.systemVersion }
        }
        #else
        return "18.1"
        #endif
    }
}

// MARK: - Multi-Mode Happ Node Pinger (TCP Handshake, HTTP 204 URLTest, ICMP/Echo)

public enum TCPNodePinger {

    /// Measures a single node according to the active `HappPingSettings`.
    public static func measureNode(
        _ node: ProxyNode,
        settings: HappPingSettings
    ) async -> Int? {
        switch settings.method {
        case .tcp:
            return await measureLatency(
                host: node.serverHost,
                port: node.serverPort,
                timeoutSeconds: settings.timeoutSeconds
            )
        case .urlTest:
            return await measureURLTestLatency(
                node: node,
                urlString: settings.testURLPreset.rawValue,
                timeoutSeconds: settings.timeoutSeconds
            )
        case .icmp:
            // On non-privileged iOS sandboxes, NWParameters.tcp with fast-SYN probe measures L3/L4 reachability RTT
            return await measureLatency(
                host: node.serverHost,
                port: node.serverPort,
                timeoutSeconds: settings.timeoutSeconds
            )
        }
    }

    /// Measures TCP SYN/ACK handshake RTT via `NWConnection` (Network.framework).
    public static func measureLatency(
        host: String,
        port: Int,
        timeoutSeconds: Double = 3.0
    ) async -> Int? {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else {
            return nil
        }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: nwPort
        )

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = max(1, Int(timeoutSeconds.rounded(.up)))
        tcpOptions.enableFastOpen = true
        let params = NWParameters(tls: nil, tcp: tcpOptions)

        let connection = NWConnection(to: endpoint, using: params)
        let startTime = ContinuousClock.now

        return await withTaskGroup(of: Int?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    final class ResumeGate: @unchecked Sendable {
                        var didResume = false
                        let lock = NSLock()
                    }
                    let gate = ResumeGate()

                    connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            gate.lock.lock()
                            defer { gate.lock.unlock() }
                            guard !gate.didResume else { return }
                            gate.didResume = true
                            let elapsed = startTime.duration(to: ContinuousClock.now)
                            let ms = Int(elapsed.components.seconds * 1000) + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
                            connection.cancel()
                            continuation.resume(returning: max(1, ms))
                        case .failed, .cancelled:
                            gate.lock.lock()
                            defer { gate.lock.unlock() }
                            guard !gate.didResume else { return }
                            gate.didResume = true
                            connection.cancel()
                            continuation.resume(returning: nil)
                        default:
                            break
                        }
                    }
                    connection.start(queue: .global(qos: .userInitiated))
                }
            }

            group.addTask {
                try? await Task.sleep(for: .milliseconds(Int(timeoutSeconds * 1000)))
                connection.cancel()
                return nil
            }

            let firstResult = await group.next() ?? nil
            group.cancelAll()
            return firstResult
        }
    }

    /// Measures HTTP 204 URLTest RTT combined with node endpoint reachability.
    public static func measureURLTestLatency(
        node: ProxyNode,
        urlString: String,
        timeoutSeconds: Double
    ) async -> Int? {
        // First verify the proxy node's own socket is reachable
        guard let tcpMs = await measureLatency(
            host: node.serverHost,
            port: node.serverPort,
            timeoutSeconds: timeoutSeconds
        ) else {
            return nil
        }

        guard let url = URL(string: urlString) else {
            return tcpMs
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let session = URLSession(configuration: config)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let start = ContinuousClock.now
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                let elapsed = start.duration(to: ContinuousClock.now)
                let httpMs = Int(elapsed.components.seconds * 1000) + Int(elapsed.components.attoseconds / 1_000_000_000_000_000)
                return max(tcpMs, (tcpMs + httpMs) / 2)
            }
        } catch {
            // Fall back to verified TCP handshake RTT if captive URL is blocked on current network
        }
        return tcpMs
    }
}
