import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Server info returned by the SA-MP query protocol (opcode `i`).
public struct ServerInfo: Equatable {
    public var passworded: Bool
    public var players: Int
    public var maxPlayers: Int
    public var hostname: String
    public var gamemode: String
    public var language: String
}

public enum SAMPQueryError: LocalizedError, Equatable {
    case resolveFailed(String)
    case socket(String)
    case timeout
    case malformed

    public var errorDescription: String? {
        switch self {
        case .resolveFailed(let host): return "Couldn't resolve \(host)."
        case .socket(let message): return "Network error: \(message)"
        case .timeout: return "Server didn't answer."
        case .malformed: return "Server sent an invalid reply."
        }
    }
}

/// The SA-MP / open.mp UDP query protocol:
///
///     request:  "SAMP" ip[4] port[2, LE] opcode [payload]
///     reply:    the same 11-byte header, then opcode-specific data
///     'i' info: password u8, players u16, max u16, hostname/gamemode/language (u32 len + bytes)
///     'p' ping: echoes the 4-byte payload
public enum SAMPQuery {
    public enum Opcode: UInt8 {
        case info = 0x69  // 'i'
        case ping = 0x70  // 'p'
    }

    public static func packet(ip: [UInt8], port: UInt16, opcode: Opcode, payload: [UInt8] = []) -> [UInt8] {
        precondition(ip.count == 4, "IPv4 address expected")
        return Array("SAMP".utf8) + ip + [UInt8(port & 0xFF), UInt8(port >> 8), opcode.rawValue] + payload
    }

    /// Parses an `i` reply, including its 11-byte header.
    public static func parseInfo(_ reply: [UInt8]) throws -> ServerInfo {
        var reader = ByteReader(reply)
        guard try reader.bytes(4) == Array("SAMP".utf8) else { throw SAMPQueryError.malformed }
        _ = try reader.bytes(6)
        guard try reader.u8() == Opcode.info.rawValue else { throw SAMPQueryError.malformed }
        let passworded = try reader.u8() != 0
        let players = Int(try reader.u16())
        let maxPlayers = Int(try reader.u16())
        let hostname = try reader.string(maxLength: 512)
        let gamemode = try reader.string(maxLength: 512)
        let language = try reader.string(maxLength: 512)
        return ServerInfo(passworded: passworded, players: players, maxPlayers: maxPlayers,
                          hostname: hostname, gamemode: gamemode, language: language)
    }

    /// Server strings are legacy 8-bit text; most are ASCII or Windows-1252.
    static func decodeText(_ bytes: [UInt8]) -> String {
        if let utf8 = String(bytes: bytes, encoding: .utf8) { return utf8 }
        var scalars = String.UnicodeScalarView()
        for byte in bytes {
            let value = (0x80...0x9F).contains(byte) ? cp1252High[Int(byte) - 0x80] : UInt32(byte)
            scalars.append(Unicode.Scalar(value) ?? "?")
        }
        return String(scalars)
    }

    /// Windows-1252 0x80-0x9F; the rest of the code page matches Latin-1.
    private static let cp1252High: [UInt32] = [
        0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
        0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
        0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
        0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178
    ]

    /// Queries a server's info and measures the round trip. Blocking; call from a
    /// background task.
    public static func query(_ address: ServerAddress, timeout: TimeInterval = 2.0) throws -> (ServerInfo, pingMS: Int) {
        let target = try resolveIPv4(address.host)
        let fd = socket(AF_INET, udpSocketType, 0)
        guard fd >= 0 else { throw SAMPQueryError.socket(String(cString: strerror(errno))) }
        defer { close(fd) }

        var tv = timeval()
        tv.tv_sec = numericCast(Int(timeout))
        tv.tv_usec = numericCast(Int((timeout - floor(timeout)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        #if canImport(Darwin)
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = address.port.bigEndian
        addr.sin_addr = in_addr(s_addr: UInt32(target[0]) | UInt32(target[1]) << 8
                                        | UInt32(target[2]) << 16 | UInt32(target[3]) << 24)

        let request = packet(ip: target, port: address.port, opcode: .info)
        let started = Date()
        let sent = request.withUnsafeBytes { buf in
            withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, buf.baseAddress, buf.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == request.count else { throw SAMPQueryError.socket(String(cString: strerror(errno))) }

        var buffer = [UInt8](repeating: 0, count: 2048)
        let deadline = started.addingTimeInterval(timeout)
        while Date() < deadline {
            let received = buffer.withUnsafeMutableBytes { recv(fd, $0.baseAddress, $0.count, 0) }
            if received < 0 {
                if errno == EINTR { continue }
                throw SAMPQueryError.timeout
            }
            let reply = Array(buffer[0..<received])
            // Ignore stray datagrams that aren't an answer to this request.
            guard reply.count >= 11, Array(reply[0..<4]) == Array("SAMP".utf8),
                  reply[10] == Opcode.info.rawValue else { continue }
            let ping = Int(Date().timeIntervalSince(started) * 1000)
            return (try parseInfo(reply), ping)
        }
        throw SAMPQueryError.timeout
    }

    /// Async wrapper that keeps the blocking socket work off Swift's cooperative pool.
    public static func queryAsync(_ address: ServerAddress, timeout: TimeInterval = 2.0) async throws -> (ServerInfo, pingMS: Int) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try query(address, timeout: timeout) })
            }
        }
    }

    static func resolveIPv4(_ host: String) throws -> [UInt8] {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        let octets = parts.compactMap { UInt8($0) }
        if parts.count == 4 && octets.count == 4 {
            return octets
        }
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = udpSocketType
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let info = result else {
            throw SAMPQueryError.resolveFailed(host)
        }
        defer { freeaddrinfo(result) }
        guard let sa = info.pointee.ai_addr else { throw SAMPQueryError.resolveFailed(host) }
        let s = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
        return [UInt8(s & 0xFF), UInt8((s >> 8) & 0xFF), UInt8((s >> 16) & 0xFF), UInt8((s >> 24) & 0xFF)]
    }

    #if canImport(Darwin)
    static let udpSocketType = SOCK_DGRAM
    #else
    static let udpSocketType = Int32(SOCK_DGRAM.rawValue)
    #endif
}

struct ByteReader {
    private let bytes: [UInt8]
    private var offset = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func bytes(_ count: Int) throws -> [UInt8] {
        guard count >= 0, offset + count <= bytes.count else { throw SAMPQueryError.malformed }
        defer { offset += count }
        return Array(bytes[offset..<offset + count])
    }

    mutating func u8() throws -> UInt8 { try bytes(1)[0] }

    mutating func u16() throws -> UInt16 {
        let b = try bytes(2)
        return UInt16(b[0]) | UInt16(b[1]) << 8
    }

    mutating func u32() throws -> UInt32 {
        let b = try bytes(4)
        return UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24
    }

    mutating func string(maxLength: Int) throws -> String {
        let length = Int(try u32())
        guard length <= maxLength else { throw SAMPQueryError.malformed }
        return SAMPQuery.decodeText(try bytes(length))
    }
}
