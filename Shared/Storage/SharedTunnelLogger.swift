import Foundation
import os.log

// MARK: - Shared App Group Tunnel Diagnostics & Log Streamer (Ring Buffer)

public final class SharedTunnelLogger: @unchecked Sendable {
    private static let lock = NSLock()
    private static let maxLogLines = 1000
    private static let maxFileSizeBytes = 512 * 1024 // 512 KB
    private static let systemLogger = Logger(subsystem: "com.scrt.north", category: "Diagnostics")

    // In-memory ring buffer to ensure logs are never lost even if container is sandboxed or unmounted
    private static var inMemoryRingBuffer: [String] = []

    public static var logFileURL: URL {
        if let shared = SharedTunnelStore.sharedContainerURL {
            return shared.appendingPathComponent("tunnel_diagnostics.log")
        }
        let fallback = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return fallback.appendingPathComponent("tunnel_diagnostics.log")
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df
    }()

    /// Appends a new diagnostic message with tag and timestamp to the log stream.
    public static func log(_ message: String, tag: String = "INFO") {
        lock.withLock {
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(tag.uppercased())] \(message)"
            let lineWithNewline = "\(line)\n"

            // 1. In-memory ring buffer
            inMemoryRingBuffer.append(line)
            if inMemoryRingBuffer.count > 500 {
                inMemoryRingBuffer.removeFirst(inMemoryRingBuffer.count - 500)
            }

            // 2. OS logger & console output
            systemLogger.notice("[\(tag.uppercased())] \(message)")

            // 3. File persistence (shared container or local cache fallback)
            let url = logFileURL
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                if let data = lineWithNewline.data(using: .utf8) {
                    handle.write(data)
                }
            } else {
                try? lineWithNewline.write(to: url, atomically: true, encoding: .utf8)
            }

            trimLogFileIfNeeded(url: url)
        }
    }

    /// Reads all lines from the shared log file or in-memory ring buffer.
    public static func readLogs() -> [String] {
        lock.withLock {
            var fileLines: [String] = []
            let url = logFileURL
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                fileLines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            }

            // Merge file lines and memory buffer, eliminating duplicates while preserving order
            var combined = fileLines
            if combined.isEmpty {
                combined = inMemoryRingBuffer
            }

            if combined.isEmpty {
                let initLine = "[\(dateFormatter.string(from: Date()))] [SYS] Northy v0.4.0 Diagnostics initialized. Ready."
                return [initLine]
            }

            return combined
        }
    }

    /// Reads full log text as a single string (useful for Copy to Clipboard or Sharing).
    public static func readFullLogString() -> String {
        let lines = readLogs()
        return lines.joined(separator: "\n")
    }

    /// Clears both file and in-memory log buffer.
    public static func clearLogs() {
        lock.withLock {
            inMemoryRingBuffer.removeAll()
            let url = logFileURL
            try? "".write(to: url, atomically: true, encoding: .utf8)
            let timestamp = dateFormatter.string(from: Date())
            let fresh = "[\(timestamp)] [SYS] Logs cleared by user."
            inMemoryRingBuffer.append(fresh)
            try? "\(fresh)\n".write(to: url, atomically: true, encoding: .utf8)
        }
    }

    public static func exportLogURL() -> URL {
        logFileURL
    }

    private static func trimLogFileIfNeeded(url: URL) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64,
              size > maxFileSizeBytes else {
            return
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        if lines.count > maxLogLines {
            let trimmed = lines.suffix(maxLogLines / 2).joined(separator: "\n")
            try? trimmed.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
