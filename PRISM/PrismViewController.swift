import UIKit
import WebKit

final class PrismViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
 private let home = URL(string: "https://api.prismdating.app/admin")!
 private var web: WKWebView!
 private let progress = UIProgressView(progressViewStyle: .bar)
 private let retry = UIButton(type: .system)
 private var observation: NSKeyValueObservation?
 private func trusted(_ url: URL) -> Bool { url.scheme == "https" && url.host == "api.prismdating.app" && (url.port == nil || url.port == 443) }
 override func viewDidLoad() {
  super.viewDidLoad(); title = "Prism Admin"
  view.backgroundColor = UIColor(red: 0.06, green: 0.08, blue: 0.11, alpha: 1)
  let appearance = UINavigationBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = view.backgroundColor; appearance.titleTextAttributes = [.foregroundColor: UIColor(red: 0.96, green: 0.8, blue: 0.49, alpha: 1)]
  navigationController?.navigationBar.standardAppearance = appearance; navigationController?.navigationBar.scrollEdgeAppearance = appearance; navigationController?.navigationBar.tintColor = .white
  navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refresh))
  navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(back))
  let config = WKWebViewConfiguration(); config.websiteDataStore = .default(); config.mediaTypesRequiringUserActionForPlayback = []
  web = WKWebView(frame: .zero, configuration: config); web.navigationDelegate = self; web.uiDelegate = self; web.isOpaque = false; web.backgroundColor = view.backgroundColor; web.allowsBackForwardNavigationGestures = true
  web.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(web)
  progress.translatesAutoresizingMaskIntoConstraints = false; progress.tintColor = UIColor(red: 0.96, green: 0.8, blue: 0.49, alpha: 1); view.addSubview(progress)
  retry.setTitle("Connessione non disponibile. Tocca per riprovare.", for: .normal); retry.titleLabel?.numberOfLines = 0; retry.titleLabel?.textAlignment = .center; retry.setTitleColor(.white, for: .normal); retry.backgroundColor = view.backgroundColor; retry.isHidden = true; retry.translatesAutoresizingMaskIntoConstraints = false; retry.addTarget(self, action: #selector(reloadHome), for: .touchUpInside); view.addSubview(retry)
  NSLayoutConstraint.activate([web.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),web.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),web.leadingAnchor.constraint(equalTo: view.leadingAnchor),web.trailingAnchor.constraint(equalTo: view.trailingAnchor),progress.topAnchor.constraint(equalTo: web.topAnchor),progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),progress.trailingAnchor.constraint(equalTo: view.trailingAnchor),retry.topAnchor.constraint(equalTo: web.topAnchor),retry.bottomAnchor.constraint(equalTo: web.bottomAnchor),retry.leadingAnchor.constraint(equalTo: web.leadingAnchor),retry.trailingAnchor.constraint(equalTo: web.trailingAnchor)])
  observation = web.observe(\.estimatedProgress, options: [.new]) { [weak self] web, _ in self?.progress.progress = Float(web.estimatedProgress); self?.progress.isHidden = web.estimatedProgress >= 1 }
  web.load(URLRequest(url: home))
 }
 @objc private func reloadHome() { retry.isHidden = true; web.load(URLRequest(url: home)) }
 @objc private func refresh() {
  web.evaluateJavaScript("!!document.querySelector('dialog[open]')") { [weak self] result, _ in
   guard let self = self else { return }
   if result as? Bool == true { let a = UIAlertController(title: "Aggiornare il pannello?", message: "Le modifiche non salvate nel popup saranno chiuse.", preferredStyle: .alert); a.addAction(UIAlertAction(title: "Annulla", style: .cancel)); a.addAction(UIAlertAction(title: "Aggiorna", style: .default) { _ in self.web.reload() }); self.present(a, animated: true) } else { self.web.reload() }
  }
 }
 @objc private func back() { web.evaluateJavaScript("(function(){var d=document.querySelector('dialog[open]');if(d){d.close();return true}var s=document.querySelector('.sidebar.open');if(s){s.classList.remove('open');return true}return false})()") { [weak self] value, _ in if value as? Bool != true, self?.web.canGoBack == true { self?.web.goBack() } } }
 func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
  guard let url = action.request.url else { decisionHandler(.cancel); return }
  if trusted(url) { decisionHandler(.allow) } else { if ["https", "mailto"].contains(url.scheme ?? "") { UIApplication.shared.open(url) }; decisionHandler(.cancel) }
 }
 func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { if let url = action.request.url, trusted(url) { webView.load(action.request) }; return nil }
 func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if (error as NSError).code != NSURLErrorCancelled { retry.isHidden = false } }
 func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { let a = UIAlertController(title: "Prism Admin", message: message, preferredStyle: .alert); a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() }); present(a, animated: true) }
 func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) { let a = UIAlertController(title: "Prism Admin", message: message, preferredStyle: .alert); a.addAction(UIAlertAction(title: "Annulla", style: .cancel) { _ in completionHandler(false) }); a.addAction(UIAlertAction(title: "Conferma", style: .default) { _ in completionHandler(true) }); present(a, animated: true) }
}
