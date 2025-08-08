import Foundation

final class PiHoleClient: ServiceClient {
    let config: ServiceConfig
    private var sid: String?
    private var csrf: String?
    private var sidExpiry: Date?
    // Persist session to avoid excessive session creation across app restarts
    private let sessionDefaults = UserDefaults.standard
    private let defaultsKeySID = "PiHoleClient.sid"
    private let defaultsKeyCSRF = "PiHoleClient.csrf"
    private let defaultsKeySidExpiry = "PiHoleClient.sidExpiry"

    init(config: ServiceConfig) {
        self.config = config
        self.loadSessionCache()
    }

    // MARK: - ServiceClient

    func testConnection() async throws -> String {
        let session = makeSession()
        try await ensureAuthenticated(session: session)
        let url = try makeURL(path: "api/info/version")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sid = sid {
            request.setValue(sid, forHTTPHeaderField: "X-FTL-SID")
            request.setValue("sid=\(sid)", forHTTPHeaderField: "Cookie")
            if let csrf = csrf {
                request.setValue(csrf, forHTTPHeaderField: "X-FTL-CSRF")
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ServiceError.network(
                    PiHoleHTTPError.httpStatus(code: http.statusCode, body: body))
            }

            // Parse version info (best-effort)
            var versionStr = "API reachable"
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let v = obj["version"] as? String {
                    versionStr = "v\(v)"
                } else if let core = obj["core"] as? String {
                    versionStr = core
                } else if let api = obj["api"] as? String {
                    versionStr = "API \(api)"
                } else if let ftl = obj["FTL"] as? String {
                    versionStr = "FTL \(ftl)"
                }
            }
            return "Pi-hole: \(versionStr)"
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func fetchStats() async throws -> ServiceStatsPayload {
        let session = makeSession()
        try await ensureAuthenticated(session: session)

        // 1) Get blocking status from v6 endpoint
        var blockingStatus: String? = nil
        do {
            let blockingURL = try makeURL(path: "api/dns/blocking")
            var blockingReq = URLRequest(url: blockingURL)
            blockingReq.httpMethod = "GET"
            blockingReq.setValue("application/json", forHTTPHeaderField: "Accept")
            if let sid = sid {
                blockingReq.setValue(sid, forHTTPHeaderField: "X-FTL-SID")
                blockingReq.setValue("sid=\(sid)", forHTTPHeaderField: "Cookie")
                if let csrf = csrf {
                    blockingReq.setValue(csrf, forHTTPHeaderField: "X-FTL-CSRF")
                }
            }
            let (bData, bResp) = try await session.data(for: blockingReq)
            if let http = bResp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                if let obj = try? JSONSerialization.jsonObject(with: bData) as? [String: Any],
                    let blocking = obj["blocking"] as? Bool
                {
                    blockingStatus = blocking ? "enabled" : "disabled"
                }
            }
        } catch {
            // Ignore blocking status errors; we'll still try to fetch summary stats below.
        }

        // 2) Try v6 summary endpoints (best-effort) before falling back to legacy
        let v6Candidates = [
            "api/stats/summary",
            "api/info/summary",
            "api/summary",
            "api/statistics/summary",
        ]

        for path in v6Candidates {
            do {
                let url = try makeURL(path: path)
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                if let sid = sid {
                    let redacted = sid.prefix(4) + "…"
                    print("[PiHoleClient] Using SID (redacted): \(redacted) for path \(path)")
                    request.setValue(sid, forHTTPHeaderField: "X-FTL-SID")
                    request.setValue("sid=\(sid)", forHTTPHeaderField: "Cookie")
                    if let csrf = csrf {
                        request.setValue(csrf, forHTTPHeaderField: "X-FTL-CSRF")
                    }
                }

                let (data, response) = try await session.data(for: request)
                let http = response as? HTTPURLResponse
                let bodyPreview = String(data: data, encoding: .utf8) ?? ""
                print(
                    "[PiHoleClient] v6 \(path) status=\(http?.statusCode ?? -1) body=\(bodyPreview.prefix(500))"
                )
                guard let httpResp = http, (200..<300).contains(httpResp.statusCode)
                else { continue }

                if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    obj["error"] == nil
                {
                    var stats = PiHoleStats(
                        status: blockingStatus,
                        domainsBeingBlocked: 0,
                        dnsQueriesToday: 0,
                        adsBlockedToday: 0,
                        adsPercentageToday: 0,
                        uniqueClients: 0,
                        queriesForwarded: 0,
                        queriesCached: 0,
                        gravityLastUpdatedRelative: nil,
                        gravityLastUpdatedAbsolute: nil
                    )

                    // Many v6 endpoints wrap data inside "data", with summary/stats nested
                    let payload: [String: Any] = {
                        let base = (obj["data"] as? [String: Any]) ?? obj
                        if let s = base["summary"] as? [String: Any] { return s }
                        if let s2 = base["statistics"] as? [String: Any] { return s2 }
                        return base
                    }()
                    // Map v6 /api/stats/summary nested structure
                    if let q = payload["queries"] as? [String: Any] {
                        if let v = q["total"] {
                            if let i = v as? Int {
                                stats.dnsQueriesToday = i
                            } else if let n = v as? NSNumber {
                                stats.dnsQueriesToday = n.intValue
                            } else if let d = v as? Double {
                                stats.dnsQueriesToday = Int(d)
                            } else if let s = v as? String, let i = Int(s) {
                                stats.dnsQueriesToday = i
                            }
                        }
                        if let v = q["blocked"] {
                            if let i = v as? Int {
                                stats.adsBlockedToday = i
                            } else if let n = v as? NSNumber {
                                stats.adsBlockedToday = n.intValue
                            } else if let d = v as? Double {
                                stats.adsBlockedToday = Int(d)
                            } else if let s = v as? String, let i = Int(s) {
                                stats.adsBlockedToday = i
                            }
                        }
                        if let v = q["percent_blocked"] {
                            if let d = v as? Double {
                                stats.adsPercentageToday = d
                            } else if let n = v as? NSNumber {
                                stats.adsPercentageToday = n.doubleValue
                            } else if let i = v as? Int {
                                stats.adsPercentageToday = Double(i)
                            } else if let s = v as? String, let d = Double(s) {
                                stats.adsPercentageToday = d
                            }
                        }
                        if let v = q["forwarded"] {
                            if let i = v as? Int {
                                stats.queriesForwarded = i
                            } else if let n = v as? NSNumber {
                                stats.queriesForwarded = n.intValue
                            } else if let d = v as? Double {
                                stats.queriesForwarded = Int(d)
                            } else if let s = v as? String, let i = Int(s) {
                                stats.queriesForwarded = i
                            }
                        }
                        if let v = q["cached"] {
                            if let i = v as? Int {
                                stats.queriesCached = i
                            } else if let n = v as? NSNumber {
                                stats.queriesCached = n.intValue
                            } else if let d = v as? Double {
                                stats.queriesCached = Int(d)
                            } else if let s = v as? String, let i = Int(s) {
                                stats.queriesCached = i
                            }
                        }
                    }
                    if let c = payload["clients"] as? [String: Any] {
                        if let v = c["total"] ?? c["active"] {
                            if let i = v as? Int {
                                stats.uniqueClients = i
                            } else if let n = v as? NSNumber {
                                stats.uniqueClients = n.intValue
                            } else if let d = v as? Double {
                                stats.uniqueClients = Int(d)
                            } else if let s = v as? String, let i = Int(s) {
                                stats.uniqueClients = i
                            }
                        }
                    }
                    if let g = payload["gravity"] as? [String: Any] {
                        if let v = g["domains_being_blocked"] {
                            if let i = v as? Int {
                                stats.domainsBeingBlocked = i
                            } else if let n = v as? NSNumber {
                                stats.domainsBeingBlocked = n.intValue
                            } else if let d = v as? Double {
                                stats.domainsBeingBlocked = Int(d)
                            } else if let s = v as? String, let i = Int(s) {
                                stats.domainsBeingBlocked = i
                            }
                        }
                        if let v = g["last_update"] {
                            if let i = v as? Int {
                                stats.gravityLastUpdatedAbsolute = i
                            } else if let n = v as? NSNumber {
                                stats.gravityLastUpdatedAbsolute = n.intValue
                            } else if let d = v as? Double {
                                stats.gravityLastUpdatedAbsolute = Int(d)
                            } else if let s = v as? String, let i = Int(s) {
                                stats.gravityLastUpdatedAbsolute = i
                            }
                        }
                    }

                    func intVal(_ keys: [String]) -> Int {
                        for k in keys {
                            if let v = payload[k] as? Int { return v }
                            if let v = payload[k] as? NSNumber { return v.intValue }
                            if let v = payload[k] as? Double { return Int(v) }
                            if let v = payload[k] as? String, let i = Int(v) { return i }
                        }
                        return 0
                    }

                    func dblVal(_ keys: [String]) -> Double {
                        for k in keys {
                            if let v = payload[k] as? Double { return v }
                            if let v = payload[k] as? NSNumber { return v.doubleValue }
                            if let v = payload[k] as? Int { return Double(v) }
                            if let v = payload[k] as? String, let d = Double(v) { return d }
                        }
                        return 0
                    }

                    // Populate using multiple possible key variants found in v6 docs/UI (fallback only if still zero)
                    if stats.dnsQueriesToday == 0 {
                        stats.dnsQueriesToday = intVal([
                            "dns_queries_today", "dns_queries", "queries", "total_queries",
                            "queries_today",
                        ])
                    }
                    if stats.adsBlockedToday == 0 {
                        stats.adsBlockedToday = intVal([
                            "ads_blocked_today", "ads_blocked", "blocked", "blocked_queries",
                        ])
                    }
                    if stats.adsPercentageToday == 0 {
                        stats.adsPercentageToday = dblVal([
                            "ads_percentage_today", "ads_percentage", "blocked_percentage",
                        ])
                    }
                    if stats.adsPercentageToday == 0 && stats.dnsQueriesToday > 0 {
                        stats.adsPercentageToday =
                            (stats.dnsQueriesToday == 0)
                            ? 0
                            : (Double(stats.adsBlockedToday) / Double(stats.dnsQueriesToday))
                                * 100.0
                    }
                    if stats.uniqueClients == 0 {
                        stats.uniqueClients = intVal(["unique_clients", "clients"])
                    }
                    if stats.queriesForwarded == 0 {
                        stats.queriesForwarded = intVal(["queries_forwarded", "forwarded"])
                    }
                    if stats.queriesCached == 0 {
                        stats.queriesCached = intVal(["queries_cached", "cached"])
                    }
                    if stats.domainsBeingBlocked == 0 {
                        stats.domainsBeingBlocked = intVal([
                            "domains_being_blocked", "domains_blocked", "domains",
                        ])
                    }

                    if let grav = payload["gravity_last_updated"] as? [String: Any] {
                        if let rel = grav["relative"] as? String {
                            stats.gravityLastUpdatedRelative = rel
                        }
                        if let abs = grav["absolute"] as? Int {
                            stats.gravityLastUpdatedAbsolute = abs
                        } else if let absS = grav["absolute"] as? String, let absI = Int(absS) {
                            stats.gravityLastUpdatedAbsolute = absI
                        }
                    }

                    // Accept if metrics are non-zero, or if expected keys are present (even if zero)
                    if stats.dnsQueriesToday > 0
                        || stats.adsBlockedToday > 0
                        || stats.domainsBeingBlocked > 0
                        || stats.uniqueClients > 0
                        || stats.queriesForwarded > 0
                        || stats.queriesCached > 0
                    {
                        print(
                            "[PiHoleClient] parsed stats (v6): total=\(stats.dnsQueriesToday) blocked=\(stats.adsBlockedToday) percent=\(stats.adsPercentageToday) clients=\(stats.uniqueClients) forwarded=\(stats.queriesForwarded) cached=\(stats.queriesCached) domains=\(stats.domainsBeingBlocked)"
                        )
                        return .pihole(stats)
                    } else {
                        let presenceKeys = [
                            "dns_queries_today", "dns_queries", "queries", "total_queries",
                            "queries_today",
                            "ads_blocked_today", "ads_blocked", "blocked", "blocked_queries",
                            "domains_being_blocked", "domains_blocked", "domains",
                        ]
                        let hasExpectedKeys = presenceKeys.contains { payload[$0] != nil }
                        let hasNestedStats =
                            payload["queries"] != nil || payload["clients"] != nil
                            || payload["gravity"] != nil
                        if hasExpectedKeys || hasNestedStats {
                            print(
                                "[PiHoleClient] parsed stats (v6): total=\(stats.dnsQueriesToday) blocked=\(stats.adsBlockedToday) percent=\(stats.adsPercentageToday) clients=\(stats.uniqueClients) forwarded=\(stats.queriesForwarded) cached=\(stats.queriesCached) domains=\(stats.domainsBeingBlocked)"
                            )
                            return .pihole(stats)
                        }
                    }
                }
            } catch {
                // Try next candidate
                continue
            }
        }

        // 3) Fallback to legacy /admin/api.php?summaryRaw (still works on many installs or downgraded v5)
        let legacyURL = try makeAPIURL(queryItems: try summaryRawQueryItems())
        var legacyReq = URLRequest(url: legacyURL)
        legacyReq.httpMethod = "GET"
        legacyReq.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sid = sid {
            legacyReq.setValue(sid, forHTTPHeaderField: "X-FTL-SID")
            legacyReq.setValue("sid=\(sid)", forHTTPHeaderField: "Cookie")
            if let csrf = csrf {
                legacyReq.setValue(csrf, forHTTPHeaderField: "X-FTL-CSRF")
            }
        }

        do {
            let (data, response) = try await session.data(for: legacyReq)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            let bodyPreview = String(data: data, encoding: .utf8) ?? ""
            print(
                "[PiHoleClient] legacy summaryRaw status=\(http.statusCode) body=\(bodyPreview.prefix(500))"
            )
            guard 200..<300 ~= http.statusCode else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ServiceError.network(
                    PiHoleHTTPError.httpStatus(code: http.statusCode, body: body))
            }

            let summary = try JSONDecoder().decode(PiHoleSummaryRaw.self, from: data)
            let hasAny =
                (summary.domainsBeingBlocked != nil)
                || (summary.dnsQueriesToday != nil)
                || (summary.adsBlockedToday != nil)
                || (summary.uniqueClients != nil)
                || (summary.queriesForwarded != nil)
                || (summary.queriesCached != nil)
            guard hasAny else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ServiceError.network(PiHoleHTTPError.httpStatus(code: 422, body: body))
            }
            var stats = PiHoleStats(raw: summary)
            if let s = blockingStatus { stats.status = s }
            print(
                "[PiHoleClient] parsed stats (legacy): total=\(stats.dnsQueriesToday) blocked=\(stats.adsBlockedToday) percent=\(stats.adsPercentageToday) clients=\(stats.uniqueClients) forwarded=\(stats.queriesForwarded) cached=\(stats.queriesCached) domains=\(stats.domainsBeingBlocked)"
            )
            return .pihole(stats)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    // MARK: - URL/session helpers

    private func makeSession() -> URLSession {
        if config.insecureSkipTLSVerify {
            return URLSession(
                configuration: .ephemeral, delegate: InsecureSessionDelegate(), delegateQueue: nil)
        } else {
            return URLSession(configuration: .ephemeral)
        }
    }

    private func makeAPIURL(queryItems: [URLQueryItem]) throws -> URL {
        guard var comps = URLComponents(string: config.baseURLString) else {
            throw ServiceError.invalidURL
        }

        // Build a path that includes /admin/api.php appended to any existing path,
        // avoiding a double "/admin" if the base already ends with it.
        // Examples:
        //   base: https://pi.hole               -> /admin/api.php
        //   base: https://host/base             -> /base/admin/api.php
        //   base: https://host/base/admin       -> /base/admin/api.php
        //   base: https://host/base/admin/      -> /base/admin/api.php
        var basePath = comps.path
        if basePath.hasSuffix("/admin/") {
            comps.path = normalizedPath(basePath + "api.php")
        } else if basePath.hasSuffix("/admin") {
            comps.path = normalizedPath(basePath + "/api.php")
        } else {
            if !basePath.hasSuffix("/") { basePath += "/" }
            comps.path = normalizedPath(basePath + "admin/api.php")
        }

        comps.queryItems = queryItems
        guard let url = comps.url else {
            throw ServiceError.invalidURL
        }
        return url
    }

    private func summaryRawQueryItems() throws -> [URLQueryItem] {
        var items: [URLQueryItem] = [URLQueryItem(name: "summaryRaw", value: nil)]
        if let sid = sid {
            items.append(URLQueryItem(name: "sid", value: sid))
        }
        return items
    }

    private func normalizedPath(_ path: String) -> String {
        // Replace multiple slashes with a single slash (excluding the scheme part which is not here)
        let cleaned = path.replacingOccurrences(of: "//", with: "/")
        // Ensure it starts with a slash
        if cleaned.hasPrefix("/") { return cleaned }
        return "/" + cleaned
    }

    // Build a URL by appending the given path to the base URL's path.
    // If the base path ends with "/admin" (or "/admin/"), strip it when building v6 /api paths.
    private func makeURL(path: String) throws -> URL {
        guard var comps = URLComponents(string: config.baseURLString) else {
            throw ServiceError.invalidURL
        }
        var basePath = comps.path
        if basePath.hasSuffix("/admin/") {
            basePath = String(basePath.dropLast("/admin/".count))
        } else if basePath.hasSuffix("/admin") {
            basePath = String(basePath.dropLast("/admin".count))
        }
        if !basePath.hasSuffix("/") { basePath += "/" }
        comps.path = normalizedPath(basePath + path)
        guard let url = comps.url else { throw ServiceError.invalidURL }
        return url
    }

    // Ensure we have a valid SID (authenticate via /api/auth if necessary)
    private func ensureAuthenticated(session: URLSession) async throws {
        if let expiry = sidExpiry, expiry > Date(), sid != nil {
            return
        }
        guard case .usernamePassword(_, let passwordKey) = config.auth else {
            // Pi-hole v6 requires password-based auth; other methods are unsupported here
            throw ServiceError.network(PiHoleClientError.passwordNotConfigured)
        }
        try await login(session: session, passwordKeychainKey: passwordKey)
    }

    private func login(session: URLSession, passwordKeychainKey: String) async throws {
        guard let passData = KeychainStorage.shared.loadSecret(forKey: passwordKeychainKey),
            let password = String(data: passData, encoding: .utf8),
            !password.isEmpty
        else {
            throw ServiceError.network(PiHoleClientError.passwordNotConfigured)
        }
        let url = try makeURL(path: "api/auth")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = ["password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
        var dataToParse = data
        if !(200..<300).contains(http.statusCode) {
            if http.statusCode == 400 || http.statusCode == 415 {
                // Retry with form-encoded body as some setups expect application/x-www-form-urlencoded
                var form = URLRequest(url: url)
                form.httpMethod = "POST"
                form.setValue(
                    "application/x-www-form-urlencoded; charset=utf-8",
                    forHTTPHeaderField: "Content-Type")
                form.setValue("application/json", forHTTPHeaderField: "Accept")
                let encoded =
                    "password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password)"
                form.httpBody = encoded.data(using: .utf8)
                let (d2, r2) = try await session.data(for: form)
                guard let http2 = r2 as? HTTPURLResponse else { throw ServiceError.unknown }
                if (200..<300).contains(http2.statusCode) {
                    dataToParse = d2
                } else {
                    if http2.statusCode == 401 { self.clearSessionCache() }
                    let body2 = String(data: d2, encoding: .utf8) ?? ""
                    throw ServiceError.network(
                        PiHoleHTTPError.httpStatus(code: http2.statusCode, body: body2)
                    )
                }
            } else {
                if http.statusCode == 401 { self.clearSessionCache() }
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ServiceError.network(
                    PiHoleHTTPError.httpStatus(code: http.statusCode, body: body)
                )
            }
        }
        let auth = try JSONDecoder().decode(PiHoleAuthResponse.self, from: dataToParse)
        if let s = auth.session, s.valid == true, let newSid = s.sid {
            self.sid = newSid
            self.csrf = s.csrf
            if let validity = s.validity {
                self.sidExpiry = Date().addingTimeInterval(TimeInterval(validity - 5))
            } else {
                self.sidExpiry = Date().addingTimeInterval(300)
            }
            self.saveSessionCache()
        } else {
            throw ServiceError.unknown
        }
    }
    // Session cache helpers
    private func loadSessionCache() {
        if let savedSID = sessionDefaults.string(forKey: defaultsKeySID) {
            self.sid = savedSID
        }
        if let savedCSRF = sessionDefaults.string(forKey: defaultsKeyCSRF) {
            self.csrf = savedCSRF
        }
        if let ts = sessionDefaults.object(forKey: defaultsKeySidExpiry) as? TimeInterval {
            let date = Date(timeIntervalSince1970: ts)
            // Only keep if still valid
            if date > Date() {
                self.sidExpiry = date
            } else {
                // Expired; clear any stale values
                clearSessionCache()
            }
        }
    }
    private func saveSessionCache() {
        if let sid = self.sid {
            sessionDefaults.set(sid, forKey: defaultsKeySID)
        }
        if let csrf = self.csrf {
            sessionDefaults.set(csrf, forKey: defaultsKeyCSRF)
        }
        if let expiry = self.sidExpiry {
            sessionDefaults.set(expiry.timeIntervalSince1970, forKey: defaultsKeySidExpiry)
        }
    }
    private func clearSessionCache() {
        self.sid = nil
        self.csrf = nil
        self.sidExpiry = nil
        sessionDefaults.removeObject(forKey: defaultsKeySID)
        sessionDefaults.removeObject(forKey: defaultsKeyCSRF)
        sessionDefaults.removeObject(forKey: defaultsKeySidExpiry)
    }
}

// MARK: - Models
// Client-local errors for clearer user messages
private enum PiHoleClientError: LocalizedError {
    case passwordNotConfigured
    var errorDescription: String? {
        "Pi-hole password is not configured. Open Services and set a password."
    }
}

private enum PiHoleHTTPError: LocalizedError {
    case httpStatus(code: Int, body: String)
    var errorDescription: String? {
        switch self {
        case .httpStatus(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}

// Decoding model for /api/auth (Pi-hole v6)
private struct PiHoleAuthResponse: Codable {
    struct Session: Codable {
        let valid: Bool
        let totp: Bool?
        let sid: String?
        let csrf: String?
        let validity: Int?
    }
    struct APIError: Codable {
        let key: String?
        let message: String?
        let hint: String?
    }
    let session: Session?
    let error: APIError?
    let took: Double?
}

// A compact representation of Pi-hole stats consumed by Home widgets.
extension PiHoleStats {
    // Convenience mapping from Pi-hole's summaryRaw payload
    fileprivate init(raw: PiHoleSummaryRaw) {
        self.init(
            status: raw.status,
            domainsBeingBlocked: raw.domainsBeingBlocked ?? 0,
            dnsQueriesToday: raw.dnsQueriesToday ?? 0,
            adsBlockedToday: raw.adsBlockedToday ?? 0,
            adsPercentageToday: raw.adsPercentageToday ?? 0,
            uniqueClients: raw.uniqueClients ?? 0,
            queriesForwarded: raw.queriesForwarded ?? 0,
            queriesCached: raw.queriesCached ?? 0,
            gravityLastUpdatedRelative: raw.gravityLastUpdated?.relative,
            gravityLastUpdatedAbsolute: raw.gravityLastUpdated?.absolute
        )
    }
}

// Decoding model for /admin/api.php?summaryRaw
private struct PiHoleSummaryRaw: Codable {
    // Common fields from /admin/api.php?summaryRaw
    // Names vary; we keep only the ones we need. Unknowns are ignored.
    let status: String?
    let domainsBeingBlocked: Int?
    let dnsQueriesToday: Int?
    let adsBlockedToday: Int?
    let adsPercentageToday: Double?
    let uniqueClients: Int?
    let queriesForwarded: Int?
    let queriesCached: Int?
    let gravityLastUpdated: GravityUpdated?

    // The gravity last updated section is itself an object:
    // {
    //   "file_exists": true,
    //   "absolute": 1691512345,
    //   "relative": "2 hours ago"
    // }
    struct GravityUpdated: Codable {
        let fileExists: Bool?
        let absolute: Int?
        let relative: String?

        enum CodingKeys: String, CodingKey {
            case fileExists = "file_exists"
            case absolute
            case relative
        }
    }

    // Map snake_case keys to camelCase
    enum CodingKeys: String, CodingKey {
        case status
        case domainsBeingBlocked = "domains_being_blocked"
        case dnsQueriesToday = "dns_queries_today"
        case adsBlockedToday = "ads_blocked_today"
        case adsPercentageToday = "ads_percentage_today"
        case uniqueClients = "unique_clients"
        case queriesForwarded = "queries_forwarded"
        case queriesCached = "queries_cached"
        case gravityLastUpdated = "gravity_last_updated"
    }
}
