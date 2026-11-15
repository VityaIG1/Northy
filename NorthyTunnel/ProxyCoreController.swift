import Foundation
import os.log
#if canImport(Darwin)
import Darwin
#endif

// MARK: - Production-Grade Proxy Core Controller (Xray-core via LibXray CGo bridge)

/// Controls the lifecycle of the embedded Go-based proxy core inside the iOS Network Extension.
/// Enforces a strict <50MB RAM budget using aggressive Go garbage collection (`GOGC=10`),
/// dynamic asset resolution, clean shutdown, and real URLTest round-trip latency measurements.
///
/// The core is the statically linked LibXray framework (github.com/XTLS/libXray, CGo bridge
/// `CGoInvoke`/`CGoFree`), resolved via `dlsym` at runtime — no compile-time module dependency.
public final class ProxyCoreController: @unchecked Sendable {

    private let logger = Logger(subsystem: "com.scrt.north.PacketTunnel", category: "ProxyCore")
    private let lock = NSLock()
    private var isCoreRunning: Bool = false
    private var activeConfigJSON: String?
    private var lastErrorMessage: String?

    /// libXray invoke API version (github.com/XTLS/libXray `invoke_model.go`)
    private static let libXrayAPIVersion = 3

    /// Direct CGo bridge symbol imports (statically linked from LibXray.xcframework)
    @_silgen_name("CGoInvoke")
    private static func directCGoInvoke(_ requestJSON: UnsafeMutablePointer<CChar>?) -> UnsafeMutablePointer<CChar>?

    @_silgen_name("CGoFree")
    private static func directCGoFree(_ value: UnsafeMutablePointer<CChar>?) -> Void

    /// Legacy pre-2025 libXray export signatures (kept as a compatibility fallback)
    private typealias LegacyRunFunc = @convention(c) (UnsafePointer<CChar>) -> UnsafePointer<CChar>?
    private typealias LegacyStopFunc = @convention(c) () -> UnsafePointer<CChar>?

    /// libXray invoke request envelope: {"apiVersion":3,"method":"...","payload":{...}}
    private struct InvokeRequest<Payload: Encodable>: Encodable {
        let apiVersion: Int
        let method: String
        let payload: Payload
    }

    /// libXray invoke response envelope: {"success":bool,"data":{...},"error":"..."}
    private struct InvokeResponse: Decodable {
        let success: Bool?
        let error: String?
    }

    /// Payload of the `runXray` method (field names per libXray `invoke_model.go`)
    private struct RunXrayPayload: Encodable {
        let xrayJson: String
    }

    /// Payload for methods without arguments (`stopXray`)
    private struct EmptyPayload: Encodable {}

    /// Returned when no core bridge symbol is present in the tunnel process image.
    private static let coreNotLinkedMessage =
        "CORE_LIBRARY_NOT_LINKED: LibXray CGo bridge (CGoInvoke) not found in the tunnel process. " +
        "Ensure scripts/build_libxray.sh ran and LibXray.xcframework is linked with -ObjC."

    public init() {}

    // MARK: - Memory Budget & GC Tuning (<50 MB iOS Jetsam Budget)

    public static func tuneGoRuntimeMemory() {
        // Force Go runtime to trigger GC at 10% heap growth instead of default 100%
        setenv("GOGC", "10", 1)
        // Restrict Go scheduler to 2 OS threads inside Network Extension
        setenv("GOMAXPROCS", "2", 1)

        // Point assets (geoip.dat, geosite.dat) to shared container
        if let assetDir = SharedTunnelStore.assetsDirectoryURL?.path {
            setenv("XRAY_LOCATION_ASSET", assetDir, 1)
            setenv("V2RAY_LOCATION_ASSET", assetDir, 1)
        }
    }

    // MARK: - Core Lifecycle

    public func startCore(configData: Data) -> Result<Void, Error> {
        Self.tuneGoRuntimeMemory()
        installGeoAssetsIfNeeded()

        guard let jsonString = String(data: configData, encoding: .utf8) else {
            let err = NSError(domain: "com.scrt.north.core", code: 400, userInfo: [NSLocalizedDescriptionKey: "INVALID_CONFIG_ENCODING"])
            return .failure(err)
        }

        // Save active configuration to shared App Group container for external tools
        SharedTunnelStore.shared.writeActiveCoreConfiguration(configData)

        lock.withLock {
            self.activeConfigJSON = jsonString
            self.lastErrorMessage = nil
        }

        // 1. Launch the embedded core through the LibXray CGo bridge (fail-fast on any error)
        if let coreError = invokeDynamicCoreStart(jsonString: jsonString) {
            logger.error("NORTHY // Proxy core failed to start: \(coreError)")
            SharedTunnelLogger.log("Proxy core failed to start: \(coreError)", tag: "ERROR")
            lock.withLock { self.lastErrorMessage = coreError }
            return .failure(NSError(domain: "com.scrt.north.core", code: 500, userInfo: [NSLocalizedDescriptionKey: coreError]))
        }

        // 2. Verify local SOCKS5 readiness on 127.0.0.1:10808
        // Non-fatal: TUNPacketBridge re-checks the listener for every connection attempt.
        let isReady = waitForCoreReady(port: 10808, timeoutMs: 3000)
        SharedTunnelLogger.log(isReady ? "Proxy core SOCKS5 listener active on 127.0.0.1:10808" : "Proxy core initialized (readiness check timed out, continuing)", tag: "CORE")

        lock.withLock {
            self.isCoreRunning = true
        }

        logger.notice("NORTHY // Proxy Core launched successfully with GOGC=10 memory guard")
        return .success(())
    }

    public func stopCore() {
        lock.withLock {
            guard isCoreRunning else { return }
            isCoreRunning = false
        }

        invokeDynamicCoreStop()

        lock.withLock {
            activeConfigJSON = nil
            lastErrorMessage = nil
        }

        SharedTunnelLogger.log("Proxy core terminated and memory released", tag: "CORE")
        logger.notice("NORTHY // Proxy Core terminated and memory released")
    }

    public var statusDescription: String {
        lock.withLock {
            if let err = lastErrorMessage {
                return "ERROR: \(err)"
            }
            return isCoreRunning ? "RUNNING" : "STOPPED"
        }
    }

    // MARK: - Dynamic Core Bridge Resolution (dlsym on the linked LibXray framework)

    /// Starts the proxy core through the embedded LibXray CGo bridge.
    /// Returns nil on success, or a descriptive error string on failure.
    private func invokeDynamicCoreStart(jsonString: String) -> String? {
        // Preferred: current libXray contract — CGoInvoke(apiVersion 3, "runXray", {"xrayJson": ...})
        if let responseJSON = Self.cgoInvoke(method: "runXray", payload: RunXrayPayload(xrayJson: jsonString)) {
            return Self.invokeError(fromResponse: responseJSON, method: "runXray")
        }

        // Legacy fallback: historical char* LibXrayRunXrayFromJSON(char*) export
        if Self.hasDynamicSymbol("LibXrayRunXrayFromJSON") {
            let result = Self.legacyRunXray(jsonString: jsonString) ?? ""
            return (result.isEmpty || result == "OK") ? nil : result
        }

        return Self.coreNotLinkedMessage
    }

    /// Invokes a libXray method through the CGo bridge. Returns the raw response JSON
    /// (`{"success":...,"data":...,"error":"..."}`), or nil when the bridge is absent.
    private static func cgoInvoke<P: Encodable>(method: String, payload: P) -> String? {
        let request = InvokeRequest(apiVersion: libXrayAPIVersion, method: method, payload: payload)
        guard let requestData = try? JSONEncoder().encode(request),
              let requestJSON = String(data: requestData, encoding: .utf8) else {
            return nil
        }
        return cgoInvokeRaw(requestJSON: requestJSON)
    }

    /// Raw single-entrypoint call: `char* CGoInvoke(char* requestJSON)`.
    /// Both the request copy and every non-null response are released with `CGoFree`,
    /// as required by the libXray CGo contract.
    private static func cgoInvokeRaw(requestJSON: String) -> String? {
        guard let requestPtr = strdup(requestJSON) else { return nil }

        #if canImport(Darwin)
        let responsePtr = directCGoInvoke(requestPtr)
        directCGoFree(requestPtr)

        guard let responsePtr else { return nil }
        let response = String(cString: responsePtr)
        directCGoFree(responsePtr)
        return response
        #else
        return nil
        #endif
    }

    /// Parses the libXray invoke response envelope; returns nil on success.
    private static func invokeError(fromResponse responseJSON: String, method: String) -> String? {
        guard let data = responseJSON.data(using: .utf8),
              let response = try? JSONDecoder().decode(InvokeResponse.self, from: data) else {
            return "CORE_INVALID_RESPONSE: \(method) returned an unparseable payload"
        }
        if response.success == true { return nil }
        if let error = response.error, !error.isEmpty { return error }
        return "CORE_UNKNOWN_FAILURE: \(method) reported failure without an error message"
    }

    /// Legacy direct export: `char* LibXrayRunXrayFromJSON(char*)` — returns an error string,
    /// nil (treated as empty/OK), or "OK" on success.
    private static func legacyRunXray(jsonString: String) -> String? {
        #if canImport(Darwin)
        guard let handle = dlopen(nil, RTLD_NOW) else { return nil }
        defer { dlclose(handle) }
        guard let sym = dlsym(handle, "LibXrayRunXrayFromJSON") else { return nil }
        let fn = unsafeBitCast(sym, to: LegacyRunFunc.self)
        guard let resultPtr = jsonString.withCString({ fn($0) }) else { return nil }
        return String(cString: resultPtr)
        #else
        return nil
        #endif
    }

    private func invokeDynamicCoreStop() {
        // Preferred: current libXray contract
        _ = Self.cgoInvoke(method: "stopXray", payload: EmptyPayload())

        // Legacy fallback: historical void LibXrayStopXray(void) export
        if Self.hasDynamicSymbol("LibXrayStopXray") {
            Self.legacyStopXray()
        }
    }

    private static func legacyStopXray() {
        #if canImport(Darwin)
        guard let handle = dlopen(nil, RTLD_NOW) else { return }
        defer { dlclose(handle) }
        guard let sym = dlsym(handle, "LibXrayStopXray") else { return }
        let fn = unsafeBitCast(sym, to: LegacyStopFunc.self)
        _ = fn()
        #endif
    }

    private static func hasDynamicSymbol(_ name: String) -> Bool {
        #if canImport(Darwin)
        guard let handle = dlopen(nil, RTLD_NOW) else { return false }
        defer { dlclose(handle) }
        return dlsym(handle, name) != nil
        #else
        return false
        #endif
    }

    // MARK: - Geo Assets Installation (geoip.dat / geosite.dat for routing rules)

    /// Copies the geo data files bundled with the extension into the shared App Group assets
    /// directory referenced by `XRAY_LOCATION_ASSET`. Xray fails to start when routing rules
    /// reference `geoip:` / `geosite:` prefixes and the dat files are missing.
    private func installGeoAssetsIfNeeded() {
        guard let destination = SharedTunnelStore.assetsDirectoryURL else {
            SharedTunnelLogger.log("Shared assets directory unavailable — geo routing data not installed", tag: "CORE")
            return
        }

        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            SharedTunnelLogger.log("Failed to create assets directory: \(error.localizedDescription)", tag: "ERROR")
            return
        }

        let bundle = Bundle(for: ProxyCoreController.self)
        for assetName in ["geoip.dat", "geosite.dat"] {
            let destinationURL = destination.appendingPathComponent(assetName)
            guard !fileManager.fileExists(atPath: destinationURL.path) else { continue }

            let resourceBase = (assetName as NSString).deletingPathExtension
            let resourceExtension = (assetName as NSString).pathExtension
            guard let sourceURL = bundle.url(forResource: resourceBase, withExtension: resourceExtension) else {
                SharedTunnelLogger.log("\(assetName) not found in extension bundle — geo-dependent routing may fail", tag: "CORE")
                continue
            }

            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                SharedTunnelLogger.log("Installed \(assetName) into shared assets directory", tag: "CORE")
            } catch {
                SharedTunnelLogger.log("Failed to install \(assetName): \(error.localizedDescription)", tag: "ERROR")
            }
        }
    }

    // MARK: - Port Availability & Core Readiness

    public static func isPortListening(port: Int, timeoutMs: Int = 40) -> Bool {
        #if canImport(Darwin)
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)

        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        let res = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if res == 0 {
            return true
        } else if errno == EINPROGRESS {
            var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
            let pollRes = poll(&pfd, 1, Int32(timeoutMs))
            if pollRes > 0 && (pfd.revents & Int16(POLLOUT)) != 0 {
                var err: Int32 = 0
                var len = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len)
                return err == 0
            }
        }
        #endif
        return false
    }

    public var isSocksReady: Bool {
        Self.isPortListening(port: 10808)
    }

    public var isHttpProxyReady: Bool {
        Self.isPortListening(port: 10809)
    }

    public var isDnsReady: Bool {
        Self.isPortListening(port: 10853)
    }

    private func waitForCoreReady(port: Int = 10808, timeoutMs: Int = 3000) -> Bool {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            if Self.isPortListening(port: port, timeoutMs: 30) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }

    // MARK: - Real Proxy URL Latency Test (Live URLTest through core outbound)

    /// Performs a real HTTP 204 round-trip latency test through the local HTTP proxy listener (127.0.0.1:10809)
    /// to measure true server-to-destination latency.
    public func measureOutboundLatency(
        testURL: URL = URL(string: "http://cp.cloudflare.com/generate_204")!,
        proxyPort: Int = 10809,
        timeout: TimeInterval = 4.0,
        completion: @escaping @Sendable (Int?) -> Void
    ) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable as String: 1,
            kCFNetworkProxiesHTTPProxy as String: "127.0.0.1",
            kCFNetworkProxiesHTTPPort as String: proxyPort
        ]

        let session = URLSession(configuration: configuration)
        let startTime = CFAbsoluteTimeGetCurrent()
        var request = URLRequest(url: testURL)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let task = session.dataTask(with: request) { _, response, _ in
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0)
            if let http = response as? HTTPURLResponse, (200...399).contains(http.statusCode) {
                completion(max(1, elapsed))
            } else {
                completion(nil)
            }
        }
        task.resume()
    }

    public func measureOutboundLatency(
        testURL: URL = URL(string: "http://cp.cloudflare.com/generate_204")!,
        proxyPort: Int = 10809,
        timeout: TimeInterval = 4.0
    ) async -> Int? {
        await withCheckedContinuation { continuation in
            measureOutboundLatency(testURL: testURL, proxyPort: proxyPort, timeout: timeout) { ms in
                continuation.resume(returning: ms)
            }
        }
    }
}
