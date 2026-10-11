import Foundation

public struct ServerAddress: Hashable, Codable, CustomStringConvertible {
    public let host: String
    public let port: UInt16

    public static let defaultPort: UInt16 = 7777

    public init(host: String, port: UInt16 = ServerAddress.defaultPort) {
        self.host = host
        self.port = port
    }

    /// Accepts `host`, `host:port`, `samp://host:port` and `[ipv6]:port`.
    public init?(_ text: String) {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for scheme in ["samp://", "omp://"] where s.lowercased().hasPrefix(scheme) {
            s = String(s.dropFirst(scheme.count))
        }
        while s.hasSuffix("/") { s.removeLast() }
        guard !s.isEmpty, !s.contains(" ") else { return nil }

        var host = s
        var port = ServerAddress.defaultPort
        if s.hasPrefix("["), let close = s.firstIndex(of: "]") {
            host = String(s[s.index(after: s.startIndex)..<close])
            let rest = s[s.index(after: close)...]
            if rest.hasPrefix(":") {
                guard let p = UInt16(rest.dropFirst()), p > 0 else { return nil }
                port = p
            } else if !rest.isEmpty {
                return nil
            }
        } else if let colon = s.lastIndex(of: ":"), s.filter({ $0 == ":" }).count == 1 {
            host = String(s[..<colon])
            guard let p = UInt16(s[s.index(after: colon)...]), p > 0 else { return nil }
            port = p
        }
        guard !host.isEmpty else { return nil }
        self.host = host
        self.port = port
    }

    /// The form samp.exe accepts on its command line.
    public var description: String {
        host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
    }
}
