import SwiftUI

enum ATXModule: String, CaseIterable {
    case messages, announcements, remote, search, connectionLog, vpn, plus, maxplayer
    var title: String {
        switch self {
        case .messages: return "Messaggi interni"
        case .announcements: return "Comunicati"
        case .remote: return "ATX Remote"
        case .search: return "Ricerca globale"
        case .connectionLog: return "Registro connessioni"
        case .vpn: return "Strumenti VPN"
        case .plus: return "AtlantiX Plus"
        case .maxplayer: return "MaxPlayer"
        }
    }
    var path: String {
        switch self {
        case .messages: return "api/messages/contacts.php"
        case .announcements: return "api/announcements/list.php"
        case .remote: return "api/atx_remote/manage.php"
        case .search: return "api/search.php"
        case .connectionLog: return "api/connections/log.php"
        case .vpn: return "api/vpn/check_proxy.php"
        case .plus: return "api/admin/atlantix_plus.php"
        case .maxplayer: return "api/settings/maxplayer.php"
        }
    }
    var listKey: String {
        switch self {
        case .messages: return "contacts"
        case .announcements: return "rows"
        default: return "rows"
        }
    }
    var needsParameters: Bool { self == .remote || self == .vpn || self == .plus || self == .maxplayer }
}

struct ATXDetailView: View {
    let title: String
    let value: JSONValue
    var body: some View {
        List {
            if case .object(let dictionary) = value {
                ForEach(dictionary.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(key.replacingOccurrences(of: "_", with: " ").capitalized).font(.caption).foregroundStyle(.secondary)
                        if let item = dictionary[key] {
                            switch item {
                            case .object, .array: Text("Dati strutturati").foregroundStyle(.secondary)
                            default: Text(item.text).textSelection(.enabled)
                            }
                        }
                    }.padding(.vertical, 4)
                }
            } else { Text("Nessun dettaglio disponibile") }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct ATXModuleView: View {
    @EnvironmentObject private var api: ATXAPI
    let module: ATXModule
    @State private var records: [JSONValue] = []
    @State private var status = ""
    @State private var loading = false
    @State private var query = ""
    @State private var page = 1
    @State private var hasMore = false
    var body: some View {
        List {
            if module.needsParameters {
                Section {
                    Label("Questa funzione richiede parametri e permessi specifici del pannello NXT. Non viene inviata alcuna operazione automatica.", systemImage: "lock.shield")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                if loading { ProgressView("Caricamento…") }
                if !status.isEmpty { Text(status).font(.footnote).foregroundStyle(.secondary) }
                ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                    NavigationLink {
                        ATXDetailView(title: primary(record), value: record)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(primary(record)).font(.headline)
                            Text(secondary(record)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }.padding(.vertical, 5)
                    }
                }
                if hasMore {
                    Button("Carica altri") { Task { await load(reset: false) } }
                }
            }
        }
        .navigationTitle(module.title)
        .toolbar { if !module.needsParameters { Button { Task { await load(reset: true) } } label: { Image(systemName: "arrow.clockwise") } } }
        .searchable(text: $query, prompt: "Cerca")
        .onSubmit(of: .search) { Task { await load(reset: true) } }
        .refreshable { await load(reset: true) }
        .task { if !module.needsParameters { await load(reset: true) } }
    }
    private func primary(_ value: JSONValue) -> String {
        for key in ["username", "title", "name", "subject", "channel", "id"] {
            if let v = value[key], v.text != "—" { return v.text }
        }
        return "Elemento"
    }
    private func secondary(_ value: JSONValue) -> String {
        for key in ["message", "last_message", "created_at", "status", "description"] {
            if let v = value[key], v.text != "—" { return v.text }
        }
        return "Apri dettagli"
    }
    private func load(reset: Bool) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        if reset { page = 1; records = [] }
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let separator = module.path.contains("?") ? "&" : "?"
            let data = try await api.request("\(module.path)\(separator)page=\(page)&per_page=50&q=\(encoded)")
            let newRows = data[module.listKey]?.array ?? data["items"]?.array ?? data.array
            records.append(contentsOf: newRows)
            hasMore = newRows.count >= 50
            page += 1
            status = records.isEmpty ? "Nessun elemento disponibile per questo account." : "\(records.count) elementi caricati"
        } catch {
            status = error.localizedDescription
            hasMore = false
        }
    }
}
