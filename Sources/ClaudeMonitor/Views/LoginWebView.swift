import SwiftUI
import WebKit

struct LoginWebView: NSViewRepresentable {
    let onAuth: (_ cookie: String, _ orgId: String?) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.startObserving(webView)
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onAuth: onAuth)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onAuth: (_ cookie: String, _ orgId: String?) -> Void
        private var hasAuthed = false
        private var urlObservation: NSKeyValueObservation?

        init(onAuth: @escaping (_ cookie: String, _ orgId: String?) -> Void) {
            self.onAuth = onAuth
        }

        func startObserving(_ webView: WKWebView) {
            // KVO on URL — catches SPA navigation that didFinish misses
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] wv, change in
                guard let self, !self.hasAuthed else { return }
                let urlStr = wv.url?.absoluteString ?? "nil"
                print("[LOGIN] URL changed → \(urlStr)")
                self.checkIfLoggedIn(webView: wv)
            }
        }

        func stopObserving() {
            urlObservation?.invalidate()
            urlObservation = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let urlStr = webView.url?.absoluteString ?? "nil"
            print("[LOGIN] didFinish → \(urlStr)")
            checkIfLoggedIn(webView: webView)
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            print("[LOGIN] redirect → \(webView.url?.absoluteString ?? "nil")")
        }

        private func checkIfLoggedIn(webView: WKWebView) {
            guard let url = webView.url, !hasAuthed else { return }

            let host = url.host ?? ""
            let path = url.path

            let isClaudeAI = host == "claude.ai" || host.hasSuffix(".claude.ai")
            let isLoginPage = path == "/login" || path.starts(with: "/oauth") || path.starts(with: "/auth")
            let isLoggedIn = isClaudeAI && !isLoginPage && path != "/"

            print("[LOGIN] check: host=\(host) path=\(path) loggedIn=\(isLoggedIn)")

            if isLoggedIn {
                print("[LOGIN] Logged in! Waiting 1s for cookies to settle...")
                // Small delay to ensure cookies are fully set after redirect
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.extractAuth(from: webView)
                }
            }
        }

        private func extractAuth(from webView: WKWebView) {
            guard !hasAuthed else { return }

            let store = webView.configuration.websiteDataStore.httpCookieStore
            store.getAllCookies { [weak self] cookies in
                guard let self, !self.hasAuthed else { return }

                print("[LOGIN] Total cookies: \(cookies.count)")
                for c in cookies where c.domain.contains("claude") {
                    let preview = String(c.value.prefix(20)) + (c.value.count > 20 ? "..." : "")
                    print("[LOGIN]   \(c.domain) | \(c.name) = \(preview) (httpOnly=\(c.isHTTPOnly))")
                }

                let claudeCookies = cookies.filter { $0.domain.contains("claude.ai") }
                print("[LOGIN] Claude cookies: \(claudeCookies.count)")

                guard !claudeCookies.isEmpty else {
                    print("[LOGIN] No claude.ai cookies — retrying in 2s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.extractAuth(from: webView)
                    }
                    return
                }

                let cookieString = claudeCookies
                    .map { "\($0.name)=\($0.value)" }
                    .joined(separator: "; ")
                print("[LOGIN] Cookie string: \(cookieString.count) chars")

                // Find org_id from cookie or URL
                var orgId = claudeCookies
                    .first(where: { $0.name == "lastActiveOrg" })?
                    .value
                print("[LOGIN] lastActiveOrg: \(orgId ?? "NOT FOUND")")

                if orgId == nil, let url = webView.url {
                    orgId = Self.extractUUID(from: url.absoluteString)
                    print("[LOGIN] UUID from URL: \(orgId ?? "NOT FOUND")")
                }

                // Last resort: try to get org_id from page JS
                if orgId == nil {
                    print("[LOGIN] Trying JS extraction...")
                    webView.evaluateJavaScript(
                        "document.cookie"
                    ) { result, _ in
                        if let jsCookies = result as? String {
                            print("[LOGIN] JS cookies: \(jsCookies.prefix(100))...")
                            // JS document.cookie doesn't include httpOnly cookies
                            // but might have lastActiveOrg
                            let parts = jsCookies.components(separatedBy: "; ")
                            for part in parts {
                                let kv = part.components(separatedBy: "=")
                                if kv.count >= 2 && kv[0] == "lastActiveOrg" {
                                    orgId = kv[1]
                                    print("[LOGIN] Found org via JS: \(orgId!)")
                                }
                            }
                        }

                        self.hasAuthed = true
                        DispatchQueue.main.async {
                            print("[LOGIN] onAuth called (orgId=\(orgId ?? "nil"))")
                            self.onAuth(cookieString, orgId)
                        }
                    }
                } else {
                    self.hasAuthed = true
                    DispatchQueue.main.async {
                        print("[LOGIN] onAuth called (orgId=\(orgId ?? "nil"))")
                        self.onAuth(cookieString, orgId)
                    }
                }
            }
        }

        private static func extractUUID(from string: String) -> String? {
            guard let regex = try? NSRegularExpression(
                pattern: "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
                options: .caseInsensitive
            ) else { return nil }
            let range = NSRange(string.startIndex..., in: string)
            guard let match = regex.firstMatch(in: string, range: range) else { return nil }
            return (string as NSString).substring(with: match.range)
        }
    }
}
