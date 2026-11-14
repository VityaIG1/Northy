import Foundation
import os.log

// MARK: - Shared App Group Tunnel Diagnostics & Log Streamer (Ring Buffer)

public final class SharedTunnelLogger: @unchecked Sendable {
    private static let lock = NSLock()
    private static let maxLogLines = 1000
    private static let maxFileSizeBytes = 256 * 1024 // 256 KB

    private static var logFileURL: URL? {
        SharedTunnelStore.sharedContainerURL?.appendingPathComponent("tunnel_diagnostics.log")
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        return df
    }()

    /// Appends a new diagnostic message with tag and timestamp to the shared log file.
    public static func log(_ message: String, tag: String = "INFO") {
        lock.withLock {
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] [\(tag.uppercased())] \(message)\n"

            guard let url = logFileURL else { return }

            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) {
                    handle.write(data)
                }
            } else {
                try? line.write(to: url, atomically: true, encoding: .utf8)
            }

            trimLogFileIfNeeded(url: url)
        }
    }

    /// Reads all lines from the shared log file.
    public static func readLogs() -> [String] {
        lock.withLock {
            guard let url = logFileURL,
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                return ["[DIAGNOSTICS] Shared container log initialized. No entries yet."]
            }
            let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            return lines.isEmpty ? ["[DIAGNOSTICS] Log stream empty."] : lines
        }
    }

    /// Reads full log text as a single string (useful for Copy to Clipboard or Sharing).
    public static func readFullLogString() -> String {
        lock.withLock {
            guard let url = logFileURL,
                  let content = try? String(contentsOf: url, encoding: .utf8) else {
                return "// NORTHY VPN DIAGNOSTICS LOG //\nNo entries found."
            }
            return content
        }
    }

    /// Clears the log file.
    public static func clearLogs() {
        lock.withLock {
            guard let url = logFileURL else { return }
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
    }

    public static func exportLogURL() -> URL? {
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
