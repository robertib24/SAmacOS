#if os(macOS)
import AppKit
import RunnerCore
import SwiftUI

struct ServersView: View {
    enum Source: String, CaseIterable, Identifiable {
        case favorites = "Favorites"
        case internet = "Internet (open.mp)"
        var id: String { rawValue }
    }

    @EnvironmentObject private var model: LauncherModel
    @State private var source: Source = .favorites
    @State private var search = ""
    @State private var selection: ServerEntry.ID?
    @State private var newFavorite = ""
    @State private var hideEmpty = false

    private var servers: [ServerEntry] {
        let list = source == .favorites ? model.favorites : model.internetServers
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return list.filter { server in
            if hideEmpty && (server.players ?? 0) == 0 { return false }
            guard !query.isEmpty else { return true }
            return server.name.lowercased().contains(query) || server.id.contains(query)
                || (server.gamemode ?? "").lowercased().contains(query)
                || (server.language ?? "").lowercased().contains(query)
        }
    }

    private var selected: ServerEntry? {
        servers.first { $0.id == selection }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $source) {
                    ForEach(Source.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
                Toggle("Hide empty", isOn: $hideEmpty)
                Spacer()
                if model.loadingServers { ProgressView().controlSize(.small) }
                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(12)

            if source == .internet, let error = model.serverListError {
                Text(error).foregroundStyle(.red).padding(.horizontal, 12).padding(.bottom, 8)
            }

            Table(servers, selection: $selection) {
                TableColumn("") { server in
                    Image(systemName: model.isFavorite(server) ? "star.fill" : "star")
                        .foregroundStyle(model.isFavorite(server) ? Color.yellow : Color.secondary)
                        .onTapGesture { model.toggleFavorite(server) }
                }
                .width(22)
                TableColumn("Server") { server in
                    HStack(spacing: 4) {
                        if server.passworded == true { Image(systemName: "lock.fill").foregroundStyle(.secondary) }
                        Text(server.name).lineLimit(1)
                    }
                }
                TableColumn("Players") { server in
                    Text(server.players.map { "\($0)/\(server.maxPlayers ?? 0)" } ?? "–").monospacedDigit()
                }
                .width(min: 60, ideal: 80)
                TableColumn("Ping") { server in
                    Text(server.pingMS.map { "\($0) ms" } ?? "–").monospacedDigit()
                }
                .width(min: 50, ideal: 60)
                TableColumn("Mode") { server in Text(server.gamemode ?? "").lineLimit(1) }
                TableColumn("Language") { server in Text(server.language ?? "").lineLimit(1) }
                    .width(min: 60, ideal: 90)
                TableColumn("Address") { server in Text(server.id).monospaced().lineLimit(1) }
                    .width(min: 120, ideal: 150)
            }
            .contextMenu(forSelectionType: ServerEntry.ID.self) { ids in
                if let entry = entry(for: ids) {
                    Button("Connect") { model.play(.connect(entry.address)) }
                    Button(model.isFavorite(entry) ? "Remove from Favorites" : "Add to Favorites") {
                        model.toggleFavorite(entry)
                    }
                    Button("Copy Address") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.id, forType: .string)
                    }
                }
            } primaryAction: { ids in
                if let entry = entry(for: ids) { model.play(.connect(entry.address)) }
            }
            .searchable(text: $search, prompt: "Search name, mode, language")

            HStack {
                if source == .favorites {
                    TextField("Add favorite (host:port)", text: $newFavorite)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)
                        .onSubmit(addFavorite)
                    Button("Add", action: addFavorite).disabled(newFavorite.isEmpty)
                }
                Spacer()
                if let server = selected {
                    Text(server.id).foregroundStyle(.secondary)
                    Button("Connect") { model.play(.connect(server.address)) }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isRunning || !model.setup.readyToPlay)
                }
            }
            .padding(12)
        }
        .task(id: source) { await reload() }
        .onChange(of: selection) { id in
            // Ping the selected server on demand (the open.mp list has thousands).
            guard let entry = servers.first(where: { $0.id == id }) else { return }
            Task { await model.refresh([entry]) }
        }
    }

    private func entry(for ids: Set<ServerEntry.ID>) -> ServerEntry? {
        guard let id = ids.first else { return nil }
        return servers.first { $0.id == id }
    }

    private func reload() async {
        switch source {
        case .favorites:
            await model.refresh(model.favorites)
        case .internet:
            if !model.loadingServers { await model.loadInternetServers() }
        }
    }

    private func addFavorite() {
        let text = newFavorite
        newFavorite = ""
        Task { await model.addFavorite(text) }
    }
}
#endif
