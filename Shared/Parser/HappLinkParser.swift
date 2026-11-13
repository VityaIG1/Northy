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

    // MARK: - Entry Point for Paste-to-Connect & Subscription Body Parsing

    /// Parses raw clipboard or subscription payload containing:
    /// - Direct HTTPS subscription URL
    /// - Happ custom deep links (`happ://add/...` or `v2raytun://import/...`)
    /// - Raw JSON Xray / sing-box subscription profiles (`{"outbounds": [...]}`)
    /// - Line-by-line URI list (VLESS, VMess, Trojan, SS, Hysteria2, TUIC)
    /// - Standard / URL-Safe Base64 subscription blocks
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

        // 2. Check if payload is an Incy deep link (`incy://...`)
        if trimmed.lowercased().hasPrefix("incy://") {
            if let decoded = decodeIncyDeepLink(trimmed) {
                if (decoded.lowercased().hasPrefix("https://") || decoded.lowercased().hasPrefix("http://")),
                   let url = URL(string: decoded) {
                    return .remoteSubscriptionURL(url)
                }
                if let nested = try? parseClipboardPayload(decoded, subscriptionId: subscriptionId) {
                    return nested
                }
            }
        }

        // 3. Check if payload is a Happ / v2raytun custom deep link
        if trimmed.lowercased().hasPrefix("happ://") || trimmed.lowercased().hasPrefix("v2raytun://") {
            if let extracted = extractEmbeddedURL(from: trimmed) {
                return .remoteSubscriptionURL(extracted)
            }
        }

        // 4. Check if payload is a raw WireGuard .conf file
        if trimmed.contains("[Interface]") && trimmed.contains("[Peer]") {
            if let wgNode = try? parseWireGuardConf(trimmed, subscriptionId: subscriptionId) {
                return .nodes([wgNode])
            }
        }

        // 5. Check if payload is a raw JSON configuration (Sing-box / Xray outbounds)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if let jsonNodes = tryParseJSONNodes(trimmed, subscriptionId: subscriptionId), !jsonNodes.isEmpty {
                return .nodes(jsonNodes)
            }
        }

        // 4. Attempt direct line-by-line URI parsing
        let directNodes = parseMultiLineURIs(trimmed, subscriptionId: subscriptionId)
        if !directNodes.isEmpty {
            return .nodes(directNodes)
        }

        // 5. Attempt Base64 subscription decoding (standard & URL-safe Base64)
        if let decodedString = decodeBase64Flexible(trimmed) {
            let decodedTrimmed = decodedString.trimmingCharacters(in: .whitespacesAndNewlines)
            if decodedTrimmed.hasPrefix("{") || decodedTrimmed.hasPrefix("[") {
                if let jsonNodes = tryParseJSONNodes(decodedTrimmed, subscriptionId: subscriptionId), !jsonNodes.isEmpty {
                    return .nodes(jsonNodes)
                }
            }
            let decodedNodes = parseMultiLineURIs(decodedString, subscriptionId: subscriptionId)
            if !decodedNodes.isEmpty {
                return .nodes(decodedNodes)
            }
        }

        throw HappParserError.malformedURI("NO_VALID_NODES_DETECTED")
    }

    // MARK: - Happ Profile-Title Decoder (Plain UTF-8, base64: prefix, URL Percent-Encoded)

    public static func decodeProfileTitle(_ headerValue: String) -> String {
        let trimmed = headerValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("base64:") {
            let b64 = String(trimmed.dropFirst(7))
            if let data = Data(base64Encoded: b64),
               let decoded = String(data: data, encoding: .utf8) {
                let clean = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty { return clean }
            }
        }
        if let unescaped = trimmed.removingPercentEncoding, unescaped != trimmed {
            return unescaped
        }
        return trimmed
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

    // MARK: - Single URI Dispatcher (VLESS, VMess, Trojan, SS, Hysteria2, TUIC)

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
        } else if lower.hasPrefix("hysteria2://") || lower.hasPrefix("hy2://") {
            return try parseHysteria2(trimmed, subscriptionId: subscriptionId)
        } else if lower.hasPrefix("tuic://") {
            return try parseTUIC(trimmed, subscriptionId: subscriptionId)
        } else if lower.hasPrefix("wireguard://") || lower.hasPrefix("wg://") {
            return try parseWireGuard(trimmed, subscriptionId: subscriptionId)
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

    // MARK: - Hysteria 2 Parser (hysteria2:// or hy2://)

    public static func parseHysteria2(_ uri: String, subscriptionId: UUID?) throws -> ProxyNode {
        let (sanitizedURI, rawFragment) = splitFragmentSafely(uri)
        let normalized = sanitizedURI.hasPrefix("hy2://")
            ? sanitizedURI.replacingOccurrences(of: "hy2://", with: "hysteria2://")
            : sanitizedURI

        guard let url = URL(string: normalized),
              let host = url.host else {
            throw HappParserError.malformedURI("HYSTERIA2_HOST_PORT_MISSING")
        }
        let port = url.port ?? 443

        let password = url.user ?? ""
        let query = queryDictionary(from: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let sni = query["sni"] ?? host
        let allowInsecure = query["insecure"] == "1"
        let remark = rawFragment ?? query["remark"] ?? "HY2 // \(host)"

        return ProxyNode(
            remark: remark,
            protocolType: .hysteria2,
            serverHost: host,
            serverPort: port,
            credential: password,
            encryption: "none",
            transport: .udp,
            security: .tls,
            sni: sni,
            allowInsecure: allowInsecure,
            subscriptionId: subscriptionId,
            rawURI: uri
        )
    }

    // MARK: - TUIC Parser (tuic://)

    public static func parseTUIC(_ uri: String, subscriptionId: UUID?) throws -> ProxyNode {
        let (sanitizedURI, rawFragment) = splitFragmentSafely(uri)
        guard let url = URL(string: sanitizedURI),
              let host = url.host else {
            throw HappParserError.malformedURI("TUIC_HOST_PORT_MISSING")
        }
        let port = url.port ?? 443

        let userString = url.user ?? ""
        let password = url.password ?? ""
        let credential = password.isEmpty ? userString : "\(userString):\(password)"

        let query = queryDictionary(from: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let sni = query["sni"] ?? host
        let allowInsecure = query["allow_insecure"] == "1" || query["insecure"] == "1"
        let remark = rawFragment ?? "TUIC // \(host)"

        return ProxyNode(
            remark: remark,
            protocolType: .tuic,
            serverHost: host,
            serverPort: port,
            credential: credential,
            encryption: "none",
            transport: .udp,
            security: .tls,
            sni: sni,
            allowInsecure: allowInsecure,
            subscriptionId: subscriptionId,
            rawURI: uri
        )
    }

    // MARK: - WireGuard Parser (wireguard:// or wg://)

    public static func parseWireGuard(_ uri: String, subscriptionId: UUID?) throws -> ProxyNode {
        let (sanitizedURI, rawFragment) = splitFragmentSafely(uri)
        guard let url = URL(string: sanitizedURI),
              let host = url.host else {
            throw HappParserError.malformedURI("WIREGUARD_HOST_MISSING")
        }
        let port = url.port ?? 51820
        let privateKey = url.user?.removingPercentEncoding ?? url.user ?? ""
        guard !privateKey.isEmpty else {
            throw HappParserError.malformedURI("WIREGUARD_PRIVATE_KEY_MISSING")
        }

        let query = queryDictionary(from: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let publicKey = query["public_key"] ?? query["pubkey"] ?? query["peer_public_key"] ?? ""
        let address = query["address"] ?? query["ip"] ?? "10.0.0.2/32"
        let mtu = Int(query["mtu"] ?? "") ?? 1420

        var reserved: [Int]? = nil
        if let resStr = query["reserved"] {
            let parts = resStr
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if !parts.isEmpty {
                reserved = parts
            }
        }

        let decodedRemark = rawFragment?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines)
        let remark = (decodedRemark?.isEmpty == false) ? decodedRemark! : "WIREGUARD // \(host)"

        return ProxyNode(
            remark: remark,
            protocolType: .wireguard,
            serverHost: host,
            serverPort: port,
            credential: privateKey,
            encryption: "chacha20-poly1305",
            transport: .udp,
            security: .none,
            subscriptionId: subscriptionId,
            rawURI: uri,
            wireguardPublicKey: publicKey,
            wireguardAddress: address,
            wireguardMTU: mtu,
            wireguardReserved: reserved
        )
    }

    // MARK: - WireGuard .conf Parser ([Interface] & [Peer])

    public static func parseWireGuardConf(_ text: String, subscriptionId: UUID?) throws -> ProxyNode {
        var interfaceDict: [String: String] = [:]
        var peerDict: [String: String] = [:]
        var currentSection: String = ""
        var remark: String?

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("#") {
                if remark == nil {
                    let comment = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                    if !comment.isEmpty && !comment.lowercased().contains("configuration") {
                        remark = comment
                    }
                }
                continue
            }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces).lowercased()
                continue
            }

            let parts = trimmed.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let key = parts[0].lowercased()
                let value = parts[1]
                if currentSection == "interface" {
                    interfaceDict[key] = value
                } else if currentSection == "peer" {
                    peerDict[key] = value
                }
            }
        }

        guard let privateKey = interfaceDict["privatekey"], !privateKey.isEmpty else {
            throw HappParserError.malformedURI("WIREGUARD_CONF_PRIVATE_KEY_MISSING")
        }
        guard let endpoint = peerDict["endpoint"], !endpoint.isEmpty else {
            throw HappParserError.malformedURI("WIREGUARD_CONF_ENDPOINT_MISSING")
        }

        let endpointParts = endpoint.split(separator: ":").map { String($0) }
        guard endpointParts.count == 2, let port = Int(endpointParts[1]) else {
            throw HappParserError.malformedURI("WIREGUARD_CONF_ENDPOINT_PORT_INVALID")
        }
        let host = endpointParts[0].trimmingCharacters(in: .whitespaces)
        let publicKey = peerDict["publickey"] ?? ""
        let address = interfaceDict["address"] ?? "10.0.0.2/32"
        let mtu = Int(interfaceDict["mtu"] ?? "") ?? 1420

        var reserved: [Int]? = nil
        if let resStr = peerDict["reserved"] {
            let parts = resStr
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
                .components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if !parts.isEmpty {
                reserved = parts
            }
        }

        let nodeRemark = remark ?? "WIREGUARD // \(host)"

        return ProxyNode(
            remark: nodeRemark,
            protocolType: .wireguard,
            serverHost: host,
            serverPort: port,
            credential: privateKey,
            encryption: "chacha20-poly1305",
            transport: .udp,
            security: .none,
            subscriptionId: subscriptionId,
            rawURI: text,
            wireguardPublicKey: publicKey,
            wireguardAddress: address,
            wireguardMTU: mtu,
            wireguardReserved: reserved
        )
    }

    // MARK: - Raw JSON Xray / Sing-box Subscription Profile Parser

    public static func tryParseJSONNodes(_ jsonString: String, subscriptionId: UUID?) -> [ProxyNode]? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return nil
        }

        var outboundsArray: [[String: Any]] = []

        if let dict = obj as? [String: Any] {
            if let outbounds = dict["outbounds"] as? [[String: Any]] {
                outboundsArray = outbounds
            } else if let servers = dict["servers"] as? [[String: Any]] {
                outboundsArray = servers
            }
        } else if let array = obj as? [[String: Any]] {
            outboundsArray = array
        }

        guard !outboundsArray.isEmpty else { return nil }

        var result: [ProxyNode] = []
        for item in outboundsArray {
            let typeStr = (item["type"] as? String ?? item["protocol"] as? String ?? "").lowercased()
            let tag = item["tag"] as? String ?? item["remark"] as? String ?? "Node"

            let server = item["server"] as? String ?? item["address"] as? String
            let port = item["server_port"] as? Int ?? item["port"] as? Int

            guard let server, let port else { continue }

            switch typeStr {
            case "vless":
                let uuid = item["uuid"] as? String ?? ""
                let flow = item["flow"] as? String
                var security: StreamSecurity = .none
                var sni: String?
                var pbk: String?
                var sid: String?

                if let tls = item["tls"] as? [String: Any] {
                    security = .tls
                    sni = tls["server_name"] as? String
                    if let reality = tls["reality"] as? [String: Any] {
                        security = .reality
                        pbk = reality["public_key"] as? String
                        sid = reality["short_id"] as? String
                    }
                }

                let node = ProxyNode(
                    remark: tag,
                    protocolType: .vless,
                    serverHost: server,
                    serverPort: port,
                    credential: uuid,
                    flow: flow,
                    transport: .tcp,
                    security: security,
                    sni: sni,
                    realityPublicKey: pbk,
                    realityShortId: sid,
                    subscriptionId: subscriptionId,
                    rawURI: "vless://\(uuid)@\(server):\(port)#\(tag)"
                )
                result.append(node)

            case "trojan":
                let password = item["password"] as? String ?? ""
                let tls = item["tls"] as? [String: Any]
                let sni = tls?["server_name"] as? String
                let node = ProxyNode(
                    remark: tag,
                    protocolType: .trojan,
                    serverHost: server,
                    serverPort: port,
                    credential: password,
                    transport: .tcp,
                    security: .tls,
                    sni: sni,
                    subscriptionId: subscriptionId,
                    rawURI: "trojan://\(password)@\(server):\(port)#\(tag)"
                )
                result.append(node)

            case "shadowsocks":
                let password = item["password"] as? String ?? ""
                let method = item["method"] as? String ?? "aes-128-gcm"
                let node = ProxyNode(
                    remark: tag,
                    protocolType: .shadowsocks,
                    serverHost: server,
                    serverPort: port,
                    credential: password,
                    encryption: method,
                    transport: .tcp,
                    security: .none,
                    subscriptionId: subscriptionId,
                    rawURI: "ss://\(password)@\(server):\(port)#\(tag)"
                )
                result.append(node)

            case "hysteria2", "hy2":
                let password = item["password"] as? String ?? ""
                let tls = item["tls"] as? [String: Any]
                let sni = tls?["server_name"] as? String
                let node = ProxyNode(
                    remark: tag,
                    protocolType: .hysteria2,
                    serverHost: server,
                    serverPort: port,
                    credential: password,
                    transport: .udp,
                    security: .tls,
                    sni: sni,
                    subscriptionId: subscriptionId,
                    rawURI: "hy2://\(password)@\(server):\(port)#\(tag)"
                )
                result.append(node)

            case "tuic":
                let uuid = item["uuid"] as? String ?? ""
                let password = item["password"] as? String ?? ""
                let tls = item["tls"] as? [String: Any]
                let sni = tls?["server_name"] as? String
                let cred = password.isEmpty ? uuid : "\(uuid):\(password)"
                let node = ProxyNode(
                    remark: tag,
                    protocolType: .tuic,
                    serverHost: server,
                    serverPort: port,
                    credential: cred,
                    transport: .udp,
                    security: .tls,
                    sni: sni,
                    subscriptionId: subscriptionId,
                    rawURI: "tuic://\(cred)@\(server):\(port)#\(tag)"
                )
                result.append(node)

            case "wireguard", "wg":
                let privateKey = item["private_key"] as? String ?? item["secret_key"] as? String ?? ""
                let publicKey = item["public_key"] as? String ?? item["peer_public_key"] as? String ?? ""
                let address = item["local_address"] as? String ?? item["address"] as? String ?? "10.0.0.2/32"
                let mtu = item["mtu"] as? Int ?? 1420
                let reserved = item["reserved"] as? [Int]
                let node = ProxyNode(
                    remark: tag,
                    protocolType: .wireguard,
                    serverHost: server,
                    serverPort: port,
                    credential: privateKey,
                    encryption: "chacha20-poly1305",
                    transport: .udp,
                    security: .none,
                    subscriptionId: subscriptionId,
                    rawURI: "wg://\(privateKey)@\(server):\(port)#\(tag)",
                    wireguardPublicKey: publicKey,
                    wireguardAddress: address,
                    wireguardMTU: mtu,
                    wireguardReserved: reserved
                )
                result.append(node)

            default:
                break
            }
        }

        return result.isEmpty ? nil : result
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
        case .hysteria2:
            outboundProtocol = "hysteria2"
            outboundSettings["servers"] = [[
                "address": node.serverHost,
                "port": node.serverPort,
                "password": node.credential
            ]]
        case .tuic:
            outboundProtocol = "tuic"
            outboundSettings["servers"] = [[
                "address": node.serverHost,
                "port": node.serverPort,
                "uuid": node.credential
            ]]
        case .wireguard:
            outboundProtocol = "wireguard"
            let peerDict: [String: Any] = [
                "publicKey": node.wireguardPublicKey ?? "",
                "endpoint": "\(node.serverHost):\(node.serverPort)",
                "allowedIPs": ["0.0.0.0/0", "::/0"]
            ]
            let addresses = (node.wireguardAddress ?? "10.0.0.2/32")
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            var wgSettings: [String: Any] = [
                "secretKey": node.credential,
                "address": addresses.isEmpty ? ["10.0.0.2/32"] : addresses,
                "peers": [peerDict],
                "mtu": node.wireguardMTU ?? 1420
            ]
            if let reserved = node.wireguardReserved, !reserved.isEmpty {
                wgSettings["reserved"] = reserved
            }
            outboundSettings = wgSettings
        }

        // Sniffing configuration (Happ domain sniffing)
        let sniffingConfig: [String: Any] = [
            "enabled": connection.enableSniffing,
            "destOverride": ["http", "tls", "quic"],
            "routeOnly": !connection.sniffOverrideDestination
        ]

        // Inbounds (TUN + Local SOCKS5 + HTTP Proxy + DNS Inbound)
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
            ],
            [
                "tag": "dns-in",
                "protocol": "dokodemo-door",
                "listen": "127.0.0.1",
                "port": 10853,
                "settings": [
                    "address": "127.0.0.1",
                    "port": 53,
                    "network": "tcp,udp",
                    "followRedirect": false
                ]
            ]
        ]

        if connection.tunnelMode == .tun {
            inbounds.insert([
                "tag": "tun-in",
                "protocol": "tun",
                "settings": [
                    "name": "utun99",
                    "MTU": connection.tunMTU,
                    "autoRoute": true,
                    "strictRoute": false
                ],
                "sniffing": sniffingConfig
            ], at: 0)
        }

        // Outbounds (Proxy + Mux + Fragment + Direct + Block + DNS Outbound)
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
        outbounds.append([
            "tag": "dns-out",
            "protocol": "dns",
            "settings": [
                "network": "tcp,udp",
                "address": routing.dnsProvider.resolverAddresses.first ?? "1.1.1.1",
                "port": 53
            ]
        ])

        // Routing Rules
        var routingRules: [[String: Any]] = [
            // Route DNS requests to DNS outbound
            [
                "type": "field",
                "inboundTag": ["dns-in"],
                "outboundTag": "dns-out"
            ],
            [
                "type": "field",
                "port": "53",
                "network": "udp",
                "outboundTag": "dns-out"
            ]
        ]

        if routing.bypassLocalNetwork || routing.routingMode == .splitBypassLANAndRegional {
            routingRules.append([
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "direct"
            ])
        }

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
            for cidr in routing.customExcludedCIDRs where !cidr.isEmpty {
                routingRules.append([
                    "type": "field",
                    "ip": [cidr],
                    "outboundTag": "direct"
                ])
            }
        } else if routing.routingMode == .directOnly {
            routingRules.append([
                "type": "field",
                "network": "tcp,udp",
                "outboundTag": "direct"
            ])
        }

        // Observability & Core Traffic Statistics Policy
        let statsPolicy: [String: Any] = [
            "system": [
                "statsInboundUplink": true,
                "statsInboundDownlink": true,
                "statsOutboundUplink": true,
                "statsOutboundDownlink": true
            ],
            "levels": [
                "0": [
                    "statsUserUplink": true,
                    "statsUserDownlink": true
                ]
            ]
        ]

        let rootConfig: [String: Any] = [
            "log": ["loglevel": connection.logLevel.rawValue],
            "stats": [:] as [String: Any],
            "policy": statsPolicy,
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

    // MARK: - Incy Deep Link Decoder (`incy://...`)

    public static func decodeIncyDeepLink(_ uri: String) -> String? {
        var payload = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        guard payload.lowercased().hasPrefix("incy://") else { return nil }
        payload = String(payload.dropFirst(7))

        if payload.lowercased().hasPrefix("import/") {
            payload = String(payload.dropFirst(7))
        } else if payload.lowercased().hasPrefix("sub/") {
            payload = String(payload.dropFirst(4))
        } else if payload.lowercased().hasPrefix("add/") {
            payload = String(payload.dropFirst(4))
        } else if payload.lowercased().hasPrefix("install-config") {
            if let components = URLComponents(string: uri),
               let queryItems = components.queryItems,
               let urlVal = queryItems.first(where: { $0.name.lowercased() == "url" })?.value {
                return urlVal
            }
        }

        payload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        if payload.isEmpty { return nil }

        if payload.lowercased().hasPrefix("https://") || payload.lowercased().hasPrefix("http://") {
            return payload
        }

        if let decoded = decodeBase64Flexible(payload) {
            return decoded
        }

        if let unescaped = payload.removingPercentEncoding, unescaped != payload {
            if let decoded = decodeBase64Flexible(unescaped) {
                return decoded
            }
            return unescaped
        }

        return payload
    }
}
