import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A server shown in the browser, from the open.mp list, favorites, or a live query.
public struct ServerEntry: Codable, Hashable, Identifiable, Sendable {
    public var address: ServerAddress
    public var name: String
    public var players: Int?
    public var maxPlayers: Int?
    public var gamemode: String?
    public var language: String?
    public var passworded: Bool?
    public var version: String?
    public var isOpenMP: Bool?
    public var pingMS: Int?

    public var id: String { address.description }

    public init(address: ServerAddress, name: String? = nil) {
        self.address = address
        self.name = name ?? address.description
    }

    /// Fills in fields from a live query.
    public mutating func apply(_ info: ServerInfo, pingMS: Int) {
        name = info.hostname.isEmpty ? name : info.hostname
        players = info.players
        maxPlayers = info.maxPlayers
        gamemode = info.gamemode
        language = info.language
        passworded = info.passworded
        self.pingMS = pingMS
    }
}

/// The public server list the open.mp launcher uses (`GET /servers/full`).
public enum OpenMPServerList {
    public static let url = URL(string: "https://api.open.mp/servers/full")!

    struct Item: Decodable {
        struct Core: Decodable {
            let ip: String
            let hn: String?
            let pc: Int?
            let pm: Int?
            let gm: String?
            let la: String?
            let pa: Bool?
            let vn: String?
            let omp: Bool?
        }
        let core: Core
    }

    public static func decode(_ data: Data) throws -> [ServerEntry] {
        let items = try JSONDecoder().decode([Item].self, from: data)
        return items.compactMap { item in
            guard let address = ServerAddress(item.core.ip) else { return nil }
            var entry = ServerEntry(address: address, name: item.core.hn)
            entry.players = item.core.pc
            entry.maxPlayers = item.core.pm
            entry.gamemode = item.core.gm
            entry.language = item.core.la
            entry.passworded = item.core.pa
            entry.version = item.core.vn
            entry.isOpenMP = item.core.omp
            return entry
        }
    }

    public static func fetch(session: URLSession = .shared) async throws -> [ServerEntry] {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try decode(data)
    }
}

/// Favorite servers, stored as JSON next to the settings.
public final class FavoritesStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public convenience init(paths: AppPaths) {
        self.init(url: paths.favoritesFile)
    }

    public func load() -> [ServerEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ServerEntry].self, from: data) else { return [] }
        return entries
    }

    public func save(_ entries: [ServerEntry]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(entries).write(to: url, options: .atomic)
    }

    @discardableResult
    public func add(_ entry: ServerEntry) throws -> [ServerEntry] {
        var entries = load()
        if let index = entries.firstIndex(where: { $0.address == entry.address }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        try save(entries)
        return entries
    }

    @discardableResult
    public func remove(_ address: ServerAddress) throws -> [ServerEntry] {
        let entries = load().filter { $0.address != address }
        try save(entries)
        return entries
    }
}
