import Foundation

// MARK: - Happ-Compatible Configuration & Subscription Parser

public enum HappParserError: LocalizedError, Sendable {
    case emptyPayload
    case unsupportedScheme(String)
    case malformedURI(String)
    case invalidBase64Payload
    case networkSubscriptionFailure(String)

    public var errorDescription: String? {
        switch self {
        case .emptyPayload:
            return "CLIPBOARD_EMPTY // NO_URI_FOUND"
        case .unsupportedScheme(let scheme):
            return "UNSUPPORTED_PROTOCOL // \(scheme.uppercased())"
        case .malformedURI(let detail):
            return "MALFORMED_CONFIG // \(detail)"
        case .invalidBase64Payload:
            return "DECODE_ERROR // INVALID_BASE64"
        case .networkSubscriptionFailure(let reason):
            return "SUBSCRIPTION_SYNC_ERROR // \(reason)"
        }
    }
}

public enum ParsedClipboardResult: Sendable {
    case nodes([ProxyNode])
    case remoteSubscriptionURL(URL)
}

public struct HappLinkParser: Sendable {

    // MARK: - Entry Point for Paste-to-Connect

    /// Parses raw clipboard text containing a single proxy link, multiple newline-separated links,
    /// a Base64-encoded subscription block, or an HTTPS subscription URL.
    public static func parseClipboardPayload(_ rawInput: String, subscriptionId: UUID? = nil) throws -> ParsedClipboardResult {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HappParserError.emptyPayload
        }

        // 1. Check if payload is an HTTPS subscription link
        if (trimmed.lowercased().hasPrefix("https://") || trimmed.lowercased().hasPrefix("http://")),
           !trimmed.contains("\n"),
           let url = URL(string: trimmed) {
            return .remoteSubscriptionURL(url)
        }

        // 2. Check if payload is a Happ custom deep link (`happ://add/...` or `v2raytun://import/...`)
        if trimmed.lowercased().hasPrefix("happ://") || trimmed.lowercased().hasPrefix("v2raytun://") {
            if let extracted = extractEmbeddedURL(from: trimmed) {
                return .remoteSubscriptionURL(extracted)
            }
        }

        // 3. Attempt direct line-by-line URI parsing
        let directNodes = parseMultiLineURIs(trimmed, subscriptionId: subscriptionId)
        if !directNodes.isEmpty {
            return .nodes(directNodes)
        }

        // 4. Attempt Base64 subscription decoding (standard & URL-safe Base64)
        if let decodedString = decodeBase64Flexible(trimmed) {
            let decodedNodes = parseMultiLineURIs(decodedString, subscriptionId: subscriptionId)
            if !decodedNodes.isEmpty {
                return .nodes(decodedNodes)
            }
        }

        throw HappParserError.malformedURI("NO_VALID_NODES_DETECTED")
    }

    // MARK: - Multi-Line URI Extraction

    public static func parseMultiLineURIs(_ text: String, subscriptionId: UUID? = nil) -> [ProxyNode] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("//") }

        var nodes: [ProxyNode] = []
        for line in lines {
            if let node = try? parseSingleURI(line, subscriptionId: subscriptionId) {
                nodes.append(node)
            }
        }
        return nodes
    }

    // MARK: - Single URI Dispatcher

    public static func parseSingleURI(_ uri: String, subscriptionId: UUID? = nil) throws -> ProxyNode {
        let trimmed = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("vless://") {
            return try parseVLESS(trimmed, subscriptionId: subscriptionId)
        } else if lower.hasPrefix("vmess://") {
            return try parseVMess(trimmed, subscriptionId: subscriptionId)
        } else if lower.hasPrefix("trojan://") {
            return try parseTrojan(trimmed, subscriptionId: subscriptionId)
        } else if lower.hasPrefix("ss://") {
            return try parseShadowsocks(trimmed, subscriptionId: subscriptionId)
        } else {
            let scheme = trimmed.components(separatedBy: "://").first ?? "UNKNOWN"
            throw HappParserError.unsupportedScheme(scheme)
        }
    }

    // MARK: - VLESS Parser (Xray / Sing-box REALITY & TLS, Cyrillic/Emoji Fragment Safe)

    private static func parseVLESS(_ uri: String, subscriptionId: UUID?) throws -> ProxyNode {
        let (sanitizedURI, rawFragment) = splitFragmentSafely(uri)
        guard let components = URLComponents(string: sanitizedURI),
              let host = components.host, !host.isEmpty,
              let uuid = components.user?.removingPercentEncoding ?? components.user, !uuid.isEmpty else {
            throw HappParserError.malformedURI("VLESS_HEADER_INVALID")
        }

        let port = components.port ?? 443
        let query = queryDictionary(from: components.queryItems)
        let decodedRemark = (rawFragment ?? components.fragment)?
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let remark = (decodedRemark?.isEmpty == false) ? decodedRemark! : "VLESS // \(host)"

        let transport = TransportNetwork(rawValue: (query["type"] ?? "tcp").lowercased()) ?? .tcp
        let security = StreamSecurity(rawValue: (query["security"] ?? "none").lowercased()) ?? .none

        return ProxyNode(
            remark: remark,
            protocolType: .vless,
            serverHost: host,
            serverPort: port,
            credential: uuid,
            encryption: query["encryption"] ?? "none",
            flow: query["flow"],
            transport: transport,
            security: security,
            sni: query["sni"] ?? query["serverName"],
            fingerprint: query["fp"] ?? "chrome",
            realityPublicKey: query["pbk"],
            realityShortId: query["sid"],
            path: query["path"] ?? query["serviceName"],
            hostHeader: query["host"],
            allowInsecure: query["allowInsecure"] == "1" || query["allowInsecure"] == "true",
            subscriptionId: subscriptionId,
            rawURI: uri
        )
    }

    // MARK: - Trojan Parser (Cyrillic/Emoji Fragment Safe)

    private static func parseTrojan(_ uri: String, subscriptionId: UUID?) throws -> ProxyNode {
        let (sanitizedURI, rawFragment) = splitFragmentSafely(uri)
        guard let components = URLComponents(string: sanitizedURI),
              let host = components.host, !host.isEmpty,
              let password = components.user?.removingPercentEncoding ?? components.user, !password.isEmpty else {
            throw HappParserError.malformedURI("TROJAN_HEADER_INVALID")
        }

        let port = components.port ?? 443
        let query = queryDictionary(from: components.queryItems)
        let decodedRemark = (rawFragment ?? components.fragment)?
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let remark = (decodedRemark?.isEmpty == false) ? decodedRemark! : "TROJAN // \(host)"

        let transport = TransportNetwork(rawValue: (query["type"] ?? "tcp").lowercased()) ?? .tcp
        let security = StreamSecurity(rawValue: (query["security"] ?? "tls").lowercased()) ?? .tls

        return ProxyNode(
            remark: remark,
            protocolType: .trojan,
            serverHost: host,
            serverPort: port,
            credential: password,
            encryption: "tls",
            flow: query["flow"],
            transport: transport,
            security: security,
            sni: query["sni"] ?? query["peer"] ?? host,
            fingerprint: query["fp"] ?? "chrome",
            realityPublicKey: query["pbk"],
            realityShortId: query["sid"],
            path: query["path"] ?? query["serviceName"],
            hostHeader: query["host"],
            allowInsecure: query["allowInsecure"] == "1" || query["allowInsecure"] == "true",
            subscriptionId: subscriptionId,
            rawURI: uri
        )
    }

    // MARK: - VMess Parser (V2RayN Base64 JSON Format)

    private struct VMessJSONPayload: Decodable {
        let v: String?
        let ps: String?
        let add: String
        let port: FlexiblePort
        let id: String
        let scy: String?
        let net: String?
        let tls: String?
        let sni: String?
        let host: String?
        let path: String?
        let fp: String?

        enum FlexiblePort: Decodable {
            case int(Int)
            case string(String)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let intVal = try? container.decode(Int.self) {
                    self = .int(intVal)
                } else if let strVal = try? container.decode(String.self) {
                    self = .string(strVal)
                } else {
                    self = .int(443)
                }
            }

            var value: Int {
                switch self {
                case .int(let v): return v
                case .string(let s): return Int(s) ?? 443
                }
            }
        }
    }

    private static func parseVMess(_ uri: String, subscriptionId: UUID?) throws -> ProxyNode {
        let base64Part = String(uri.dropFirst("vmess://".count))
        guard let decoded = decodeBase64Flexible(base64Part),
              let data = decoded.data(using: .utf8),
              let payload = try? JSONDecoder().decode(VMessJSONPayload.self, from: data) else {
            throw HappParserError.malformedURI("VMESS_JSON_INVALID")
        }

        let transport = TransportNetwork(rawValue: (payload.net ?? "tcp").lowercased()) ?? .tcp
        let isTLS = (payload.tls ?? "").lowercased() == "tls"

        return ProxyNode(
            remark: (payload.ps?.isEmpty == false ? payload.ps! : "VMESS // \(payload.add)"),
            protocolType: .vmess,
            serverHost: payload.add,
            serverPort: payload.port.value,
            credential: payload.id,
            encryption: payload.scy ?? "auto",
            transport: transport,
            security: isTLS ? .tls : .none,
            sni: payload.sni ?? payload.host,
            fingerprint: payload.fp ?? "chrome",
            path: payload.path,
            hostHeader: payload.host,
            subscriptionId: subscriptionId,
            rawURI: uri
        )
    }

    // MARK: - Shadowsocks Parser (SIP002 & Legacy Base64)

    private static func parseShadowsocks(_ uri: String, subscriptionId: UUID?) throws -> ProxyNode {
        let withoutScheme = String(uri.dropFirst("ss://".count))
        let (mainPart, rawFragment) = splitFragmentSafely(withoutScheme)
        let remark = rawFragment?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "SHADOWSOCKS"

        // SIP002 format: base64(method:password)@host:port
        if mainPart.contains("@") {
            let parts = mainPart.components(separatedBy: "@")
            guard parts.count == 2 else {
                throw HappParserError.malformedURI("SS_SIP002_INVALID")
            }
            let userInfo = decodeBase64Flexible(parts[0]) ?? (parts[0].removingPercentEncoding ?? parts[0])
            let credParts = userInfo.split(separator: ":", maxSplits: 1).map(String.init)
            guard credParts.count == 2 else {
                throw HappParserError.malformedURI("SS_CIPHER_INVALID")
            }

            let hostPort = parts[1].components(separatedBy: "?")[0]
            let hpParts = hostPort.split(separator: ":", maxSplits: 1).map(String.init)
            guard hpParts.count == 2, let port = Int(hpParts[1]) else {
                throw HappParserError.malformedURI("SS_HOST_PORT_INVALID")
            }

            return ProxyNode(
                remark: remark.isEmpty ? "SS // \(hpParts[0])" : remark,
                protocolType: .shadowsocks,
                serverHost: hpParts[0],
                serverPort: port,
                credential: credParts[1],
                encryption: credParts[0],
                transport: .tcp,
                security: .none,
                subscriptionId: subscriptionId,
                rawURI: uri
            )
        } else {
            // Legacy format: base64(method:password@host:port)
            guard let decoded = decodeBase64Flexible(mainPart) else {
                throw HappParserError.invalidBase64Payload
            }
            return try parseShadowsocks("ss://\(decoded)#\(remark)", subscriptionId: subscriptionId)
        }
    }

    // MARK: - Xray / Sing-box Core JSON Config Builder (Full Happ Parity)

    public static func buildXrayCoreConfiguration(
        for node: ProxyNode,
        routing: TunnelRoutingConfiguration,
        connection: HappConnectionSettings = HappConnectionSettings()
    ) throws -> Data {
        var streamSettings: [String: Any] = [
            "network": node.transport.rawValue,
            "security": node.security.rawValue
        ]

        let allowInsecure = node.allowInsecure || connection.allowInsecureByDefault

        if node.security == .reality {
            streamSettings["realitySettings"] = [
                "serverName": node.sni ?? node.serverHost,
                "fingerprint": node.fingerprint ?? "chrome",
                "publicKey": node.realityPublicKey ?? "",
                "shortId": node.realityShortId ?? ""
            ]
        } else if node.security == .tls {
            streamSettings["tlsSettings"] = [
                "serverName": node.sni ?? node.serverHost,
                "allowInsecure": allowInsecure,
                "fingerprint": node.fingerprint ?? "chrome"
            ]
        }

        if node.transport == .ws {
            streamSettings["wsSettings"] = [
                "path": node.path ?? "/",
                "headers": ["Host": node.hostHeader ?? node.sni ?? node.serverHost]
            ]
        } else if node.transport == .grpc {
            streamSettings["grpcSettings"] = [
                "serviceName": node.path ?? ""
            ]
        } else if node.transport == .xhttp {
            streamSettings["xhttpSettings"] = [
                "path": node.path ?? "/",
                "host": node.hostHeader ?? node.sni ?? node.serverHost,
                "mode": "auto"
            ]
        }

        // Socket Options: TCP Fast Open + TLS ClientHello Fragmentation (Happ DPI Bypass)
        var sockopt: [String: Any] = [
            "tcpFastOpen": connection.enableTCPFastOpen
        ]
        if connection.enableTLSFragment {
            sockopt["dialerProxy"] = "fragment"
        }
        streamSettings["sockopt"] = sockopt

        let outboundProtocol: String
        var outboundSettings: [String: Any] = [:]

        switch node.protocolType {
        case .vless:
            outboundProtocol = "vless"
            var userDict: [String: Any] = [
                "id": node.credential,
                "encryption": node.encryption
            ]
            if let flow = node.flow, !flow.isEmpty {
                userDict["flow"] = flow
            }
            outboundSettings["vnext"] = [[
                "address": node.serverHost,
                "port": node.serverPort,
                "users": [userDict]
            ]]
        case .vmess:
            outboundProtocol = "vmess"
            outboundSettings["vnext"] = [[
                "address": node.serverHost,
                "port": node.serverPort,
                "users": [[
                    "id": node.credential,
                    "security": node.encryption
                ]]
            ]]
        case .trojan:
            outboundProtocol = "trojan"
            outboundSettings["servers"] = [[
                "address": node.serverHost,
                "port": node.serverPort,
                "password": node.credential
            ]]
        case .shadowsocks:
            outboundProtocol = "shadowsocks"
            outboundSettings["servers"] = [[
                "address": node.serverHost,
                "port": node.serverPort,
                "method": node.encryption,
                "password": node.credential
            ]]
        }

        // Sniffing configuration (Happ domain sniffing)
        let sniffingConfig: [String: Any] = [
            "enabled": connection.enableSniffing,
            "destOverride": ["http", "tls", "quic"],
            "routeOnly": !connection.sniffOverrideDestination
        ]

        // Inbounds (TUN + Local SOCKS5/HTTP Proxy)
        var inbounds: [[String: Any]] = [
            [
                "tag": "socks-in",
                "protocol": "socks",
                "listen": "127.0.0.1",
                "port": 10808,
                "settings": ["auth": "noauth", "udp": true],
                "sniffing": sniffingConfig
            ],
            [
                "tag": "http-in",
                "protocol": "http",
                "listen": "127.0.0.1",
                "port": 10809,
                "sniffing": sniffingConfig
            ]
        ]

        if connection.tunnelMode == .tun {
            inbounds.insert([
                "tag": "tun-in",
                "protocol": "tun",
                "settings": [
                    "name": "utun99",
                    "MTU": connection.tunMTU,
                    "autoRoute": true
                ],
                "sniffing": sniffingConfig
            ], at: 0)
        }

        // Outbounds (Proxy + Mux + Fragment + Direct + Block)
        var proxyOutbound: [String: Any] = [
            "tag": "proxy",
            "protocol": outboundProtocol,
            "settings": outboundSettings,
            "streamSettings": streamSettings
        ]

        if connection.enableMux && node.flow == nil {
            proxyOutbound["mux"] = [
                "enabled": true,
                "concurrency": connection.muxConcurrency
            ]
        }

        var outbounds: [[String: Any]] = [proxyOutbound]

        if connection.enableTLSFragment {
            outbounds.append([
                "tag": "fragment",
                "protocol": "freedom",
                "settings": [
                    "domainStrategy": "AsIs",
                    "fragment": [
                        "packets": "tlshello",
                        "length": connection.tlsFragmentPreset.rawValue,
                        "interval": connection.tlsFragmentPreset.intervalRange
                    ]
                ],
                "streamSettings": [
                    "sockopt": [
                        "tcpFastOpen": connection.enableTCPFastOpen,
                        "tcpNoDelay": true
                    ]
                ]
            ])
        }

        outbounds.append([
            "tag": "direct",
            "protocol": "freedom",
            "settings": ["domainStrategy": "UseIP"]
        ])
        outbounds.append([
            "tag": "block",
            "protocol": "blackhole"
        ])

        var routingRules: [[String: Any]] = [
            [
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "direct"
            ]
        ]

        if routing.routingMode == .splitBypassLANAndRegional {
            routingRules.append([
                "type": "field",
                "domain": ["geosite:category-ru", "regexp:.*\\.ru$", "regexp:.*\\.su$", "regexp:.*\\.рф$"],
                "outboundTag": "direct"
            ])
            routingRules.append([
                "type": "field",
                "ip": ["geoip:ru"],
                "outboundTag": "direct"
            ])
        } else if routing.routingMode == .directOnly {
            routingRules.append([
                "type": "field",
                "network": "tcp,udp",
                "outboundTag": "direct"
            ])
        }

        let rootConfig: [String: Any] = [
            "log": ["loglevel": connection.logLevel.rawValue],
            "dns": [
                "servers": routing.dnsProvider.resolverAddresses
            ],
            "inbounds": inbounds,
            "outbounds": outbounds,
            "routing": [
                "domainStrategy": connection.domainStrategy.rawValue,
                "rules": routingRules
            ]
        ]

        return try JSONSerialization.data(withJSONObject: rootConfig, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Helpers

    /// Splits `#fragment` before passing to `URLComponents` so unescaped spaces, Cyrillic, or emojis never break URI parsing.
    private static func splitFragmentSafely(_ uri: String) -> (baseURI: String, fragment: String?) {
        guard let hashIndex = uri.firstIndex(of: "#") else {
            return (uri, nil)
        }
        let base = String(uri[..<hashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let fragment = String(uri[uri.index(after: hashIndex)...])
        return (base, fragment)
    }

    private static func queryDictionary(from items: [URLQueryItem]?) -> [String: String] {
        guard let items else { return [:] }
        var dict: [String: String] = [:]
        for item in items {
            if let value = item.value {
                dict[item.name] = value
            }
        }
        return dict
    }

    private static func decodeBase64Flexible(_ input: String) -> String? {
        var sanitized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = sanitized.count % 4
        if remainder > 0 {
            sanitized.append(String(repeating: "=", count: 4 - remainder))
        }

        guard let data = Data(base64Encoded: sanitized, options: [.ignoreUnknownCharacters]),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }
        return decoded
    }

    private static func extractEmbeddedURL(from deepLink: String) -> URL? {
        if let range = deepLink.range(of: "https://") ?? deepLink.range(of: "http://") {
            let urlSubstring = String(deepLink[range.lowerBound...])
            return URL(string: urlSubstring.removingPercentEncoding ?? urlSubstring)
        }
        return nil
    }
}
