//
//  QBittorrentClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

final class QBittorrentClient: ServiceClient {
    let config: ServiceConfig

    // In-memory cookie cache for this instance; internal so QBittorrent.swift extension can access it
    var _instanceCookie: String?

    // Reuse a single URLSession per client (respecting insecure TLS option)
    // Internal access (not private) so the QBittorrent.swift extension can reuse it
    lazy var session: URLSession = {
        if config.insecureSkipTLSVerify {
            return URLSession(
                configuration: .ephemeral,
                delegate: InsecureSessionDelegate(),
                delegateQueue: nil
            )
        } else {
            return URLSession(configuration: .ephemeral)
        }
    }()

    init(config: ServiceConfig) {
        self.config = config
    }

    func testConnection() async throws -> String {
        do {
            return try await _testConnection()
        } catch ServiceError.httpStatus(let code) where code == 403 {
            // Session expired -- force re-authenticate and retry once
            _instanceCookie = nil
            return try await _testConnection()
        }
    }

    private func _testConnection() async throws -> String {
        let sessionCookie = try await authenticate()

        let url = try config.url(appending: "/api/v2/app/version")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            if let versionString = String(data: data, encoding: .utf8) {
                return
                    "qBittorrent version: \(versionString.trimmingCharacters(in: .whitespacesAndNewlines))"
            } else {
                throw ServiceError.decoding(
                    NSError(
                        domain: "QBittorrent",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid version response"]
                    )
                )
            }
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func authenticate(forceReauth: Bool = false) async throws -> String {
        if !forceReauth, let cookie = _instanceCookie {
            return cookie
        }
        let url = try config.url(appending: "/api/v2/auth/login")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch config.auth {
        case .usernamePassword(let username, let passwordKey):
            guard
                let passData = KeychainStorage.shared.loadSecret(forKey: passwordKey),
                let password = String(data: passData, encoding: .utf8)
            else {
                throw ServiceError.missingSecret
            }

            var components = URLComponents()
            components.queryItems = [
                URLQueryItem(name: "username", value: username),
                URLQueryItem(name: "password", value: password),
            ]
            let formData = components.percentEncodedQuery ?? ""
            request.httpBody = formData.data(using: .utf8)

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ServiceError.unknown
            }

            // Require a real SID cookie; don't accept fake fallbacks
            if let setCookie = http.value(forHTTPHeaderField: "Set-Cookie")
                ?? headerValue(http, for: "set-cookie")
            {
                if let sidPair = extractSIDCookie(from: setCookie) {
                    _instanceCookie = sidPair
                    return sidPair
                }
            }

            // Some instances return a body text "Ok." but we still require SID cookie
            if let responseString = String(data: data, encoding: .utf8) {
                let trimmed = responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed == "Fails." {
                    throw ServiceError.httpStatus(401)
                }
            }

            // If we reach here, authentication didn't yield a cookie
            throw ServiceError.httpStatus(http.statusCode)

        default:
            throw ServiceError.unknown
        }
    }

    func fetchStats() async throws -> ServiceStatsPayload {
        do {
            return try await _fetchStats()
        } catch ServiceError.httpStatus(let code) where code == 403 {
            // Session expired -- force re-authenticate and retry once
            _instanceCookie = nil
            return try await _fetchStats()
        }
    }

    private func _fetchStats() async throws -> ServiceStatsPayload {
        let sessionCookie = try await authenticate()

        // Transfer info
        let transferURL = try config.url(appending: "/api/v2/transfer/info")
        var transferRequest = URLRequest(url: transferURL)
        transferRequest.httpMethod = "GET"
        transferRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        transferRequest.setValue(sessionCookie, forHTTPHeaderField: "Cookie")

        var uploadSpeed: Double = 0
        var downloadSpeed: Double = 0

        do {
            let (data, response) = try await session.data(for: transferRequest)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct TransferInfo: Codable {
                let dlInfoSpeed: Int?
                let upInfoSpeed: Int?
                let dlspeed: Int?
                let upspeed: Int?
                enum CodingKeys: String, CodingKey {
                    case dlInfoSpeed = "dl_info_speed"
                    case upInfoSpeed = "up_info_speed"
                    case dlspeed
                    case upspeed
                }
            }

            let info = try JSONDecoder().decode(TransferInfo.self, from: data)
            downloadSpeed = Double(info.dlInfoSpeed ?? info.dlspeed ?? 0)
            uploadSpeed = Double(info.upInfoSpeed ?? info.upspeed ?? 0)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }

        // Torrent states
        let torrentsURL = try config.url(appending: "/api/v2/torrents/info")
        var torrentsRequest = URLRequest(url: torrentsURL)
        torrentsRequest.httpMethod = "GET"
        torrentsRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        torrentsRequest.setValue(sessionCookie, forHTTPHeaderField: "Cookie")

        do {
            let (data, response) = try await session.data(for: torrentsRequest)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct Torrent: Codable {
                let state: String?
            }
            let torrents = try JSONDecoder().decode([Torrent].self, from: data)

            let downloadingStates: Set<String> = ["downloading", "forceddl", "metadl"]
            let seedingStates: Set<String> = ["uploading", "forcedup"]

            let downloading = torrents.reduce(0) { count, t in
                let s = (t.state ?? "").lowercased()
                return count + (downloadingStates.contains(s) ? 1 : 0)
            }

            let seeding = torrents.reduce(0) { count, t in
                let s = (t.state ?? "").lowercased()
                return count + (seedingStates.contains(s) ? 1 : 0)
            }

            let stats = QBittorrentStats(
                seeding: seeding,
                downloading: downloading,
                uploadSpeedBytesPerSec: uploadSpeed,
                downloadSpeedBytesPerSec: downloadSpeed
            )
            return .qbittorrent(stats)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    // Extract "SID=..." pair from Set-Cookie header value
    private func extractSIDCookie(from header: String) -> String? {
        guard let range = header.range(of: "SID=") else { return nil }
        let start = range.lowerBound
        let afterSID = header[start...]
        if let semicolon = afterSID.firstIndex(of: ";") {
            return String(afterSID[..<semicolon])
        } else {
            return String(afterSID)
        }
    }

    // Case-insensitive header lookup fallback using allHeaderFields
    private func headerValue(_ http: HTTPURLResponse, for key: String) -> String? {
        for (k, v) in http.allHeaderFields {
            if String(describing: k).lowercased() == key.lowercased() {
                return v as? String
            }
        }
        return nil
    }
}
