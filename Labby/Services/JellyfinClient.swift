//
//  JellyfinClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

final class JellyfinClient: ServiceClient {
    let config: ServiceConfig

    // Reuse a single URLSession per client (respecting insecure TLS option)
    private lazy var session: URLSession = {
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

    // Stable device id for Jellyfin "MediaBrowser" header
    private static let deviceIdKey = "JellyfinClient.deviceId"
    private static func stableDeviceId() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: deviceIdKey)
        return newId
    }

    init(config: ServiceConfig) {
        self.config = config
    }

    func testConnection() async throws -> String {
        let authToken = try await authenticate()

        let url = try config.url(appending: "/System/Info")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct Info: Codable {
                let ProductName: String?
                let Version: String?
                let OperatingSystem: String?
            }
            let decoded = try JSONDecoder().decode(Info.self, from: data)
            let name = decoded.ProductName ?? "Jellyfin"
            let version = decoded.Version ?? "?"
            return "\(name) version: \(version)"
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    private func authenticate() async throws -> String {
        // API token path: read and return without network round-trip
        if case .apiToken(let secretKey) = config.auth {
            guard let tokenData = KeychainStorage.shared.loadSecret(forKey: secretKey),
                let token = String(data: tokenData, encoding: .utf8)
            else {
                throw ServiceError.missingSecret
            }
            return token
        }

        // Username/password flow: POST to /Users/AuthenticateByName
        let url = try config.url(appending: "/Users/AuthenticateByName")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let deviceId = Self.stableDeviceId()
        let authHeader =
            "MediaBrowser Client=\"Labby\", Device=\"iOS\", DeviceId=\"\(deviceId)\", Version=\"0.0.1\""
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        switch config.auth {
        case .usernamePassword(let username, let passwordKey):
            guard let passData = KeychainStorage.shared.loadSecret(forKey: passwordKey),
                let password = String(data: passData, encoding: .utf8)
            else {
                throw ServiceError.missingSecret
            }

            let authBody: [String: Any] = [
                "Username": username,
                "Pw": password,
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: authBody)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw ServiceError.unknown
            }

            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct AuthResponse: Codable {
                let AccessToken: String?
                let User: UserInfo?
            }
            struct UserInfo: Codable {
                let Name: String?
            }

            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let accessToken = authResponse.AccessToken else {
                throw ServiceError.unknown
            }

            return accessToken

        default:
            throw ServiceError.unknown
        }
    }

    func fetchStats() async throws -> ServiceStatsPayload {
        let authToken = try await authenticate()

        let url = try config.url(appending: "/Items/Counts")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct Counts: Codable {
                let MovieCount: Int?
                let SeriesCount: Int?
            }
            let decoded = try JSONDecoder().decode(Counts.self, from: data)
            let movies = decoded.MovieCount ?? 0
            let tvShows = decoded.SeriesCount ?? 0
            return .jellyfin(JellyfinStats(tvShows: tvShows, movies: movies))
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }
}
