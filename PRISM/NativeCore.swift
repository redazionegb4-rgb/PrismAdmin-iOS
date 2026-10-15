import SwiftUI
import CoreFoundation
import Security
import UserNotifications
import FirebaseMessaging

typealias Object = [String: Any]
func object(_ value: Any?) -> Object { value as? Object ?? [:] }
func objects(_ value: Any?) -> [Object] { value as? [Object] ?? [] }
func value(_ root: Object, _ path: String) -> Any? {
 var current: Any = root
 for key in path.split(separator: ".") { guard let next = (current as? Object)?[String(key)], !(next is NSNull) else { return nil }; current = next }
 return current
}
func string(_ value: Any?) -> String {
 guard let value = value, !(value is NSNull) else { return "" }
 if let string = value as? String { return string }
 return String(describing: value)
}
func put(_ root: inout Object, _ path: String, _ new: Any) {
 let keys = path.split(separator: ".").map(String.init)
 guard let head = keys.first else { return }
 if keys.count == 1 { root[head] = new; return }
 var child = object(root[head]); put(&child, keys.dropFirst().joined(separator: "."), new); root[head] = child
}
let gold = Color(red: 0.97, green: 0.79, blue: 0.43)
let canvas = Color(red: 0.035, green: 0.045, blue: 0.065)
let panel = Color(red: 0.075, green: 0.09, blue: 0.12)
struct Catalog {
 static let data: Object = {
  guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"), let bytes = try? Data(contentsOf: url), let json = try? JSONSerialization.jsonObject(with: bytes) else { return [:] }
  return object(json)
 }()
 static let modules = objects(data["modules"])
 static func module(_ id: String) -> Object { modules.first { string($0["id"]) == id } ?? [:] }
 static func label(_ key: String) -> String { string(object(data["labels"])[key]).isEmpty ? key.replacingOccurrences(of: "_", with: " ").capitalized : string(object(data["labels"])[key]) }
 static func display(_ data: Any?) -> String {
  let raw = string(data)
  if let b = data as? NSNumber, CFGetTypeID(b) == CFBooleanGetTypeID() { return b.boolValue ? "Sì" : "No" }
  let names = ["open":"Aperta", "closed":"Chiusa", "reviewing":"In gestione", "pending":"Da verificare", "approved":"Approvata", "rejected":"Rifiutata", "owner":"Titolare", "moderator":"Moderatore", "support":"Assistenza", "draft":"Bozza", "running":"In corso", "sent":"Inviata", "confirmed":"Confermato", "none":"Non attivo"]
  if let name = names[raw] { return name }
  if raw.contains("T"), let date = isoDate(raw) { return date.formatted(date: .abbreviated, time: .shortened) }
  return raw.isEmpty ? "Non inserito" : raw
 }
}
func isoDate(_ raw: String) -> Date? {
 let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
 return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
}
struct AdminFailure: LocalizedError { let message: String; var errorDescription: String? { message } }
enum SecureSession {
 static let service = "app.prism.admin.native.session"
 static func read() -> String {
  let q: Object = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"cookie",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
  var result: CFTypeRef?; guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let bytes = result as? Data else { return "" }; return String(data: bytes, encoding: .utf8) ?? ""
 }
 static func save(_ cookie: String) {
  let q: Object = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"cookie"]
  SecItemDelete(q as CFDictionary)
  if !cookie.isEmpty { var item = q; item[kSecValueData as String] = Data(cookie.utf8); item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly; SecItemAdd(item as CFDictionary, nil) }
 }
}
@MainActor final class AdminStore: ObservableObject {
 @Published var authenticated = false
 @Published var checking = true
 @Published var name = ""
 @Published var role = "owner"
 @Published var counts: Object = [:]
 @Published var selectedTab = "dashboard"
 @Published var managementPath: [String] = []
 @Published var alert = ""
 private var csrf = ""
 private var cookie = SecureSession.read()
 private var timer: Timer?
 private var pendingSection: String?
 let base = "https://api.prismdating.app"
 func allowed(_ module: Object) -> Bool {
  if role == "support" { return string(module["id"]) == "support" }
  return role == "owner" || module["owner"] as? Bool != true
 }
 func request(_ path: String, method: String = "GET", body: Object? = nil, bytes: Data? = nil) async throws -> Object {
  guard path.hasPrefix("/"), !path.contains(".."), let url = URL(string: base + "/admin/api" + path), url.host == "api.prismdating.app" else { throw AdminFailure(message: "Indirizzo non valido.") }
  var req = URLRequest(url: url); req.httpMethod = method; req.timeoutInterval = 30; req.httpShouldHandleCookies = false
  req.setValue(base, forHTTPHeaderField: "Origin"); req.setValue("application/json", forHTTPHeaderField: "Accept")
  if !cookie.isEmpty { req.setValue(cookie, forHTTPHeaderField: "Cookie") }
  if !csrf.isEmpty { req.setValue(csrf, forHTTPHeaderField: "X-Prism-CSRF") }
  if let bytes = bytes { req.httpBody = bytes; req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type") }
  else if let body = body { req.httpBody = try JSONSerialization.data(withJSONObject: body); req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
  let (data, response) = try await URLSession.shared.data(for: req)
  guard let http = response as? HTTPURLResponse else { throw AdminFailure(message: "Risposta del servizio non valida.") }
  let result = data.isEmpty ? [:] : object(try? JSONSerialization.jsonObject(with: data))
  if let header = http.value(forHTTPHeaderField: "Set-Cookie") {
   for entry in HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie":header], for: url) where entry.name == "__Host-prism_admin" {
    cookie = entry.value.isEmpty ? "" : entry.name + "=" + entry.value; SecureSession.save(cookie)
   }
  }
  guard (200..<300).contains(http.statusCode) else {
   if http.statusCode == 401 && path != "/login" { authenticated = false; csrf = ""; cookie = ""; SecureSession.save(""); pause() }
   let detail = result["detail"] as? String ?? objects(result["detail"]).map { string($0["msg"]) }.joined(separator: "\n")
   throw AdminFailure(message: detail.isEmpty ? "Operazione non riuscita. Riprova." : detail)
  }
  return result
 }
 func restore() async {
  defer { checking = false }
  guard !cookie.isEmpty else { return }
  do { accept(try await request("/session")); await refreshCounts(); await syncPush() } catch { if !cookie.isEmpty { alert = error.localizedDescription } }
 }
 func login(email: String, password: String) async throws {
  accept(try await request("/login", method: "POST", body: ["username":email.trimmingCharacters(in: .whitespacesAndNewlines),"password":password]))
  await refreshCounts(); await syncPush()
 }
 private func accept(_ response: Object) { csrf = string(response["csrf"]); name = string(response["name"]); role = string(response["role"]); authenticated = true; selectedTab = role == "support" ? "support" : "dashboard"; resume(); consumeSection() }
 func logout() async throws { _ = try await request("/logout", method:"POST"); cookie = ""; csrf = ""; SecureSession.save(""); authenticated = false; counts = [:]; pause() }
 func refreshCounts() async { guard authenticated else { return }; do { counts = object(try await request("/notifications")["counts"]) } catch { if authenticated { alert = error.localizedDescription } } }
 func resume() { pause(); guard authenticated else { return }; timer = Timer.scheduledTimer(withTimeInterval:30,repeats:true) { [weak self] _ in Task { @MainActor in await self?.refreshCounts(); await self?.syncPush() } } }
 func pause() { timer?.invalidate(); timer = nil }
 func open(_ section: String) { guard ["support","photos","reports"].contains(section) else { return }; pendingSection = section; consumeSection() }
 private func consumeSection() {
  guard authenticated, let section = pendingSection else { return }; pendingSection = nil
  guard allowed(Catalog.module(section)) else { return }
  if section == "reports" { selectedTab = "more"; managementPath = [section] } else { selectedTab = section }
 }
 func syncPush() async {
  guard authenticated, let token = UserDefaults.standard.string(forKey:"adminFCMToken"), !token.isEmpty else { return }
  let defaults = UserDefaults.standard; let id = defaults.string(forKey:"adminPushInstallation") ?? UUID().uuidString; defaults.set(id,forKey:"adminPushInstallation")
  let settings = await UNUserNotificationCenter.current().notificationSettings()
  do {
   if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional { _ = try await request("/push/devices",method:"POST",body:["token":token,"platform":"ios","installation":id]) }
   else { _ = try await request("/push/remove",method:"POST",body:["installation":id]) }
  } catch { /* Retry on next foreground sync; do not interrupt an administrator's form. */ }
 }
}
