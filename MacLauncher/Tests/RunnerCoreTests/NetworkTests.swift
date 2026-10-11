import XCTest
@testable import RunnerCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class SAMPQueryTests: XCTestCase {
    func testRequestPacketLayout() {
        let packet = SAMPQuery.packet(ip: [127, 0, 0, 1], port: 7777, opcode: .info)
        XCTAssertEqual(packet, [0x53, 0x41, 0x4D, 0x50, 127, 0, 0, 1, 0x61, 0x1E, 0x69])
    }

    func testParseInfoReply() throws {
        let reply = Self.infoReply(hostname: "Los Santos RP", gamemode: "Roleplay", language: "Romana",
                                   players: 123, maxPlayers: 500, password: true)
        let info = try SAMPQuery.parseInfo(reply)
        XCTAssertEqual(info, ServerInfo(passworded: true, players: 123, maxPlayers: 500,
                                        hostname: "Los Santos RP", gamemode: "Roleplay", language: "Romana"))
    }

    func testLegacyEncodingFallsBackToWindows1252() throws {
        var reply = Self.infoReply(hostname: "", gamemode: "", language: "")
        // Rebuild with a raw 1252 byte (0xE9 = é) in the hostname.
        reply = Array(reply[0..<16]) + [1, 0, 0, 0, 0xE9] + Array(reply[20...])
        XCTAssertEqual(try SAMPQuery.parseInfo(reply).hostname, "é")
        XCTAssertEqual(SAMPQuery.decodeText([0x80, 0x41, 0x9F]), "€AŸ")
    }

    func testTruncatedRepliesAreRejected() {
        let reply = Self.infoReply(hostname: "Server", gamemode: "dm", language: "en")
        for cut in [0, 5, 11, 15, reply.count - 1] {
            XCTAssertThrowsError(try SAMPQuery.parseInfo(Array(reply.prefix(cut))), "cut at \(cut)")
        }
        var wrongOpcode = reply
        wrongOpcode[10] = 0x72
        XCTAssertThrowsError(try SAMPQuery.parseInfo(wrongOpcode))
    }

    /// Real UDP round trip against a tiny fake server on localhost.
    func testQueryAgainstLocalServer() throws {
        let fd = socket(AF_INET, SAMPQuery.udpSocketType, 0)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }
        var addr = sockaddr_in()
        #if canImport(Darwin)
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr = in_addr(s_addr: UInt32(0x0100007F))  // 127.0.0.1
        addr.sin_port = 0
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr -> Int32 in
                guard bind(fd, ptr, len) == 0 else { return -1 }
                return getsockname(fd, ptr, &len)
            }
        }
        XCTAssertEqual(bound, 0)
        let port = UInt16(bigEndian: addr.sin_port)

        let reply = Self.infoReply(hostname: "Grove Street", gamemode: "Freeroam", language: "English",
                                   players: 7, maxPlayers: 50)
        let served = expectation(description: "served")
        DispatchQueue.global().async {
            var buffer = [UInt8](repeating: 0, count: 512)
            var peer = sockaddr_storage()
            var peerLen = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let n = withUnsafeMutablePointer(to: &peer) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(fd, &buffer, buffer.count, 0, $0, &peerLen) }
            }
            if n == 11 && buffer[10] == 0x69 {
                _ = withUnsafePointer(to: &peer) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(fd, reply, reply.count, 0, $0, peerLen) }
                }
            }
            served.fulfill()
        }

        let (info, ping) = try SAMPQuery.query(ServerAddress(host: "127.0.0.1", port: port), timeout: 2)
        wait(for: [served], timeout: 2)
        XCTAssertEqual(info.hostname, "Grove Street")
        XCTAssertEqual(info.players, 7)
        XCTAssertEqual(info.maxPlayers, 50)
        XCTAssertGreaterThanOrEqual(ping, 0)
    }

    static func infoReply(hostname: String, gamemode: String, language: String,
                          players: UInt16 = 0, maxPlayers: UInt16 = 100, password: Bool = false) -> [UInt8] {
        func str(_ s: String) -> [UInt8] {
            let b = Array(s.utf8)
            let n = UInt32(b.count)
            return [UInt8(n & 0xFF), UInt8(n >> 8 & 0xFF), UInt8(n >> 16 & 0xFF), UInt8(n >> 24)] + b
        }
        return Array("SAMP".utf8) + [127, 0, 0, 1, 0x61, 0x1E, 0x69, password ? 1 : 0,
                                     UInt8(players & 0xFF), UInt8(players >> 8),
                                     UInt8(maxPlayers & 0xFF), UInt8(maxPlayers >> 8)]
            + str(hostname) + str(gamemode) + str(language)
    }
}

final class ServerListTests: XCTestCase {
    func testDecodesOpenMPList() throws {
        let json = """
        [
          {"core":{"gm":"Roleplay","hn":"Example RP","ip":"51.10.20.30:7777","la":"English","pa":false,
                   "pc":250,"pm":1000,"vn":"omp 1.4.0","omp":true,"pr":true},
           "ru":{"weather":"10"}},
          {"core":{"ip":"play.example.org:7778","hn":"Minimal"}},
          {"core":{"ip":"not a valid address","hn":"Broken"}}
        ]
        """
        let servers = try OpenMPServerList.decode(Data(json.utf8))
        XCTAssertEqual(servers.count, 2)
        XCTAssertEqual(servers[0].address, ServerAddress(host: "51.10.20.30", port: 7777))
        XCTAssertEqual(servers[0].name, "Example RP")
        XCTAssertEqual(servers[0].players, 250)
        XCTAssertEqual(servers[0].maxPlayers, 1000)
        XCTAssertEqual(servers[0].isOpenMP, true)
        XCTAssertEqual(servers[1].address.port, 7778)
        XCTAssertNil(servers[1].players)
    }

    func testFavorites() throws {
        let store = FavoritesStore(url: try temporaryDirectory().appendingPathComponent("favorites.json"))
        XCTAssertEqual(store.load(), [])
        let a = ServerEntry(address: ServerAddress(host: "1.1.1.1"), name: "A")
        let b = ServerEntry(address: ServerAddress(host: "2.2.2.2", port: 7778), name: "B")
        try store.add(a)
        try store.add(b)
        var renamed = a
        renamed.name = "A2"
        try store.add(renamed)
        XCTAssertEqual(store.load().map(\.name), ["A2", "B"])
        try store.remove(a.address)
        XCTAssertEqual(store.load().map(\.id), ["2.2.2.2:7778"])
    }

    func testApplyingQueryResult() {
        var entry = ServerEntry(address: ServerAddress(host: "1.1.1.1"))
        entry.apply(ServerInfo(passworded: false, players: 3, maxPlayers: 10, hostname: "Host",
                               gamemode: "dm", language: "en"), pingMS: 42)
        XCTAssertEqual(entry.name, "Host")
        XCTAssertEqual(entry.pingMS, 42)
        XCTAssertEqual(entry.players, 3)
    }
}
