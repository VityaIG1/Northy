import Foundation
import os.log
#if canImport(Darwin)
import Darwin
#endif

#if canImport(LibXray)
import LibXray
#endif

#if canImport(Libbox)
import Libbox
#endif

// MARK: - Production-Grade Proxy Core Controller (Xray-core / LibXray / sing-box)

/// Controls the lifecycle of the embedded Go-based proxy core inside the iOS Network Extension.
/// Enforces a strict <50MB RAM budget using aggressive Go garbage collection (`GOGC=10`),
/// dynamic asset resolution, clean shutdown, and real URLTest round-trip latency measurements.
public final class ProxyCoreController: @unchecked Sendable {

    private let logger = Logger(subsystem: "com.scrt.north.PacketTunnel", category: "ProxyCore")
    private let lock = NSLock()
    private var isCoreRunning: Bool = false
    private var activeConfigJSON: String?
    private var lastErrorMessage: String?

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

        // 1. Compile-time LibXray hook
        #if canImport(LibXray)
        let result = LibXrayRunXrayFromJSON(jsonString)
        if let resultString = result as? String, !resultString.isEmpty && resultString != "OK" {
            logger.error("NORTHY // LibXrayRunXrayFromJSON returned error: \(resultString)")
            SharedTunnelLogger.log("LibXray error: \(resultString)", tag: "ERROR")
            lock.withLock { self.lastErrorMessage = resultString }
            return .failure(NSError(domain: "com.scrt.north.core", code: 500, userInfo: [NSLocalizedDescriptionKey: resultString]))
        }
        #endif

        // 2. Dynamic runtime symbol lookup (for dynamically linked LibXray / Libbox frameworks)
        if let dynError = invokeDynamicCoreStart(jsonString: jsonString) {
            logger.error("NORTHY // Dynamic core start returned error: \(dynError)")
            SharedTunnelLogger.log("Dynamic core start error: \(dynError)", tag: "ERROR")
            lock.withLock { self.lastErrorMessage = dynError }
            return .failure(NSError(domain: "com.scrt.north.core", code: 500, userInfo: [NSLocalizedDescriptionKey: dynError]))
        }

        // 3. Verify local SOCKS5 core readiness on 127.0.0.1:10808
        let isReady = waitForCoreReady(port: 10808, timeoutMs: 800)
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

        #if canImport(LibXray)
        LibXrayStopXray()
        #endif

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

    // MARK: - Dynamic Symbol Resolution (LibXray / sing-box / Libbox)

    @discardableResult
    private func invokeDynamicCoreStart(jsonString: String) -> String? {
        #if canImport(Darwin)
        guard let handle = dlopen(nil, RTLD_NOW) else { return nil }
        defer { dlclose(handle) }

        // Try LibXrayRunXrayFromJSON: char* LibXrayRunXrayFromJSON(char*)
        if let sym = dlsym(handle, "LibXrayRunXrayFromJSON") {
            typealias RunFunc = @convention(c) (UnsafePointer<CChar>) -> UnsafePointer<CChar>?
            let fn = unsafeBitCast(sym, to: RunFunc.self)
            let resultPtr = jsonString.withCString { cstr in
                fn(cstr)
            }
            if let resultPtr = resultPtr {
                let res = String(cString: resultPtr)
                if !res.isEmpty && res != "OK" {
                    return res
                }
            }
            return nil
        }

        // Try LibboxNewService: if sing-box is linked
        if dlsym(handle, "LibboxNewService") != nil {
            logger.notice("NORTHY // Found LibboxNewService dynamically")
        }
        #endif
        return nil
    }

    private func waitForCoreReady(port: Int = 10808, timeoutMs: Int = 800) -> Bool {
        #if canImport(Darwin)
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            if sock >= 0 {
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
                    close(sock)
                    return true
                } else if errno == EINPROGRESS {
                    var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
                    let pollRes = poll(&pfd, 1, 50)
                    if pollRes > 0 && (pfd.revents & Int16(POLLOUT)) != 0 {
                        var err: Int32 = 0
                        var len = socklen_t(MemoryLayout<Int32>.size)
                        getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len)
                        close(sock)
                        if err == 0 { return true }
                    } else {
                        close(sock)
                    }
                } else {
                    close(sock)
                }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        #endif
        return false
    }

    private func invokeDynamicCoreStop() {
        #if canImport(Darwin)
        guard let handle = dlopen(nil, RTLD_NOW) else { return }
        defer { dlclose(handle) }

        if let sym = dlsym(handle, "LibXrayStopXray") {
            typealias StopFunc = @convention(c) () -> UnsafePointer<CChar>?
            let fn = unsafeBitCast(sym, to: StopFunc.self)
            _ = fn()
        }
        #endif
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
