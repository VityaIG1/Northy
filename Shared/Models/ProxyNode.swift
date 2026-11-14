import Foundation

// MARK: - Supported Proxy Protocols (Happ Core Compatible)

public enum ProxyProtocolType: String, Codable, CaseIterable, Sendable {
    case vless = "VLESS"
    case vmess = "VMESS"
    case trojan = "TROJAN"
    case shadowsocks = "SS"
    case hysteria2 = "HY2"
    case tuic = "TUIC"
    case wireguard = "WG"

    public var badgeLabel: String {
        switch self {
        case .vless: return "VLESS"
        case .vmess: return "VMESS"
        case .trojan: return "TROJAN"
        case .shadowsocks: return "SS"
        case .hysteria2: return "HYSTERIA2"
        case .tuic: return "TUIC"
        case .wireguard: return "WIREGUARD"
        }
    }
}

// MARK: - Stream Transport & Security

public enum TransportNetwork: String, Codable, Sendable {
    case tcp = "tcp"
    case ws = "ws"
    case grpc = "grpc"
    case httpUpgrade = "httpupgrade"
    case xhttp = "xhttp"
    case udp = "udp"
}

public enum StreamSecurity: String, Codable, Sendable {
    case none = "none"
    case tls = "tls"
    case reality = "reality"
}

// MARK: - ProxyNode Configuration Model

public struct ProxyNode: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var remark: String
    public var protocolType: ProxyProtocolType
    public var serverHost: String
    public var serverPort: Int
    /// UUID for VLESS/VMess, password for Trojan/Shadowsocks
    public var credential: String
    /// Cipher method for Shadowsocks or encryption mode for VLESS/VMess
    public var encryption: String
    /// XTLS flow (e.g., "xtls-rprx-vision")
    public var flow: String?
    public var transport: TransportNetwork
    public var security: StreamSecurity
    public var sni: String?
    public var fingerprint: String?
    /// REALITY public key (`pbk`)
    public var realityPublicKey: String?
    /// REALITY short ID (`sid`)
    public var realityShortId: String?
    /// WebSocket / HTTP path or gRPC serviceName
    public var path: String?
    /// Host header override
    public var hostHeader: String?
    public var allowInsecure: Bool
    /// Optional subscription group ID
    public var subscriptionId: UUID?
    /// Original raw URI string
    public var rawURI: String
    /// WireGuard specific configuration
    public var wireguardPublicKey: String?
    public var wireguardAddress: String?
    public var wireguardMTU: Int?
    public var wireguardReserved: [Int]?
    /// Last measured RTT in milliseconds (nil if not measured or unreachable)
    public var latencyMs: Int?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        remark: String,
        protocolType: ProxyProtocolType,
        serverHost: String,
        serverPort: Int,
        credential: String,
        encryption: String = "none",
        flow: String? = nil,
        transport: TransportNetwork = .tcp,
        security: StreamSecurity = .none,
        sni: String? = nil,
        fingerprint: String? = "chrome",
        realityPublicKey: String? = nil,
        realityShortId: String? = nil,
        path: String? = nil,
        hostHeader: String? = nil,
        allowInsecure: Bool = false,
        subscriptionId: UUID? = nil,
        rawURI: String,
        wireguardPublicKey: String? = nil,
        wireguardAddress: String? = nil,
        wireguardMTU: Int? = nil,
        wireguardReserved: [Int]? = nil,
        latencyMs: Int? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.remark = remark
        self.protocolType = protocolType
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.credential = credential
        self.encryption = encryption
        self.flow = flow
        self.transport = transport
        self.security = security
        self.sni = sni
        self.fingerprint = fingerprint
        self.realityPublicKey = realityPublicKey
        self.realityShortId = realityShortId
        self.path = path
        self.hostHeader = hostHeader
        self.allowInsecure = allowInsecure
        self.subscriptionId = subscriptionId
        self.rawURI = rawURI
        self.wireguardPublicKey = wireguardPublicKey
        self.wireguardAddress = wireguardAddress
        self.wireguardMTU = wireguardMTU
        self.wireguardReserved = wireguardReserved
        self.latencyMs = latencyMs
        self.createdAt = createdAt
    }

    public var endpointDisplay: String {
        "\(serverHost):\(serverPort)"
    }

    public var transportBadge: String {
        "\(transport.rawValue.uppercased()) // \(security.rawValue.uppercased())"
    }
}

// MARK: - Subscription Group

public struct SubscriptionSource: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var urlString: String
    public var lastUpdated: Date
    public var nodeCount: Int
    public var uploadBytes: Int64?
    public var downloadBytes: Int64?
    public var totalQuotaBytes: Int64?
    public var expireTimestamp: TimeInterval?
    public var updateIntervalHours: Int?
    public var supportURL: String?
    public var webPageURL: String?
    public var routingRulesPayload: String?
    public var announcement: String?

    public init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        lastUpdated: Date = .now,
        nodeCount: Int = 0,
        uploadBytes: Int64? = nil,
        downloadBytes: Int64? = nil,
        totalQuotaBytes: Int64? = nil,
        expireTimestamp: TimeInterval? = nil,
        updateIntervalHours: Int? = nil,
        supportURL: String? = nil,
        webPageURL: String? = nil,
        routingRulesPayload: String? = nil,
        announcement: String? = nil
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.lastUpdated = lastUpdated
        self.nodeCount = nodeCount
        self.uploadBytes = uploadBytes
        self.downloadBytes = downloadBytes
        self.totalQuotaBytes = totalQuotaBytes
        self.expireTimestamp = expireTimestamp
        self.updateIntervalHours = updateIntervalHours
        self.supportURL = supportURL
        self.webPageURL = webPageURL
        self.routingRulesPayload = routingRulesPayload
        self.announcement = announcement
    }

    public var effectiveSupportURL: URL? {
        if let s = supportURL, let u = URL(string: s) { return u }
        if let w = webPageURL, let u = URL(string: w) { return u }
        return nil
    }

    public var formattedExpirationDate: String? {
        guard let expire = expireTimestamp, expire > 0 else { return nil }
        let date = Date(timeIntervalSince1970: expire)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Happ Ping Settings (Настройки пинга)

public enum PingMeasurementMethod: String, Codable, CaseIterable, Sendable {
    case tcp = "TCP"
    case urlTest = "PROXY_GET"
    case icmp = "ICMP"

    public var localizationKey: String {
        switch self {
        case .tcp: return "ping.method.tcp"
        case .urlTest: return "ping.method.urltest"
        case .icmp: return "ping.method.icmp"
        }
    }

    public var shortTag: String {
        switch self {
        case .tcp: return "TCP SYN"
        case .urlTest: return "HTTP 204"
        case .icmp: return "ICMP ECHO"
        }
    }
}

public enum PingTestURLPreset: String, Codable, CaseIterable, Sendable {
    case cloudflare204 = "https://cp.cloudflare.com/generate_204"
    case google204 = "https://www.gstatic.com/generate_204"
    case connectivityCheck = "http://connectivitycheck.gstatic.com/generate_204"
    case appleCaptive = "https://www.apple.com/library/test/success.html"

    public var displayName: String {
        switch self {
        case .cloudflare204: return "CLOUDFLARE // CP.CLOUDFLARE.COM/GENERATE_204"
        case .google204: return "GOOGLE // WWW.GSTATIC.COM/GENERATE_204"
        case .connectivityCheck: return "GSTATIC // CONNECTIVITYCHECK/GENERATE_204"
        case .appleCaptive: return "APPLE // CAPTIVE.APPLE.COM/SUCCESS"
        }
    }
}

public enum PingResultDisplayMode: String, Codable, CaseIterable, Sendable {
    case millisecondsAndBars = "MS_AND_BARS"
    case barsOnly = "BARS_ONLY"

    public var localizationKey: String {
        switch self {
        case .millisecondsAndBars: return "ping.display.ms"
        case .barsOnly: return "ping.display.bars"
        }
    }
}

public struct HappPingSettings: Codable, Hashable, Sendable {
    public var method: PingMeasurementMethod
    public var testURLPreset: PingTestURLPreset
    public var timeoutSeconds: Double
    public var displayMode: PingResultDisplayMode
    public var sortNodesByLatency: Bool
    public var autoPingOnStartup: Bool
    public var concurrencyLimit: Int

    public static let availableTimeouts: [Double] = [1.5, 3.0, 5.0]

    public init(
        method: PingMeasurementMethod = .tcp,
        testURLPreset: PingTestURLPreset = .cloudflare204,
        timeoutSeconds: Double = 3.0,
        displayMode: PingResultDisplayMode = .millisecondsAndBars,
        sortNodesByLatency: Bool = false,
        autoPingOnStartup: Bool = true,
        concurrencyLimit: Int = 8
    ) {
        self.method = method
        self.testURLPreset = testURLPreset
        self.timeoutSeconds = timeoutSeconds
        self.displayMode = displayMode
        self.sortNodesByLatency = sortNodesByLatency
        self.autoPingOnStartup = autoPingOnStartup
        self.concurrencyLimit = concurrencyLimit
    }
}

// MARK: - Happ Connection & Core Settings (Настройки соединения, фрагментации, Mux, Sniffing)

public enum TunnelExecutionMode: String, Codable, CaseIterable, Sendable {
    case tun = "TUN"
    case proxyOnly = "PROXY_ONLY"

    public var localizationKey: String {
        switch self {
        case .tun: return "connection.mode.tun"
        case .proxyOnly: return "connection.mode.proxy"
        }
    }
}

public enum XrayDomainStrategy: String, Codable, CaseIterable, Sendable {
    case ipIfNonMatch = "IPIfNonMatch"
    case asIs = "AsIs"
    case ipOnDemand = "IPOnDemand"
}

public enum XrayLogLevel: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case error = "error"
    case warning = "warning"
    case info = "info"
    case debug = "debug"
}

public enum TLSFragmentPreset: String, Codable, CaseIterable, Sendable {
    case aggressive = "10-30"
    case balanced = "30-60"
    case subtle = "50-100"

    public var intervalRange: String {
        switch self {
        case .aggressive: return "5-10"
        case .balanced: return "10-20"
        case .subtle: return "15-30"
        }
    }

    public var label: String {
        "LEN \(rawValue)B // INT \(intervalRange)MS"
    }

    public var displayName: String {
        switch self {
        case .aggressive: return "AGGRESSIVE"
        case .balanced: return "BALANCED"
        case .subtle: return "SUBTLE"
        }
    }
}

public struct HappConnectionSettings: Codable, Hashable, Sendable {
    public var tunnelMode: TunnelExecutionMode
    public var enableSniffing: Bool
    public var sniffOverrideDestination: Bool
    public var enableMux: Bool
    public var muxConcurrency: Int
    public var enableTLSFragment: Bool
    public var tlsFragmentPreset: TLSFragmentPreset
    public var enableTCPFastOpen: Bool
    public var allowInsecureByDefault: Bool
    public var connectOnDemand: Bool
    public var disconnectOnSleep: Bool
    public var tunMTU: Int
    public var domainStrategy: XrayDomainStrategy
    public var logLevel: XrayLogLevel

    public static let availableMTUs: [Int] = [1280, 1360, 1400, 1500]

    public init(
        tunnelMode: TunnelExecutionMode = .tun,
        enableSniffing: Bool = true,
        sniffOverrideDestination: Bool = true,
        enableMux: Bool = false,
        muxConcurrency: Int = 8,
        enableTLSFragment: Bool = false,
        tlsFragmentPreset: TLSFragmentPreset = .aggressive,
        enableTCPFastOpen: Bool = false,
        allowInsecureByDefault: Bool = false,
        connectOnDemand: Bool = false,
        disconnectOnSleep: Bool = false,
        tunMTU: Int = 1400,
        domainStrategy: XrayDomainStrategy = .ipIfNonMatch,
        logLevel: XrayLogLevel = .warning
    ) {
        self.tunnelMode = tunnelMode
        self.enableSniffing = enableSniffing
        self.sniffOverrideDestination = sniffOverrideDestination
        self.enableMux = enableMux
        self.muxConcurrency = muxConcurrency
        self.enableTLSFragment = enableTLSFragment
        self.tlsFragmentPreset = tlsFragmentPreset
        self.enableTCPFastOpen = enableTCPFastOpen
        self.allowInsecureByDefault = allowInsecureByDefault
        self.connectOnDemand = connectOnDemand
        self.disconnectOnSleep = disconnectOnSleep
        self.tunMTU = tunMTU
        self.domainStrategy = domainStrategy
        self.logLevel = logLevel
    }
}

// MARK: - Incy / Happ Subscription Settings (Настройки подписок & Маскировка Incy / Happ)

public enum SubscriptionUserAgentProfile: String, Codable, CaseIterable, Sendable {
    case incyDefault = "Incy/1.0.0/ios"
    case incyLegacy = "Incy/0.9.8/ios"
    case happDefault = "Happ/3.0.0/ios"
    case happLegacy = "Happ/0.4.0 (iOS; Northy)"
    case v2rayNG = "v2rayNG/1.8.23"
    case clashMeta = "ClashMetaForAndroid/2.10.1"
    case singBox = "SFI/1.10.0 (iOS; sing-box 1.10.0)"

    public var shortLabel: String {
        switch self {
        case .incyDefault: return "INCY 1.0 // DEFAULT"
        case .incyLegacy: return "INCY LEGACY"
        case .happDefault: return "HAPP 3.0"
        case .happLegacy: return "HAPP LEGACY"
        case .v2rayNG: return "V2RAYNG"
        case .clashMeta: return "CLASH.META"
        case .singBox: return "SING-BOX"
        }
    }
}

public struct HappSubscriptionSettings: Codable, Hashable, Sendable {
    public var autoUpdateOnLaunch: Bool
    public var updateIntervalHours: Int
    public var userAgentProfile: SubscriptionUserAgentProfile
    public var pingAfterSync: Bool
    public var enableHappMasquerading: Bool
    public var customUserAgent: String?

    public static let availableIntervals: [Int] = [1, 6, 12, 24]

    public init(
        autoUpdateOnLaunch: Bool = true,
        updateIntervalHours: Int = 6,
        userAgentProfile: SubscriptionUserAgentProfile = .incyDefault,
        pingAfterSync: Bool = true,
        enableHappMasquerading: Bool = true,
        customUserAgent: String? = nil
    ) {
        self.autoUpdateOnLaunch = autoUpdateOnLaunch
        self.updateIntervalHours = updateIntervalHours
        self.userAgentProfile = userAgentProfile
        self.pingAfterSync = pingAfterSync
        self.enableHappMasquerading = enableHappMasquerading
        self.customUserAgent = customUserAgent
    }

    public var resolvedUserAgent: String {
        if let custom = customUserAgent, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if enableHappMasquerading {
            return "Incy/1.0.0/ios"
        }
        return userAgentProfile.rawValue
    }
}

// MARK: - Routing & DNS Settings (Happ Split-Tunneling Architecture)

public enum RoutingMode: String, Codable, CaseIterable, Sendable {
    case globalTunnel = "GLOBAL"
    case splitBypassLANAndRegional = "SPLIT_BYPASS"
    case directOnly = "DIRECT"

    public var localizationKey: String {
        switch self {
        case .globalTunnel:
            return "routing.mode.global"
        case .splitBypassLANAndRegional:
            return "routing.mode.split"
        case .directOnly:
            return "routing.mode.direct"
        }
    }

    public var subtitleKey: String {
        switch self {
        case .globalTunnel:
            return "routing.mode.global.desc"
        case .splitBypassLANAndRegional:
            return "routing.mode.split.desc"
        case .directOnly:
            return "routing.mode.direct.desc"
        }
    }
}

public enum DNSProviderOption: String, Codable, CaseIterable, Sendable {
    case cloudflare = "1.1.1.1"
    case google = "8.8.8.8"
    case quad9 = "9.9.9.9"
    case adguard = "94.140.14.14"

    public var displayName: String {
        switch self {
        case .cloudflare:
            return "CLOUDFLARE // 1.1.1.1"
        case .google:
            return "GOOGLE // 8.8.8.8"
        case .quad9:
            return "QUAD9 // 9.9.9.9"
        case .adguard:
            return "ADGUARD // 94.140.14.14"
        }
    }

    public var resolverAddresses: [String] {
        switch self {
        case .cloudflare:
            return ["1.1.1.1", "1.0.0.1"]
        case .google:
            return ["8.8.8.8", "8.8.4.4"]
        case .quad9:
            return ["9.9.9.9", "149.112.112.112"]
        case .adguard:
            return ["94.140.14.14", "94.140.15.15"]
        }
    }

    public var dohURLString: String {
        switch self {
        case .cloudflare:
            return "https://cloudflare-dns.com/dns-query"
        case .google:
            return "https://dns.google/dns-query"
        case .quad9:
            return "https://dns.quad9.net/dns-query"
        case .adguard:
            return "https://dns.adguard-dns.com/dns-query"
        }
    }
}

public struct TunnelRoutingConfiguration: Codable, Hashable, Sendable {
    public var routingMode: RoutingMode
    public var dnsProvider: DNSProviderOption
    public var bypassLocalNetwork: Bool
    public var enableIPv6Routing: Bool
    public var customExcludedCIDRs: [String]
    public var strictKillSwitch: Bool

    public init(
        routingMode: RoutingMode = .splitBypassLANAndRegional,
        dnsProvider: DNSProviderOption = .cloudflare,
        bypassLocalNetwork: Bool = true,
        enableIPv6Routing: Bool = false,
        customExcludedCIDRs: [String] = [
            "10.0.0.0/8",
            "172.16.0.0/12",
            "192.168.0.0/16",
            "100.64.0.0/10"
        ],
        strictKillSwitch: Bool = true
    ) {
        self.routingMode = routingMode
        self.dnsProvider = dnsProvider
        self.bypassLocalNetwork = bypassLocalNetwork
        self.enableIPv6Routing = enableIPv6Routing
        self.customExcludedCIDRs = customExcludedCIDRs
        self.strictKillSwitch = strictKillSwitch
    }
}

// MARK: - Live Tunnel Telemetry

public struct TunnelRuntimeTelemetry: Codable, Sendable {
    public var isConnected: Bool
    public var activeNodeId: UUID?
    public var rxBytes: UInt64
    public var txBytes: UInt64
    public var rxSpeed: UInt64
    public var txSpeed: UInt64
    public var connectedSince: Date?
    public var coreStatus: String
    public var lastError: String?

    public init(
        isConnected: Bool = false,
        activeNodeId: UUID? = nil,
        rxBytes: UInt64 = 0,
        txBytes: UInt64 = 0,
        rxSpeed: UInt64 = 0,
        txSpeed: UInt64 = 0,
        connectedSince: Date? = nil,
        coreStatus: String = "IDLE",
        lastError: String? = nil
    ) {
        self.isConnected = isConnected
        self.activeNodeId = activeNodeId
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.rxSpeed = rxSpeed
        self.txSpeed = txSpeed
        self.connectedSince = connectedSince
        self.coreStatus = coreStatus
        self.lastError = lastError
    }

    enum CodingKeys: String, CodingKey {
        case isConnected, activeNodeId, rxBytes, txBytes, rxSpeed, txSpeed, connectedSince, coreStatus, lastError
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isConnected = try container.decodeIfPresent(Bool.self, forKey: .isConnected) ?? false
        self.activeNodeId = try container.decodeIfPresent(UUID.self, forKey: .activeNodeId)
        self.rxBytes = try container.decodeIfPresent(UInt64.self, forKey: .rxBytes) ?? 0
        self.txBytes = try container.decodeIfPresent(UInt64.self, forKey: .txBytes) ?? 0
        self.rxSpeed = try container.decodeIfPresent(UInt64.self, forKey: .rxSpeed) ?? 0
        self.txSpeed = try container.decodeIfPresent(UInt64.self, forKey: .txSpeed) ?? 0
        self.connectedSince = try container.decodeIfPresent(Date.self, forKey: .connectedSince)
        self.coreStatus = try container.decodeIfPresent(String.self, forKey: .coreStatus) ?? (self.isConnected ? "RUNNING" : "IDLE")
        self.lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
    }
}
