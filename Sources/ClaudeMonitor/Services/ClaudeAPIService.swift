import Foundation

enum APIError: LocalizedError {
    case noCookie
    case noOrgId
    case unauthorized
    case networkError(Error)
    case decodingError(Error, String)
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noCookie: return "No session cookie configured"
        case .noOrgId: return "Could not find organization ID"
        case .unauthorized: return "Session expired — update your cookie"
        case .networkError(let e): return "Network: \(e.localizedDescription)"
        case .decodingError(_, let body): return "Unexpected API response: \(body.prefix(200))"
        case .httpError(let code, _): return "HTTP \(code)"
        }
    }

    var responseBody: String? {
        switch self {
        case .decodingError(_, let body): return body
        case .httpError(_, let body): return body.isEmpty ? nil : body
        default: return nil
        }
    }
}

actor ClaudeAPIService {
    static let shared = ClaudeAPIService()
    private let baseURL = "https://claude.ai"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func fetchUsage(orgId: String, cookie: String) async throws -> UsageResponse {
        try await request("/api/organizations/\(orgId)/usage", cookie: cookie)
    }

    func fetchCredits(orgId: String, cookie: String) async throws -> PrepaidCredits {
        try await request("/api/organizations/\(orgId)/prepaid/credits", cookie: cookie)
    }

    func fetchSubscription(orgId: String, cookie: String) async throws -> SubscriptionDetails {
        try await request("/api/organizations/\(orgId)/subscription_details", cookie: cookie)
    }

    func fetchOrgInfo(orgId: String, cookie: String) async throws -> OrganizationInfo {
        try await request("/api/organizations/\(orgId)", cookie: cookie)
    }

    func fetchRoutineBudget(orgId: String, cookie: String) async throws -> RoutineBudget {
        try await request(
            "/v1/code/routines/run-budget",
            cookie: cookie,
            extraHeaders: ["x-organization-uuid": orgId, "anthropic-beta": "ccr-triggers-2026-01-30"]
        )
    }

    /// Try multiple strategies to discover the org UUID
    func discoverOrgId(cookie: String) async throws -> String {
        // Strategy 1: /api/organizations/discoverable (might be array or wrapped)
        if let orgId = try? await discoverViaDiscoverable(cookie: cookie) {
            return orgId
        }

        // Strategy 2: /api/account_profile
        if let orgId = try? await discoverViaAccountProfile(cookie: cookie) {
            return orgId
        }

        // Strategy 3: raw fetch /api/organizations/discoverable and inspect
        let rawBody = try await rawRequest("/api/organizations/discoverable", cookie: cookie)
        throw APIError.decodingError(
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown format")),
            rawBody
        )
    }

    // MARK: - Org Discovery Strategies

    private func discoverViaDiscoverable(cookie: String) async throws -> String {
        // Try as plain array
        if let orgs: [DiscoverableOrg] = try? await request("/api/organizations/discoverable", cookie: cookie) {
            if let first = orgs.first { return first.uuid }
        }

        // Try as wrapped object
        struct WrappedOrgs: Decodable {
            let organizations: [DiscoverableOrg]?
            let data: [DiscoverableOrg]?
        }
        if let wrapped: WrappedOrgs = try? await request("/api/organizations/discoverable", cookie: cookie) {
            if let first = (wrapped.organizations ?? wrapped.data)?.first {
                return first.uuid
            }
        }

        throw APIError.noOrgId
    }

    private func discoverViaAccountProfile(cookie: String) async throws -> String {
        struct AccountProfile: Decodable {
            let uuid: String?
            let account: AccountInfo?
            let memberships: [Membership]?

            struct AccountInfo: Decodable {
                let memberships: [Membership]?
            }

            struct Membership: Decodable {
                let organization: OrgRef?

                struct OrgRef: Decodable {
                    let uuid: String?
                }
            }
        }

        let profile: AccountProfile = try await request("/api/account_profile", cookie: cookie)

        // Try memberships at top level
        if let orgId = profile.memberships?.first?.organization?.uuid {
            return orgId
        }

        // Try nested under account
        if let orgId = profile.account?.memberships?.first?.organization?.uuid {
            return orgId
        }

        throw APIError.noOrgId
    }

    // MARK: - Private

    private func request<T: Decodable>(
        _ path: String,
        cookie: String,
        extraHeaders: [String: String]? = nil
    ) async throws -> T {
        let (data, _) = try await rawData(path, cookie: cookie, extraHeaders: extraHeaders)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw APIError.decodingError(error, body)
        }
    }

    private func rawRequest(_ path: String, cookie: String) async throws -> String {
        let (data, _) = try await rawData(path, cookie: cookie)
        return String(data: data, encoding: .utf8) ?? "<binary>"
    }

    private func rawData(
        _ path: String,
        cookie: String,
        extraHeaders: [String: String]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let url = URL(string: baseURL + path)!
        var req = URLRequest(url: url)
        req.setValue(cookie, forHTTPHeaderField: "Cookie")
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        req.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")

        if let extraHeaders {
            for (k, v) in extraHeaders {
                req.setValue(v, forHTTPHeaderField: k)
            }
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw APIError.httpError(http.statusCode, body)
        }

        return (data, http)
    }
}
