import SwiftUI

private let atxBackgroundColor = Color(red: 0.045, green: 0.065, blue: 0.11)
private let panel = Color(red: 0.09, green: 0.12, blue: 0.19)

struct RootView: View {
    @EnvironmentObject var api: ATXAPI
    var body: some View {
        Group { if api.loggedIn { MainTabs() } else { LoginView() } }
            .preferredColorScheme(.dark)
            .task { await api.restore() }
            .alert("AtlantiX", isPresented: Binding(get: { api.error != nil }, set: { if !$0 { api.error = nil } })) {
                Button("OK") { api.error = nil }
            } message: { Text(api.error ?? "") }
    }
}

struct LoginView: View {
    @EnvironmentObject var api: ATXAPI
    @State private var username = ""
    @State private var password = ""
    @State private var code = ""
    var body: some View {
        ZStack {
            atxBackgroundColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 65)
                    Image(systemName: "square.stack.3d.up.fill").font(.system(size: 55)).foregroundStyle(.cyan)
                    Text("ATX PANEL").font(.system(size: 34, weight: .black, design: .rounded)).tracking(2)
                    Text("Gestisci AtlantiX ovunque tu sia").foregroundStyle(.secondary)
                    VStack(spacing: 14) {
                        TextField("Username", text: $username).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Password", text: $password).textContentType(.password)
                        SecureField("Codice di accesso", text: $code)
                    }.textFieldStyle(ATXField()).padding(20).background(panel, in: RoundedRectangle(cornerRadius: 24))
                    Button { Task { await api.login(username: username, password: password, code: code) } } label: {
                        HStack { if api.busy { ProgressView() }; Text("Accedi al pannello"); Image(systemName: "arrow.right") }
                            .fontWeight(.bold).frame(maxWidth: .infinity).padding(17)
                    }.buttonStyle(.borderedProminent).disabled(api.busy || username.isEmpty || password.isEmpty || code.isEmpty)
                    Text("Accesso protetto · cms.axdash.biz").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 60)
                }.padding(24)
            }
        }
    }
}
struct ATXField: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.padding(15).background(atxBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Home", systemImage: "square.grid.2x2.fill") }
            LinesView().tabItem { Label("Linee", systemImage: "person.2.fill") }
            ConnectionsView().tabItem { Label("Online", systemImage: "dot.radiowaves.left.and.right") }
            ResellersView().tabItem { Label("Reseller", systemImage: "person.3.fill") }
            MoreView().tabItem { Label("Altro", systemImage: "ellipsis.circle.fill") }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var api: ATXAPI
    let stats: [(String,String,String)] = [("online","Online","dot.radiowaves.left.and.right"),("connections","Connessioni","network"),("total","Linee totali","person.2"),("expiring","In scadenza","clock"),("expired","Scadute","exclamationmark.circle"),("subresellers","Reseller","person.3")]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Bentornato,").foregroundStyle(.secondary)
                        Text(api.dashboard?["member"]?["username"]?.text ?? "AtlantiX").font(.largeTitle.bold())
                        Text("Crediti: \(api.dashboard?["member"]?["credits"]?.text ?? "—")").foregroundStyle(.cyan).fontWeight(.semibold)
                    }
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        ForEach(stats, id: \.0) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: item.2).foregroundStyle(.cyan)
                                Text(api.dashboard?["stats"]?[item.0]?.text ?? "—").font(.system(size: 30, weight: .bold, design: .rounded))
                                Text(item.1).font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(17).background(panel, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    Text("Ultime linee create").font(.title3.bold())
                    ForEach(Array((api.dashboard?["recent"]?.array ?? []).enumerated()), id: \.offset) { _, row in
                        InfoRow(title: row["username"]?.text ?? "—", subtitle: row["created"]?.text ?? "", symbol: "person.crop.circle")
                    }
                }.padding()
            }.background(atxBackgroundColor).navigationTitle("Panoramica")
                .toolbar { Button { Task { await api.refreshDashboard() } } label: { Image(systemName: "arrow.clockwise") } }
                .refreshable { await api.refreshDashboard() }
        }
    }
}

struct InfoRow: View {
    let title: String; let subtitle: String; let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.cyan).frame(width: 36)
            VStack(alignment: .leading, spacing: 4) { Text(title).fontWeight(.semibold); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            Spacer()
        }.padding(15).background(panel, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct LinesView: View {
    @EnvironmentObject var api: ATXAPI
    @State private var query = ""
    var body: some View {
        NavigationStack {
            ScrollView { LazyVStack(spacing: 10) {
                ForEach(Array(api.lines.enumerated()), id: \.offset) { _, line in
                    NavigationLink { ATXDetailView(title: line["username"]?.text ?? "Linea", value: line) } label: {
                        InfoRow(title: line["username"]?.text ?? "—", subtitle: "Scadenza: \(line["exp_date_formatted"]?.text ?? line["expiry"]?.text ?? "Consulta dettagli")", symbol: "play.rectangle")
                    }.buttonStyle(.plain)
                }
            }.padding() }.background(atxBackgroundColor).navigationTitle("Linee IPTV")
                .searchable(text: $query, prompt: "Cerca username")
                .onSubmit(of: .search) { Task { await api.loadLines(query: query) } }
                .task { await api.loadLines() }
                .refreshable { await api.loadLines(query: query) }
        }
    }
}
struct ConnectionsView: View {
    @EnvironmentObject var api: ATXAPI
    var body: some View {
        NavigationStack {
            ScrollView { LazyVStack(spacing: 10) {
                ForEach(Array(api.connections.enumerated()), id: \.offset) { _, row in
                    NavigationLink { ATXDetailView(title: row["username"]?.text ?? "Connessione", value: row) } label: {
                        InfoRow(title: row["username"]?.text ?? "—", subtitle: "\(row["channel"]?.text ?? "") · \(row["user_ip"]?.text ?? "")", symbol: "antenna.radiowaves.left.and.right")
                    }.buttonStyle(.plain)
                }
            }.padding() }.background(atxBackgroundColor).navigationTitle("Connessioni")
                .task { await api.loadConnections() }.refreshable { await api.loadConnections() }
        }
    }
}
struct ResellersView: View {
    @EnvironmentObject var api: ATXAPI
    var body: some View {
        NavigationStack {
            ScrollView { LazyVStack(spacing: 10) {
                ForEach(Array(api.resellers.enumerated()), id: \.offset) { _, row in
                    NavigationLink { ATXDetailView(title: row["username"]?.text ?? "Reseller", value: row) } label: {
                        InfoRow(title: row["username"]?.text ?? "—", subtitle: "Crediti: \(row["credits"]?.text ?? "—")", symbol: "person.2.circle")
                    }.buttonStyle(.plain)
                }
            }.padding() }.background(atxBackgroundColor).navigationTitle("Reseller")
                .task { await api.loadResellers() }.refreshable { await api.loadResellers() }
        }
    }
}
struct MoreView: View {
    @EnvironmentObject var api: ATXAPI
    var body: some View {
        NavigationStack {
            List {
                Section("Account") { LabeledContent("Pannello", value: "AtlantiX NXT"); LabeledContent("Server", value: "cms.axdash.biz") }
                Section("Gestione") {
                    NavigationLink("Movimenti crediti") { CreditsView() }
                    NavigationLink("Messaggi interni") { ATXModuleView(module: .messages) }
                    NavigationLink("Comunicati") { ATXModuleView(module: .announcements) }
                    NavigationLink("ATX Remote") { ATXModuleView(module: .remote) }
                    NavigationLink("Ricerca globale") { ATXModuleView(module: .search) }
                    NavigationLink("Attività connessioni") { ATXModuleView(module: .connectionLog) }
                    NavigationLink("Strumenti VPN") { ATXModuleView(module: .vpn) }
                    NavigationLink("AtlantiX Plus") { ATXModuleView(module: .plus) }
                    NavigationLink("Impostazioni MaxPlayer") { ATXModuleView(module: .maxplayer) }
                }
                Section { Button("Esci dall'account", role: .destructive) { Task { await api.logout() } } }
            }.navigationTitle("Altro")
        }
    }
}
struct CreditsView: View {
    @EnvironmentObject var api: ATXAPI
    var body: some View {
        ScrollView { LazyVStack(spacing: 10) {
            ForEach(Array(api.credits.enumerated()), id: \.offset) { _, row in
                InfoRow(title: "\(row["amount"]?.text ?? "—") crediti", subtitle: "\(row["actor_username"]?.text ?? "") → \(row["target_username"]?.text ?? "")", symbol: "creditcard")
            }
        }.padding() }.background(atxBackgroundColor).navigationTitle("Movimenti crediti")
            .task { await api.loadCredits() }.refreshable { await api.loadCredits() }
    }
}
