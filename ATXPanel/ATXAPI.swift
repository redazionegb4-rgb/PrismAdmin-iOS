import Foundation

struct APIResponse: Decodable {
    let success: Bool
    let message: String?
    let data: JSONValue?
}

indirect enum JSONValue: Decodable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else { self = .array(try c.decode([JSONValue].self)) }
    }
    subscript(_ key: String) -> JSONValue? { if case .object(let d) = self { return d[key] }; return nil }
    var array: [JSONValue] { if case .array(let v) = self { return v }; return [] }
    var text: String { switch self { case .string(let s): return s; case .number(let n): return n.rounded() == n ? String(Int(n)) : String(n); case .bool(let b): return b ? "Sì" : "No"; default: return "—" } }
    var int: Int { Int(text) ?? 0 }
}

@MainActor final class ATXAPI: ObservableObject {
    @Published var loggedIn = false
    @Published var busy = false
    @Published var error: String?
    @Published var dashboard: JSONValue?
    @Published var lines: [JSONValue] = []
    @Published var resellers: [JSONValue] = []
    @Published var connections: [JSONValue] = []
    @Published var credits: [JSONValue] = []
    private let base = URL(string: "https://cms.axdash.biz/")!
    private let session: URLSession
    init() {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = .shared
        cfg.httpShouldSetCookies = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: cfg)
    }
    func request(_ path: String, method: String = "GET", body: [String: String]? = nil) async throws -> JSONValue {
        guard let url = URL(string: path, relativeTo: base) else { throw ATXError.message("Indirizzo non valido") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (bytes, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ATXError.message("Risposta server non valida") }
        guard let result = try? JSONDecoder().decode(APIResponse.self, from: bytes) else {
            throw ATXError.message("Risposta non JSON (HTTP \(http.statusCode)) da \(url.path). Verifica che il file sia presente sul server.")
        }
        guard result.success else { throw ATXError.message(result.message ?? "Operazione non riuscita") }
        return result.data ?? .null
    }
    func login(username: String, password: String, code: String) async {
        busy = true; error = nil; defer { busy = false }
        do {
            // This lightweight server endpoint initializes the same PHP session and returns the CSRF token.
            let csrf = try await request("api/mobile/csrf.php")["csrf"]?.text ?? ""
            guard !csrf.isEmpty else { throw ATXError.message("Token di sessione mancante") }
            let result = try await request("api/auth/login.php", method: "POST", body: ["username":username,"password":password,"access_code":code,"csrf":csrf,"step":"login"])
            if result["need_otp"]?.text == "Sì" { throw ATXError.message("Questo account richiede 2FA. Contatta l'amministratore.") }
            loggedIn = true
            await refreshDashboard()
        } catch { self.error = error.localizedDescription }
    }
    func restore() async {
        do { dashboard = try await request("api/dashboard/overview.php"); loggedIn = true }
        catch { loggedIn = false }
    }
    func refreshDashboard() async { do { dashboard = try await request("api/dashboard/overview.php") } catch { self.error = error.localizedDescription } }
    func loadLines(query: String = "") async {
        do { let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""; lines = try await request("api/lines/list.php?page=1&per_page=50&q=\(q)")["rows"]?.array ?? [] }
        catch { self.error = error.localizedDescription }
    }
    func loadResellers() async { do { resellers = try await request("api/subresellers/list.php?page=1&per_page=50")["rows"]?.array ?? [] } catch { self.error = error.localizedDescription } }
    func loadConnections() async { do { connections = try await request("api/connections/list.php")["rows"]?.array ?? [] } catch { self.error = error.localizedDescription } }
    func loadCredits() async { do { credits = try await request("api/credits/log.php?page=1&per_page=50")["rows"]?.array ?? [] } catch { self.error = error.localizedDescription } }
    func logout() async {
        // Logout endpoint redirects to the web login; its session cookie is still invalidated.
        if let url = URL(string: "api/auth/logout.php", relativeTo: base) { _ = try? await session.data(from: url) }
        loggedIn = false; dashboard = nil; lines = []; resellers = []; connections = []; credits = []
    }
}
enum ATXError: LocalizedError { case message(String); var errorDescription: String? { if case .message(let s) = self { return s }; return nil } }
